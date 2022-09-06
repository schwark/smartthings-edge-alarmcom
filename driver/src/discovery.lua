local log = require "log"
local config = require("config")
local socket = require('socket')
local utils = require("st.utils")
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
    device_network_id = 'ALARMCOMPROXYPANEL',
    label = device.name,
    profile = config.DEVICE_PROFILE,
    manufacturer = device.manufacturer,
    model = device.model,
    vendor_provided_label = device.usn
  }
  return driver:try_create_device(metadata)
end

function discovery.get_device_details()
  local ip_port = nil
  local usn = nil
  local device_res = find_device()
  if device_res ~= nil then
    device_res = parse_ssdp(device_res)
    log.info(utils.stringify_table(device_res, "device_res"))
  end
  if device_res ~= nil and device_res.nt ~= nil and device_res.nt == config.URN then
    ip_port = device_res.location:match('http://([^/]+)')
    usn = device_res.usn
  end
  return ip_port, usn
end

function discovery.start(driver, opts, cons)
    local ip_port, usn = discovery.get_device_details()

    if ip_port ~= nil then
      log.info('===== panel found on network: '..ip_port)

      local device = {location = ip_port, name ='Alarm.com Panel', manufacturer = 'Alarm.com', model = 'Alarm.com Proxy', label = usn}
      return create_device(driver, device)
    end
    log.error('===== panel not found on network')
end

return discovery