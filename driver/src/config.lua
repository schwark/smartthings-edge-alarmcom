local config = {}
-- device info
-- NOTE: In the future this information
-- may be submitted through the Developer
-- Workspace to avoid hardcoded values.
config.PANEL_PROFILE='AlarmComSecuritySystem.vPx'
config.SENSOR_PROFILE='AlarmComContactSensor.v1'
config.PANEL_MODEL='Alarm.com Panel'
config.DEVICE_TYPE='LAN'
config.URN='urn:SmartThingsCommunity:device:GenericProxy:1'
-- SSDP Config
config.MC_ADDRESS='239.255.255.250'
config.MC_PORT=1900
config.MC_TIMEOUT=2
config.MSEARCH=table.concat({
  'M-SEARCH * HTTP/1.1',
  'HOST: 239.255.255.250:1900',
  'MAN: "ssdp:discover"',
  'MX: 4',
  'ST: '..config.URN
}, '\r\n')
config.SCHEDULE_PERIOD=300
config.ALARM_ID='ALARMCOMPROXYPANEL'
return config