Classroom={
    Name = {UNIC=true},
    Teacher={FK={FK.hasOne,DataModel.Teacher}},
    Students={FK={FK.hasMany,DataModel.Student}},
}