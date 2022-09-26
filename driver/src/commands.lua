local log = require "log"
local capabilities = require "st.capabilities"
local Alarm = require("alarm")
local utils = require("st.utils")
local config = require("config")
local socket = require("socket")

local command_handlers = {}

local switch_states = {
    armAway = {switch = 'on', security = 'armedAway'}, 
    armStay = {switch = 'on', security = 'armedStay'}, 
    disarm = {switch = 'off', security = 'disarmed'}
}

-- SSDP Response parser
local function parse_ssdp(data)
    if not data then return nil end
    log.info("ssdp response:\n"..data)
    local res = {}
    res.status = data:sub(0, data:find('\r\n'))
    for k, v in data:gmatch('([%w-]+):[%s]-([%w+-:%. /=]+)') do
      res[k:lower()] = v
    end
    return res
  end
  
  local function is_my_device(device_res)
    if device_res ~= nil then
        local field = 'st'
        if device_res.nt then field = 'nt' end
        if device_res[field] ~= nil and device_res[field]:match(config.URN) then
            return true
        end   
    end
    return false
  end

  -- This function enables a UDP
  -- Socket and broadcast a single
  -- M-SEARCH request, i.e., it
  -- must be looped appart.
  function command_handlers.find_device()
    -- UDP socket initialization
    local upnp = socket.udp()
    upnp:setsockname('*', 0)
    upnp:setoption('broadcast', true)
    upnp:settimeout(config.MC_TIMEOUT)
    upnp:setoption('ip-add-membership', {multiaddr = config.MC_ADDRESS, interface = '0.0.0.0'})
    
    -- broadcasting request
    log.info('===== scanning network...')
    log.debug('sending.. '..config.MSEARCH)
    upnp:sendto(config.MSEARCH, config.MC_ADDRESS, config.MC_PORT)
    local ip = nil
    local res = nil
    local port = nil
    local usn = nil

    repeat
        -- Socket will wait n seconds
        -- based on the s:setoption(n)
        -- to receive a response back.
        res, ip = upnp:receivefrom()
        log.debug("got a response from "..(ip or "nil"))
        local device_res = res and parse_ssdp(res) or nil
        log.debug(res and utils.stringify_table(device_res) or "nil")

        if is_my_device(device_res) then
            port = device_res.location:match('http://[^:/]+:(%d+)')
            usn = device_res.usn
            log.info("SSDP found a proxy at "..ip..":"..port)
        else
            if "timeout" ~= ip then
                ip = nil
            end
        end
    until ip
  
    -- close udp socket
    upnp:close()
  
    return ip, port, usn
  end
  
  function command_handlers.get_panel_device(driver)
    local result = nil
    local devices = driver:get_devices()
    for i, each in ipairs(devices) do
      if config.ALARM_ID == each.device_network_id then
        result = each
        break
      end
    end
    return result
  end
  
function command_handlers.get_panel(device)
    local panel = device:get_field("panel")
    if not panel then
        local ip_port
        if device.preferences.proxyip and "" ~= device.preferences.proxyip then
            log.info("initializing proxy from preferences...")
            ip_port = device.preferences.proxyip..':'..(device.preferences.proxyport or '8081')
        else
            local ip, port, usn = command_handlers.find_device()
            ip_port = ip and port and ip..':'..port or nil
        end
        if ip_port ~= nil then
            log.info("initializing panel with "..ip_port)
            panel = Alarm({proxy = ip_port, username=device.preferences.username, password=device.preferences.password})            
            if panel then
                device:set_field("panel", panel)
            else
                log.error("unable to initialize panel")
            end
        end
    end
    local pref_username = tostring(device.preferences.username)
    local pref_password = tostring(device.preferences.password)
    if(panel and (panel.username ~= pref_username or panel.password ~= pref_password)) then
        panel.username = pref_username
        panel.password = pref_password
    end
    return panel
end

local function handle_command(driver, device, command, type)
    log.info("Send "..type.." command to device")
  
    local panel = assert(command_handlers.get_panel(device))
    if panel then
        local params = {}
        if device.preferences.bypass then
            params.bypass = true
        end
        if device.preferences.silent then
            params.silent = true
        end
        if device.preferences.nodelay then
            params.nodelay = true
        end
        log.debug("params are "..utils.stringify_table(params))
        local success = panel[type](panel,params)
        if success then            
            device:emit_event(capabilities.securitySystem.securitySystemStatus[switch_states[type].security]())
            device:emit_event(capabilities.switch.switch[switch_states[type].switch]())
        else
            log.error("command "..type.." failed")
        end
    end
end

function command_handlers.handle_armStay(driver, device, command)
    handle_command(driver, device, command, "armStay")
end

function command_handlers.handle_armAway(driver, device, command)
    handle_command(driver, device, command, "armAway")
end

function command_handlers.handle_disarm(driver, device, command)
    handle_command(driver, device, command, "disarm")
end

function command_handlers.handle_get_sensors(driver, device)
    local panel = assert(command_handlers.get_panel(device))
    local result = nil
    if panel then
        result = panel:get_sensors()
    end
    return result
end

function command_handlers.handle_refresh(driver, device, command)
    log.info("Send refresh command to device")
  
    local panel = assert(command_handlers.get_panel(device))
    if panel then
        local state = panel:get_state()
        if state and switch_states[state] then  
            log.info("Panel state is "..state)  
            if(device:get_latest_state('main','securitySystem', 'securitySystemStatus') ~= switch_states[state].security) then
                device:emit_event(capabilities.securitySystem.securitySystemStatus[switch_states[state].security]())
                device:emit_event(capabilities.switch.switch[switch_states[state].switch]())
            end
        else
            log.error("panel refresh failed")
        end

        local sensors = panel:get_sensors()
        if sensors then
            local devices = driver:get_devices()
            for i, each in ipairs(devices) do
                local id = each.device_network_id
                if sensors[id] then
                    local status = each:get_latest_state('main', 'contactSensor', 'contact')
                    if sensors[id].status and status ~= sensors[id].status then
                        each:emit_event(capabilities.contactSensor.contact[sensors[id].status]())
                    end
                end
            end
        end
    end   
end



return command_handlers