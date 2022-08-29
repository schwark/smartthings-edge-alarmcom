local Browser = require('browser')
local log = require("log")

local M = {}; M.__index = M
local function constructor(self,o)
    o = o or {}
    o.browser = o.browser or Browser()
    o.states = { "disarm", "armStay", "armAway" }
    if o.location then
        o.base = 'http://'..o.location..'/'        
    else
        o.base = nil
    end
    setmetatable(o, M)
    return o
end
setmetatable(M, {__call = constructor})

function M:command(command, params)
    local result = nil
    local params = params or {}
    local response, code
    local browser = self.browser
    log.info("executing "..command)
    local flags = {}
    local headers = {}
    headers['content-type'] = 'application/json'
    if params.bypass then
        flags["bypass"] = true
    end
    if params.silent then
        flags["silent"] = true
    end
    if params.nodelay then
        flags["nodelay"] = true
    end
    response, code = browser:request({ url = self.base..command, method="POST", params = flags, headers = headers} )                
    if(200 == code and "table" == type(response)) then
        result = response.status            
        log.info(command.." got response status result "..result)
    else
        log.error(command.." request failed with error code "..code)
    end
    return result
end

function M:armStay(params)
    --bypass
    --silent
    --nodelay
    local params = params or {}
    return self:command("armStay", params)
end

function M:armAway(params)
    --bypass
    --silent
    --nodelay
    local params = params or {}
    return self:command("armAway", params)
end

function M:disarm()
    return self:command("disarm")
end

function M:refresh()
    return self:command("status")
end

return M