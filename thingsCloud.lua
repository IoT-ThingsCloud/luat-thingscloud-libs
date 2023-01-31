-- 合宙模组 luat 接入 ThingsCloud 云平台的代码库
-- ThingsCloud MQTT 接入文档：https://docs.thingscloud.xyz/guide/connect-device/mqtt.html
require "log"
require "http"
require "mqtt"

module(..., package.seeall)

local projectKey = "" -- project_key
local accessToken = "" -- access_token
local typeKey = "" -- type_key
local host, port = "", 1883
local apiEndpoint = "" -- api endpoint
local mqttc = nil
local connected = false
local deviceInfo = {}

local certFetchRetryMax = 5
local certFetchRetryCnt = 0

local SUBSCRIBE_PREFIX = {
    ATTRIBUTES_GET_REPONSE = "attributes/get/response/",
    ATTRIBUTES_PUSH = "attributes/push",
    COMMAND_SEND = "command/send/",
    COMMAND_REPLY_RESPONSE = "command/reply/response/",
    DATA_SET = "data/",
    GW_ATTRIBUTES_PUSH = "gateway/attributes/push",
    GW_COMMAND_SEND = "gateway/command/send"
}
local EVENT_TYPES = {
    connect = true,
    attributes_report_response = true,
    attributes_get_response = true,
    attributes_push = true,
    command_send = true,
    command_reply_response = true,
    data_set = true,
    gw_attributes_push = true,
    gw_command_send = true
}
local CALLBACK = {}
local QUEUE = {
    PUBLISH = {}
}
local logger = {}
function logger.info(...)
    log.info("ThingsCloud", ...)
end

function on(eType, cb)
    if not eType or not EVENT_TYPES[eType] or type(cb) ~= "function" then
        return
    end
    CALLBACK[eType] = cb
    logger.info("on", eType)
end

local function cb(eType, ...)
    if not eType or not EVENT_TYPES[eType] or not CALLBACK[eType] then
        return
    end
    CALLBACK[eType](...)
    logger.info("cb", eType, ...)
end

local function mqttConnect()
    local retryCount = 0
    logger.info("thingscloud connecting...")
    while not mqttc:connect(host, port) do
        -- 重试连接
        logger.info("mqtt reconnecting...")
        sys.wait(1000 * 10)
        retryCount = retryCount + 1
        if (retryCount > 5) then
            cb("connect", false)
            return
        end
    end
    connected = true
    logger.info("thingscloud connected")

    subscribe("attributes/push")
    subscribe("attributes/get/response/+")
    subscribe("command/send/+")
    subscribe("command/reply/response/+")

    sys.taskInit(function()
        cb("connect", true)
    end)
end

function connect(param)
    if not param.host or not param.projectKey then
        logger.info("host or projectKey not found")
        return
    end
    host = param.host
    projectKey = param.projectKey

    if param.accessToken then
        accessToken = param.accessToken
        sys.taskInit(function()
            while not socket.isReady() do
                logger.info("wait socket ready...")
                sys.wait(2000)
            end
            sys.taskInit(procConnect)
        end)
    else
        if not param.apiEndpoint then
            logger.info("apiEndpoint not found")
            return
        end
        apiEndpoint = param.apiEndpoint
        if param.typeKey ~= "" or param.typeKey ~= nil then
            typeKey = param.typeKey
        end
        sys.taskInit(function()
            while not socket.isReady() do
                logger.info("wait socket ready...")
                sys.wait(2000)
            end
            sys.taskInit(fetchDeviceCert)
        end)
    end
end

function disconnect() 
    mqttc:disconnect()
end

-- 一型一密，使用IMEI作为DeviceKey，领取设备证书AccessToken
function fetchDeviceCert()
    local header = {}
    header["Project-Key"] = projectKey
    header["Content-Type"] = "application/json"
    local url = apiEndpoint .. "/device/v1/certificate"
    local deviceKey = misc.getImei()
    http.request("POST", url, nil, header, json.encode({
        device_key = deviceKey,
        type_key = typeKey
    }), 3000, function(result, prompt, head, body)
        log.info("http fetch cert:", deviceKey, result, prompt, head, body)
        if result and prompt == "200" then
            local data = json.decode(body)
            if data.result == 1 then
                deviceInfo = data.device
                accessToken = deviceInfo.access_token
                procConnect()
                return
            end
        end
        if certFetchRetryCnt < certFetchRetryMax then
            -- 重试
            certFetchRetryCnt = certFetchRetryCnt + 1
            sys.wait(1000 * 10)
            fetchDeviceCert()
        end
    end)
end

function procConnect()
    mqttc = mqtt.client(misc.getImei(), 300, accessToken, projectKey)
    mqttConnect()
    if not isConnected() then
        return
    end
    while true do
        if #QUEUE.PUBLISH > 0 then
            local item = table.remove(QUEUE.PUBLISH, 1)
            logger.info("publish", item.topic, item.data)
            if mqttc:publish(item.topic, item.data) then
                -- 
            end
        end

        local result, data, param = mqttc:receive(100, "pub_msg")
        if result then
            logger.info("mqtt:receive", data.topic or nil, data.payload or "nil")
            if (data.topic:sub(1, SUBSCRIBE_PREFIX.ATTRIBUTES_GET_REPONSE:len()) ==
                SUBSCRIBE_PREFIX.ATTRIBUTES_GET_REPONSE) then
                local response = json.decode(data.payload)
                local responseId = tonumber(data.topic:sub(SUBSCRIBE_PREFIX.ATTRIBUTES_GET_REPONSE:len() + 1))
                cb("attributes_get_response", response, responseId)
            elseif (data.topic == SUBSCRIBE_PREFIX.ATTRIBUTES_PUSH) then
                local response = json.decode(data.payload)
                cb("attributes_push", response)
            elseif (data.topic:sub(1, SUBSCRIBE_PREFIX.COMMAND_SEND:len()) == SUBSCRIBE_PREFIX.COMMAND_SEND) then
                local response = json.decode(data.payload)
                if response.method and response.params then
                    cb("command_send", response)
                end
            elseif (data.topic:sub(1, SUBSCRIBE_PREFIX.COMMAND_REPLY_RESPONSE:len()) ==
                SUBSCRIBE_PREFIX.COMMAND_REPLY_RESPONSE) then
                local response = json.decode(data.payload)
                local replyId = tonumber(data.topic:sub(SUBSCRIBE_PREFIX.COMMAND_REPLY_RESPONSE:len() + 1))
                cb("command_reply_response", response, replyId)
            elseif (data.topic:sub(1, SUBSCRIBE_PREFIX.DATA_SET:len()) == SUBSCRIBE_PREFIX.DATA_SET) then
                local tmp = split(data.topic, "/")
                if #tmp == 3 and tmp[3] == "set" then
                    local identifier = tmp[2]
                    cb("data_set", data.payload)
                end
            elseif (data.topic == SUBSCRIBE_PREFIX.GW_ATTRIBUTES_PUSH) then
                local response = json.decode(data.payload)
                cb("gw_attributes_push", response)
            elseif (data.topic == SUBSCRIBE_PREFIX.GW_COMMAND_SEND) then
                local response = json.decode(data.payload)
                cb("gw_command_send", response)
            end
        else
            if data == "pub_msg" then
            elseif data == "timeout" then
            elseif data == "CLOSED" then
                -- connected = false
                -- logger.info("mqtt closed")
                -- disconnect()
                -- sys.wait(3000)
                -- mqttConnect()
            else
                connected = false
                logger.info("mqtt disconnected")
                disconnect()
                sys.wait(3000)
                mqttConnect()
            end
        end
    end
end

function isConnected()
    return connected
end

local function insertPublishQueue(topic, data)
    if not connected then
        return
    end
    table.insert(QUEUE.PUBLISH, {
        topic = topic,
        data = data
    })
end

function subscribe(topic)
    if not connected then
        return
    end
    logger.info("subscribe", topic)
    mqttc:subscribe(topic)
end

function publish(topic, data)
    insertPublishQueue(topic, data)
end

function reportAttributes(tableData)
    insertPublishQueue("attributes", json.encode(tableData))
    sys.publish("QUEUE_PUBLISH", "ATTRIBUTES")
end

function getAttributes(attrsList, options)
    options = options or {}
    options.getId = options.getId or 1000
    local data = {
        keys = attrsList
    }
    if #attrsList == 0 then
        data = {}
    end
    insertPublishQueue("attributes/get/" .. tostring(options.getId), json.encode(data))
end

function reportEvent(event, options)
    options = options or {}
    options.eventId = options.eventId or 1000
    insertPublishQueue("event/report/" .. tostring(options.eventId), json.encode(event))
end

function replyCommand(commandReply, options)
    options = options or {}
    options.replyId = options.replyId or 1000
    insertPublishQueue("command/reply/" .. tostring(options.replyId), json.encode(commandReply))
end

function publishCustomTopic(identifier, data, options)
    if type(identifier) ~= "string" then
        return
    end
    insertPublishQueue("data/" .. identifier, data)
end

function getAccessToken()
    return accessToken
end

function isGateway()
    if deviceInfo.conn_type == "3" then
        return true
    end
    return false
end

function split(str, sep)
    local sep, fields = sep or ":", {}
    local pattern = string.format("([^%s]+)", sep)
    str:gsub(pattern, function(c)
        fields[#fields + 1] = c
    end)
    return fields
end
