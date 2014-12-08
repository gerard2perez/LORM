local manager = {}
function manager.Schema(schema,fk,context)
    local fkType = schema.__schema[fk].FK[1]
    switch(fkType,{
        [FK.hasOne]=function()
            schema.__FK[fk] = {
                ParentTable = schema.__name,
                ParentColumn = schema.__primary,
                RefTable = schema.__schema[fk].FK[2],
                RefColumn = _G[schema.__schema[fk].FK[2]].__primary
            }
            local exfk = schema.__FK[fk].ParentTable
            context[ schema.__FK[fk].RefTable ].__FK[exfk] = context[ schema.__FK[fk].RefTable ].__FK[exfk] or {}
            cloneTable(schema.__FK[fk],context[ schema.__FK[fk].RefTable ].__FK[exfk])
            context[ schema.__FK[fk].RefTable ].__FK[exfk].FK =  schema.__name..schema.__FK[fk].RefTable.."_"..schema.__FK[fk].RefColumn
            context[ schema.__FK[fk].RefTable ].__FK[exfk].Kind = FK.belongsTo
            schema.__FK[fk].Kind = fkType
            --context[ schema.__FK[fk].RefTable ].__schema[context[ schema.__FK[fk].RefTable ].__FK[exfk].FK] = {DataType=DataType.INTEGER,Extra="NOT NULL"}
            schema.__schema[fk] = {DataType=DataType.VIRTUAL}
            schema.__FK[fk].RefFK = schema.__FK[fk].ParentTable..schema.__FK[fk].RefTable
                                .."_"..schema.__FK[fk].RefColumn

            --context[ schema.__FK[fk].RefTable ].__schema[schema.__FK[fk].RefFK] = {DataType=DataType.INTEGER,EXTRA="NOT NULL"}
        end,
        [FK.belongsTo] = function()
            schema.__FK[fk] = {
                RefTable = schema.__name,
                RefColumn = schema.__primary,
                ParentTable = schema.__schema[fk].FK[2],
                ParentColumn = _G[schema.__schema[fk].FK[2]].__primary,
                Kind = fkType,
            }

            schema.__schema[fk] = {DataType=DataType.VIRTUAL}
            schema.__FK[fk].FK = schema.__FK[fk].ParentTable..schema.__FK[fk].RefTable
                                .."_"..schema.__FK[fk].RefColumn
            --schema.__schema[schema.__FK[fk].FK] = {DataType=DataType.INTEGER,Extra="NOT NULL"}
        end,
        [FK.hasMany] = function()
            schema.__FK[fk] = {
                ParentTable = schema.__name,
                ParentColumn = schema.__primary,
                RefTable = schema.__schema[fk].FK[2],
                RefColumn = _G[schema.__schema[fk].FK[2]].__primary
            }
            local exfk = schema.__FK[fk].ParentTable
            context[ schema.__FK[fk].RefTable ].__FK[exfk] = context[ schema.__FK[fk].RefTable ].__FK[exfk] or {}
            cloneTable(schema.__FK[fk],context[ schema.__FK[fk].RefTable ].__FK[exfk])
            context[ schema.__FK[fk].RefTable ].__FK[exfk].FK =  schema.__name..schema.__FK[fk].RefTable.."_"..schema.__FK[fk].RefColumn
            schema.__FK[fk].Kind = fkType
            -- --context[ schema.__FK[fk].RefTable ].__schema[context[ schema.__FK[fk].RefTable ].__FK[exfk].FK] = {DataType=DataType.INTEGER,Extra="NOT NULL"}
            schema.__schema[fk] = {DataType=DataType.COLLECTION}
            schema.__FK[fk].RefFK = schema.__FK[fk].ParentTable..schema.__FK[fk].RefTable
                                .."_"..schema.__FK[fk].RefColumn
        end
    })
    return schema
end
function manager.hasRelation(column,properties)
    if properties.FK ~= nil then
        if FK[properties.FK[1]] == properties.FK[1] then return true end
    end
    return false
end
function manager.insert(entity,field,value,SchemaTable,OC)
    local Proto = SchemaTable.__prototype[field]
    local DataType = Proto.DataType
    local VirtualElements = OC[Proto.RefTable].__PERSISTENT
    switch(DataType,{
        ['VIRTUAL'] = function()
            local VirtualElement = VirtualElements[ tostring(value[Proto.RefColumn]) ]
            if VirtualElement ~= nil then
                entity.__private[field] = VirtualElement
                entity.__public[field] = { value[Proto.RefColumn] }
            else
                if value[Proto.RefColumn] == nil then
                    local x = _G[SchemaTable.__name]
                                :where( SchemaTable.__checkinsert, '=', value[SchemaTable.__checkinsert] )
                                :single()
                        entity.__private[field] = value
                        entity.__public[field] = {  }
                else
                    if value.__status == entity_state.new then
                        entity.__private[field] = value
                        entity.__public[field] = { value[Proto.RefColumn] }
                    else
                        VirtualElements[ tostring(value[Proto.RefColumn])] = value
                    end
                end
            end
            for p,v in pairs(_G[SchemaTable.__prototype[field].RefTable].__prototype) do
                if v.DataType == "VIRTUAL_LIST" then
                    --TODO trigger an update of list
                end
            end
        end,
        ['VIRTUAL_LIST']=function()
            local elms = _G[Proto.RefTable]:where(Proto.RefColumn,'=',1)
            print('Unimplemented')
        end
    });
end
function manager.getProperty( table,field,SchemaTable,OC )
    local proto = SchemaTable.__FK[field]
    local vems   = OC[proto.ParentTable].__PERSISTENT
    local kind  = SchemaTable.__FK[field].Kind
    return switch(kind,{
        [FK.belongsTo] = function()
            local f,v = table.__values[field]:Primary()
            return vems[ tostring(v) ] or table.__values[field]
        end,
        [FK.hasOne] = function()
            local x = _G[proto.RefTable]:where(proto.RefFK,'=',table[SchemaTable.__primary]):single()
            return x or table.__values[field]
        end,
        [FK.hasMany] = function()
            return table.__values[field]
        end
    })
end
function manager.setProperty(entity,field,value,SchemaTable,OC )
    local proto = SchemaTable.__FK[field]
    local kind  = SchemaTable.__FK[field].Kind
    switch(kind,{
        [FK.belongsTo] = function()
            local vems   = OC[proto.ParentTable].__PERSISTENT
            if vems[ tostring(value[proto.ParentColumn]) ] == nil then
            --A unregistered element is about to be placed
                if value.__status == entity_state.new then
                --Unsaved value, might exist in db
                    local tmp = _G[proto.ParentTable]
                            :where( _G[proto.ParentTable].__unic, '=', value[_G[proto.ParentTable].__unic] )
                            :single()
                    if tmp == nil then
                    --Is a purly new unsaved entity
                        --entity.__values[field] = value[proto.ParentColumn]--value --{ [proto.ParentColumn] = tostring(value)}--[proto.ParentColumn]
                            entity.__values[field] = value
                    else
                    --The entity exists and the db and has been restored to de OC
                        entity.__values[field] = tmp
                    end

                else
                -- The element is in database but hasn't been added to OC
                    vems[ tostring(value[proto.ParentColumn]) ] = value
                end
            else
                entity.__values[field] = value
            end

            for name,refield in rawpairs(_G[proto.ParentTable].__FK) do
                if proto.FK  == refield.RefFK and refield.Kind == FK.hasMany then
                    entity.__values[proto.ParentTable].__values[name]:Add(entity)
                end
            end
        end,
        [FK.hasOne] = function()
            local vems   = OC[proto.RefTable].__PERSISTENT
            if vems[ tostring(value[proto.RefColumn]) ] == nil then
            --A unregistered element is about to be placed
                if value.__status == entity_state.new then
                --Unsaved value, might exist in db
                    local tmp = _G[proto.RefTable]
                            :where( _G[proto.RefTable].__unic, '=', value[_G[proto.RefTable].__unic] )
                            :single()
                    print("--TODO handle COLLECTION restore hasOne")
                    if tmp == nil then
                    --Is a purly new unsaved entity
                        manager.findPossibleVirtualProperty( value, proto.RefFK, entity, _G[proto.RefTable])
                        entity.__values[field] = value
                        entity.__original[field] = value
                    else
                    --The entity exists and the db and has been restored to de OC
                        print("Restore from OC")
                        entity.__values[field] = tmp
                    end
                else
                -- The element is in database but hasn't been added to OC
                    vems[ tostring(value[proto.RefColumn]) ] = value
                end
            else
                entity.__values[field] = value
            end
        end
    });
end
function manager.findPossibleVirtualProperty(table,key,value,SchemaTable)
    for p,v in pairs(SchemaTable.__FK) do
        if v.FK == key then
            switch(v.Kind,{
                [FK.belongsTo]=function()
                    table[p] = value
                end
            })
        end
    end
end
return manager
