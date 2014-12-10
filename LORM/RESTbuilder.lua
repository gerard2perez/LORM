RESTbuilder = {}
setmetatable(RESTbuilder,{
    __call=function(host)
        local REST = {
            __host = "http://www.syncdemo.phalcon",
            __verb = {POST=4,GET=1,PUT=2,DELETE=3},
            __resources = {},
            __router={},
            __datatypes={
                json = {
                    ['Accept']='application/json',
                    ['Content-Type']= 'application/json'
                }
            }
        }
        setmetatable(REST.__router,{
            __index=function(t,key)
                if REST.__resources[key] == nil then
                    REST.__resources[key] = {}
                    setmetatable(REST.__resources[key],{
                        __call=function(t,accept,url,body,headers)
                            local _body = {}
                            local _url = {}

                            if body then
                                for p,v in pairs(body) do
                                    table.insert( _body,string.format('%s=%s',p,url_encode(v) or 'empty') )
                                end
                                body = table.concat(_body,"&")
                            end

                            url = url or ""
                            if url ~= "" and type(url) == "table" then
                                local u = url.path
                                url.path = nil
                                for p,v in pairs(url) do
                                    table.insert( _url,string.format('%s=%s',p,url_encode(v) or 'empty') )
                                end
                                url = u.."?"..table.concat(_url,"&")
                            end
                            local verb = REST.__router.verb
                            url = string.format("%s/%s%s",LORMConfig.RestSync.host,key:lower(),url)
                            log( string.format("%s\t%s",verb,url ) )
                            log(string.format("\tBody => %s",body))
                            local header = REST.__datatypes[accept]
                            for p,v in pairs(headers) do
                                header[p] = v
                            end
                            return Request(url,verb,{
                              headers=header,
                                body=body
                            })
                        end
                    })
                end
                return REST.__resources[key]
            end
        })

        setmetatable(REST, {
            __index = function(table,verb)
            verb = verb:upper()
                assert(table.__verb[verb],"Invalid HTTP verb.")
                table.__router.verb = verb
                return table.__router
            end
        })

        return REST
    end
})
return RESTbuilder
