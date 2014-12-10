local widget = require( "widget" )
local ClassroomName = nil
local Classrooms = nil
local pick = nil
local superview = nil
function picker()
    --Get All Classrooms
    Classrooms = EMMAContext.Classroom:findAll()
    --Get Labels for pickers
    local labels = {}
    if #Classrooms == 0 then
        labels[1]="empty"
    end
    for id,classroom in pairs(Classrooms) do
        table.insert(labels,classroom.Name)
    end
    
    local columnData = {
        { 
            align = "right",
            width = 140,
            height= 50,
            startIndex = 1,
            labels = labels
        }
    }
    -- Create the widget
    local pickerWheel = widget.newPickerWheel
    {
        top = 0,
        left = display.contentCenterX,
        columns = columnData
    } 
    pickerWheel.anchorX=1
    return pickerWheel
    
    --local values = pickerWheel:getValues()
    --log(values)
end

local idx = -1


local function handleButtonEvent( event )
    if ( "ended" == event.phase ) then
        switch(event.target:getLabel():lower(),{
            ["editar"] = function()
                local val = pick:getValues()[1].index 
                ClassroomName.text = Classrooms[val].Name
                idx = val
            end,
            ["crear nuevo"] = function()
                ClassroomName.text = ""
                    idx = -1
            end,
            ["guardar"] = function()
                
                if idx == -1 and ClassroomName.text~= "" then
                   local gdr = EMMAContext.Classroom{Name=ClassroomName.text}
                   gdr:save()
                    pick:removeSelf()
                    pick= picker()
                elseif idx > -1 and ClassroomName.text~= "" then
                    Classrooms[idx].Name = ClassroomName.text
                    Classrooms[idx]:save()
                    pick:removeSelf()
                    pick= picker()
                end
                    ClassroomName.text=""
                    superview:insert(pick)
            end,
            ["atras"]=function()
                STB.back()
            end
        })
        --STB.Go("View."..event.target:getLabel():lower())
    end
end

return STB{ "View.group",{
        create=function(e,v,d)
            superview=v
            v.out("Classroom Creation")
            pick=picker()
            v:insert(pick)
            local bt_create = widget.newButton
            {
                label = "Crear Nuevo",
                onEvent = handleButtonEvent,
                emboss = false,
                shape="roundedRect",
                width = 150,
                height = 40,
                cornerRadius = 2,
                labelColor ={default={ 1,1,1,1 }},
                fillColor = { default={ 98/254, 178/254, 232/254, 1 }, over={ 1, 0.1, 0.7, 0.4 } },
                strokeColor = {default={ 118/254, 198/254, 252/254, 1 }, over={ 0.8, 0.8, 1, 1 } },
                strokeWidth = 2
            }
            -- Center the button
            bt_create.x = display.contentCenterX*0.5
            bt_create.y = pick.y + pick.height*0.5 + bt_create.height
            v:insert(bt_create)
            
            
            local bt_edit = widget.newButton
            {
                label = "Editar",
                onEvent = handleButtonEvent,
                emboss = false,
                shape="roundedRect",
                width = 150,
                height = 40,
                cornerRadius = 2,
                labelColor ={default={ 1,1,1,1 }},
                fillColor = { default={ 98/254, 178/254, 232/254, 1 }, over={ 1, 0.1, 0.7, 0.4 } },
                strokeColor = {default={ 118/254, 198/254, 252/254, 1 }, over={ 0.8, 0.8, 1, 1 } },
                strokeWidth = 2
            }
            -- Center the button
            bt_edit.x = display.contentCenterX*1.5
            bt_edit.y = pick.y + pick.height*0.5 + bt_edit.height
            v:insert(bt_edit)
            
            ClassroomName = native.newTextField( display.contentWidth*0.05, bt_edit.y+bt_edit.height, display.contentWidth*0.9, 40 )
            ClassroomName.anchorX=0
            ClassroomName.anchorY=0
            ClassroomName.size=30
            v:insert(ClassroomName)
            
            
            local bt_guardar = widget.newButton
            {
                label = "Guardar",
                onEvent = handleButtonEvent,
                emboss = false,
                shape="roundedRect",
                width = 150,
                height = 40,
                cornerRadius = 2,
                labelColor ={default={ 1,1,1,1 }},
                fillColor = { default={ 98/254, 178/254, 232/254, 1 }, over={ 1, 0.1, 0.7, 0.4 } },
                strokeColor = {default={ 118/254, 198/254, 252/254, 1 }, over={ 0.8, 0.8, 1, 1 } },
                strokeWidth = 2
            }
            bt_guardar.x = display.contentCenterX*0.8
            bt_guardar.y = display.contentHeight - bt_guardar.height
            v:insert(bt_guardar)
            
            local bt_back = widget.newButton
            {
                label = "Atras",
                onEvent = handleButtonEvent,
                emboss = false,
                shape="roundedRect",
                width = 150,
                height = 40,
                cornerRadius = 2,
                labelColor ={default={ 1,1,1,1 }},
                fillColor = { default={ 98/254, 178/254, 232/254, 1 }, over={ 1, 0.1, 0.7, 0.4 } },
                strokeColor = {default={ 118/254, 198/254, 252/254, 1 }, over={ 0.8, 0.8, 1, 1 } },
                strokeWidth = 2
            }
            bt_back.x = display.contentCenterX*1.2
            bt_back.y = display.contentHeight - bt_back.height
            v:insert(bt_back)
        end,
        clean=function()
            if ClassroomName ~= nil then
                ClassroomName:removeSelf()
                ClassroomName = nil
            end
        end
    }
}