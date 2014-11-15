local RM = relp("foreign")
local RS = {}

function SchemaBuilder(Context)
    if LORMVerbose.Schema then
        print("***")
    end
    local namespace = Context.Namespace
    local Schema = Context.Database
    Context.Namespace = nil
    Context.Database = nil

    local Schema = {}
    local unic = {}
    --Prepare the context
    for Table,Columns in rawpairs(Context) do
        require (string.format("%s.%s",namespace,Table) )
        Columns = _G[Table]
        Columns.UUSID = {DataType=DataType.TEXT}
        if LORMConfig.TimeStamps then
            Columns.Created = {DataType=DataType.DATE}
            Columns.Updated = {DataType=DataType.DATE}
        end
        if LORMConfig.RestSync ~=nil then
            Columns.Sync = {DataType=DataType.DATE}
        end
        Schema[Table] = {__schema=Columns}
    end
    --Prepare Columns
    for table,def in rawpairs(Schema) do
        local schema = def.__schema
        Schema[table].__name = table
        Schema[table].__FK = {}
        for column,_ in rawpairs(schema) do
            if schema[column].UNIC == true then
                Schema[table].__unic = column
            end
            if schema[column].DataType == DataType.PRIMARY then
                Schema[table].__primary = column
            end
            schema[column].DataType = schema[column].DataType or DataType.TEXT
        end
        --Add Primary key if not defined. By default id
        if Schema[table].__primary == nil then
            Schema[table].__primary = LORMDefaultId
            schema[LORMDefaultId] = {DataType=DataType.PRIMARY}
        end
    end
    --Hide private properties ( double underscore '__' )
    for p,v in rawpairs(Context) do
        Context[p] = Schema[p]
        _G[p] = Context[p]
    end
    Schema = nil
    --At this point we need to add the index for the relationships
    --In order to keep code clean most of the procces would be handled by the RM
    for table,definition in rawpairs(Context) do
        for Column,Structure in rawpairs(definition.__schema) do
            if RM.hasRelation(Column,Structure) then
                local x = RM.Schema(definition,Column,Context)
                --log(Context[table])
            end
        end
    end
    --The Schema if fully built
    if LORMVerbose.Schema then
        log(Context)
        print("***")
    end
    return Context
end
local function rawsome()
local sql = [[CREATE TABLE IF NOT EXISTS ]]..tab..[[(]]
    require(ns..[[.]]..tab);
    local column = "{";
    local prototype = {_TMO={CI={},IC={}}}
    local proto = {}
    local index = 1
    local FOREIGNS = {}
    for p,v in pairs(_G[tab]) do
        if v.REF ~= nil then
            local col,foreign = ManageRelationship(v,Context,ns)
            p = col or p
            if foreign ~= nil then
                FOREIGNS[p] = foreign
            end
        end

        column=column..p;
        prototype[p] = "text"
        prototype._TMO.CI[p]=index
        prototype._TMO.IC[index]=p
        v.DataType = v.DataType or "TEXT"
        prototype[p] = v.DataType
        if v.DataType == "REFERENCE" then
            v.ColumnDef = p .. " INTEGER"
        else
            v.ColumnDef = p .. " "..v.DataType
        end
        if v.UNIC then
            proto.UNIC = p
            v.UNIC = nil
        end
        if v.KEY then
            proto.PRIMARYKEY = p
            v.ColumnDef = v.ColumnDef.." PRIMARY KEY"
            column=column.." PRIMARY KEY"
            prototype[p] = "auto"
        end

        sql = sql..v.ColumnDef..[[,]]
        index=index+1
    end
    proto.FOREIGNS = FOREIGNS
    for virtualcolumn,value in pairs(FOREIGNS) do
        sql = sql..value.query..[[,]]
        _G[tab][virtualcolumn] = "INTEGER"
    end
    sql = sql:gsub([[,$]], [[);]]);
    _G[tab]._PROTOTYPE = proto
    return sql,column, prototype
end
return SchemaBuilder
