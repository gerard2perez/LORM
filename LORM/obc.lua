local RM = relp("foreign")
local entity = relp("entitymodel")
relp("promise")
local ObjectCordinator = {}
local json = require"json"
local crypto = require "crypto"
local Server = relp('RESTbuilder')(LORMConfig.RestSync.host)

function ObjectCordinator.new(self,NS,DB)
    local crypto = require"crypto"
    local lfs = require"lfs"
    require "sqlite3"
    lfs.chdir(system.pathForFile("",system.DocumentsDirectory))
    if _G["LORMOC"] == nil then
        _G["LORMOC"] = {
            conexion = sqlite3.open( DB )
        }
    end
    local OC = _G["LORMOC"]
    --Enable FOREIGN KEYS
    OC.conexion:exec("PRAGMA foreign_keys = ON;")

    --Autoclose Database when app quits
    local function onSystemEvent( event )
        if( event.type == "applicationExit" ) then
            OC.conexion:close()
        end
    end
    Runtime:addEventListener( "system", onSystemEvent )
    local Add = function(self,entity)
        if type(self.__list) == "string" then
            self.__list = {}
        end
        local Schema = _G[entity.__kind].__FK
        table.insert(self.__list,entity)
        for name,refield in rawpairs(Schema) do
            if refield.ParentTable == self.__self.__kind then
                entity.__values[name]=self.__self
                if entity.__status ~= entity_state.new then
                    entity.__status = entity_state.modified
                end
            end
        end
    end
    local Remove = function(self,variable)
        local kind = type(variable)
        local entity =variable
        if kind == "number" then

            table.remove(self.__list,variable)
        elseif kind == "table" then
            local index = 0
            for p,v in rawpairs(self.__list) do
                index = index + 1
                if v == variable then
                    entity = variable
                    break
                end
            end
            table.remove(self.__list,index)
        end

        local Schema = _G[entity.__kind].__FK
        for name,refield in rawpairs(Schema) do
            if refield.ParentTable == self.__self.__kind then
                entity.__values[name]='unloaded'
                if entity.__status ~= entity_state.new then
                    entity.__status = entity_state.modified
                end
            end
        end

    end
    local List = function(self)
        return self.__list
    end
    function OC.List(SchemaTable,entity,field,value)
        entity.__values[field] = {
            __self = entity,
            __list = 'Unloaded',
            Add = Add,
            Remove = Remove,
            List = List
        }
        setmetatable(entity.__values[field],{
            __metatable={
                __pairs = function(t)
                   return rawpairs({
                                List = string.format("%s(%s %s)",tostring(List),SchemaTable.__FK[field].RefTable,"object"),
                                Add = string.format("%s(%s %s)",tostring(Add),SchemaTable.__FK[field].RefTable,"object"),
                                Remove = string.format("%s(%s %s)",tostring(Add),SchemaTable.__FK[field].RefTable,"object"),
                                PrivateMembers = t.__list
                        })
                end
            },
            __index=function(t,key)
                if type(key) == "number" then
                    return OC[SchemaTable.__FK[field].RefTable].__PERSISTENT[tostring(t.__list[key])] or t.__list[key]
                end
                return t.__list[key]
            end,
        })


    end

    function OC.exists(entity,SchemaTable)
        for p,storedEntity in pairs(OC[SchemaTable.__name].__PERSISTENT) do
            local unic = SchemaTable.__unic or SchemaTable.__primary
            if entity[unic] ==  storedEntity[unic] then
                return storedEntity
            end
        end
        return false
    end

    function OC.add(entity,SchemaTable)
       OC[SchemaTable.__name].__PERSISTENT[ tostring(entity[SchemaTable.__primary]) ] = entity
    end
    function OC.insert(entity,field,value,SchemaTable)
        RM.insert(entity,field,value,SchemaTable,OC)
    end
    function OC.restore(original,entity,SchemaTable)
        for column,value in pairs(entity.__values) do
            original.__original[column] = value
            if original.__status == entity_state.new then
                original.__values[column] = value
            end
        end
        OC[SchemaTable.__name].__PERSISTENT[ tostring(original[SchemaTable.__primary]) ] = original
        entity = nil
        for p,v in pairs(original,__values) do
            if original.__original[p] ~= original.__values[p] and SchemaTable.__prototype[p].DataType:find("VIRTUAL") == nil then
                print("Modified")
                rawset(original,'__status',entity_state.modified)
                return entity_state.modified
            end
        end
        rawset(original,'__status',entity_state.unchanged)
        return entity_state.unchanged
    end
    function OC:dbContext()
        local OldContext = {}
        for row in self.conexion:nrows([[SELECT * FROM sqlite_master WHERE type='table' ORDER BY name]]) do
            local sql = [[select * from ]] .. row.name .. [[ limit 1;]]
            local stmt = self.conexion:prepare(sql)
            OldContext[row.name] = stmt:get_named_types()
        end
        return OldContext
    end
    --Creates new Entities
    function OC.deleteEntity(self)
        local SchemaTable = _G[self.__kind]
        local EC = OC[self.__kind]
        self:undo()
        local primary, primary_value = self:Primary()
        if self.__status and self.__status ~= entity_state.new then
            local qry = string.format( "DELETE FROM %s WHERE %s=%d", SchemaTable.__name, primary, primary_value )
            if OC.conexion:exec(qry) == 0 then
                self = {}
            else
                print(context:errmsg())
            end
        end
    end
    function OC.toJSON(self,str)
        local SchemaTable = _G[self.__kind]
        log(SchemaTable.__schema)
        local res = {}
        for p,v in pairs(self) do
            if SchemaTable.__schema[p].DataType ~= DataType.VIRTUAL and SchemaTable.__schema[p].DataType ~= DataType.COLLECTION then
                res[p] = v
                rawprint(p,SchemaTable.__schema[p].DataType)
            elseif SchemaTable.__FK[p].Kind == FK.belongsTo then
                local a,b = self[p]:Primary()
                res[SchemaTable.__FK[p].FK] = b
            end
        end
        if str == false then
            return res
        else
            local r={}
            for p,v in pairs(res) do
                if type(v) ~= "table" then
                    table.insert(r,string.format('"%s":"%s"',p,v))
                end
            end
            return string.format('{%s}',table.concat(r,","))
        end
    end

    function ToDate(test)
        if test then
            return test:gsub(' ','T')..'Z'
        end
    end

    function OC.PullTable(self)
        local promise = Promise:new()
        local SchemaTable = _G[self.__name]
        Server.get[SchemaTable.__name:lower()]('json'):done(function(ev)
            --[[
            local data = ev.response
            for p,v in pairs(data) do
                v.Created = ToDate(v.Created)
                v.Updated = ToDate(v.Updated)
                v.Sync = ToDate(v.Sync)
                log(v)
                local is = (_G[self.__name]):where('Created','=', ToDate(v.Created) ):single()
                log(is)
            end]]
            promise:resolve(ev)
        end):fail(function(ev)
            promise:reject(ev)
        end)

        return promise
    end

    function OC.syncEntity(self,override)
        override = override or false
        local promise = Promise:new()
        if  self:save()== false then return promise:reject("Couldn't save the row") end
        local SchemaTable = _G[self.__kind]
        local body = self:toJSON(false)
        body.UUSID = nil
        local json = require"json"
        local headers = { OVERRIDE = override}
        Server.put[SchemaTable.__name:lower()]('json',"/"..self.UUSID,body,headers):done(function(HTTP)
            switch( tostring(HTTP.status),{
                ['200'] = function()
                --We just new to update the Sync variable
                    self.Sync = HTTP.response.Sync
                    self:save(false)
                    promise:resolve(HTTP)
                end,
                ['201'] = function()
                --We just new to update the Sync variable
                    self.Sync = HTTP.response.Sync
                    self:save(false)
                    promise:resolve(HTTP)
                end,
                ['203'] = function()
                    --Special Action may be needed
                    promise:resolve(LORMConfig.RestSync.UpdateCriteria(self,HTTP) )
                end,
                ['207'] = function()
                    --No Action neded
                    promise.resolve(HTTP)
                end,
                ['default'] = function()
                --Just for preventing the tak to happend
                    promise:reject(HTTP)
                end
            } )
        end):fail(function(HTTP)
            switch( tostring(HTTP.status),{
                ['409']=function()
                    if LORMConfig.RestSync.AlwaysOverride == true then
                        self:sync(true):done(function(HTTP)
                            promise:resolve(self,HTTP)
                        end):fail(function(HTTP)
                            promise:reject(HTTP)
                        end)
                    else
                        promise:reject(LORMConfig.RestSync.FailCriteria(self,HTTP))
                    end
                end,
                ['default']=function()
                --Yo must Process all the errors
                    promise:reject(LORMConfig.RestSync.FailCriteria(self,HTTP))
                end
            })
        end)
        return promise
    end

    function OC.saveEntity(self,updaterecords)
        local SchemaTable = _G[self.__kind]
        local EC = OC[self.__kind]
        opts = opts or {}
        local qry = ""

        local function SaveSelf()
            if EC.exists(self) == false then
                if self.__status == entity_state.unchanged then return true end
                if self.__status == entity_state.new and LORMConfig.TimeStamps ~= false then
                    self.Created = os.date("!%Y-%m-%d %H:%M:%S")--..(system.getTimer()*1000).."Z"
                    self.Updated = self.Created
                elseif LORMConfig.TimeStamps ~= false and updaterecords ~= false then
                    self.Updated = os.date("!%Y-%m-%d %H:%M:%S")--..(system.getTimer()*1000).."Z"
                end
                local qry = OC[SchemaTable.__name].querybuilder.insert(self,SchemaTable)
                if OC.conexion:exec( qry ) == 0 then
                    self.__values[SchemaTable.__primary] = OC.conexion:last_insert_rowid()
                    self.UUSID = crypto.digest( crypto.sha256,system.getInfo('deviceID')..OC.conexion:last_insert_rowid() )
                    self.__original[SchemaTable.__primary] = self.__values[SchemaTable.__primary]
                    EC.add(self)
                    self.__status = entity_state.unchanged
                    return true
                else
                    print("Warning: "..qry)
                    print("Warning: "..OC.conexion:errmsg())
                    return false
                end
            else
                local qry = OC[SchemaTable.__name].querybuilder.update(self,SchemaTable)
                if OC.conexion:exec( qry ) == 0 then
                    self.__status = entity_state.unchanged
                    if LORMConfig.TimeStamps ~= false and updaterecords ~= false then
                        self.Updated = os.date("!%Y-%m-%dT%H:%M%S")
                    end
                    return true
                else
                    print("Warning: "..qry)
                    print("Warning: "..OC.conexion:errmsg())
                    return false
                end
            end
        end

        return switch(self.__status,{
            [entity_state.new] = function()
                if SchemaTable.__unic and opts.force ~= true then
                    local oldentity = EC.exists(self)
                    if oldentity == false then
                    --Object is not in the OC
                        oldentity =
                            _G[SchemaTable.__name]
                            :where( SchemaTable.__unic, '=', self[SchemaTable.__unic] ):single()
                        if oldentity ~= nil then
                            if EC.restore( self, oldentity ) == entity_state.unchanged then
                                EC.add(self)
                                return false
                            end
                        end
                    else
                    --Object doesnot exits
                        if EC.restore( self, oldentity ) == entity_state.unchanged then
                            EC.add(self)
                            return false
                        end
                    end
                end
                for p,v in pairs (SchemaTable.__schema) do
                    switch(v.DataType,{
                        [DataType.COLLECTION] = function()
                            return switch(SchemaTable.__FK[p].Kind,{
                                [FK.hasMany] = function()
                                    if SaveSelf() then
                                        if type(self[p].__list) == "table" then
                                            local el = #self[p].__list
                                            for i=1,el do
                                                self[p].__list[i]:save()
                                            end
                                        end
                                    end
                                end
                            })
                        end,
                        [DataType.VIRTUAL]=function()
                            return switch(SchemaTable.__FK[p].Kind,{
                                [FK.hasMany] = function()
                                    print("has many")
                                end,
                                [FK.belongsTo] = function()
                                    --self[p]:save()
                                    --self[p] = self[p]
                                    return SaveSelf()
                                end,
                                [FK.hasOne] = function()
                                    if SaveSelf() then
                                        switch( self.__original[p].__status,{
                                            [entity_state.new] = function()
                                                self[p] = self.__original[p]
                                                self.__original[p]:save()
                                                self[p] = self.__original[p]
                                            end
                                        })
                                    end
                                end
                            })
                        end
                    })
                    --if v.DataType == "VIRTUAL" and self[p].__status == entity_state.new then
                        --print("Save"..p)
                        --self[p]:save()
                        --self[p] = self[p]
                    --end
                end
                return SaveSelf()

            end,
            [entity_state.modified]=function()
                return SaveSelf()
            end,
            [entity_state.unchanged]=function()
                return true
            end,
            ['default']=function()
                print("Unknown "+self.__status)
                    return false
            end
        });
    end
    function OC.newEntity(self,data)
        local entity = entity:new(data,self,OC)
        return entity
    end
    function OC.findEntity(self,id)
        local EC = OC[self.__name]
        local entity = EC.__PERSISTENT[ tostring(id) ]
        --OC[self.__name].exists(self)
        if entity ~= nil then
            print("Restored from OC")
            return entity
        else
            local qry = string.format("SELECT * FROM %s WHERE %s = %s LIMIT 1;",self.__name,self.__primary,id)
            for row in OC.conexion:nrows(qry) do
                EC.__PERSISTENT[ tostring(row[self.__primary]) ] = self:new(row)
                print("Handle Restore of Virtuals")
                --Restore(row)
                --for p, v in pairs(class._prototype.FOREIGNS) do
                --    local grupo = Grupo:find(object[p])
                --    object[v.table] = grupo
                --end
                rawset(EC.__PERSISTENT[ tostring(row[self.__primary]) ],'__status',entity_state.unchanged)
                return EC.__PERSISTENT[ tostring(row[self.__primary]) ]
            end

        end
    end
    function OC.whereEntity(self,column,operator,value)
        OC[self.__name].querybuilder.where(column,operator,value)
        return self
    end
    function OC.singleEntity(self)
        local EC = OC[self.__name]
        EC.querybuilder.limit(1)
        local qry = EC.querybuilder.build()
        for row in OC.conexion:nrows(qry) do
        --The entity exits on the db
            if EC.__PERSISTENT[ tostring(row[self.__primary]) ] == nil then
            --The entity is not in the oc, so we need to create one to register
                local entity = self:new(row)
                print("Handle virtuals")
                rawset(entity,'__status',entity_state.unchanged)
                EC.__PERSISTENT[ tostring(row[self.__primary]) ] = entity
                return entity
            else
            --The entity is registered in the OC
                return EC.__PERSISTENT[ tostring(row[self.__primary]) ]
            end
        end
        if OC.conexion:errmsg() ~= "not an error" then
        --An error happend while executing the query
            print(OC.conexion:errmsg())
        end

        --No result
        return nil
    end
    function OC.findAllEntities(self)
        local EC = OC[self.__name]
        local qry = string.format("SELECT * FROM %s",self.__name)
        local result = setmetatable({},{
            __tostring = function()
                return "List ["..self.__name.."]"
            end
        })
        for row in OC.conexion:nrows(qry) do
            if EC.__PERSISTENT[ tostring(row[self.__primary]) ] == nil then
                EC.__PERSISTENT[ tostring(row[self.__primary]) ] = self:new(row)
                rawset(EC.__PERSISTENT[ tostring(row[self.__primary]) ],'__status',entity_state.unchanged)
                print("Handle Restore of Virtuals")
            end
            result[#result+1] = EC.__PERSISTENT[ tostring(row[self.__primary]) ]
        end

        return result
    end
    function OC.syncTable(self)
        local EC = OC[self.__name]
        local promise = Promise:new()
        local all = {}
        timer.performWithDelay(0,function()
            for _,entity in pairs(EC.__PERSISTENT) do
                table.insert(all,entity:sync())
            end
            when(all):done(function(...)
                promise:resolve(...)
            end):fail(function(...)
                promise:reject(...)
            end)
        end)
        return promise
    end
    function OC.getEntities(self)
        local qry = EC.querybuilder.build()
        local result = {}
        for row in OC.conexion:nrows(qry) do
            --print(tostring(row[self.__primary])=='1')
            if EC.__PERSISTENT[ tostring(row[self.__primary]) ] == nil then
                EC.__PERSISTENT[ tostring(row[self.__primary]) ] = self:new(row)
                print("Handle Restore of Virtuals")
                rawset(EC.__PERSISTENT[ tostring(row[self.__primary]) ],'__status',entity_state.unchanged)
            end
            result[#result+1] = EC.__PERSISTENT[ tostring(row[self.__primary]) ]

        end
        if OC.conexion:errmsg() ~= "not an error" then
            print(OC.conexion:errmsg())
        end
        return result
    end
    return OC
end
return ObjectCordinator
