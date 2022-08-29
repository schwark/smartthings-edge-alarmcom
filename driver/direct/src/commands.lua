local log = require "log"
local capabilities = require "st.capabilities"
local Alarm = require("alarm")

local command_handlers = {}

function command_handlers.get_panel(device)
    local panel = device:get_field("panel")
    if not panel then
        local username = device.preferences.username
        local password = device.preferences.password
        if username and username ~= "" and password and password ~= "" then
            panel = Alarm({username = username, password = password})            
        end
        if panel then
            device:set_field("panel", panel)
        end
    end
    return panel
end

function command_handlers.handle_armStay(driver, device, command)
    log.info("Send armStay command to device")
  
    local panel = assert(command_handlers.get_panel(device))
    if panel then
        local params = {}
        if command.args.bypassAll then
            params.bypass = true
        end
        if device.preferences.silent then
            params.silent = true
        end
        if device.preferences.nodelay then
            params.nodelay = true
        end
        local code = panel:armStay(params)
        if 200 == code then            
            device:emit_event(capabilities.securitySystem.armStay())
        end
    end
end

function command_handlers.handle_armAway(driver, device, command)
    log.info("Send armAway command to device")
  
    local panel = assert(command_handlers.get_panel(device))
    if panel then
        local params = {}
        if command.args.bypassAll then
            params.bypass = true
        end
        if device.preferences.silent then
            params.silent = true
        end
        if device.preferences.nodelay then
            params.nodelay = true
        end
        local code = panel:armAway(params)
        if 200 == code then            
            device:emit_event(capabilities.securitySystem.armAway())
        end
    end
end

function command_handlers.handle_disarm(driver, device, command)
    log.info("Send disarm command to device")
  
    local panel = assert(command_handlers.get_panel(device))
    if panel then
        local code = panel:disarm()
        if 200 == code then            
            device:emit_event(capabilities.securitySystem.disarm())
        end
    end   
end

function command_handlers.handle_refresh(driver, device, command)
    log.info("Send refresh command to device")
  
    local panel = assert(command_handlers.get_panel(device))
    if panel then
        local state = panel:get_state()
        if state then            
            device:emit_event(capabilities.securitySystem[state]())
        end
    end   
end



return command_handlers