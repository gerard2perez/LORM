log_to_tab=print
log=print

STB = require "storybuilder"
STB.composer.recycleOnSceneChange = true
function gout(stringinfo)
    log_to_tab('garbage',stringinfo)
end

LORMPath = "LORM"
LORMConfig={
    TimeStamps = true,
    DeleteDb = false,
    RestSync ={
        host = "http://www.syncdemo.phalcon", -- This may Not Work on your server
    }
}
LORMVerbose={
    Schema = false,
    Migration = false
}

print(collectgarbage("count")*1024)
require "DataModel.EMMAContext"
print(collectgarbage("count")*1024)
print("Delta after requiring the model")
STB.Go("View.splash")
print("OK")