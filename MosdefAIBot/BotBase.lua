local ADDON_NAME = 'MosdefAIBot'
local PREFIX = ADDON_NAME

AI = AI or {}

AI.CHAT_PREFIX = PREFIX
AI.AUTO_DPS = false
AI.AUTO_CLEANSE = true
AI.AUTO_TAUNT = true
AI.ALLOW_AUTO_MOVEMENT = true
AI.ALLOW_AUTO_REFACE = true
AI.DISABLE_CDS = false
AI.AUTO_PURGE = true
AI.IS_DOING_ONUPDATE = false
AI.AUTO_AOE = false
AI.DISABLE_DRAIN = false
AI.DISABLE_THREAT_MANAGEMENT = false

AI.BossModules = {}
AI.ZoneModules = {}

-- did the addon load successfully
local isAddonLoaded = false

-- is the bot allowed to run for this class
local isGreenlit = true

local isInCombat = false

-- whether the bot 'ticks' or takes any action
local isAIEnabled = false

local autoEnableIfInRaid = true

local tickTime = 0

local lastIwtTime = 0
local wrongFacingIwtTime = 0
local lastRefaceLeaderTime = 0

local lastPlayerEnterWorld = nil

local previousZoneName = nil

local cachedOnUpdateCallbacks = nil

local findEnabledBossModule

local goToPositionDestination = nil
local hasReachedGoToPosition = nil

local registeredClassEventHandlers = {}
local registeredPendingActions = {}

--
local desiredPlayerFacing = nil
local desiredVehicleAimAngle = nil
local desiredFollowTarget = nil

local function onUpdate()
    if not isAIEnabled or not isGreenlit then
        return
    end
    if not cachedOnUpdateCallbacks then
        cachedOnUpdateCallbacks = {}
        for func in pairs(AI) do
            if MaloWUtils_StrStartsWith(func, "doOnUpdate") then
                table.insert(cachedOnUpdateCallbacks, AI[func])
            end
        end
    end
    ---        
    AI.IS_DOING_ONUPDATE = true
    local bossMod = findEnabledBossModule()
    -- if we have a boss module
    if bossMod and type(bossMod.onUpdate) == "function" and bossMod:onUpdate() then
        -- execute the base on update method but skip all the class specific ones
        AI.doOnUpdate_BotBase()
        AI.IS_DOING_ONUPDATE = false
        return
    end
    for i, f in ipairs(cachedOnUpdateCallbacks) do
        f()
    end
    AI.IS_DOING_ONUPDATE = false
    -- do auto-dps towards the end
    if AI.AUTO_DPS and AI.doAutoDps then
        AI.doAutoDps()
    end

    local now = GetTime()
    -- execute pending action before boss updates
    for i, action in ipairs(registeredPendingActions) do
        if now >= action.when and action.executed == false and action.f() then
            action.executed = true
        end
    end

    -- clean up executed actions
    local done = false
    while not done do
        done = true
        for i, action in ipairs(registeredPendingActions) do
            if action.executed == true then
                table.remove(registeredPendingActions, i)
                done = false
                break
            end
        end
    end
end

local function onAddOnLoad()
    if IsInRaid() and autoEnableIfInRaid then
        isAIEnabled = true
    end
    --- invokes any 'doOnLoad_' funcs that have been registered by any addon
    for i in pairs(AI) do
        if MaloWUtils_StrStartsWith(i, "doOnLoad") then
            AI[i]()
        end
    end

    -- invoke on enter for current zone
    previousZoneName = GetRealZoneText()
    local zoneId = GetCurrentMapAreaID()
    for i in pairs(AI.ZoneModules) do
        if AI.ZoneModules[i].zoneName == previousZoneName or AI.ZoneModules[i].zoneId == zoneId then
            AI.ZoneModules[i]:onEnter()
        end
    end
end

local total = 0
local function onAddOnUpdate(self, elapsed)
    total = total + elapsed
    tickTime = GetTime()
    if total >= 0.1 then
        total = 0
        onUpdate()
    end

    -- delay
    if lastPlayerEnterWorld ~= nil then
        local diff = (tickTime - lastPlayerEnterWorld)
        if diff > 1 then
            lastPlayerEnterWorld = nil
            onAddOnLoad()
        end
    end
end

local function loadBossModule(bossName, creatureId)
    -- print("Attempting to load bossModule "..bossName)
    if bossName == nil and creatureId == nil then
        return
    end

    for i, mod in ipairs(AI.BossModules) do
        local foundMod = nil
        if creatureId ~= nil and type(mod.creatureId) == "table" then
            for i, id in ipairs(mod.creatureId) do
                if id == creatureId then
                    foundMod = mod
                    break
                end
            end
        end
        if bossName ~= nil and mod.name:lower() == bossName:lower() then
            foundMod = mod
        end
        if foundMod ~= nil and not foundMod.enabled then
            foundMod.enabled = true
            foundMod:onStart()
            AI.Print(bossName .. " module enabled, good luck!")
        end
    end
end

findEnabledBossModule = function()
    for i, mod in ipairs(AI.BossModules) do
        if mod.enabled == true then
            -- print("Found enabled bos mod "..mod.name)
            return mod
        end
    end
    return nil
end

local function unloadBossModules()
    -- print ("Disabling boss modules")
    for i, mod in ipairs(AI.BossModules) do
        if mod.enabled == true then
            -- AI.Print("stopping boss mod " .. mod.name)
            mod:onStop()
            mod.enabled = false
        end
    end
end

local f = CreateFrame("frame", ADDON_NAME .. "Frame", UIParent)
f:SetPoint("CENTER")
f:SetScript("OnUpdate", onAddOnUpdate)
f:SetSize(1, 1)
f:Show()

-- expose a slash command to  control the bot via commands
SlashCmdList["AIBotCOMMAND"] = function(msg)
    if not isAddonLoaded then
        AI.Print(PREFIX .. " has not loaded yet!")
        return
    end

    -- TODO: Add control bot via leader
    if MaloWUtils_StrStartsWith(msg, "on") then
        isAIEnabled = true
        print(PREFIX .. " is enabled!")
        AI.SendAddonMessage("on")
        return true
    end

    if MaloWUtils_StrStartsWith(msg, "off") then
        isAIEnabled = false
        print(PREFIX .. " is disabled!")
        AI.SendAddonMessage("off")
        return true
    end

    if MaloWUtils_StrStartsWith(msg, "auto-dps") then
        if msg:find("on") then
            AI.toggleAutoDps(true)
            if UnitName("player"):lower() == tostring(AI.Config.tank or ""):lower() then
                AI.SendAddonMessage("auto-dps", "on")
            end
            return true
        else
            AI.toggleAutoDps(false)
            if UnitName("player"):lower() == tostring(AI.Config.tank or ""):lower() then
                AI.SendAddonMessage("auto-dps", "off")
            end
            return true
        end
    end

    if MaloWUtils_StrStartsWith(msg, 'come-to-me') then
        AI.SendAddonMessage("come-to-me")
        return true
    end

    if MaloWUtils_StrStartsWith(msg, 'follow-me') then
        AI.SendAddonMessage("follow-me")
        return true
    end

    if MaloWUtils_StrStartsWith(msg, 'stop-follow') then
        AI.SendAddonMessage("stop-follow")
        return true
    end

    if MaloWUtils_StrStartsWith(msg, 'same-facing') then
        AI.SendAddonMessage('set-facing', GetPlayerFacing())
        return true
    end

    if MaloWUtils_StrStartsWith(msg, 'same-vehicle-aim') then
        if AI.IsPossessing() and IsVehicleAimAngleAdjustable() then
            AI.SendAddonMessage('set-vehicle-aim-angle', VehicleAimGetAngle())
        else
            AI.Print("You must be in a vehicle with adjustable aim")
        end
        return true
    end

    AI.Print("unrecognized command: " .. msg)
end
SLASH_AIBotCOMMAND1 = "/aibot"
--

local function onAddOnChatMessage(from, message)

    local cmd = string.sub(message, 1, string.find(message, "|") - 1)
    local params = string.sub(message, string.find(message, "|") + 1)

    -- print("onAddOnChatMessage from "..from.. " cmd: "..cmd .. " params:" .. params)

    if cmd == "on" then
        isAIEnabled = true
        print(PREFIX .. " is enabled!")
    elseif cmd == "off" then
        isAIEnabled = false
        print(PREFIX .. " is disabled!")
    elseif cmd == "load-boss-module" and UnitName("player") ~= from then
        loadBossModule(params)
    elseif cmd == "auto-dps" then
        if params == "on" then
            AI.toggleAutoDps(true)
        else
            AI.toggleAutoDps(false)
        end
    elseif cmd == "come-to-me" then
        if from ~= UnitName("player") then
            -- print("Moving to "..from)
            local x, y = AI.GetPosition(from)
            AI.SetMoveToPosition(x, y, 0.001)
        end
    elseif cmd == "set-facing" then
        if from ~= UnitName("player") then
            -- print("set-facing from " .. from .. " params: " .. params)
            desiredPlayerFacing = params
        end
    elseif cmd == 'set-vehicle-aim-angle' then
        -- print('set-vehicle-aim-angle to ' .. params)
        if AI.IsPossessing() and IsVehicleAimAngleAdjustable() then
            desiredVehicleAimAngle = params
        end
    elseif cmd == 'follow-me' then
        if from ~= UnitName("player") then
            AI.Print("setting follow to "..from)
            desiredFollowTarget = from
        end
    elseif cmd == 'stop-follow' then
        AI.Print("Clearing follow")
        desiredFollowTarget = nil        
    end
end

local function handleFacingWrongWay()
    if AI.ALLOW_AUTO_REFACE then
        if GetCVar("autoInteract") ~= 1 then
            SetCVar("autoInteract", 1)
        end
        InteractUnit("target")
        SetCVar("autoInteract", 0)
        wrongFacingIwtTime = tickTime
    end
end

local cachedUnitCastCb = nil
local function onEvent(self, event, ...)
    local arg1 = select(1, ...)
    local arg2 = select(2, ...)
    local arg3 = select(3, ...)
    local arg4 = select(4, ...)
    local arg5 = select(5, ...)
    local arg6 = select(6, ...)
    local arg7 = select(7, ...)
    local arg8 = select(8, ...)

    local bossMod = findEnabledBossModule()

    if event == "ADDON_LOADED" and arg1 == ADDON_NAME then
        isAddonLoaded = true
        AI.Print(PREFIX .. " has been successfully loaded")
    elseif event == "CHAT_MSG_ADDON" and arg1 == PREFIX then
        local msg = arg2
        local from = arg4
        onAddOnChatMessage(from, msg)
    elseif event == "PLAYER_REGEN_DISABLED" then
        AI.isInCombat = true
        loadBossModule(UnitName("target"), AI.GetUnitCreatureId("target"))
        AI.SendAddonMessage("load-boss-module", UnitName("target"))
    elseif event == "PLAYER_REGEN_ENABLED" then
        AI.isInCombat = false
        unloadBossModules()
        AI.ResetMoveToPosition()
    elseif event == "PLAYER_ENTERING_WORLD" then
        lastPlayerEnterWorld = GetTime()
        AI.ResetMoveToPosition()
    elseif event == "UI_ERROR_MESSAGE" then
        if arg1 == "You are facing the wrong way!" or arg1 == "Target needs to be in front of you." then
            handleFacingWrongWay()
        end
    elseif event == "UNIT_SPELLCAST_START" or event == "UNIT_SPELLCAST_CHANNEL_START" then
        local caster, spellName, rank = arg1, arg2, arg3
        -- print("UNIT_SPELLCAST_START arg1 "..arg1.. " arg2 "..arg2 .. " arg3 "..arg3 .. " arg4 "..arg4)
        if cachedUnitCastCb == nil then
            cachedUnitCastCb = {}
            for f in pairs(AI) do
                if MaloWUtils_StrStartsWith(f, "doOnTargetStartCasting") then
                    table.insert(cachedUnitCastCb, AI[f])
                end
            end
        end
        -- if arg1 == "target" then
        --     for i, f in ipairs(cachedUnitCastCb) do
        --         f()
        --     end
        -- end
        if bossMod ~= nil and type(bossMod[event]) == "function" then
            bossMod[event](bossMod, caster, spellName)
        end

    elseif event == "PLAYER_TARGET_CHANGED" then
        if AI.IsInCombat() and AI.IsValidOffensiveUnit("target") then
            loadBossModule(UnitName("target"), AI.GetUnitCreatureId("target"))
            AI.SendAddonMessage("load-boss-module", UnitName("target"))
        end
    elseif event == "ZONE_CHANGED_NEW_AREA" then
        local zoneName = GetRealZoneText()
        local zoneId = GetCurrentMapAreaID()
        print("new zone " .. zoneName .. " id: " .. zoneId)
        for i in pairs(AI.ZoneModules) do
            if AI.ZoneModules[i].zoneName == zoneName or AI.ZoneModules[i].zoneId == zoneId then
                AI.ZoneModules[i]:onEnter()
            end
            if previousZoneName ~= nil and previousZoneName ~= zoneName and AI.ZoneModules[i].zoneName ==
                previousZoneName then
                AI.ZoneModules[i]:onLeave()
            end
        end
    elseif event == "UNIT_AURA" then
        -- print("UNIT_AURA "..arg1)
    elseif event == "RAID_BOSS_EMOTE" then
        print("RAID_BOSS_EMOTE" .. arg1 .. arg2 .. arg3)
    elseif event == "COMBAT_LOG_EVENT_UNFILTERED" then
        -- event out unit deaths
        if arg2 == "UNIT_DIED" or arg2 == "UNIT_DESTROYED" then
            local unitName = arg7
            if unitName:lower() == UnitName("player"):lower() then
                unloadBossModules()
                AI.ResetMoveToPosition()
            end
            -- print("unit died/destroyed "..arg6.. " ".. arg7)
            if bossMod and bossMod[arg2] and type(bossMod[arg2]) == "function" then
                bossMod[arg2](bossMod, unitName)
            end
            return
            -- event out spell  events
        elseif arg2:sub(1, 5) == "SPELL" then
            local spellId, spellName, spellSchool, extraArg1, extraArg2, extraArg3 = select(9, ...)
            local caster, target = arg4 or "n/a", arg7 or "n/a"
            local unitName = UnitName("player"):lower()
            if unitName == caster:lower() or unitName == target:lower() then
                -- print(arg2 .. " spell "..spellName.. " caster "..caster .. " target "..target or "")
            end
            local args = {
                spellName = spellName,
                caster = caster,
                target = target,
                spellId = spellId,
                arg1 = extraArg1 or "n/a",
                arg2 = extraArg2 or "n/a",
                arg3 = extraArg3 or "n/a"
            }
            -- print(arg2 .. " ".. MaloWUtils_ConvertTableToString(args))
            if bossMod and bossMod[arg2] and type(bossMod[arg2]) == "function" then
                bossMod[arg2](bossMod, args)
            end
            for i in pairs(registeredClassEventHandlers) do
                if registeredClassEventHandlers[i].event == arg2 and type(registeredClassEventHandlers[i].f) ==
                    "function" then
                    registeredClassEventHandlers[i].f(f, args)
                end
            end
            return
        end
    end

    if bossMod and bossMod[event] and type(bossMod[event]) == "function" then
        -- print("invoking "..event .. " on boss mod ".. bossMod.name)
        bossMod[event](bossMod, ...)
    end

    for i in pairs(registeredClassEventHandlers) do
        if registeredClassEventHandlers[i].event == event and type(registeredClassEventHandlers[i].f) == "function" then
            registeredClassEventHandlers[i].f(f, ...)
        end
    end
end

-- #auto movement

function AI.SetMoveToPosition(x, y, minDist)
    --AI.StopMoving()
    goToPositionDestination = {
        x = x,
        y = y,
        minDistance = minDist or 0.003
    }
    hasReachedGoToPosition = false
end

function AI.HasMoveToPosition()
    return goToPositionDestination ~= nil
end

function AI.ResetMoveToPosition()
    goToPositionDestination = nil
    hasReachedGoToPosition = false
    AI.ALLOW_AUTO_MOVEMENT = true
    -- AI.StopMoving()
end

function AI.HasReachedDestination()
    return hasReachedGoToPosition
end

local function doAutoMovementUpdate()
    if goToPositionDestination == nil then
        return true
    end

    local curX, curY = AI.GetPosition("player")
    local dX, dY = goToPositionDestination.x - curX, goToPositionDestination.y - curY
    local distance = math.sqrt(dX * dX + dY * dY)
    if hasReachedGoToPosition and distance <= goToPositionDestination.minDistance * 1.2 then
        -- Allow 20% leeway if you reached the destination previously.
        return true
    end
    if distance <= goToPositionDestination.minDistance then
        AI.StopMoving()
        hasReachedGoToPosition = true
        goToPositionDestination = nil
        return true
    end
    hasReachedGoToPosition = false

    local currentFacing = GetPlayerFacing()
    local desiredFacing = math.atan2(dX, dY) + math.pi
    local diff = desiredFacing - currentFacing

    -- the difference btwn our facing and desired facing is more than 10 degrees, then we bother w/ turning left/righ.
    if math.abs(diff) > 0.1745329252 then
        if diff > 0 then
            if (currentFacing + 2 * math.pi) - desiredFacing < diff then
                diff = (currentFacing + 2 * math.pi) - desiredFacing
                TurnLeftStop()
                TurnRightStop()
                TurnRightStart()
            else
                TurnRightStop()
                TurnLeftStop()
                TurnLeftStart()
            end
        elseif diff < 0 then
            if (currentFacing - 2 * math.pi) - desiredFacing > diff then
                diff = (currentFacing - 2 * math.pi) - desiredFacing
                TurnRightStop()
                TurnLeftStop()
                TurnLeftStart()
            else
                TurnLeftStop()
                TurnRightStop()
                TurnRightStart()
            end
        end
    else
        TurnRightStop()
        TurnLeftStop()
    end
    if math.abs(diff) < math.pi / 3 then
        MoveForwardStart()
    else
        MoveForwardStop()
    end
    return false
end

function AI.doOnUpdate_BotBase()
    if wrongFacingIwtTime > 0 then
        local diff = tickTime - wrongFacingIwtTime
        if diff > 0.2 then
            wrongFacingIwtTime = 0
            AI.StopMoving()
        end
    end
    if lastRefaceLeaderTime > 0 then
        local diff = tickTime - lastRefaceLeaderTime
        if diff > 0.2 then
            lastRefaceLeaderTime = 0
            AI.StopMoving()
        end
    end
    --
    if AI.ALLOW_AUTO_MOVEMENT then
        doAutoMovementUpdate()
    end

    if desiredPlayerFacing ~= nil then
        local currentFacing = GetPlayerFacing()
        local diff = desiredPlayerFacing - currentFacing
        if math.abs(diff) > 0.1745329252 then
            if diff > 0 then
                if (currentFacing + 2 * math.pi) - desiredPlayerFacing < diff then
                    diff = (currentFacing + 2 * math.pi) - desiredPlayerFacing
                    TurnLeftStop()
                    TurnRightStop()
                    TurnRightStart()
                else
                    TurnRightStop()
                    TurnLeftStop()
                    TurnLeftStart()
                end
            elseif diff < 0 then
                if (currentFacing - 2 * math.pi) - desiredPlayerFacing > diff then
                    diff = (currentFacing - 2 * math.pi) - desiredPlayerFacing
                    TurnRightStop()
                    TurnLeftStop()
                    TurnLeftStart()
                else
                    TurnLeftStop()
                    TurnRightStop()
                    TurnRightStart()
                end
            end
        else
            desiredPlayerFacing = nil
            TurnRightStop()
            TurnLeftStop()
        end
    end

    if desiredVehicleAimAngle ~= nil and AI.IsPossessing() and IsVehicleAimAngleAdjustable() then
        local currentAimAngle = VehicleAimGetAngle()
        local diff = desiredVehicleAimAngle - currentAimAngle
        if math.abs(diff) > 0.1745329252 then
            if diff > 0 then
                VehicleAimUpStart()
            else
                VehicleAimDownStart()
            end
        else
            VehicleAimUpStop()
            VehicleAimDownStop()
            desiredVehicleAimAngle = nil
        end
    end

    if desiredFollowTarget ~= nil and desiredFollowTarget ~= UnitName("player") then
        local calcDist = AI.GetDistanceTo(AI.GetPosition(desiredFollowTarget))
        if AI.GetDistanceTo(AI.GetPosition(desiredFollowTarget)) > 0.003 then
            AI.SetMoveToPosition(AI.GetPosition(desiredFollowTarget))
        end
    end
end

-- stub, overridden
function AI.do_PriorityTarget()
    return false
end

-- stub
function AI.FollowCrawl(unit)
    if unit ~= nil and UnitExists(unit) then
        FollowUnit(unit)
        lastRefaceLeaderTime = tickTime
    end
end

-- stub overridden by class AIs
function AI.DO_DPS(isAoE)
end

function AI.ExecuteDpsMethod(isAoE)
    AI.RegisterPendingAction(function()
        if not AI.AUTO_DPS then
            if type(AI.PRE_DO_DPS) ~= "function" or not AI.PRE_DO_DPS(isAoE) then
                AI.DO_DPS(isAoE)
            end
        end
        return true
    end, null, "DO_DPS")
end

-- generic mount function, customizable
function AI.DO_MOUNT(flyMount)
    if flyMount then
        RunMacroText("/use blue wind rider")
    else
        RunMacroText("/use amani war bear")
    end
end

function AI.toggleAutoDps(on)
    if on then
        AI.AUTO_DPS = true
        print(PREFIX .. " AUTO_DPS ON")
        return true
    else
        AI.AUTO_DPS = false
        print(PREFIX .. " AUTO_DPS OFF")
        return true
    end
end

function AI.toggleAoEMode()
    if AI.AUTO_AOE then
        AI.AUTO_AOE = false
        -- AI.Print("auto-AOE OFF")
    else
        AI.AUTO_AOE = true
        -- AI.Print("auto-AOE ON")
    end
end

function AI.RegisterBossModule(mod)
    AI.Print("registering boss module " .. mod.name)
    table.insert(AI.BossModules, mod)
    if mod.events then
        for i, e in ipairs(mod.events) do
            -- print(mod.name .. " registered event " .. e)
            f:RegisterEvent(e)
        end
    end
end

function AI.RegisterZoneModule(mod)
    AI.Print("registering zone module " .. mod.zoneName)
    table.insert(AI.ZoneModules, mod)
    if mod.events then
        for i, e in ipairs(mod.events) do
            f:RegisterEvent(e)
        end
    end
end

function AI.RegisterClassEvent(event, f)
    table.insert(registeredClassEventHandlers, {
        event = event,
        f = f
    })
end

function AI.RegisterPendingAction(f, delay, id)
    local now = GetTime()
    local actionId = id or now
    for i, v in ipairs(registeredPendingActions) do
        if v.id == actionId then
            return
        end
    end
    local action = {
        id = actionId,
        f = f,
        when = now,
        executed = false
    }
    if type(delay) == "number" then
        action.when = now + delay
    end

    table.insert(registeredPendingActions, action)
end

f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("CHAT_MSG_ADDON")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:RegisterEvent("UI_ERROR_MESSAGE")
f:RegisterEvent("UNIT_SPELLCAST_START")
f:RegisterEvent("UNIT_SPELLCAST_STOP")
f:RegisterEvent("UNIT_SPELLCAST_CHANNEL_START")
f:RegisterEvent("PLAYER_TARGET_CHANGED")
f:RegisterEvent("ZONE_CHANGED_NEW_AREA")
f:RegisterEvent("PLAYER_REGEN_DISABLED")
f:RegisterEvent("PLAYER_REGEN_ENABLED")
f:RegisterEvent("CHAT_MSG_RAID_BOSS_EMOTE")
f:RegisterEvent("RAID_BOSS_EMOTE")
f:RegisterEvent("UNIT_DIED")
f:RegisterEvent("UNIT_AURA")
f:RegisterEvent("UNIT_DESTROYED")
f:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
f:SetScript("OnEvent", onEvent)
