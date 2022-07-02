--- 智能硬件接入 ThingsCloud MQTT 的示例代码

module(..., package.seeall)

require "utils"
require "pm"
require "misc"
require "http"
require "thingsCloud"

local project, version, rtos_version = _G.PROJECT, _G.VERSION, rtos.get_version()

-- 登录 ThingsCloud: https://console.thingscloud.xyz/
-- 复制设备证书和MQTT接入点地址，在设备详情页的【连接】页面可以找到。请勿泄露设备证书。
-- 以下请根据自己的项目修改为实际值
--------------------------------------------------------//
-- ProjectKey
local projectKey = ""
-- AccessToken
local accessToken = ""
-- MQTT 接入点，只需主机名部分。
local mqttHost = "bj-3-mqtt.iot-api.com"
--------------------------------------------------------//


-- 该示例通过模组ADC引脚，读取电压模拟量，上报云平台
local ADC_ID = 3
adc.open(ADC_ID)
-- 初始化全局变量，可用来保存ADC电压实时数据
local adc_value = 0
-- 读取电压的函数
local function readADC()
    -- adcval为number类型，表示adc的原始值，无效值为0xFFFF
    -- voltval为number类型，表示转换后的电压值，单位为毫伏，无效值为0xFFFF
    local adcval, voltval = adc.read(ADC_ID)
    adc_value = voltval
end
-- 定时调用以上函数，读取 ADC 电压值
sys.timerLoopStart(readADC, 1000)

-- 设备接收到云平台下发的属性时，触发该函数
local function onAttributesPush(attributes)
    log.info("recv attributes push", json.encode(attributes))
end

-- 设备接收到云平台下发的命令时，触发该函数
local function onCommandSend(command)
    log.info("recv command send", json.encode(command))
    if command.method == "ota" then
        sys.taskInit(
            function()
                -- 执行在线升级
                -- TODO

                sys.wait(5000)

                -- 完成任务后，回复平台
                thingsCloud.replyCommand(
                    {
                        method = "ota",
                        params = {
                            status = true
                        }
                    }
                )
            end
        )
    elseif command.method == "restart" then
        -- 调用模组的重启指令
        sys.restart("CLOUD_COMMAND_RESTART")
    elseif command.method == "other_name" then
    -- 执行其它自定义命令，触发硬件执行一些操作
    -- TODO
    -- callSomeFunction()
    end
end

-- 设备向云平台发送读取云端属性后，接收到云平台下发的命令时，触发该函数
-- attributes 是table结构的属性JSON数据
-- responseId 作为请求标识，通常可以不使用
local function onAttributesGetResponse(attributes, responseId)
    log.info("attributes get response", json.encode(attributes), responseId)

    if attributes.config_value1 then
    -- 获得云平台回复的属性值，实现相应的自定义逻辑
    -- TODO
    end
end

-- 设备成功连接云平台后，触发该函数
local function onConnect(result)
    if result then
        -- 当设备连接成功后，立即向云平台请求属性最新值，例如读取以下保存配置信息的属性。
        -- 参数是 table 数组格式，用来指定希望读取的属性名称，如果数组为空，可请求所有属性
        -- 云平台回复属性值，在事件 attributes_get_response 的回调函数中接收
        thingsCloud.getAttributes(
            {
                "config_value1",
                "config_value2"
            }
        )
    end
end

-- 设备接入云平台的初始化逻辑，在独立协程中完成
sys.taskInit(
    function()
        -- 连接云平台，内部支持判断网络可用性、MQTT自动重连
        -- 这里采用了设备一机一密方式，需要为每个设备固件单独写入证书。另外也支持一型一密，相同设备类型下的所有设备使用相同固件。
        thingsCloud.connect(
            {
                host = mqttHost,
                projectKey = projectKey,
                accessToken = accessToken
            }
        )

        -- 注册各类事件的回调函数，在回调函数中编写所需的硬件端操作逻辑
        thingsCloud.on("connect", onConnect)
        thingsCloud.on("attributes_push", onAttributesPush)
        thingsCloud.on("attributes_get_response", onAttributesGetResponse)
        thingsCloud.on("command_send", onCommandSend)
    end
)

-- 在独立的协程中上报数据到云平台，可实现固定时间间隔的上报。
-- 上报的数据，可在其它协程中读取，例如读取串口传感器数据
sys.taskInit(
    function()
        while true do
            -- 此处要判断是否已连接成功
            if thingsCloud.isConnected() then
                -- 上报属性
                local cur_ts = os.time() -- 读取当前设备本地时间戳
                thingsCloud.reportAttributes(
                    {
                        cur_ts = cur_ts,
                        adc_value = adc_value, -- 这里上报前边定时采集的 ADC 电压值全局变量
                        vbat = misc.getVbatt(),
                        rssi = net.getRssi()
                    }
                )

                -- 上报事件，可携带参数，参数不会写入云端属性
                thingsCloud.reportEvent(
                    {
                        method = "alarm",
                        params = {
                            msg = "",
                            code = 1390
                        }
                    }
                )

            -- 使用自定义 topic 上报数据，必须在设备类型中创建自定义数据流
            -- thingsCloud.publishCustomTopic("custom", "test")
            end
            -- 上报间隔时间为60秒
            -- 使用 ThingsCloud 免费版时，数据上报频率不要低于1分钟，否则可能会被断开连接，造成设备通信不稳定
            sys.wait(1000 * 60)
        end
    end
)
