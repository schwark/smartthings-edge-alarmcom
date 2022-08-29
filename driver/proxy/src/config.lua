local config = {}
-- device info
-- NOTE: In the future this information
-- may be submitted through the Developer
-- Workspace to avoid hardcoded values.
config.DEVICE_PROFILE='AlarmComSecuritySystem.vP'
config.DEVICE_TYPE='LAN'
-- SSDP Config
config.MC_ADDRESS='239.255.255.250'
config.MC_PORT=1900
config.MC_TIMEOUT=2
config.MSEARCH=table.concat({
  'M-SEARCH * HTTP/1.1',
  'HOST: 239.255.255.250:1900',
  'MAN: "ssdp:discover"',
  'MX: 4',
  'ST: urn:SmartThingsCommunity:device:AlarmComProxy:1'
}, '\r\n')
config.SCHEDULE_PERIOD=300
return config