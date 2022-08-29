local log = require "log"
local config = require("config")
local socket = require('socket')
local discovery = {}

-- SSDP Response parser
local function parse_ssdp(data)
  log.info("ssdp response:\n"..data)
  local res = {}
  res.status = data:sub(0, data:find('\r\n'))
  for k, v in data:gmatch('([%w-]+):[%s]-([%w+-:%. /=]+)') do
    res[k:lower()] = v
  end
  return res
end

-- This function enables a UDP
-- Socket and broadcast a single
-- M-SEARCH request, i.e., it
-- must be looped appart.
local function find_device()
  -- UDP socket initialization
  local upnp = socket.udp()
  upnp:setsockname('*', 0)
  upnp:setoption('broadcast', true)
  upnp:settimeout(config.MC_TIMEOUT)

  -- broadcasting request
  log.info('===== SCANNING NETWORK...')
  upnp:sendto(config.MSEARCH, config.MC_ADDRESS, config.MC_PORT)

  -- Socket will wait n seconds
  -- based on the s:setoption(n)
  -- to receive a response back.
  local res = upnp:receivefrom()

  -- close udp socket
  upnp:close()

  return res
end

local function create_device(driver, device)
  log.info('===== CREATING DEVICE...')
  log.info('===== DEVICE DESTINATION ADDRESS: '..device.location)
  -- device metadata table
  local metadata = {
    type = config.DEVICE_TYPE,
    device_network_id = device.location,
    label = device.name,
    profile = config.DEVICE_PROFILE,
    manufacturer = device.manufacturer,
    model = device.model,
    vendor_provided_label = device.usn
  }
  return driver:try_create_device(metadata)
end

function discovery.start(driver, opts, cons)
  while true do
    local device_res = find_device()

    if device_res ~= nil then
      device_res = parse_ssdp(device_res)
      log.info('===== DEVICE FOUND IN NETWORK...')
      log.info('===== DEVICE DESCRIPTION AT: '..device_res.location)
      local ip_port = device_res.location:match('http://([^/]+)')

      local device = {location = ip_port, name ='Alarm.com Panel', manufacturer = 'Alarm.com', model = 'Alarm.com Proxy', label = device_res.usn}
      return create_device(driver, device)
    end
    log.error('===== DEVICE NOT FOUND IN NETWORK')
  end
end

return discovery