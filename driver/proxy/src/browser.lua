local cosock = require "cosock"
local https = cosock.asyncify 'socket.http'
local ltn12 = require "ltn12"
local json = require("st.json")
local log = require("log")

local function interp(s, tab)
    return (s:gsub('%%%((%a%w*)%)([-0-9%.]*[cdeEfgGiouxXsq])',
              function(k, fmt) return tab[k] and ("%"..fmt):format(tab[k]) or
                  '%('..k..')'..fmt end))
end
getmetatable("").__mod = interp

local M = {}; M.__index = M
local function constructor(self,o)
    o = o or {}
    o.jar = o.jar or {}
    o.state = o.state or {}
    o.agent = o.agent or "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/104.0.0.0 Safari/537.36"
    o.referer = nil
    o.proxy = o.proxy or nil
    o.proxy_domains = { ['www.alarm.com'] = '1' }
    setmetatable(o, M)
    return o
end
setmetatable(M, {__call = constructor})

local function urlencode(str)
    if str == nil then
      return
    end
    str = str:gsub("\n", "\r\n")
    str = str:gsub("([^%w _%%%-%.~])", function(c)
        return string.format("%%%02X", string.byte(c))
      end)
    str = str:gsub(" ", "+")
    return str
end

local function make_body(params, headers)
    local result = ""
    if headers['content-type'] and headers['content-type']:match('json') then
        result = json.encode(params)
    else
        for key, value in pairs(params) do
            result = result .. urlencode(key) .. "=" .. urlencode(value) .. "&"
        end
    end
    return result
end

local function parse_cookies(header, cookies)
    local cookies = cookies or {}
    if header then
        header = header:gsub('expires=[^;]+', "")
        for c in header:gmatch('([^,]+)') do
            local name, value = c:match('^%s*([%w%-%~%._%+%!]+)=([^;]*)')
            cookies[name] = value
        end
    end
    return cookies
end

local function make_cookies(cookies)
    local result = ""
    for name, value in pairs(cookies) do
        result = result .. name .. "=" .. value .. "; "
    end
    return result
end

function M:set_proxy(proxy)
    if proxy and "" ~= proxy then
        self.proxy = proxy
    end
end

function M:add_cookies(cookies)
    if not cookies then
        return
    end
    for name, value in pairs(cookies) do
        self.jar[name] = value
    end
end

function M:add_vars(vars)
    if not vars then
        return
    end
    for name, value in pairs(vars) do
        self.state[name] = value
    end
end

local function merge_vars(params, vars)
    for key, value in pairs(params) do
        if(vars[key] and not value) then
            params[key] = vars[key]
        end
    end
end

local function extract_vars(vars, response) 
    for key, _ in pairs(vars) do
        vars[key] = response:match('<input.- name=[\'"]' .. key .. '.- value=[\'"]([^\'"]*)')
    end
    return vars
end

function M:make_proxy_url(url)
    local result = url
    if self.proxy and not url.match(self.proxy) then
        local protocol, domain, path = url:match('(https?)://([^/]+)(.*)')
        local domain_prefix = self.proxy_domains[domain]
        if domain_prefix then
            result = 'http://'..self.proxy..'/'..domain_prefix..'/'..path
        end
    end
    log.debug("proxy url for "..url.." is "..result)
    return result
end

function M:make_absolute(base_url, url)
    local result = url
    if not url:match('^http') then -- not absolute url 
        if '/' == url:sub(1,1) then -- not relative path
            local protocol, domain, path = base_url:match('(https?)://([^/]+)(.*)')
            if self.proxy and domain:match(self.proxy) then
                local prefix
                prefix, path = path:match('/([^/]+)(/?.*)')
                domain = domain..'/'..prefix
            end
            result = protocol..'://'..domain..url
        else
            result = base_url:gsub('[^/]*$',url)
        end
    end
    log.debug("absolute url for "..url.." is "..result)
    return result
end

function M:cookie(name)
    return self.jar[name]
end

function M:request(args)
    local url = args.url
    local method = args.method or "GET"
    local headers = args.headers or {}
    local params = args.params or {}
    local cookies = args.cookies or {}
    local nofollow = args.nofollow or false
    local response, code

    self.add_cookies(cookies)
    while(nil ~= url) do
        merge_vars(params, self.state)
        response = ""
        code = nil
        local body = make_body(params, headers)
        local cookie_string = make_cookies(self.jar)
        if cookie_string ~= "" then
            headers['cookie'] = cookie_string
        end
        if self.agent then
            headers['user-agent'] = self.agent
        end
        if self.referer then
            headers['referer'] = self.referer
        end
        method = method:upper()

        local source
        if "GET" == method then
            if body and body ~= "" then
                url = url .. "?" .. body
            end
            source = nil
        else
            headers["content-type"] = headers["content-type"] or "application/x-www-form-urlencoded"
            headers["content-length"] = tostring(#body)
            source = ltn12.source.string(body)
        end
        local response_list = {}
        local result, rheaders, status
        log.info(method .. " " .. url)
        url = self:make_proxy_url(url)
        result, code, rheaders, status = https.request {
            url = url,
            method = method, 
            headers = headers,
            source = source,
            sink = ltn12.sink.table(response_list)
        }
        local temp_response
        if response_list then
            temp_response = table.concat(response_list)
        end
        if(nil ~= result and code >= 200 and code < 400) then
            parse_cookies(rheaders["set-cookie"], self.jar)
            if not nofollow and (code == 302 or code == 301) then
                url = self:make_absolute(url, rheaders['location'])
                log.info("redirecting to "..url)
            else
                if response_list then
                    if rheaders['content-type']:match('json')  then
                        log.info("decoding json response "..temp_response)
                        response = json.decode(temp_response)
                        log.info("got json object "..json.encode(response))
                    else
                        self.referer = url
                        response = temp_response
                        if response then
                            self.state = extract_vars(self.state, response)
                        end
                        log.info(self.state, "state")
                    end    
                end
                url = nil
            end
        else
            url = nil
        end
    end
    return response, code
end

return M