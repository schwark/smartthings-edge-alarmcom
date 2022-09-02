local log = require "log"
local capabilities = require "st.capabilities"
local Alarm = require("alarm")
local utils = require("st.utils")
local discovery = require("discovery")

local command_handlers = {}

local switch_states = {
    armAway = {switch = 'on', security = 'armedAway'}, 
    armStay = {switch = 'on', security = 'armedStay'}, 
    disarm = {switch = 'off', security = 'disarmed'}
}

function command_handlers.get_panel(device)
    local panel = device:get_field("panel")
    if not panel then
        local ip_port = discovery.get_device_details()
        if ip_port ~= nil then
            log.info("initializing panel with "..ip_port)
            panel = Alarm({location = ip_port})            
            if panel then
                device:set_field("panel", panel)
            else
                log.error("unable to initialize panel")
            end
        end
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

function command_handlers.handle_refresh(driver, device, command)
    log.info("Send refresh command to device")
  
    local panel = assert(command_handlers.get_panel(device))
    if panel then
        local state = panel:refresh()
        if state and switch_states[state] then  
            log.info("Panel state is "..state)  
            device:emit_event(capabilities.securitySystem.securitySystemStatus[switch_states[state].security]())
            device:emit_event(capabilities.switch.switch[switch_states[state].switch]())
        else
            log.error("refresh failed")
        end
    end   
end



return command_handlers