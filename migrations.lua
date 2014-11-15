local function ColumnToSQL(column,data,fk )
    data.DataType = data.DataType or data.Kind
    return switch( data.DataType,{
        ['default'] = function()
            data.Extra = data.Extra or ""
            return string.format("%s %s %s",column,data.DataType,data.Extra)
        end,
        [DataType.VIRTUAL] = function()
                return switch(fk.Kind,{
                    [FK.hasMany] = function()
                            return {
                                fk.RefTable,
                                fk.RefFK,
                                string.format("FOREIGN KEY(%s) REFERENCES %s(%s)",fk.RefFK,fk.ParentTable,fk.ParentColumn),
                            }
                    end,
                    [FK.hasOne] = function()
                        return {
                            fk.RefTable,
                            fk.RefFK,
                            string.format("FOREIGN KEY(%s) REFERENCES %s(%s)",fk.RefFK,fk.ParentTable,fk.ParentColumn),
                            --string.format("%s NOT NULL",fk.RefFK)
                        }
                    end,
                    [FK.belongsTo] = function()
                        return {
                            fk.RefTable,
                            fk.FK,
                            string.format("FOREIGN KEY(%s) REFERENCES %s(%s)",fk.FK,fk.ParentTable,fk.ParentColumn),
                            --string.format("%s NOT NULL",fk.FK)
                        }
                    end
                })
        end,
        [DataType.COLLECTION] = function()
                return {
                        fk.RefTable,
                        fk.RefFK,
                        string.format("FOREIGN KEY(%s) REFERENCES %s(%s)",fk.RefFK,fk.ParentTable,fk.ParentColumn),
                    }
        end,
        [DataType.PRIMARY] = function()
            return string.format("%s %s",column,"INTEGER PRIMARY KEY")
        end
    }) or ""

end
local function TableToSQL(tablename,qrycolumns,foreingkeys)
    if foreingkeys ~= nil then
        for p,v in pairs(foreingkeys) do
            table.insert(foreingkeys,v)
            foreingkeys[p]=nil
        end
    end
    if foreingkeys ~= nil then
        tbqry = string.format("CREATE TABLE IF NOT EXISTS %s(%s , %s)",tablename, table.concat(qrycolumns," , "),table.concat(foreingkeys," , ") )
    else
        tbqry = string.format("CREATE TABLE IF NOT EXISTS %s(%s)",tablename, table.concat(qrycolumns," , ") )
    end
    return tbqry:gsub(" +"," "):gsub(" , ",", "):gsub(" %)","%)")

end
local Migrations = function(Schema,OldSchema,conn)
    if LORMVerbose.Migration then
        print("---")
        print("Migrations")
    end
    local qrycolumns={}
    local foreingkeys = {}
    --Builds a table wich contains every columndef
    for tablename,tabledef in pairs(Schema) do
        qrycolumns[tablename] = qrycolumns[tablename] or {}
        local schema = tabledef.__schema
        for col,column in pairs(schema) do
            switch(column.DataType,{
                ['default'] = function()
                    table.insert(qrycolumns[tablename],ColumnToSQL(col,column,nil ))
                end,
                [DataType.VIRTUAL] = function()
                --Get Foreing Key for OneToOne relation
                    local data = ColumnToSQL(col,column,Schema[tablename].__FK[col] )
                    foreingkeys[data[1]] = foreingkeys[data[1]] or {}
                    foreingkeys[data[1]][data[2]] = foreingkeys[data[1]][data[2]] or {}
                    foreingkeys[data[1]][data[2]] = data[3]
                end,
                [DataType.COLLECTION] = function()
                    local data = ColumnToSQL(col,column,Schema[tablename].__FK[col] )
                    print("You must place the foreing here")
                end

            })
        end
    end
    for tablename,tabledef in pairs(Schema) do
        if foreingkeys[tablename] ~= nil then
            for p, v in pairs(foreingkeys[tablename]) do
                --local a,b = next(v)
                table.insert(qrycolumns[tablename],p.." NOT NULL")
            end
        end
    end
    --After all the FKs are created now we create the query string
    for tablename, definition in pairs(Schema) do
        if OldSchema[tablename] == nil then
            local qry = TableToSQL(tablename,qrycolumns[tablename],foreingkeys[tablename])
            if conn:exec( qry ) == 1 then
                assert(false, string.format("Error executing: %s [%s]", qry, conn:errmsg() ))
            else
                if LORMVerbose.Migration then
                    print(qry)
                end
            end
        else
        --Dinamyc table currently disabled
        print("--Dinamyc table currently disabled")
        end
    end
    if LORMVerbose.Migration then
        print("---")
    end
end
return Migrations
