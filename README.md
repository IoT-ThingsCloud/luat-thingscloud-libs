这里是合宙模组 luat 方式接入 [ThingsCloud](https://www.thingscloud.xyz/) 云平台的 lib 库，以及示例代码。

支持 Air720UG/UH、Air724UG、Air722UG、Air820UG。

## 实现功能

该代码库面向对合宙luat开发框架有一定的掌握的硬件开发者。通过封装良好的 lib 库，5分钟即可将模组接入 ThingsCloud 云平台，实现以下功能：

- 上报模组端的数据，例如各种串口外设传感器的数据，可定时上报。
- 模组可实时接收云平台下发的数据，包括属性下发或命令下发。
- 支持自定义Topic，需结合云平台设备类型的自定义数据流。
- 支持一机一密身份验证，也支持一型一密，便于相同设备类型下的所有设备使用相同固件。
- 支持一型一密自动注册新设备，便于量产设备不用预注册。

## ThingsCloud 准备工作

- [快速上手控制台](https://www.thingscloud.xyz/docs/guide/quickstart/signin-console.html)
- [如何获得设备证书？](https://www.thingscloud.xyz/docs/guide/connect-device/device-certificate.html)
- [ThingsCloud MQTT 接入文档](https://docs.thingscloud.xyz/guide/connect-device/mqtt.html)

## 使用方法

### 安装

所有接口都封装在 `thingsCloud.lua` 这一个文件中，只需将 `thingsCloud.lua` 复制到自己的工程项目中，或放置在主程序可以找到的通用库路径下。

### 使用

## 快速运行示例

### examples/basic_connect

使用 luatools 或 VSCode LuatIDE，将以下脚本文件烧录到模组。

- `main.lua`
- `testBasic.lua` 
- `thingsCloud.lua`

`thingsCloud.lua` 是 lib 库文件，无需修改。

`testBasic.lua` 是示例程序，展示了基本用法，只需修改以下部分即可运行。

```lua
-- 登录 ThingsCloud: https://console.thingscloud.xyz/
-- 复制设备证书和MQTT接入点地址，在设备详情页的【连接】页面可以找到。请勿泄露设备证书。
-- 以下请根据自己的项目修改为实际值
--------------------------------------------------------//
-- ProjectKey
local projectKey = ""
-- AccessToken
local accessToken = ""
-- MQTT 接入点，只需主机名部分。
local mqttHost = ""
--------------------------------------------------------//
```

在 ThingsCloud 云平台创建设备后，在设备详情页的【连接】页面可以找到证书和MQTT接入点，如下：

![image](https://user-images.githubusercontent.com/97299260/148683169-b5ef8f41-0960-4298-8269-2b792179e8f2.png)

固件成功烧录后，模组即可成功接入平台，定时上报数据。

![image](https://user-images.githubusercontent.com/97299260/148683283-a25871b7-b7b7-4e88-9767-e863240aaa2c.png)

设备详情页显示设备属性实时数据。

![image](https://user-images.githubusercontent.com/97299260/148683057-797cc9dd-f7cd-4948-9b43-f03d944c0555.png)

可查看数据历史。

![image](https://user-images.githubusercontent.com/97299260/148683088-ae05c067-7700-4429-bed2-a8aef656518c.png)

下发属性

![image](https://user-images.githubusercontent.com/97299260/148683107-c6b0aff6-d5b1-4424-98cf-c4d7bdf3695f.png)

下发命令

![image](https://user-images.githubusercontent.com/97299260/148683123-487cdfc8-9615-42c7-a5b6-b18e936b94fc.png)

### examples/fetch_certificate

这是一型一密的示例程序，使用 luatools 或 VSCode LuatIDE，将以下脚本文件烧录到模组。

- `main.lua`
- `testBasic.lua` 
- `thingsCloud.lua`

`thingsCloud.lua` 是 lib 库文件，无需修改。

`testBasic.lua` 是示例程序，展示了基本用法，只需修改以下部分即可运行。

```lua
-- 登录 ThingsCloud: https://console.thingscloud.xyz/
-- 复制设备证书和MQTT接入点地址，在设备详情页的【连接】页面可以找到。请勿泄露设备证书。
-- 以下请根据自己的项目修改为实际值
--------------------------------------------------------//
-- ProjectKey
local projectKey = ""
-- MQTT 接入点，只需主机名部分。请根据自己的项目修改为实际值
local mqttHost = ""
-- API 接入点，用来请求设备证书。请根据自己的项目修改为实际值
local apiEndpoint = ""
--------------------------------------------------------//

```

设备启动后，会先使用模组的 IMEI 作为设备唯一标识 `DeviceKey` ，向云平台请求设备证书。

- 需要先在云平台预注册设备，将IMEI填写到设备唯一标识中。
- 如不希望预注册，而是当设备请求证书时自动创建设备，请使用下边的示例。


### examples/fetch_certificate_auto_create

这是在一型一密 `examples/fetch_certificate` 的基础上，支持自动创建设备。

使用 luatools 或 VSCode LuatIDE，将以下脚本文件烧录到模组。

- `main.lua`
- `testBasic.lua` 
- `thingsCloud.lua`

`thingsCloud.lua` 是 lib 库文件，无需修改。

`testBasic.lua` 是示例程序，展示了基本用法，只需修改以下部分即可运行。

```lua
-- 登录 ThingsCloud: https://console.thingscloud.xyz/
-- 复制设备证书和MQTT接入点地址，在设备详情页的【连接】页面可以找到。请勿泄露设备证书。
-- 以下请根据自己的项目修改为实际值
--------------------------------------------------------//
-- ProjectKey
local projectKey = ""
-- TypeKey
local typeKey = ""
-- MQTT 接入点，只需主机名部分。请根据自己的项目修改为实际值
local mqttHost = ""
-- API 接入点，用来请求设备证书。请根据自己的项目修改为实际值
local apiEndpoint = ""
--------------------------------------------------------//

```

设备启动后，会先使用模组的 IMEI 作为设备唯一标识 `DeviceKey` ，向云平台请求设备证书。如果该设备不存在，则会自动创建新设备。

- 需要先在 ThingsCloud 控制台中创建设备类型，拿到设备类型的 `TypeKey`，自动创建的设备将关联到该设备类型。
- 同时还需要在设备类型的设置中，开启【允许自动创建新设备】。
- 当然，还要确保项目中未达到设备数上限，如果超过，需要购买付费版扩容。




## 关于 ThingsCloud

ThingsCloud 是物联网设备统一接入平台和低代码应用开发平台。可以帮助任何需要数字化改造的行业客户，在极短的时间内搭建物联网应用，并适应不断变化的发展需求。ThingsCloud 支持智能传感器、执行器、控制器、智能硬件等设备接入，支持 MQTT/HTTP/TCP/Modbus/LoRa/Zigbee/WiFi/BLE 等通信协议，实现数据采集、分析、监控，还可以灵活配置各种规则，生成项目应用 SaaS 和用户应用 App，这一切无需任何云端代码开发。

- 官网：https://www.thingscloud.xyz/
- 控制台：https://console.thingscloud.xyz/
- 教程：https://docs.thingscloud.xyz/tutorials/
- 使用文档：https://docs.thingscloud.xyz
- 设备接入：https://docs.thingscloud.xyz/guide/connect-device/
- 博客：https://www.thingscloud.xyz/blog/
- B站：https://space.bilibili.com/1953347444


![articles/2023/20230112114634_afd61232cd029fca77eaebe67e12beaf.png](https://img-1300291923.cos.ap-beijing.myqcloud.com/articles/2023/20230112114634_afd61232cd029fca77eaebe67e12beaf.png)

![](https://img-1300291923.cos.ap-beijing.myqcloud.com/articles/2023/20230303162529_7d47018b2466053ef3af13dcfd23b703.png)

![](https://img-1300291923.cos.ap-beijing.myqcloud.com/articles/2023/20230303194054_fe9320028f7b499a18893b7a0d25b3c7.png)

![](https://img-1300291923.cos.ap-beijing.myqcloud.com/articles/2023/20230303163508_4b2e3b2052e282bcf2e36143fe90d101.png)

![](https://img-1300291923.cos.ap-beijing.myqcloud.com/articles/2023/20230303164617_c0f98e1ae66b5987aba3408faf86ac1d.png)

![](https://img-1300291923.cos.ap-beijing.myqcloud.com/articles/2023/20230303163103_40fe1d013e8d1d665bdd3cd0ae42adc0.png)

### 技术支持

联系 ThingsCloud 技术支持

![](https://img-1300291923.cos.ap-beijing.myqcloud.com/service/support-qrcode-wlww-1208.png)