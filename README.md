# ESP8266 Lua/NodeMCU module for Vindriktning PM1006 PM sensors

[esp8266-nodemcu-pm1006](https://finalrewind.org/projects/esp8266-nodemcu-pm1006/)
provides an ESP8266 NodeMCU Lua module (`pm1006.lua`) as well as MQTT /
HomeAssistant / InfluxDB integration example (`init.lua`) for **PM1006**
particulate matter (PM2.5) sensors found in IKEA Vindriktning.

## Dependencies

**pm1006.lua** has been tested with Lua 5.1 on NodeMCU firmware 3.0.1 (Release
202112300746, integer build). It does not require any special modules.

Most practical applications (such as the example in init.lua) need the
following modules.

* gpio
* mqtt
* node
* softuart
* tmr
* wifi

## Setup

Connect the Vindriktning PCB to your ESP8266/NodeMCU board as [documented by
Hypfer](https://github.com/Hypfer/esp8266-vindriktning-particle-sensor):

* Vindriktning test point "+5V" → NodeMCU 5V (→ ESP8266 3V3 via LDO)
* Vindriktning test point "GND" → ESP8266/NodeMCU GND
* Vindriktning test point "REST" → NodeMCU D2 (ESP8266 GPIO4)

If you use a different UART pin, you need to adjust the `softuart.setup` call
in the examples provided in this repository to reflect that change. Keep in
mind that some ESP8266 pins must have well-defined logic levels at boot time
and may therefore be unsuitable for PM1006 connection.

## Usage

Copy **pm1006.lua** to your NodeMCU board and set it up as follows.

```lua
pm1006 = require("pm1006")
port = softuart.setup(9600, nil, 2)
port:on("data", 20, uart_callback)

function uart_callback(data)
	local pm2_5 = pm1006.parse_frame(data)
	if pm2_5 ~= nil then
		-- pm2_5 : PM2.5 concentration [µg/m³]
	else
		-- invalid frame header or checksum
	end
end
```

## Application Example

**init.lua** is an example application with optional HomeAssistant and InfluxDB integration.
It uses oversampling to smoothen readings, and only reports the average of every group of ten readings.
To use it, you need to create a **config.lua** file with WiFI and MQTT/InfluxDB settings:

```lua
station_cfg = {ssid = "...", pwd = "..."}
mqtt_host = "..."
influx_url = "..."
influx_attr = "..."
```

Both `mqtt_host` and `influx_url` are optional, though it does not make much sense to specify neither.
InfluxDB readings will be published as `vindriktning[influx_attr] pm2_5_ugm3=%d.%01d`.
So, unless `influx_attr = ''`, it must start with a comma, e.g. `influx_attr = ',device=' .. device_id`.

## Resources

Mirrors of the esp8266-nodemcu-pm1006 repository are maintained at the following locations:

* [Chaosdorf](https://chaosdorf.de/git/derf/esp8266-nodemcu-pm1006)
* [git.finalrewind.org](https://git.finalrewind.org/esp8266-nodemcu-pm1006/)
* [GitHub](https://github.com/derf/esp8266-nodemcu-pm1006)
