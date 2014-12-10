local widget = require( "widget" )
local GradeName = nil
local Grades = nil
local pick = nil
local superview=nil
function picker()
    --Get All Grades
    Grades = EMMAContext.Grade:findAll()
    --Get Labels for pickers
    local labels = {}

    for id,grade in pairs(Grades) do
        table.insert(labels,grade.Name)
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
    if #Grades == 0 then
        labels[1]="empty"
    end
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
                GradeName.text = Grades[val].Name
                idx = val
            end,
            ["crear nuevo"] = function()
                GradeName.text = ""
                    idx = -1
            end,
            ["guardar"] = function()
                
                if idx == -1 and GradeName.text~= "" then
                   local gdr = EMMAContext.Grade{Name=GradeName.text}
                   gdr:save()
                    pick:removeSelf()
                    pick= picker()
                elseif idx > -1 and GradeName.text~= "" then
                    Grades[idx].Name = GradeName.text
                    Grades[idx]:save()
                    pick:removeSelf()
                    pick= picker()
                end
                    GradeName.text=""
                superview:insert(pick)
            end,
            ["atras"]=function()
                STB.back()
            end
        })
        --STB.Go("View."..event.target:getLabel():lower())
    end
end

return STB{ "View.grade",{
        create=function(e,v,d)
            superview=v
            v.out("Grade Creation")
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
            
            GradeName = native.newTextField( display.contentWidth*0.05, bt_edit.y+bt_edit.height, display.contentWidth*0.9, 40 )
            GradeName.anchorX=0
            GradeName.anchorY=0
            GradeName.size=30
            v:insert(GradeName)
            
            
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
            if GradeName ~= nil then
                GradeName:removeSelf()
                GradeName = nil
            end
        end
    }
}