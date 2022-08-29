local capabilities = require "st.capabilities"
local Driver = require "st.driver"
local log = require "log"

local discovery = require('discovery')
local commands = require('commands')
local lifecycles = require('lifecycles')

local driver = Driver("Alarm.com driver", {
    discovery = discovery.start,
    lifecycle_handlers = lifecycles,
    supported_capabilities = {
        capabilities.switch,
        capabilities.securitySystem,
        capabilities.healthCheck,
        capabilities.refresh
    },    
    capability_handlers = {
      [capabilities.securitySystem.ID] = {
        [capabilities.securitySystem.commands.armAway.NAME] = commands.handle_armAway,
        [capabilities.securitySystem.commands.armStay.NAME] = commands.handle_armStay,
        [capabilities.securitySystem.commands.disarm.NAME] = commands.handle_disarm,
      },
      [capabilities.switch.ID] = {
        [capabilities.switch.commands.on.NAME] = commands.handle_armStay,
        [capabilities.switch.commands.off.NAME] = commands.handle_disarm,
      },
      [capabilities.refresh.ID] = {
        [capabilities.refresh.commands.refresh.NAME] = commands.handle_refresh,
      },
      [capabilities.healthCheck.ID] = {
        [capabilities.healthCheck.commands.ping.NAME] = commands.handle_refresh,
      },
    }
  })


--------------------
-- Initialize Driver
driver:run()