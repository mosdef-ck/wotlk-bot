AI = AI or {}


local function onHealAIUpdate()

end

function AI.onLoad_Shaman()

    local spec = AI.GetMySpecName()
    
    if spec == "Restoration" then
        AI.RegisterOnUpdateHandler(onHealAIUpdate)
    else
        MB.Print(spec.. " is not a supporte spec")
end 