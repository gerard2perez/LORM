local widget = require( "widget" )

-- Function to handle button events
local function handleButtonEvent( event )

    if ( "ended" == event.phase ) then
        print("GoTO:"..event.target:getLabel():lower())
        STB.Go("View."..event.target:getLabel():lower())
    end
end

return STB{ "View.splash",{
    create=function(e,v,d)
        --v.out(collectgarbage("count")*1024)
        --local Grade = EMMAContext.Grade{Name="Grade 1"}
        --v.out(collectgarbage("count")*1024)
        --Grade:save()
        --v.out(collectgarbage("count")*1024)
        --v.out(collectgarbage("collect"))
        --v.out(collectgarbage("count")*1024)
        --v.out("Single Object Creation")
        local bt_grade = widget.newButton
        {
            label = "Grade",
            onEvent = handleButtonEvent,
            emboss = false,
            shape="roundedRect",
            width = 200,
            height = 40,
            cornerRadius = 2,
            labelColor ={default={ 1,1,1,1 }},
            fillColor = { default={ 98/254, 178/254, 232/254, 1 }, over={ 1, 0.1, 0.7, 0.4 } },
            strokeColor = {default={ 118/254, 198/254, 252/254, 1 }, over={ 0.8, 0.8, 1, 1 } },
            strokeWidth = 2
        }
        -- Center the button
        bt_grade.x = display.contentCenterX
        bt_grade.y = display.contentCenterY*0.5
            
        local bt_classroom = widget.newButton
        {
            label = "Group",
            onEvent = handleButtonEvent,
            emboss = false,
            shape="roundedRect",
            width = 200,
            height = 40,
            cornerRadius = 2,
            labelColor ={default={ 1,1,1,1 }},
            fillColor = { default={ 98/254, 178/254, 232/254, 1 }, over={ 1, 0.1, 0.7, 0.4 } },
            strokeColor = {default={ 118/254, 198/254, 252/254, 1 }, over={ 0.8, 0.8, 1, 1 } },
            strokeWidth = 2
        }
            
        bt_classroom.x = display.contentCenterX
        bt_classroom.y = display.contentCenterY*1.5
        
            
        
        v:insert(bt_classroom)
        v:insert(bt_grade)
    end,
    prepare=function(e,v,d)
        --v.out("Prepare")
    end
}}