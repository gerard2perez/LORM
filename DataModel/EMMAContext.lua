EMMA = {
    Namespace   = 'DataModel',
    Database    = 'EMMAContext',
    
    Grade       ={},
    Classroom   ={},
    Teacher     ={},
    Student     ={},
    Unit        ={}
    
}
return require(LORMPath..".lorm"):new(EMMA)