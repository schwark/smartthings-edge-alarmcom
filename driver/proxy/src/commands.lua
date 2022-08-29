local log = require "log"
local capabilities = require "st.capabilities"
local Alarm = require("alarm")

local command_handlers = {}

local switch_states = {armAway = 'on', armStay = 'on', disarm = 'off'}

function command_handlers.get_panel(device)
    local panel = device:get_field("panel")
    if not panel then
        panel = Alarm({location = device.device_network_id})            
        if panel then
            device:set_field("panel", panel)
        end
    end
    return panel
end

local function handle_command(driver, device, command, type)
    log.info("Send "..type.." command to device")
  
    local panel = assert(command_handlers.get_panel(device))
    if panel then
        local params = {}
        if command.args.bypassAll or device.preferences.bypass then
            params.bypass = true
        end
        if device.preferences.silent then
            params.silent = true
        end
        if device.preferences.nodelay then
            params.nodelay = true
        end
        local code = panel[type](panel,params)
        if 200 == code then            
            device:emit_event(capabilities.securitySystem[type]())
            device:emit_event(capabilities.switch.switch[switch_states[type]]())
        end
    end
end

function command_handlers.handle_armStay(driver, device, command)
    return handle_command(driver, device, command, "armStay")
end

function command_handlers.handle_armAway(driver, device, command)
    return handle_command(driver, device, command, "armAway")
end

function command_handlers.handle_disarm(driver, device, command)
    return handle_command(driver, device, command, "disarm")
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