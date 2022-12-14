local Browser = require('browser')
local log = require("log")

local M = {}; M.__index = M
local function constructor(self,o)
    o = o or {}
    o.panel_id = o.panel_id or nil
    o.user_id = o.user_id or nil
    o.system_id = o.system_id or nil
    o.browser = o.browser or Browser({proxy = o.proxy})
    o.username = o.username or nil
    o.password = o.password or nil
    o.states = { "disarm", "armStay", "armAway" }
    o.sensors = o.sensors or false
    setmetatable(o, M)
    return o
end
setmetatable(M, {__call = constructor})

local function is_empty(var)
    return not var or "" == var or var:match('userdata:')
end

function M:login()
    if is_empty(self.username) or is_empty(self.password) then 
        return nil
    end
    log.info("logging in...")
    local response, code
    local browser = self.browser
    local vars = {
                __PREVIOUSPAGE = '',
			  	__VIEWSTATE = '',
			  	__VIEWSTATEGENERATOR = '',
			  	__EVENTVALIDATION = ''
    }
    browser:add_vars(vars)
    response, code = browser:request({ url = "https://www.alarm.com/login.aspx"})
    if "timeout" ~= tostring(code) and type(code) ~= "string" and code < 300 then
        local params = {
                 __PREVIOUSPAGE = "",
			  	__VIEWSTATE = "",
			  	__VIEWSTATEGENERATOR = "",
			  	__EVENTVALIDATION = "",
			  	IsFromNewSite = '1',
			  	JavaScriptTest =  '1',
			  	['ctl00$ContentPlaceHolder1$loginform$hidLoginID'] = '',
				['ctl00$ContentPlaceHolder1$loginform$txtUserName'] = self.username,
			  	txtPassword = self.password,
			  	['ctl00$ContentPlaceHolder1$loginform$signInButton'] = 'Login'
        }
        response, code = browser:request({ url = "https://www.alarm.com/web/Default.aspx", method = "POST", params = params } )        
    end
    return code
end

function M:init()
    log.info("getting panel id...")
    local response, code
    local browser = self.browser
    local user_id, system_id
    code = self:login()
    if not code then return false end
    if "timeout" ~= tostring(code) and type(code) ~= "string" and code < 300 then
        local headers = {AjaxRequestUniqueKey = browser:cookie('afg'), Accept = "application/vnd.api+json"}
        response, code = browser:request({ url = "https://www.alarm.com/web/api/identities", headers = headers} )                
        self.user_id = response['data'][1]['id']
        self.system_id = response['data'][1]['relationships']['selectedSystem']['data']['id']
        log.info(self.user_id, "user-id")
        log.info(self.system_id, "system-id")
    end
    local panel_id
    if "timeout" ~= tostring(code) and type(code) ~= "string" and code<300 then
        local headers = {AjaxRequestUniqueKey = browser:cookie('afg'), Accept = "application/vnd.api+json"}
        response, code = browser:request({ url = "https://www.alarm.com/web/api/systems/systems/"..self.system_id, headers = headers} )                
        self.panel_id = response['data']['relationships']['partitions']['data'][1]['id']
        log.info(self.panel_id, "panel-id")
    end    
    log.info(code)
    local success = type(code) ~= "string" and 200 == code
    assert(success)
    return success
end

function M:command(params)
    local params = params or {}
    if not self.panel_id and not self:init() then
        return nil
    end
    local response, code, headers
    local browser = self.browser
    local command = params.command
    log.info("executing "..command)
    local flags = {statePollOnly = false}
    if params.bypass then
        flags["forceBypass"] = true
    end
    if params.silent then
        flags["silentArming"] = true
    end
    if params.nodelay then
        flags["noEntryDelay"] = true
    end
    for i = 1, 2 do
        headers = {AjaxRequestUniqueKey = browser:cookie('afg'), Accept = "application/vnd.api+json"}
        headers['content-type'] = 'application/json'
        response, code = browser:request({ url = "https://www.alarm.com/web/api/devices/partitions/"..self.panel_id.."/"..command, method="POST", headers = headers, params = flags} )                
        if "timeout" ~= tostring(code) and 200 == code then
            break
        else
            self:login()
        end
    end
    return code
end

function M:get_sensors()
    log.info("getting sensors data...")
    local result = nil
    if not self.panel_id then
        self:init()
    end
    local response, code, headers
    local browser = self.browser
    local statuses = {"open", "closed"}
    
    for i = 1, 2 do
        headers = {AjaxRequestUniqueKey = browser:cookie('afg'), Accept = "application/vnd.api+json"}
        response, code = browser:request({ url = "https://www.alarm.com/web/api/devices/sensors", headers = headers} )                
        if "timeout" ~= tostring(code) and 200 == code then
            result = {}
            for i, item in ipairs(response['data']) do
                result[item.id] = {name = item.attributes.description, status=statuses[item.attributes.openClosedStatus]}
            end
            break
        else
            self:login()
        end
    end
    return result
end

function M:get_state()
    log.info("getting panel state...")
    local result = nil
    if not self.panel_id and not self:init() then
        return nil
    end
    local response, code, headers
    local browser = self.browser
    for i = 1, 2 do
        headers = {AjaxRequestUniqueKey = browser:cookie('afg'), Accept = "application/vnd.api+json"}
        response, code = browser:request({ url = "https://www.alarm.com/web/api/devices/partitions/"..self.panel_id, headers = headers} )                
        if "timeout" ~= tostring(code) and 200 == code then
            result = self.states[response['data']['attributes']['state']]
            break
        else
            self:login()
        end
    end
    return result
end

function M:armStay(params)
    --bypass
    --silent
    --nodelay
    local params = params or {}
    params["command"] = "armStay"
    return self:command(params)
end

function M:armAway(params)
    --bypass
    --silent
    --nodelay
    local params = params or {}
    params["command"] = "armAway"
    return self:command(params)
end

function M:disarm()
    local params = {}
    params["command"] = "disarm"
    return self:command(params)
end

return M