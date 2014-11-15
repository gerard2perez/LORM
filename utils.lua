local json = require("json")
function explode(div,str)
    if (div=='') then return false end
    local pos,arr = 0,{}
    -- for each divider found
    for st,sp in function() return string.find(str,div,pos,true) end do
    table.insert(arr,string.sub(str,pos,st-1)) -- Attach chars left of current divider
    pos = sp + 1 -- Jump past current divider
    end
    table.insert(arr,string.sub(str,pos)) -- Attach chars right of last divider
    return arr
end

rawnext = next
function next(t,k)
  local m = getmetatable(t)
  local n = m and m.__next or rawnext
  return n(t,k)
end

rawpairs = pairs
function pairs(t)
    local m = getmetatable(t)
    local n = rawpairs
    if m and m.__pairs then
        n = m.__pairs
    end
    return n(t)
end
--function pairs(t) return next,t,nil end
function switch(eval,cases)
    for p,v in pairs(cases) do
        if p == eval then
            return v()
        end
    end
    if cases['default'] then
        return cases['default']()
    else
        return nil,nil,nil
    end
end

function relp(file)
    return require (string.format("%s.%s",LORMPath,file) )
end

function cloneTable(source,target)
    for p,v in pairs(source) do
        target[p] = v
    end
end

function format(...)
    rawprint( string.format(...) )
end
rawprint = print

function url_encode(str)
    if (str) then
        str = string.gsub (str, "\n", "\r\n")
        str = string.gsub (str, "([^%w %-%_%.%~])",
            function (c) return string.format ("%%%02X", string.byte(c)) end)
        str = string.gsub (str, " ", "+")
    end
    return str
end

function log ( t )
    local ident = '\t'
    local print_r_cache={}

    local function sub_print_r(t,indent)
        if (print_r_cache[tostring(t)]) then
            rawprint(indent.."*"..tostring(t))
        else
            print_r_cache[tostring(t)]=true
            if (type(t)=="table") then
                for pos,val in rawpairs(t) do
                    if (type(val)=="table") then
                        format("%s[%s] => %s",indent,pos, tostring(val):gsub("table: ","").." {")
                        sub_print_r(val,indent..ident)
                        rawprint( (indent).."}")
                    elseif (type(val)=="string") then
                        format("%s[%s] => '%s'",indent,pos,val)
                    else
                        format("%s[%s] => %s",indent,pos,tostring(val))
                    end
                end
            else
                rawprint(indent..tostring(t))
            end
        end
    end

    if (type(t)=="table") then
        rawprint(tostring(t).." {")
        sub_print_r(t,ident)
        rawprint("}")
    else
        sub_print_r(t,'')
    end
    rawprint("")
end
function print ( t )
    local ident = '\t'
    local print_r_cache={}
    local function sub_print_r(t,indent)
        if (print_r_cache[tostring(t)]) then
            rawprint(indent.."*"..tostring(t))
        else
            print_r_cache[tostring(t)]=true
            if (type(t)=="table") then
                for pos,val in pairs(t) do
                    if (type(val)=="table") then
                        format("%s[%s] => %s",indent,pos, tostring(val):gsub("table: ","").." {")
                        sub_print_r(val,indent..ident)
                        rawprint( (indent).."}")
                    elseif (type(val)=="string") then
                        format("%s[%s] => '%s'",indent,pos,val)
                    else
                        format("%s[%s] => %s",indent,pos,tostring(val))
                    end
                end
            else
                rawprint(indent..tostring(t))
            end
        end
    end
    if (type(t)=="table") then
        rawprint(tostring(t).." {")
        sub_print_r(t,ident)
        rawprint("}")
    else
        sub_print_r(t,'')
    end
    rawprint("")
end

--
--Return's a Promise
--
function Request(url,method,params)
    local promise = Promise:new()
    local handler = function( ev )
        if ev.isError then
            ev.response = ev.response or {}
            LORMConfig.RestSync.fail(self,ev)
            promise:reject(self,ev)
        else
            if ev.status >= 200 and ev.status < 300 then
                switch( tostring(ev.status) ,{
                    ['default'] = function()
                        if ev.responseHeaders['Content-Type'] == 'application/json' then
                            ev.response = json.decode(ev.response) or {}
                        end
                    end,
                    ['204'] = function()
                            print("---")
                        ev.response = {}
                    end
                })
                --if LORMConfig.RestSync.success(self, json.decode( ev.response ) ) then
                promise:resolve(ev)

                --end
            else
                --LORMConfig.RestSync.fail(self,ev.response,ev.status)
                promise:reject(ev)
            end
        end
    end
    network.request( url, method or "GET", handler, params)
    return promise
end
