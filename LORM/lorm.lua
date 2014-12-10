--------------------------------------------------------------------------------
-- lorm.lua, v0.0.1
-- This file is a part of LORM project
-- Copyright (c) 2014 Gerardo Pérez <gerard2perez@outlook.com>
-- License: MIT
--------------------------------------------------------------------------------
LORM = {ObjectCordinator={}}
LORMConfig = LORMConfig or {RestSync={}}
LORMConfig={
    DeleteDb = LORMConfig.DeleteDb or false,
    AlwaysOverride = LORMConfig.AlwaysOverride or false,
    TimeStamps = LORMConfig.TimeStamps or true,
    RestSync ={
        host = LORMConfig.RestSync.host or nil,
        FailCriteria=LORMConfig.RestSync.fail or function(entity,HTTP)
            print("No fail action implemented")
            return HTTP
        end,
        UpdateCriteria=LORMConfig.RestSync.success or function(entity,HTTP)
            print("No update action implemented")
            return HTTP
        end
    }
}

require "sqlite3"
require(LORMPath..".utils")
relp("constants")

local tableEntity={}
local contextEntity={}
local ObjectStoreCordinator={}
local RM = relp("foreign")
local SB = relp("schema")
local MM = relp("migrations")
local EntityClass = relp("entityclass")
local obc = relp("obc")

function LORM:new(Context)
    local Database = Context.Database
    local NameSpace = Context.Namespace
    
    if LORMConfig.DeleteDb == true then
        local deleted = os.remove(Database) or false
        if deleted then
            print(Database.." has been deleted.")
        else
            print(Database.." couldn't been deleted.")
        end
        
    end
    
    LORM.ObjectCordinator[NameSpace.."."..Database] = obc:new(NameSpace,Database)
    rawprint(NameSpace,Database)
    local OC = LORM.ObjectCordinator[NameSpace.."."..Database]
    local ctx = {_dbname,_conexion}
    local con = OC.conexion

    --Prepare Clases to be used with user's Namespace
    _G[NameSpace] = {}
    for p,v in rawpairs(Context) do
        _G[NameSpace][p] = p
    end
    _G[NameSpace].Namespace,_G[NameSpace].Database = nil,nil
    --Get Actual Schema if exits
    lfs.chdir(system.pathForFile("",system.DocumentsDirectory))
    local OldSchema = OC:dbContext()
    --Build New Schema
    local Schema = SB(Context)
    MM(Schema,OldSchema,con)
    _G[Database] = {}
    for table,class in pairs(Schema) do
        _G[Database][table] = EntityClass(table,class,OC)
        _G[table] = _G[Database][table]
    end
    collectgarbage("collect")
    return ctx
end
return LORM
