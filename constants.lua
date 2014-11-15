function stringit( data)  for p,v in pairs(data) do data[p] = p end end
LORMDefaultId = LORMDefaultId or "Id"

entity_state = {
    new='new',
    modified='modified',
    deleted='deleted',
    unchanged='unchanged'
}
FK = {
    hasOne="",
    belongsTo="",
    hasMany="",
    belongsToMany="",
    --hasManyThrough,
    --belongToManyTrough,
}
DataType={
    INTEGER='',
    TEXT='',
    VIRTUAL='',
    COLLECTION='',
    PRIMARY=''
}


luatosqlType = {
    TEXT="string",
    INTEGER="number",
    PRIMARY="number",
    DATE="string"
}

stringit(FK)
stringit(DataType)
DataType.DATE = "TEXT"
