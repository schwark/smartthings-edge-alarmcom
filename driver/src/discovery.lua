local log = require "log"
local config = require("config")
local commands = require('commands')
local socket = require("socket")
local discovery = {}


local function create_panel(driver, device)
  log.info('===== creating Panel...')
  log.info('===== panel destination: '..(device.location or "nil"))
  local network_id = config.ALARM_ID
  local usn = device.usn or network_id
  -- device metadata table
  local metadata = {
    type = config.DEVICE_TYPE,
    device_network_id = network_id,
    label = device.name,
    profile = config.PANEL_PROFILE,
    manufacturer = device.manufacturer,
    model = device.model,
    vendor_provided_label = usn
  }
  return driver:try_create_device(metadata)
end

local function create_sensor(driver, device)
  log.info('===== creating sensor...'..device.name)
  local network_id = device.id
  local usn = device.id
  -- device metadata table
  local metadata = {
    type = config.DEVICE_TYPE,
    device_network_id = network_id,
    label = device.name,
    profile = config.SENSOR_PROFILE,
    manufacturer = device.manufacturer,
    model = device.model,
    vendor_provided_label = usn
  }
  return driver:try_create_device(metadata)
end

function discovery.start(driver, opts, cons)
    local panel_device = commands.get_panel_device(driver)
    if nil == panel_device then
      -- create the alarm panel
      local ip_port, usn = commands.get_device_details()

      if ip_port ~= nil then
        log.info('===== proxy found on network: '..ip_port)
      else
        log.error('===== proxy not found on network')
      end

      local device = {location = ip_port, name ='Alarm.com Panel', manufacturer = 'Alarm.com', model = config.PANEL_MODEL, label = usn}
      create_panel(driver, device)    
    else
      local sensors = assert(commands.handle_get_sensors(driver, panel_device))
      for id, item in pairs(sensors) do
        local device = {id = id, name = item.name, manufacturer = 'Alarm.com', model = 'Alarm.com Sensor'}
        create_sensor(driver, device)
        socket.sleep(2)
      end
    end
end

return discovery