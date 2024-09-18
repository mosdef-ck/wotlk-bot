local ADDON_NAME = 'WOTLKAIBot'
local PREFIX  = ADDON_NAME
AI = AI or {}


-- did the addon load successfully
local isAddonLoaded = false
-- is the bot allowed to run for this class
local isGreenlit = false

local isInCombat = false

-- whether the bot 'ticks' or takes any action
local isAIEnabled = false

-- which classes this bot is allowed to run for
local ALLOWED_CLASSES = { "SHAMAN" }

-- This makes the bot tick 
local onUpdateHandlers = {}
function AI.RegisterOnUpdateHandler(func)
    table.insert(onUpdateHandlers, func)
end

local function onUpdate()
    if not isAIEnabled or not isGreenlit then
        return
    end
    for i,func in ipairs(onUpdateHandlers) do
        func()
    end
end

local total = 0
local function onAddOnUpdate(self, elapsed)
	total = total + elapsed
	if total >= 0.1 then
		total = 0
		onUpdate()
	end
end


local f = CreateFrame("frame", MY_NAME .. "Frame", UIParent)
f:SetPoint("CENTER")
f:SetScript("OnUpdate", onAddOnUpdate)
f:SetSize(1, 1)
f:Show()

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
    local class = AI.GetClass("player")
    for i, a in ipairs(ALLOWED_CLASSES) do
        if class == a then
            isGreenlit = true
            if class == "SHAMAN" then
                AI.onLoad_Shaman()
                MB.Print(PREFIX .. " loaded shaman AI addon")
                print(PREFIX .. " loaded shaman AI addon")
            end
            return
        end
    end
    MB.Print("class "..class.. " is unsupported by "..ADDON_NAME) 
end

local function onEvent(self, event, arg1, arg2, arg3, arg4, arg5, ...)
    if event == "ADDON_LOADED" and arg1 == ADDON_NAME then
        isAddonLoaded = true
        onAddOnLoad()
    elseif event == "CHAT_MSG_ADDON" and arg1 == PREFIX then
        local msg = arg2
        local from = arg4
        onAddOnChatMessage(from, msg)
    elseif event == "PLAYER_ENTER_COMBAT" then
        isInCombat = true
    elseif event == "PLAYER_LEAVE_COMBAT" then
        isInCombat = false
end


f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("CHAT_MSG_ADDON")
f:SetScript("OnEvent", onEvent)

--expose a slash command to  control the bot via commands
local AIControlPrefix = "AIBOT"
SlashCmdList[AIControlPrefix.."COMMAND"] = function(msg)
    if not isAddonLoaded then
        MB.Print(PREFIX.. " has not loaded yet!")
        return
    end

    -- TODO: Add control bot via leader
    local matches, rem = MaloWUtils_StringStartsWith(msg, "enable")
    if matches then
        isAIEnabled = true
        print(PREFIX .. " is enabled!")  
        return true
    end

    matches, rem = MaloWUtils_StringStartsWith(msg, "disable")
    if matches then
        isAIEnabled = false
        print(PREFIX .. " is disabled!")
    end

    MB.Print("Unrecognized command: "..msg)
end
SLASH_AIBOTCOMMAND1 = "/"..AIControlPrefix
--

