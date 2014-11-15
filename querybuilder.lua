local function builder(tablename)
    local query = {
        table = tablename,
        wherestatement="",
        selectstatement="",
        limitstatement="",
        _skip = 0,
        _take = 0
    }
    function query.update(entity,SchemaTable)
        local update = {}
        for p,v in pairs(SchemaTable.__schema) do
            table.insert(update,switch(v.DataType,{
                [DataType.TEXT] = function()
                    return string.format("%s='%s'",p,entity[p])
                end,
                [DataType.INTEGER] = function()
                    return string.format("%s=%s",p,entity[p])
                end,
                [DataType.VIRTUAL] = function()
                        return switch(SchemaTable.__FK[p].Kind,{
                            [FK.belongsTo] = function()
                                return string.format("%s=%s",SchemaTable.__FK[p].FK,entity[p][SchemaTable.__FK[p].ParentColumn] or 0)
                            end,
                            ['default'] = function()
                                return nil
                            end
                        })

                        --return columns.."",values..""
                end,
                ['default']=function()
                    return nil
                end
            }))

        end
        local qry = string.format("UPDATE %s SET %s WHERE %s=%s",SchemaTable.__name,table.concat(update,","),entity:Primary())
        return qry
    end
    function query.insert(entity,SchemaTable)
        local columns,values = "",""
        for p,v in pairs(SchemaTable.__schema) do
            columns,values = switch(v.DataType,{
                [DataType.TEXT] = function()
                    return string.format("%s,%s",columns,p),string.format("%s,'%s'",values,entity[p])
                end,
                [DataType.INTEGER] = function()

                    return columns..","..p,values..","..entity[p]
                end,
                [DataType.VIRTUAL] = function()
                        return switch(SchemaTable.__FK[p].Kind,{
                            [FK.belongsTo] = function()
                                return
                                    string.format("%s,%s",columns,SchemaTable.__FK[p].FK),
                                    string.format("%s,'%s'",values,entity[p][SchemaTable.__FK[p].ParentColumn] or 0)
                            end,
                            ['default'] = function()
                                return columns.."",values..""
                            end
                        })

                        --return columns.."",values..""
                end,
                ['default']=function()
                    return columns.."",values..""
                end
            });
        end
        columns,values = columns:gsub("^,",""),values:gsub("^,","")
        local qry = string.format("INSERT INTO %s(%s) values(%s);",tablename,columns,values)
        return qry
    end
    function query.build()
        query.select()
        query.limit()
        local qry = string.format("%s %s %s",query.selectstatement,query.wherestatement,query.limitstatement)
        query.selectstatement,query.wherestatement,query.limitstatement = "","",""
        query._skip,query._take = 0,0
        return qry
    end
    function query.skip(n)
        query._skip = n
        if query._take == 0 then
            query._take = 1
        end
        query.limit()
    end
    function query.take(n)
        query._take = n
        query.limit()
    end
    function query.limit(n)
        query._take = n or query._take
        if query._skip == 0 and query._take>0 then
            query.limitstatement =string.format("LIMIT %d",query._take)
        elseif query._skip>0 and query._take>0 then
            query.limitstatement =string.format("LIMIT %d, %d",query._skip,query._take)
        end
    end
    function query.select(columns)
        if query.selectstatement == "" then
            query.selectstatement = string.format("SELECT %s FROM %s",columns or "*",query.table)
        end
    end
    function query.where(column,operator,value )
        value = value or ""
        if query.wherestatement ~= "" then
            query.wherestatement = string.format("%s and %s %s '%s'",query.wherestatement,column,operator,value )
        else
            query.wherestatement = string.format("WHERE %s %s '%s'",column,operator,value )
        end
    end
    return query
end

return builder
