local ADDON_NAME = 'AIBotBase'
local PREFIX  = ADDON_NAME

AI = AI or {}

-- did the addon load successfully
local isAddonLoaded = false

-- is the bot allowed to run for this class
local isGreenlit = true

local isInCombat = false

-- whether the bot 'ticks' or takes any action
local isAIEnabled = false


local cachedOnUpdateCallbacks = nil
local function onUpdate()
    if not isAIEnabled or not isGreenlit then
        return
    end
    if not cachedOnUpdateCallbacks then
        cachedOnUpdateCallbacks = {}
        for func in pairs(AI) do
			print(func)		
            if MaloWUtils_StrStartsWith(func, "doOnUpdate") then
                table.insert(cachedOnUpdateCallbacks, AI[func])
            end
        end
    end
    for i, f in ipairs(cachedOnUpdateCallbacks) do 
        f()
    end
end

local total = 0
local function onAddOnUpdate(self, elapsed)
	total = total + elapsed
	if total >= 0.2 then
		total = 0
		onUpdate()
	end
end


local f = CreateFrame("frame", ADDON_NAME .. "Frame", UIParent)
f:SetPoint("CENTER")
f:SetScript("OnUpdate", onAddOnUpdate)
f:SetSize(1, 1)
f:Show()

--expose a slash command to  control the bot via commands
SlashCmdList["AIBotCOMMAND"] = function(msg)
    if not isAddonLoaded then
        AI.Print(PREFIX.. " has not loaded yet!")
        return
    end

    -- TODO: Add control bot via leader
    if MaloWUtils_StrStartsWith(msg, "on") then
        isAIEnabled = true
        print(PREFIX .. " is enabled!")  
        return true
    end

    if MaloWUtils_StrStartsWith(msg, "off") then
        isAIEnabled = false
        print(PREFIX .. " is disabled!")
		return true
    end
	

    AI.Print("unrecognized command: ".. msg)
end
SLASH_AIBotCOMMAND1 = "/aibot"
--

local function onAddOnChatMessage(from, message)
    local messageType = string.sub(mbCom.message, 1, string.find(mbCom.message, " ") - 1)
	local message = string.sub(mbCom.message, string.find(mbCom.message, " ") + 1)

    if message == "enable" then
        isAIEnabled = true
        print(PREFIX .. " is enabled!")  
    elseif message == "disable" then
        isAIEnabled = false
        print(PREFIX .. " is disabled!")
    end
end

local function onAddOnLoad()
    --- invokes any 'doOnLoad_' funcs that have been registered by any addon
    for func in pairs(AI) do        
        if MaloWUtils_StrStartsWith(func, "doOnLoad") then
            AI[func]()
        end
    end
end

local function onEvent(self, event, arg1, arg2, arg3, arg4, arg5, ...)
    if event == "ADDON_LOADED" and arg1 == ADDON_NAME then
		isAddonLoaded = true		
		AI.Print(PREFIX.." has been successfully loaded")
    elseif event == "CHAT_MSG_ADDON" and arg1 == PREFIX then
        local msg = arg2
        local from = arg4
        onAddOnChatMessage(from, msg)
    elseif event == "PLAYER_ENTER_COMBAT" then
        AI.isInCombat = true
    elseif event == "PLAYER_LEAVE_COMBAT" then
        AI.isInCombat = false
	elseif event == "PLAYER_ENTERING_WORLD" then
		onAddOnLoad()
	end
end


f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("CHAT_MSG_ADDON")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:SetScript("OnEvent", onEvent)