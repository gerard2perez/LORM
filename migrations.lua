local function mout(data)
    if LORMVerbose.Migration then
        log_to_tab("Migrations",data)
    end
end
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
        log_to_tab("Migrations","---")
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
                    log_to_tab("Migrations",qry)
                end
            end
        else
            local qryqueu = {add={},delete={},rename={}}
            local old = OldSchema[tablename]
            --Add Columns
            for p,field in pairs(definition.__schema) do
                --Add Colums
                switch(field.DataType,{
                    [DataType.COLLECTION] = function() end,
                    [DataType.VIRTUAL] = function() end,
                    ['default']=function()
                        if old[p] == nil and old[field.Column] == nil then
                            table.insert(qryqueu.add,[[ALTER TABLE ]]..tablename..[[ ADD ]]..p..[[ ]]..field.DataType..[[]])        
                        end
                    end
                })
            end
            --ALTER TABLE Customer CHANGE Address Addr char(50);
            
            --Remove Columns
            for p,v in pairs(old) do
                local rename = false
                for fieldname,fielddata in pairs(definition.__schema) do
                    if p == fielddata.Column then
                        rename =true
                    end
                end
                if definition.__schema[p] == nil and rename == false then
                    local columns = {}
                    local newcolumns = {}
                    for column,datatype in pairs(old) do
                        if column ~= p then
                            table.insert(columns,column)
                            table.insert(newcolumns,ColumnToSQL(column,definition.__schema[column]))
                        end
                    end
                    local foreingkeys = nil
                    for p,column in pairs(definition.__FK) do
                        if  column.Kind == FK.belongsTo then
                            local data = ColumnToSQL(p,definition.__schema[p],definition.__FK[p] )
                            foreingkeys = foreingkeys or {}
                            foreingkeys[data[1]] = foreingkeys[data[1]] or {}
                            foreingkeys[data[1]][data[2]] = foreingkeys[data[1]][data[2]] or {}
                            foreingkeys[data[1]][data[2]] = data[3]
                        end
                    end
                    if foreingkeys ~= nil then
                        for p, v in pairs(foreingkeys) do
                            local a,b = next(v)
                            table.insert(columns,a)
                            table.insert(newcolumns,a.." INTEGER NOT NULL")
                        end
                    end
                    local fks = {}
                    for p,v in pairs(foreingkeys) do
                        local a,b = next(v)
                        table.insert(fks,b)
                    end
                    foreingkeys = fks
                    fks=nil
                    columns = table.concat(columns,", ")
                    newcolumns = table.concat(newcolumns,", ")
                    table.insert(qryqueu.delete,[[BEGIN TRANSACTION;]])
                    table.insert(qryqueu.delete,[[CREATE TEMPORARY TABLE ]]..tablename..[[_backup(]]..newcolumns..[[);]])
                    table.insert(qryqueu.delete,string.format("INSERT INTO %s_backup(%s) SELECT %s FROM %s;",tablename,columns,columns,tablename))
                    table.insert(qryqueu.delete,[[DROP TABLE ]]..tablename..[[;]])
                    if foreingkeys == nil then
                        table.insert(qryqueu.delete,[[CREATE TABLE ]]..tablename..[[(]]..newcolumns..[[);]])
                    else
                        table.insert(qryqueu.delete,
                        string.format("CREATE TABLE %s(%s , %s)",tablename, newcolumns,table.concat(foreingkeys,", ") ) )
                    end
                    table.insert(qryqueu.delete,[[INSERT INTO ]]..tablename..[[ SELECT ]]..columns..[[ FROM ]]..tablename..[[_backup;]])
                    table.insert(qryqueu.delete,[[DROP TABLE ]]..tablename..[[_backup;]])
                    table.insert(qryqueu.delete,[[COMMIT TRANSACTION;]])
                end
            end
            for _,qry in pairs(qryqueu.delete) do
                if conn:exec(qry) == 1 then
                    mout(conn:errmsg())
                    conn:exec("ROLLBACK TRANSACTION;")
                    return false
                else
                    mout(qry)
                end
            end
            for _,qry in pairs(qryqueu.add) do
                if conn:exec(qry) == 1 then
                    mout(conn:errmsg())
                    conn:exec("ROLLBACK TRANSACTION;")
                    return false
                else
                    mout(qry)
                end
            end
        end
    end
    if LORMVerbose.Migration then
        log_to_tab("Migrations","---")
    end
end
return Migrations
