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
AI.USE_MANA_REGEN = true
AI.DISABLE_WARLOCK_CURSE = false
AI.DISABLE_PRIEST_DISPERSION = false
AI.DISABLE_PET_AA = false
AI.DISABLE_DEEP_FREEZE = false

AI.BossModules = {}
AI.ZoneModules = {}

-- did the addon load successfully
local isAddonLoaded = false

-- is the bot allowed to run for this class
local isGreenlit = true

local isInCombat = false

-- whether the bot 'ticks' or takes any action
local isAIEnabled = true

local autoEnableIfInRaid = true

local tickTime = 0

local lastPlayerEnterWorld = nil

local previousZoneName = nil

local cachedOnUpdateCallbacks = nil
local lastCallbackCheckTime = GetTime()

local findEnabledBossModule, findZoneModule

local hasReachedGoToPosition = nil
local goToPath = nil
local goToPathCurrentWp = nil
local maxSpeedObserved = 0

local registeredClassEventHandlers = {}
local registeredPendingActions = {}

--
local desiredPlayerFacing = nil
local desiredVehicleAimAngle = nil
local desiredFollowTarget = nil
local focusedTarget = nil

local lastPosCheckTime = 0
local positionSetTime = 0
local lastCheckedPosition = nil
local lastSoulwellCheckTime = 0
local lastFishFeastCheckTime = 0

local objectAvoidance = nil

local function onUpdate()

    if not isAIEnabled or not isGreenlit then
        return
    end

    if not cachedOnUpdateCallbacks or GetTime() > lastCallbackCheckTime + 2 then
        cachedOnUpdateCallbacks = {}
        for func in pairs(AI) do
            if strcontains(func, "doOnUpdate") then
                table.insert(cachedOnUpdateCallbacks, AI[func])
            end
        end
    end

    -- not AI.IsPlayerInControl() or 
    if UnitIsDeadOrGhost("player") then
        return
    end
    ---            

    local bossMod = findEnabledBossModule()

    -- execute pending actions first
    local now = GetTime()
    -- execute pending action before boss updates
    AI.IS_DOING_ONUPDATE = true
    for i, action in ipairs(registeredPendingActions) do
        if now >= action.when and not action.executed and (action.f(bossMod) or action.oneshot) then
            action.executed = true
        end
    end
    -- clean up executed actions

    for i = #registeredPendingActions, 1, -1 do
        if registeredPendingActions[i].executed then
            table.remove(registeredPendingActions, i)
        end
    end

    -- execute boss actions    
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
    if AI.AUTO_DPS and type(AI.doAutoDps) == "function" then
        if type(AI.PRE_DO_DPS) ~= "function" or not AI.PRE_DO_DPS(AI.AUTO_AOE) then
            AI.doAutoDps()
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
        if (AI.ZoneModules[i].zoneName == previousZoneName or AI.ZoneModules[i].zoneId == zoneId) and
            not AI.ZoneModules[i].active then
            AI.ZoneModules[i]:onEnter()
            AI.ZoneModules[i].active = true
            UIErrorsFrame:AddMessage("activated zone module: " .. AI.ZoneModules[i].zoneName)
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

local function loadBossModule(creatureId)

    if UnitIsDeadOrGhost("player") then
        return
    end
    if creatureId == nil then
        return
    end
    local ncreatureId = tonumber(creatureId)
    if ncreatureId == nil then
        UIErrorsFrame:AddMessage("Failed to load boss-module for: " .. creatureId)
        return
    end

    for i, mod in ipairs(AI.BossModules) do
        local foundMod = nil
        if ncreatureId ~= nil and type(mod.creatureId) == "table" then
            for i, id in ipairs(mod.creatureId) do
                if id == ncreatureId then
                    foundMod = mod
                    break
                end
            end
        end
        if ncreatureId ~= nil and type(mod.creatureId) == "number" then
            if mod.creatureId == ncreatureId then
                foundMod = mod
            end
        end
        if ncreatureId ~= nil and type(mod.creatureId) == "string" then
            if tonumber(mod.creatureId) == ncreatureId then
                foundMod = mod
            end
        end

        if foundMod ~= nil and not foundMod.enabled then
            foundMod.enabled = true
            foundMod:onStart()
            UIErrorsFrame:AddMessage(foundMod.name .. " module enabled, good luck!")
            -- print("loaded boss module for " .. foundMod.name)
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

findZoneModule = function()
    local zoneName = GetRealZoneText()
    local subzone = GetMinimapZoneText()
    local zoneId = GetCurrentMapAreaID()
    for i, mod in ipairs(AI.ZoneModules) do
        if mod.zoneName == zoneName or mod.zoneId == zoneId or mod.zoneName == subzone then
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
            UIErrorsFrame:AddMessage(mod.name .. " module stopped.")
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
    elseif cmd == "load-boss-module" then
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
            local x, y, z = AI.GetPosition(from)
            AI.SetMoveToPosition(x, y, z)
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
            AI.Print("setting follow to " .. from)
            desiredFollowTarget = from
        end
    elseif cmd == 'stop-follow' then
        AI.Print("Clearing follow")
        desiredFollowTarget = nil
        AI.ResetMoveToPosition()
    elseif cmd == 'set-focused-target' then
        local guid = params
        AI.SetFocusedTarget(guid)
        -- print("got focused target guid: " .. guid)
    elseif cmd == "interact-with" then
        if from ~= UnitName("player") then
            local guid = params
            -- print("guid is " .. guid)
            if not guid or guid == "" then
                ClearTarget()
                AssistUnit(from)
                guid = UnitGUID("target")
            end
            if guid then
                local info = AI.GetObjectInfoByGUID(guid)
                if info then
                    info:InteractWith()
                end
            else
                local gos = AI.FindNearbyGameObjects()
                if #gos > 0 and gos[1].distance <= 10 then
                    print("interacting with " .. gos[1].name)
                    gos[1]:InteractWith()
                end
            end
        end
    elseif cmd == "use-trinkets" then
        if from ~= UnitName("player") and AI.IsDps() then
            -- print("received use-trinkets from " .. from)
            AI.RegisterPendingAction(function()
                local used = AI.UseInventorySlot(13) and AI.UseInventorySlot(10) and AI.UseInventorySlot(14)
                return used
            end, 0, "USE_TRINKETS");
        end
    elseif cmd == "form-star" then
        if from ~= UnitName("player") then
            -- print("received form-star from " .. from)
            local rad90 = math.pi / 2
            AssistUnit(from)
            if not AI.IsValidOffensiveUnit() then
                TargetUnit(from)
            end
            local tx, ty, tz
            local theta
            if not params or params == "" then
                tx, ty, tz = AI.GetPosition("target")
            else
                tx, ty, tz = splitstr3(params, ",")
                if tx == nil then
                    local obj = AI.GetObjectInfoByGUID(params)
                    tx, ty, tz = obj.x, obj.y, obj.z
                end
            end

            if UnitName("target") ~= from then
                theta = AI.CalcFacing(tx, ty, AI.GetPosition(from))
            else
                theta = AI.CalcFacing(tx, ty, AI.GetPosition())
            end
            local r = tonumber(params) or AI.Config.starFormationRadius
            if AI.IsHealer() then
                AI.SetMoveTo(tx + r * math.cos(theta), ty + r * math.sin(theta))
            end
            if AI.IsDpsPosition(1) then
                theta = theta + rad90 * 1
                AI.SetMoveTo(tx + r * math.cos(theta), ty + r * math.sin(theta))
            end
            if AI.IsDpsPosition(2) then
                theta = theta + rad90 * 2
                AI.SetMoveTo(tx + r * math.cos(theta), ty + r * math.sin(theta))
            end
            if AI.IsDpsPosition(3) then
                theta = theta + rad90 * 3
                AI.SetMoveTo(tx + r * math.cos(theta), ty + r * math.sin(theta))
            end
        end
    elseif cmd == 'toggle-closest-door' then
        local gos = AI.FindNearbyGameObjects()
        if #gos > 0 then
            local door = gos[1]
            print("toggling door " .. door.name .. " state " .. door.state)
            if door.state == 1 then
                door:SetGoState(0)
            else
                door:SetGoState(1)
            end
        end
    else
        local bossMod = findEnabledBossModule()
        if bossMod and type(bossMod.ON_ADDON_MESSAGE) == 'function' then
            bossMod:ON_ADDON_MESSAGE(from, cmd, params)
        end

        local zone = findZoneModule()
        if zone ~= nil and type(zone.ON_ADDON_MESSAGE) == 'function' then
            zone:ON_ADDON_MESSAGE(from, cmd, params)
        end
    end

end

local function handleFacingWrongWay()
    if AI.ALLOW_AUTO_REFACE and not AI.HasCTM() then
        StopFollowing()
        AI.SetFacingCoords(AI.GetPosition("target"))
    end
end

local cachedUnitCastCb = nil
local function onEvent(self, event, ...)
    local arg1 = select(1, ...) or ""
    local arg2 = select(2, ...) or ""
    local arg3 = select(3, ...) or ""
    local arg4 = select(4, ...) or ""
    local arg5 = select(5, ...) or ""
    local arg6 = select(6, ...) or ""
    local arg7 = select(7, ...) or ""
    local arg8 = select(8, ...) or ""

    local bossMod = findEnabledBossModule()

    if event == "ADDON_LOADED" and arg1 == ADDON_NAME then
        isAddonLoaded = true
        AI.Print(PREFIX .. " has been successfully loaded")
        previousZoneName = GetRealZoneText()
    elseif event == "CHAT_MSG_ADDON" and arg1 == PREFIX then
        local msg = arg2
        local from = arg4
        onAddOnChatMessage(from, msg)
    elseif event == "PLAYER_REGEN_DISABLED" then
        loadBossModule(AI.GetUnitCreatureId("target"))
        AI.SendAddonMessage("load-boss-module", AI.GetUnitCreatureId("target"))
    elseif event == "PLAYER_REGEN_ENABLED" then
        unloadBossModules()
        AI.ResetMoveToPosition()
        AI.Config.startHealOverrideThreshold = 100
    elseif event == "PLAYER_ENTERING_WORLD" then
        lastPlayerEnterWorld = GetTime()
        AI.ResetMoveToPosition()
    elseif event == "PLAYER_TALENT_UPDATE" then
        -- print("talent update")
        --- invokes any 'doOnLoad_' funcs that have been registered by any addon
        if not lastPlayerEnterWorld or tickTime - lastPlayerEnterWorld > 1 then
            for i in pairs(AI) do
                if strcontains(i, "doOnLoad") then
                    AI[i]()
                end
            end
        end
    elseif event == "UI_ERROR_MESSAGE" then
        if strcontains(arg1, "wrong way") or strcontains(arg1, "in front of you") then
            handleFacingWrongWay()
        end
    elseif event == "UNIT_SPELLCAST_START" or event == "UNIT_SPELLCAST_CHANNEL_START" then
        local caster, spellName, rank = arg1, arg2, arg3
        -- print("UNIT_SPELLCAST_START arg1 "..arg1.. " arg2 "..arg2 .. " arg3 "..arg3 .. " arg4 "..arg4)
        -- if cachedUnitCastCb == nil then
        --     cachedUnitCastCb = {}
        --     for f in pairs(AI) do
        --         if MaloWUtils_StrStartsWith(f, "doOnTargetStartCasting") then
        --             table.insert(cachedUnitCastCb, AI[f])
        --         end
        --     end
        -- end
        -- if arg1 == "target" then
        --     for i, f in ipairs(cachedUnitCastCb) do
        --         f()
        --     end
        -- end
        if bossMod ~= nil and type(bossMod[event]) == "function" then
            bossMod[event](bossMod, caster, spellName)
        end

    elseif event == "PLAYER_TARGET_CHANGED" then
        if AI.IsInCombat() and AI.IsValidOffensiveUnit("target", true) then
            loadBossModule(AI.GetUnitCreatureId("target"))
            AI.SendAddonMessage("load-boss-module", AI.GetUnitCreatureId("target"))
        end
    elseif event == "UNIT_TARGET" then
        if UnitName("player") == arg1 and AI.IsInCombat() and AI.IsValidOffensiveUnit("target", true) then
            loadBossModule(AI.GetUnitCreatureId("target"))
            AI.SendAddonMessage("load-boss-module", AI.GetUnitCreatureId("target"))
        end

    elseif (event == "ZONE_CHANGED_NEW_AREA" or event == "ZONE_CHANGED_INDOORS" or event == "ZONE_CHANGED") then
        local zoneName = GetRealZoneText()
        local subzone = GetMinimapZoneText()
        local zoneId = GetCurrentMapAreaID()
        local realMapId = GetCurrentMapID()
        if event == "ZONE_CHANGED_NEW_AREA" then
            print("new zone " .. zoneName .. " zoneId: " .. zoneId .. " realMapId: " .. (realMapId or "") ..
                      " subZone: " .. (subzone or ""))
        end
        for i, mod in ipairs(AI.ZoneModules) do
            if mod.active == true and (mod.zoneName ~= zoneName or mod.zoneId ~= zoneId or mod.subzone == subzone) then
                -- print("leaving zone " .. mod.zoneName)
                mod:onLeave()
                mod.active = false
            end
            if (mod.zoneName == zoneName or mod.zoneId == zoneId or mod.subzone == subzone) and not mod.active then
                previousZoneName = zoneName
                mod.active = true
                mod:onEnter()
                UIErrorsFrame:AddMessage("activated zone module: " .. mod.zoneName)
            end
        end
        local bossMod = findEnabledBossModule()
        if bossMod and bossMod.subzone and bossMod.subzone:lower() ~= subzone:lower() and not AI.IsInCombat() then
            unloadBossModules()
        end
        -- load boss modules related to the current subzone
        for i, mod in ipairs(AI.BossModules) do
            if mod.subzone and mod.subzone:lower() == subzone:lower() and not mod.active and #mod.creatureId > 0 then
                loadBossModule(mod.creatureId[1])
                AI.SendAddonMessage("load-boss-module", mod.creatureId[1])
            end
        end
    elseif event == "UNIT_AURA" then
        -- print("UNIT_AURA "..arg1)
    elseif event == "RAID_BOSS_EMOTE" then
        -- print("RAID_BOSS_EMOTE" .. arg1 .. arg2 .. arg3)
    elseif event == "CHAT_MSG_MONSTER_YELL" then
        -- print("CHAT_MSG_MONSTER_YELL "..arg1.. " "..arg2)
    elseif event == "CHAT_MSG_RAID_BOSS_EMOTE" then
        -- print("CHAT_MSG_RAID_BOSS_EMOTE "..arg1.. " "..arg2)
    elseif event == "CHAT_MSG_MONSTER_EMOTE" then
        -- print("CHAT_MSG_MONSTER_EMOTE "..arg1.. " "..arg2)    
    elseif event == "COMBAT_LOG_EVENT_UNFILTERED" then
        -- event out unit deaths
        if arg2 == "UNIT_DIED" or arg2 == "UNIT_DESTROYED" then
            local unitName = arg7
            if unitName:lower() == UnitName("player"):lower() then
                unloadBossModules()
                AI.ResetMoveToPosition()
                AI.StopMoving()
                AI.ClearObjectAvoidance()
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

function AI.SetMoveToPosition(tx, ty, tz, dist, onArrival)
    local minDistance = dist or 0.5
    if AI.IsInVehicle() then
        minDistance = dist or 5
    end
    local x, y, cz = AI.GetPosition()
    local currentPos = AI.PathFinding.Vector3.new(x, y, cz):to2D()
    if currentPos:distanceTo({
        x = tx,
        y = ty
    }) > minDistance then
        goToPath = {{
            x = tx,
            y = ty,
            z = tz or cz,
            minDistance = minDistance,
            onArrival = onArrival,
            startTime = GetTime(),
            endTime = nil
        }}
        goToPathCurrentWp = 1
        -- print("SetMoveTo "..x.." y:"..y.." minDist:"..minDistance)
        hasReachedGoToPosition = false
        positionSetTime = GetTime()
        AI.StopMoving()
        if IsFollowing() then
            StopFollowing()
        end
    end
    -- print(table2str(goToPath))
    -- else
    -- print("move-to pos differential too small to navigate")
    -- end
    -- AI.StopCasting()
    -- AI.StopMoving()
end

function AI.SetMoveToPath(path, dist, onArrival)
    if not path or type(path) ~= "table" or #path == 0 then
        print("no path given to move to")
        return false
    else
        -- AI.StopMoving()
        -- if IsFollowing() then
        --     StopFollowing()
        -- end
        local minDistance = dist or 0.7
        if AI.IsInVehicle() then
            minDistance = dist or 5
        end
        local x, y, z = AI.GetPosition()
        local currentPos = AI.PathFinding.Vector3.new(x, y, z):to2D()
        goToPath = {}
        for i, p in ipairs(path) do
            -- if currentPos:distanceTo(p) > minDistance then
            table.insert(goToPath, {
                x = p.x,
                y = p.y,
                z = p.z or z,
                minDistance = minDistance,
                onArrival = onArrival,
                startTime = nil,
                endTime = nil
            })
            -- end
        end
        if #goToPath > 0 then
            -- print("got path of length " .. #goToPath)
            goToPathCurrentWp = 1
            hasReachedGoToPosition = false
            positionSetTime = GetTime()
            -- print("go to path set")
        else
            print("path distance differential was too small to navigate")
        end
    end
    return true
end

function AI.SetMoveTo(...)
    AI.SetMoveToPosition(...)
end

function AI.HasMoveToPosition()
    return goToPath ~= nil and #goToPath > 0 and not hasReachedGoToPosition
end

function AI.HasMoveTo()
    return AI.HasMoveToPosition()
end

function AI.HasCTM()
    local ctmX, ctmY, ctmZ = GetClickToMove();
    return ctmX ~= nil and ctmY ~= nil
end

function AI.ResetMoveToPosition()
    goToPath = nil
    hasReachedGoToPosition = false
    AI.ALLOW_AUTO_MOVEMENT = true
    -- AI.StopMoving()
    -- print("ResetMoveToPosition")
end
function AI.ResetMoveTo()
    return AI.ResetMoveToPosition()
end

function AI.HasReachedDestination()
    return hasReachedGoToPosition
end

function AI.IsFacingTowardsDestination()
    if not AI.HasMoveToPosition() then
        return nil
    end
    local wp = goToPath[goToPathCurrentWp]
    return AI.IsFacingTowards(wp.x, wp.y)
end

function AI.GetMoveTo()
    if AI.HasMoveTo() then
        local wp = goToPath[goToPathCurrentWp]
        return wp.x, wp.y, wp.z
    end
    return nil
end

function AI.GetMoveToFinalDestination()
    if AI.HasMoveTo() then
        local countWp = #goToPath
        if countWp > 0 then
            return goToPath[countWp].x, goToPath[countWp].y, goToPath[countWp].z
        end
    end
    return nil
end

function AI.ShouldMoveTo(x, y, z)
    local nx, ny, nz = x, y, z
    if type(x) == "table" then
        nz = x.z or 0
        ny = x.y or 0
        nx = x.x or 0
    end
    local finalDestX, finalDestY, finalDestZ = AI.GetMoveToFinalDestination()
    return not AI.HasMoveTo() or (math.abs(finalDestX - nx) > 0.1 or math.abs(finalDestY - ny) > 0.1)
end

function AI.IsCurrentPathSafeFromObstacles(obstacles)
    if not goToPath or #goToPath == 0 or hasReachedGoToPosition or goToPathCurrentWp == #goToPath then
        return true
    end
    local px, py = AI.GetPosition()
    for p = goToPathCurrentWp, #goToPath, 1 do
        local cx, cy = goToPath[p].x, goToPath[p].y
        for i, o in ipairs(obstacles) do
            if AI.DoesLineIntersect(px, py, cx, cy, o.x, o.y, o.radius) then
                return false
            end
        end
        px, py = cx, cy
    end
    return true
end

-- Object Avoidance Algorithm
function AI.SetObjectAvoidance(descriptor)
    if type(descriptor.guids) == "table" then
        objectAvoidance = {
            name = descriptor.name or "AVOID_OBJECTS",
            objGuids = descriptor.guids,
            objRadius = descriptor.radius or 3,
            gridSize = descriptor.gridSize or 1,
            safeDistance = descriptor.safeDistance or descriptor.gridSize,
            polygon = descriptor.polygon,
            lastCheckTime = 0,
            targetVectorGUID = nil,
            targetVector = nil,
            targetVectorMinDistance = descriptor.gridSize or 1.5
        }
        -- print("obj-avoidance enabled")
        -- print(table2str(objectAvoidance))
        return true
    end
    print("invalid avoidance descriptor specified")
    return false
end

function AI.HasObjectAvoidance()
    return objectAvoidance ~= nil
end

function AI.ClearObjectAvoidance()
    objectAvoidance = nil
    -- print("obj-avoidance disabled")
    if AI.HasMoveTo() then
        AI.ResetMoveToPosition()
    end
end

function AI.SetObjectAvoidanceTarget(guidOrObj, minDistance)
    if AI.HasObjectAvoidance() then
        if (not objectAvoidance.targetVectorGUID or objectAvoidance.targetVectorGUID ~= guidOrObj) and
            (not objectAvoidance.targetVector or objectAvoidance.targetVector ~= guidOrObj) then
            print("obj-avoidance target set" .. table2str({
                target = guidOrObj,
                minDistance = minDistance
            }))
        end
        if (type(guidOrObj) == "string") then
            objectAvoidance.targetVectorGUID = guidOrObj
        else
            objectAvoidance.targetVector = guidOrObj
        end
        objectAvoidance.targetVectorMinDistance = minDistance or objectAvoidance.gridSize
        -- print('obj-avoidance targetVector set')
        return true
    end
    return false
end

function AI.GetObjectAvoidanceTarget()
    if AI.HasObjectAvoidance() then
        if objectAvoidance.targetVectorGUID then
            return objectAvoidance.targetVectorGUID
        else
            return objectAvoidance.targetVector
        end
    end
    return nil
end

function AI.ClearObjectAvoidanceTarget()
    if AI.HasObjectAvoidance() then
        objectAvoidance.targetVector = nil
        objectAvoidance.targetVectorGUID = nil
    end
end

local objectAvoidancePathGenerator = coroutine.create(function()
    while true do
        if objectAvoidance then
            local px, py, pz = AI.GetPosition()
            local polygon = ternary(objectAvoidance.polygon ~= nil, objectAvoidance.polygon,
                AI.PathFinding.createCircularPolygon({
                    x = px,
                    y = py,
                    z = pz
                }, 50))

            local obstacles = {}
            for i, guid in ipairs(objectAvoidance.objGuids) do
                local obj
                if type(guid) == "string" then
                    obj = AI.GetObjectInfoByGUID(guid)
                elseif guid.guid then
                    obj = AI.GetObjectInfoByGUID(guid.guid)
                else
                    obj = guid
                end
                if obj then
                    if type(guid) == "table" then
                        obj.radius = guid.radius or objectAvoidance.objRadius
                    else
                        obj.radius = objectAvoidance.objRadius
                    end
                    table.insert(obstacles, obj)
                end
            end
            -- target vector/guid opts
            local targetVector = nil
            if objectAvoidance.targetVectorGUID ~= nil then
                local targetObj = AI.GetObjectInfoByGUID(objectAvoidance.targetVectorGUID)
                if targetObj then
                    if targetObj == nil or AI.GetDistanceTo(targetObj.x, targetObj.y) <=
                        objectAvoidance.targetVectorMinDistance then
                        -- print('obj-avoidance arrived at target location or GUID no longer valid')
                        objectAvoidance.targetVectorGUID = nil
                    else
                        -- print('obj-avoidance will move to specified targetVectorGUID')
                        targetVector = targetObj
                    end
                end
            end
            if targetVector == nil and objectAvoidance.targetVector then
                if AI.GetDistanceTo(objectAvoidance.targetVector.x, objectAvoidance.targetVector.y) <=
                    objectAvoidance.targetVectorMinDistance then
                    -- print("arrived to target vector while avoiding objects")
                    objectAvoidance.targetVector = nil
                else
                    -- print('obj-avoidance will move to specified targetVector')
                    targetVector = objectAvoidance.targetVector
                end
            end
            local safeDist = ternary(objectAvoidance.safeDistance ~= nil, objectAvoidance.safeDistance,
                objectAvoidance.gridSize)
            local path = nil
            local iterations = 300
            if targetVector then
                local gridSize = 3.0
                if AI.CalcDistance(px, py, targetVector.x, targetVector.y) > 40 then
                    gridSize = 5
                elseif AI.CalcDistance(px, py, targetVector.x, targetVector.y) <= 10 then
                    gridSize = 0.5
                end
                local facing = AI.CalcFacing(targetVector.x, targetVector.y, px, py)
                local nTx, nTy = targetVector.x + (objectAvoidance.targetVectorMinDistance * math.cos(facing)),
                    targetVector.y + (objectAvoidance.targetVectorMinDistance * math.sin(facing))
                -- print('obj-avoidance generating safe path to targetVector')

                path = CalculatePathWhileAvoidingAStar(GetCurrentMapID(), AI.PathFinding.Vector3.new(px, py, pz),
                    AI.PathFinding.Vector3.new(nTx, nTy, targetVector.z), obstacles, gridSize, iterations)
                if type(path) ~= "table" or #path == 0 then
                    print('objAvoidance:: failed to generate safe path to targetVector')
                end
            end
            if type(path) ~= "table" or #path == 0 then
                path = FindSafeLocationInPolygonAStar(GetCurrentMapID(), AI.PathFinding.Vector3.new(px, py, pz),
                    obstacles, polygon, objectAvoidance.gridSize, safeDist, iterations)
            end

            coroutine.yield(path)
        else
            coroutine.yield()
        end
    end
end)

local function doAutoMovementUpdate()
    if goToPath == nil or #goToPath == 0 or hasReachedGoToPosition then
        return true
    end

    local wp = goToPath[goToPathCurrentWp]
    local totalWp = #goToPath

    local ctmX, ctmY, ctmZ = GetClickToMove();
    local dist = AI.GetDistanceTo(wp.x, wp.y)
    local speed = AI.GetSpeed()
    if speed > maxSpeedObserved then
        maxSpeedObserved = speed
    end
    -- print("dist to MoveTo:" .. dist .. " goToPath# " .. goToPathCurrentWp .. " totalWp: " .. totalWp .. " ctmX: " ..
    --           (ctmX or "nil") .. " ctmY: " .. (ctmY or "nil") .. " ctmZ: " .. (ctmZ or "nil") .. " speed: " .. speed);
    local diff = 1
    if goToPathCurrentWp >= totalWp then
        diff = 0.5
    end
    if maxSpeedObserved >= 7 then
        diff = 2.5
    end
    local bossMod = findEnabledBossModule()
    
    if dist <= diff then
        -- reached coordinates1
        if goToPathCurrentWp >= totalWp then
            -- if AI.IsMoving() then
            --     AI.StopMoving()
            -- end
            wp.endTime = GetTime()
            hasReachedGoToPosition = true
            goToPath = nil
            if type(wp.onArrival) == "function" then
                wp.onArrival(bossMod, nil, wp, true)
            else
                if AI.IsDps() and UnitExists("target") then
                    AI.SetFacingUnit("target")
                end
            end
            -- SetCVar('autoInteract', 0)
            -- print("final destination  wp " .. goToPathCurrentWp)
            return true
        elseif goToPathCurrentWp < totalWp then
            -- print("reached wp " .. goToPathCurrentWp .. " moving on to next wp")
            goToPathCurrentWp = goToPathCurrentWp + 1
            local oldWp = wp
            wp = goToPath[goToPathCurrentWp]
            if type(wp.onArrival) == "function" then
                wp.onArrival(bossMod, oldWp, wp)
            end
        end
    end

    hasReachedGoToPosition = false
    SetCVar('autoInteract', 1)
    -- end

    if ctmX == nil or (math.abs(ctmX - wp.x) > 0.25 or math.abs(ctmY - wp.y) > 0.251) then
    -- if ctmX == nil then
        ClickToMove(wp.x, wp.y, wp.z)
    end
    return false
end

function AI.doOnUpdate_BotBase()
    --    
    if desiredPlayerFacing ~= nil then
        local currentFacing = GetPlayerFacing()
        local diff = desiredPlayerFacing - currentFacing
        if math.abs(diff) > 0.05 then
            AI.SetFacing(desiredPlayerFacing)
            desiredPlayerFacing = nil
        end
    end

    if desiredVehicleAimAngle ~= nil and AI.IsInVehicle() and IsVehicleAimAngleAdjustable() then
        local currentAimAngle = VehicleAimGetAngle()
        local diff = desiredVehicleAimAngle - currentAimAngle
        -- print("Current angle:"..currentAimAngle.. " Desired: "..desiredVehicleAimAngle.. " Diff:"..diff)                
        -- if math.abs(diff) > 0.1745329252 then
        if math.abs(diff) > 0.08726646 then
            if diff > 0 then
                -- print("Current angle:"..currentAimAngle.. " Desired: "..desiredVehicleAimAngle.. " Diff:"..diff)                
                VehicleAimIncrement(diff)
                -- VehicleAimUpStart()
            else
                -- print("Current angle:"..currentAimAngle.. " Desired: "..desiredVehicleAimAngle.. " Diff:"..diff)                
                VehicleAimDecrement(math.abs(diff))
                -- VehicleAimDownStart()
            end
        else
            -- print("Stopped at aim angle: "..currentAimAngle)
            VehicleAimUpStop()
            VehicleAimDownStop()
            desiredVehicleAimAngle = nil
        end
    end

    if desiredFollowTarget and desiredFollowTarget ~= UnitName("player") then
        local calcDist = AI.GetDistanceTo(AI.GetPosition(desiredFollowTarget))
        local distToFollow = 3
        if AI.IsInVehicle() then
            distToFollow = 7
        end
        if calcDist >= distToFollow then
            local x, y, z = AI.GetPosition(desiredFollowTarget)
            local ctmX, ctmY, ctmZ = GetClickToMove();
            if ctmX == nil or (math.abs(ctmX - x) > 0.5 or math.abs(ctmY - y) > 0.5) then
                -- print("Following " .. desiredFollowTarget .. " at dist " .. calcDist)
                AI.SetMoveToPosition(x, y, z)
            end
        end
    end

    -- Perform object avoidance wp generation
    if objectAvoidance ~= nil then
        if tickTime > (objectAvoidance.lastCheckTime + 0.5) then
            if coroutine.status(objectAvoidancePathGenerator) ~= "dead" then
                local resumeAttempt, path = coroutine.resume(objectAvoidancePathGenerator)
                -- print("resumeAttempt, path " .. tostring(resumeAttempt), path, coroutine.status(objectAvoidancePathGenerator))
                if resumeAttempt then
                    if path and type(path) == "table" and #path > 0 then
                        AI.SetMoveToPath(path)
                    else
                        -- if AI.HasMoveTo() then
                        --     AI.ResetMoveTo()
                        -- end
                    end
                else
                    print("objectAvoidancePathGenerator resume failure " .. path)
                end

                objectAvoidance.lastCheckTime = tickTime
            else
                print("objectAvoidancePathGenerator coroutine is dead")
                objectAvoidance = nil
            end
        end
    end

    if AI.ALLOW_AUTO_MOVEMENT then
        doAutoMovementUpdate()
    end

    if not AI.IsInCombat() and not AI.HasMoveTo() then
        -- soulwell
        if not AI.HasContainerItem("fel healthstone") and tickTime > lastSoulwellCheckTime then
            local soulwell = AI.FindNearbyGameObjects("soulwell")
            if #soulwell > 0 and soulwell[1].distance <= 20 then
                if AI.GetDistanceTo(soulwell[1].x, soulwell[1].y) <= 5 then
                    soulwell[1]:InteractWith()
                else
                    local p = AI.PathFinding.FindSafeSpotInCircle(soulwell[1], 5)
                    if p then
                        AI.SetMoveTo(p.x, p.y, p.z, 0, function()
                            soulwell[1]:InteractWith()
                        end)
                    end
                end
            end
            lastSoulwellCheckTime = tickTime + 1
        end
        -- fish/great feast
        if tickTime > lastFishFeastCheckTime and (not AI.HasBuff("drink") or not AI.HasBuff("food")) and
            (AI.GetBuffDuration("well fed") < 3400 or AI.GetUnitPowerPct() < 85 or AI.GetUnitHealthPct() < 90) and
            not AI.IsCasting() then
            local feasts = AI.FindNearbyGameObjects("fish feast", "great feast")
            if #feasts > 0 and feasts[1].distance <= 20 then
                if AI.GetDistanceTo(feasts[1].x, feasts[1].y) <= 5 then
                    feasts[1]:InteractWith()
                else
                    local p = AI.PathFinding.FindSafeSpotInCircle(feasts[1], 5)
                    AI.SetMoveTo(p.x, p.y, p.z, 0, function()
                        feasts[1]:InteractWith()
                    end)
                end
            end
            lastFishFeastCheckTime = tickTime + 1
        end

    end

end

function AI.SetDesiredFacing(facing)
    desiredPlayerFacing = facing
end

function AI.HasDesiredFacing()
    return desiredPlayerFacing ~= nil
end

function AI.SetDesiredAimAngle(angle)
    desiredVehicleAimAngle = angle
    -- print("SetDesiredAimAngle "..angle)
end
function AI.HasDesiredAimAngle()
    return desiredVehicleAimAngle ~= nil
end

function AI.SetFocusedTarget(guid)
    if guid ~= nil and guid ~= "" then
        local info = AI.GetObjectInfoByGUID(guid)
        if info then
            focusedTarget = info
        end
    end
end

function AI.GetFocusedTarget()
    return focusedTarget
end

function AI.HasFocusedTarget()
    if focusedTarget == nil then
        return false
    end
    local info = AI.GetObjectInfoByGUID(focusedTarget.guid)
    if not info then
        focusedTarget = nil
        return false
    end
    if info.isDead then
        focusedTarget = nil
        return false
    end
    return true
end

-- stub, overridden
function AI.do_PriorityTarget()
    return false
end
-- stub overridden by class AIs
function AI.DO_DPS(isAoE)
end

function AI.FollowCrawl(unit)
    if unit ~= nil and UnitExists(unit) then
        AI.SetFacingCoords(AI.GetPosition(unit))
    end
end

function AI.MustCastSpell(spell, target)
    local tick = GetTime()
    local cd = GetSpellCooldown(spell)
    if cd == nil or cd == 0 or (tick - cd) < 5 then
        AI.RegisterPendingAction(function()
            if AI.CanCastSpell(spell, target, true) then
                AI.StopCasting()
            end
            return AI.CastSpell(spell, target)
        end, nil, spell)
    end
end

function AI.ExecuteDpsMethod(isAoE)
    if not AI.IS_DOING_ONUPDATE then
        if ((not AI.HasMoveTo() or AI.GetDistanceTo(AI.GetMoveToFinalDestination()) < 1) or AI.IsInVehicle()) then
            if type(AI.PRE_DO_DPS) ~= "function" or not AI.PRE_DO_DPS(isAoE) then
                if not AI.HasBuff("invisibility") and not AI.HasBuff("fade") then
                    AI.DO_DPS(isAoE)
                end
            end
        end
    end
end

-- generic mount function, customizable
function AI.DO_MOUNT(flyMount)
    if flyMount then
        if AI.IsPriest() then
            RunMacroText("/use magnificent flying carpet")
        else
            RunMacroText("/use bronze drake")
        end
    else
        RunMacroText("/use amani war bear")
    end
end

function AI.toggleAutoDps(on)
    if on then
        AI.AUTO_DPS = true
        UIErrorsFrame:AddMessage(PREFIX .. " AUTO_DPS ON");
        return true
    else
        AI.AUTO_DPS = false
        UIErrorsFrame:AddMessage(PREFIX .. " AUTO_DPS OFF");
        return true
    end
end

function AI.toggleAoEMode(flag)
    if flag then
        AI.AUTO_AOE = flag
        UIErrorsFrame:AddMessage(PREFIX .. " AUTO_AOE ON");
        -- AI.Print("auto-AOE OFF")
    else
        AI.AUTO_AOE = flag
        UIErrorsFrame:AddMessage(PREFIX .. " AUTO_AOE OFF");
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
        createTime = now,
        executed = false
    }
    if type(delay) == "number" then
        action.when = now + delay
    end

    table.insert(registeredPendingActions, action)
    table.sort(registeredPendingActions, function(a, b)
        return a.createTime < b.createTime
    end)
end

function AI.RegisterOneShotAction(f, delay, id)
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
        createTime = now,
        executed = false,
        oneshot = true
    }
    if type(delay) == "number" then
        action.when = now + delay
    end

    table.insert(registeredPendingActions, action)
    table.sort(registeredPendingActions, function(a, b)
        return a.createTime < b.createTime
    end)
end

f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("CHAT_MSG_ADDON")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:RegisterEvent("UI_ERROR_MESSAGE")
f:RegisterEvent("UNIT_SPELLCAST_START")
f:RegisterEvent("UNIT_SPELLCAST_STOP")
f:RegisterEvent("UNIT_SPELLCAST_CHANNEL_START")
f:RegisterEvent("PLAYER_TARGET_CHANGED")
f:RegisterEvent("PLAYER_TALENT_UPDATE")
f:RegisterEvent("UNIT_TARGET")
f:RegisterEvent("ZONE_CHANGED")
f:RegisterEvent("ZONE_CHANGED_INDOORS")
f:RegisterEvent("ZONE_CHANGED_NEW_AREA")
f:RegisterEvent("PLAYER_REGEN_DISABLED")
f:RegisterEvent("PLAYER_REGEN_ENABLED")
f:RegisterEvent("CHAT_MSG_RAID_BOSS_EMOTE")
f:RegisterEvent("RAID_BOSS_EMOTE")
f:RegisterEvent("CHAT_MSG_MONSTER_YELL")
f:RegisterEvent("CHAT_MSG_MONSTER_EMOTE")
f:RegisterEvent("CHAT_MSG_MONSTER_PARTY")
f:RegisterEvent("CHAT_MSG_MONSTER_WHISPER")
f:RegisterEvent("UNIT_DIED")
f:RegisterEvent("UNIT_AURA")
f:RegisterEvent("UNIT_DESTROYED")
f:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
f:SetScript("OnEvent", onEvent)

-- Listen for events
RegisterCustomEventHandler("smsg_spell_cast_go", function(spellId, spellName, casterGuid, targetGuid, src, dest)
    local bossMod = findEnabledBossModule()
    if bossMod and bossMod["SMSG_SPELL_CAST_GO"] and type(bossMod["SMSG_SPELL_CAST_GO"]) == "function" then
        -- print("smsg_spell_cast_go", spellId, spellName, casterGuid, targetGuid, table2str(src), table2str(dest))
        bossMod["SMSG_SPELL_CAST_GO"](bossMod, spellId, spellName, casterGuid, targetGuid, src, dest)
    end
    -- print("smsg_spell_cast_go", spellId, spellName, casterGuid, targetGuid, table2str(src), table2str(dest))
end)
RegisterCustomEventHandler("smsg_spell_cast_start", function(spellId, spellName, casterGuid, targetGuid, src, dest)
    local bossMod = findEnabledBossModule()
    if bossMod and bossMod["SMSG_SPELL_CAST_START"] and type(bossMod["SMSG_SPELL_CAST_START"]) == "function" then
        -- print("smsg_spell_cast", spellId, spellName, casterGuid, targetGuid, table2str(src), table2str(dest))
        bossMod["SMSG_SPELL_CAST_START"](bossMod, spellId, spellName, casterGuid, targetGuid, src, dest)
    end
    -- print("smsg_spell_cast_start", spellId, spellName, casterGuid, targetGuid, table2str(src), table2str(dest))
end)
