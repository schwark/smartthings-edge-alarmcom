local commands = require('commands')
local config = require('config')
local log = require('log')

local lifecycle_handler = {}

local function cancel_timers(driver, device)
  if not device.thread.timers then return end
  for timer in pairs(device.thread.timers) do
    device.thread:cancel_timer(timer)
  end
end

local function setup_polling(driver, device)
  local poll = device.preferences.poll or config.SCHEDULE_PERIOD
  if(device.model ~= config.PANEL_MODEL) or 0 == poll then return end
  cancel_timers(driver, device)
  log.info('setting up refresh timer every '..poll..' seconds')
  -- Refresh schedule
  device.thread:call_on_schedule(
    poll,
    function ()
      return commands.handle_refresh(driver, device)
    end,
    'Refresh schedule')
  return true
end

function lifecycle_handler.infoChanged(driver, device)
  if(setup_polling(driver, device)) then
    commands.handle_refresh(driver, device)
  end
end

function lifecycle_handler.init(driver, device)
  -------------------
  -- Set up scheduled
  -- services once the
  -- driver gets
  -- initialized.
  if(setup_polling(driver, device)) then
    commands.handle_refresh(driver, device)
  end
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

function lifecycle_handler.removed(driver, device)
  -- Remove Schedules created under
  -- device.thread to avoid unnecessary
  -- CPU processing.
  cancel_timers(driver, device)
end

return lifecycle_handler