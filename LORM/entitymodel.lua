local RM = relp("foreign")
local entity = {
    undo=nil,delete=nil, new = nil}
function entity:new(values,SchemaTable,OC)
    local EC = OC[SchemaTable.__name]
    --Entity table definition
    local newentity = {
        __kind = SchemaTable.__name,
        __original={},
        __values={},
        __status = entity_state.new,
        __function = {
            toJSON=OC.toJSON,
            save=OC.saveEntity,
            delete=OC.deleteEntity,
            Primary=function(self)
                return SchemaTable.__primary , self[SchemaTable.__primary]
            end
        }
    }
    if LORMConfig.RestSync.host ~= nil then
        newentity.__function.sync = OC.syncEntity
    end

    local val = tostring(newentity):gsub("table: ","")
    --Hide double underscore variables and makes only model properties aviable
    setmetatable(newentity,{
        __metatable = {
            __pairs=function(table)
                local public = {}
                for p,v in pairs(table.__values) do
                    public[p] = v
                end
                return rawpairs(public)
            end
        },
        --RM handles Virtual and Collectin DataTypes
        __index = function(table,key)
            if table.__function[key] then
                return table.__function[key]
            elseif table.__values[key] == nil then
                print(string.format("WARNING: %s does not belongs to the table %s",key,SchemaTable.__name) )
                return nil
            end
            return switch(SchemaTable.__schema[key].DataType,{
                --[DataType.PRIMARY]      = function() rawprint(key..' is a read-only property') end,
                ['default']             = function() return table.__values[key] end,
                [DataType.VIRTUAL]      = function()
                    --if type(table.__values[key]) == "number" and table.__values[key] >0 then

                        --return RM.getProperty( table,key,SchemaTable,OC )
                    --end
                    return  RM.getProperty( table,key,SchemaTable,OC ) or {}
                    --if prop~=nil then _,table.__values[key] = prop:Primary() end
                end,
                [DataType.COLLECTION]   = function()
                    return RM.getProperty( table,key,SchemaTable,OC )
                end
            })
        end,
        --RM handles Virtual and Collectin DataTypes
        __newindex = function(table,key,value)
            if SchemaTable.__schema[key] == nil then
                print("WARNING: Property "..key.." is not in the model.")
                return nil
            end
            switch(SchemaTable.__schema[key].DataType,{
                ['default']             = function() table.__values[key] = value end,
                [DataType.VIRTUAL]      = function() return RM.setProperty( table,key,value,SchemaTable,OC ) end,
                [DataType.COLLECTION]   = function() return RM.setProperty( table,key,value,SchemaTable,OC ) end
            })
            if table.__status ~= entity_state.new then
                rawset(table,"__status",entity_state.modified)
            end
            --log(OC.Alumno.__PERSISTENT)
        end,
        __tostring = function()
            return string.format("%s (%s)",SchemaTable.__name,val)
        end
    })
    for column,config in pairs(SchemaTable.__schema) do
        if config.DataType == "TEXT" then
            newentity.__values[column] = ""
            newentity.__original[column] = ""
        elseif config.DataType == DataType.COLLECTION then
            EC.List(newentity,column,{})
        elseif config.DataType == "VIRTUAL" then
            newentity.__values[column] = 'unloaded'
            newentity.__original[column] = {}
        elseif values[column] == nil then
            newentity.__values[column] = 0
            newentity.__original[column] = 0
        end
    end
    for property, value in pairs(values) do
        newentity[property] = value
    end
    newentity.__status = entity_state.new

    function newentity.__function:undo()
        for p,v in pairs(privateTable._oldvalues) do
            newTable[p]=v
        end
        privateTable._entity_state = privateTable._laststate
    end
    --TODO move this to the OC
    --OC.listener=OC.listener or {}
    --OC.listener[SchemaTable.__name] = OC.listener[SchemaTable.__name] or {}
    --table.insert( OC.listener[SchemaTable.__name],newentity )
    return newentity
end
return entity
