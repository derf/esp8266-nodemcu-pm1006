publishing_mqtt = false
publishing_http = false

watchdog = tmr.create()
chip_id = string.format("%06X", node.chipid())
device_id = "esp8266_" .. chip_id

dofile("config.lua")

if mqtt_host then
	mqtt_prefix = "sensor/" .. device_id
	mqttclient = mqtt.Client(device_id, 120)
end

print("Vindriktning " .. chip_id)

ledpin = 4
gpio.mode(ledpin, gpio.OUTPUT)
gpio.write(ledpin, 0)

pm1006 = require("pm1006")

pm_values = {}

function log_restart()
	print("Network error " .. wifi.sta.status())
end

function setup_client()
	print("Connected")
	gpio.write(ledpin, 1)
	if mqtt_host then
		publishing_mqtt = true
		mqttclient:publish(mqtt_prefix .. "/state", "online", 0, 1, function(client)
			publishing_mqtt = false
		end)
	end
	port = softuart.setup(9600, nil, 2)
	port:on("data", 20, uart_callback)
end

function connect_mqtt()
	print("IP address: " .. wifi.sta.getip())
	print("Connecting to MQTT " .. mqtt_host)
	mqttclient:on("connect", hass_register)
	mqttclient:on("connfail", log_restart)
	mqttclient:on("offline", log_restart)
	mqttclient:lwt(mqtt_prefix .. "/state", "offline", 0, 1)
	mqttclient:connect(mqtt_host)
end

function connect_wifi()
	print("WiFi MAC: " .. wifi.sta.getmac())
	print("Connecting to ESSID " .. station_cfg.ssid)
	if mqtt_host then
		wifi.eventmon.register(wifi.eventmon.STA_GOT_IP, connect_mqtt)
	else
		wifi.eventmon.register(wifi.eventmon.STA_GOT_IP, setup_client)
	end
	wifi.eventmon.register(wifi.eventmon.STA_DHCP_TIMEOUT, log_restart)
	wifi.eventmon.register(wifi.eventmon.STA_DISCONNECTED, log_restart)
	wifi.setmode(wifi.STATION)
	wifi.sta.config(station_cfg)
	wifi.sta.connect()
end

function uart_callback(data)
	local pm2_5 = pm1006.parse_frame(data)
	if pm2_5 == nil then
		print("Invalid PM1006 frame")
		return
	else
		table.insert(pm_values, pm2_5)
		if table.getn(pm_values) == 10 then
			local pm_sum = 0
			for i, pm_value in ipairs(pm_values) do
				pm_sum = pm_sum + pm_value
			end
			local pm_int = pm_sum / 10
			local pm_frac = pm_sum % 10
			local json_str = string.format('{"pm2_5_ugm3": %d.%d, "rssi_dbm": %d}', pm_int, pm_frac, wifi.sta.getrssi())
			local influx_str = string.format("pm2_5_ugm3=%d.%d", pm_int, pm_frac)
			pm_values = {}
			if mqtt_host then
				if not publishing_mqtt then
					watchdog:start(true)
					publishing_mqtt = true
					gpio.write(ledpin, 0)
					mqttclient:publish(mqtt_prefix .. "/data", json_str, 0, 0, function(client)
						publishing_mqtt = false
						if influx_url and influx_attr and influx_str then
							publish_influx(influx_str)
						else
							gpio.write(ledpin, 1)
							collectgarbage()
						end
					end)
				end
			elseif influx_url and influx_attr and influx_str then
				publish_influx(influx_str)
			end
		end
	end
end

function publish_influx(payload)
	if not publishing_http then
		publishing_http = true
		http.post(influx_url, influx_header, "vindriktning" .. influx_attr .. " " .. payload, function(code, data)
			publishing_http = false
			gpio.write(ledpin, 1)
			collectgarbage()
		end)
	end
end

function hass_register()
	local hass_device = string.format('{"connections":[["mac","%s"]],"identifiers":["%s"],"model":"ESP8266 + PM1006","name":"Vindriktning %s","manufacturer":"derf"}', wifi.sta.getmac(), device_id, chip_id)
	local hass_entity_base = string.format('"device":%s,"state_topic":"%s/data","expire_after":90', hass_device, mqtt_prefix)
	local hass_pm2_5 = string.format('{%s,"name":"PM2.5","object_id":"%s_pm2_5","unique_id":"%s_pm2_5","device_class":"pm25","unit_of_measurement":"µg/m³","value_template":"{{value_json.pm2_5_ugm3}}"}', hass_entity_base, device_id, device_id)
	local hass_rssi = string.format('{%s,"name":"RSSI","object_id":"%s_rssi","unique_id":"%s_rssi","device_class":"signal_strength","unit_of_measurement":"dBm","value_template":"{{value_json.rssi_dbm}}","entity_category":"diagnostic"}', hass_entity_base, device_id, device_id)

	mqttclient:publish("homeassistant/sensor/" .. device_id .. "/pm2_5/config", hass_pm2_5, 0, 1, function(client)
		mqttclient:publish("homeassistant/sensor/" .. device_id .. "/rssi/config", hass_rssi, 0, 1, function(client)
			collectgarbage()
			setup_client()
		end)
	end)
end

watchdog:register(120 * 1000, tmr.ALARM_SEMI, node.restart)
watchdog:start()

connect_wifi()
