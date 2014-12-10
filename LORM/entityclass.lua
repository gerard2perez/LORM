local builder = relp("querybuilder")
local entity = relp("entitymodel")

function EntityClass(Table,SchemaTable,OC)
    --TODO move this definition to the Object Cordinator
    if OC[Table] == nil then
        OC[Table] = {
            __PERSISTENT={},
            __TABLE = Table
        }
    else
        print("Entity Class "..Table.." already exists")
    end
    local EC = OC[Table]
    EC.exists = function(entity)
        return OC.exists(entity,SchemaTable)
    end

    EC.add = function(entity)
        OC.add(entity,SchemaTable)
    end

    EC.restore = function(original,entity)
        return OC.restore(original,entity,SchemaTable)
    end

    EC.List = function(entity,field,value)
        OC.List(SchemaTable,entity,field,value)
    end
    EC.insert = function(entity,field,value)
        return OC.insert(entity,field,value,SchemaTable)
    end

    EC.querybuilder = builder(Table)

    SchemaTable.Pull = OC.PullTable
    SchemaTable.Sync = OC.syncTable
    SchemaTable.new = OC.newEntity
    SchemaTable.find = OC.findEntity
    SchemaTable.where = OC.whereEntity
    SchemaTable.single = OC.singleEntity
    SchemaTable.findAll = OC.findAllEntities
    setmetatable(SchemaTable,{
        __metatable = {
             __pairs = function (t,k)
                local ctable = {}
                for p,v in rawpairs(t) do
                    if p:find("^__") == nil then
                        ctable[p] = v
                    end
                end
                return rawpairs(ctable)
            end
        },
        __call = function(...)
                return SchemaTable.new(...)
        end,
        __index=function(table,key)
                --print("__index")
            if rawget(table,"__develop") == false then
                return nil
            else
                return rawget(table,key)
            end

        end,
        __newindex = function(table,key,value)
            --print("__newindex")
            if key:find("_") ~= nil and rawget(table,"__develop")== true then
                rawset(table,key,value)
            end
        end,
        __tostring = function(table)
            return string.format("%s[EntityClass]",Table)
        end
    })
    return SchemaTable
end

return EntityClass
