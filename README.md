# ESP8266 Lua/NodeMCU module for Vindriktning PM1006 particle monitor

This repository contains a Lua module (`pm1006.lua`) as well as ESP8266/NodeMCU
MQTT gateway application example (`init.lua`) for the **PM1006** particulate
matter (PM2.5) sensor found in IKEA Vindriktning.

## Dependencies

pm1006.lua has been tested with Lua 5.1 on NodeMCU firmware 3.0.1 (Release
202112300746, integer build). Most practical applications (such as the example
in init.lua) require the following modules.

* gpio
* mqtt
* node
* softuart
* tmr
* uart
* wifi

## Setup

Connect the PM1006 sensor to your ESP8266/NodeMCU board as [documented by Hypfer](https://github.com/Hypfer/esp8266-vindriktning-particle-sensor).

If you use a different UART pin, you need to adjust the softuart.setup call in
the examples provided in this repository to reflect that change. Keep in mind
that some ESP8266 pins must have well-defined logic levels at boot time and may
therefore be unsuitable for PM1006 connection.

## Usage

Copy **pm1006.lua** to your NodeMCU board and set it up as follows.

```lua
pm1006 = require("pm1006")
port = softuart.setup(9600, nil, 2)
port:on("data", 20, uart_callback)

function uart_callback(data)
	local pm2_5 = pm1006.parse_frame(data)
	if pm25i ~= nil then
		-- pm2_5 contains PM2.5 value in µg/m³
	else
		-- invalid frame header or checksum
	end
end
```

See **init.lua** for an example. To use it, you need to create a **config.lua** file with WiFI and MQTT settings:

```lua
station_cfg.ssid = "..."
station_cfg.pwd = "..."
mqtt_host = "..."
```
