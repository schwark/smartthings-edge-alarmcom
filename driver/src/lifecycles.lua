local commands = require('commands')
local config = require('config')

local lifecycle_handler = {}

function lifecycle_handler.init(driver, device)
  -------------------
  -- Set up scheduled
  -- services once the
  -- driver gets
  -- initialized.

  if(device.model ~= config.PANEL_MODEL) then return end
  -- Refresh schedule
  device.thread:call_on_schedule(
    config.SCHEDULE_PERIOD,
    function ()
      return commands.handle_refresh(driver, device)
    end,
    'Refresh schedule')
end

function lifecycle_handler.added(driver, device)
  -- Once device has been created
  -- at API level, poll its state
  -- via refresh command and send
  -- request to share server's ip
  -- and port to the device os it
  -- can communicate back.
  if(device.model ~= config.PANEL_MODEL) then return end
  commands.handle_refresh(driver, device)
end

function lifecycle_handler.removed(_, device)
  -- Remove Schedules created under
  -- device.thread to avoid unnecessary
  -- CPU processing.
  for timer in pairs(device.thread.timers) do
    device.thread:cancel_timer(timer)
  end
end

return lifecycle_handler