function typeof(var)
    local _type = type(var);
    if(_type ~= "table" and _type ~= "userdata") then
        return _type;
    end
    local _meta = getmetatable(var);
    if(_meta ~= nil and _meta._NAME ~= nil) then
        return _meta._NAME;
    else
        return _type;
    end
end
function extend(target,base)
    local res = {}
    for attr,value in pairs(base) do
        if(  typeof(value) == "table") then
            
            res[attr] = extend({},base[attr])
        else
            res[attr] = value
        end
    end
    
    for attr,value in pairs(target) do
        if(  typeof(value) == "table") then
            res[attr] = extend(target[attr],res[attr])
        else
            res[attr] = value 
        end
    end
    return res
end
STORYBUILDER = {
    composer = require "composer",
    debug=false,
    Go=function(Name)
        STORYBUILDER.composer.gotoScene( Name, {effect="fade",time = 400})
    end,
    back= function()
        STORYBUILDER.composer.gotoScene(STORYBUILDER.composer._previousScene,{effect="fade",time = 400})
    end
}
setmetatable(STORYBUILDER,{
    __call = function(self,args)
        local name = args[1]
        local bkg = args[2]
        local events = args[3]
        local CleanName = name:gsub("View.","")
        CleanName = CleanName:sub(0,1):upper()..CleanName:sub(2,-1)
        local composer = STORYBUILDER.composer
        if events == nil then
            events = bkg
            bkg = ""
        end
        local ext = extend({h=0,k=10},{h=1})
        events = extend(events,{
            create=function()end,
            clean=function()end,
            prepare=function()end,
            began=function() end,
            destroy=function()end
        })
        local rootView = display.newGroup()
        function rootView.out(stringinfo)
            log_to_tab(CleanName,stringinfo)
        end
        local scene = composer.newScene()
        scene.name = name
        function scene:create(event)
            self.view:insert(rootView)
            event.SuperView = self.view
            rootView.out("=========Create Event")
            events.create(event,rootView,STORYBUILDER.debug)
        end
        function scene:show( event )
            if event.phase == "will" then
                rootView.out("=========Will Show Event")
                events.prepare(event,rootView,STORYBUILDER.debug)
            elseif event.phase == "did" then
                --STORYBUILDER.composer.removeHidden()
                rootView.out("=========Did Show Event")
                events.began(event,rootView,STORYBUILDER.debug)
            end
        end
        function scene:hide( event )
            if event.phase == "will" then
                rootView.out("=========Will Hide Event")
                events.clean(event,rootView,STORYBUILDER.debug)
            elseif event.phase == "did" then
                rootView.out("=========Did Hide Event")
                return true
            end 
        end        
        function scene:destroy( event )
            rootView.out("=========Destroy Event")
            events.destroy(event,rootView,STORYBUILDER.debug)
        end
        scene:addEventListener( "create", scene )
        scene:addEventListener( "show", scene )
        scene:addEventListener( "hide", scene )
        scene:addEventListener( "destroy", scene )
        return scene
    end
})
return STORYBUILDER