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

local lastPlayerEnterWorld = nil

local previousZoneName = nil

local cachedOnUpdateCallbacks = nil

local findEnabledBossModule

local hasReachedGoToPosition = nil
local goToPath = nil
local goToPathCurrentWp = nil
local lastCTMTick = 0

local registeredClassEventHandlers = {}
local registeredPendingActions = {}

--
local desiredPlayerFacing = nil
local desiredVehicleAimAngle = nil
local desiredFollowTarget = nil

local lastPosCheckTime = 0
local positionSetTime = 0
local lastCheckedPosition = nil
local lastSoulwellCheckTime = 0
local lastFishFeastCheckTime = 0

local executeDpsMethod = nil

local objectAvoidance = nil

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

    -- not AI.IsPlayerInControl() or 
    if UnitIsDeadOrGhost("player") then
        return
    end
    ---        
    AI.IS_DOING_ONUPDATE = true

    local bossMod = findEnabledBossModule()

    -- execute pending actions first
    local now = GetTime()
    -- execute pending action before boss updates
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

    if executeDpsMethod ~= nil and not AI.AUTO_DPS then
        if ((not AI.HasMoveTo() or AI.GetDistanceTo(AI.GetMoveToFinalDestination()) < 1) or AI.IsInVehicle()) then
            if type(AI.PRE_DO_DPS) ~= "function" or not AI.PRE_DO_DPS(executeDpsMethod.isAoE == true) then
                if not AI.HasBuff("invisibility") and not AI.HasBuff("fade") then
                    AI.DO_DPS(executeDpsMethod.isAoE == true)
                end
            end
        end
        executeDpsMethod = nil
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
        if foundMod ~= nil and not foundMod.enabled then
            foundMod.enabled = true
            foundMod:onStart()
            UIErrorsFrame:AddMessage(foundMod.name .. " module enabled, good luck!")
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
    else
        local bossMod = findEnabledBossModule()
        if bossMod and type(bossMod.ON_ADDON_MESSAGE) == 'function' then
            bossMod:ON_ADDON_MESSAGE(cmd, params)
        end
    end

end

local function handleFacingWrongWay()
    if AI.ALLOW_AUTO_REFACE and not AI.HasMoveToPosition() and not AI.IsMoving() then
        AI.SetFacingCoords(AI.GetPosition("target"))
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
        loadBossModule(AI.GetUnitCreatureId("target"))
        AI.SendAddonMessage("load-boss-module", AI.GetUnitCreatureId("target"))
    elseif event == "PLAYER_REGEN_ENABLED" then
        AI.isInCombat = false
        unloadBossModules()
        AI.ResetMoveToPosition()
        AI.StopMoving()
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
            loadBossModule(AI.GetUnitCreatureId("target"))
            AI.SendAddonMessage("load-boss-module", AI.GetUnitCreatureId("target"))
        end
    elseif event == "ZONE_CHANGED_NEW_AREA" then
        local zoneName = GetRealZoneText()
        local zoneId = GetCurrentMapAreaID()
        local realMapId = GetCurrentMapID()
        print("new zone " .. zoneName .. " areaId: " .. zoneId .. " realMapId: " .. (realMapId or ""))
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
    local minDistance = dist or 0.7
    if AI.IsInVehicle() then
        minDistance = dist or 5
    end
    local x, y, cz = AI.GetPosition()
    local currentPos = AI.PathFinding.Vector3.new(x, y, cz):to2D()
    -- if currentPos:distanceTo({
    --     x = tx,
    --     y = ty
    -- }) > minDistance then
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
    -- print(table2str(goToPath))
    -- else
    -- print("move-to pos differential too small to navigate")
    -- end
    -- AI.StopCasting()
    -- AI.StopMoving()
end

function AI.SetMoveToPath(path, dist, onArrival)
    if not path or type(path) ~= "table" or #path == 0 then
        -- print("no path given to move to")
        return false
    else
        -- AI.StopMoving()
        if IsFollowing() then
            StopFollowing()
        end
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
            goToPathCurrentWp = 1
            hasReachedGoToPosition = false
            positionSetTime = GetTime()
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
    return goToPath ~= nil and #goToPath > 0
end

function AI.HasMoveTo()
    return AI.HasMoveToPosition()
end

function AI.ResetMoveToPosition()
    goToPath = nil
    hasReachedGoToPosition = false
    AI.ALLOW_AUTO_MOVEMENT = true
    AI.StopMoving()
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

function AI.IsCurrentPathSafeFromObstacles(obstacles)
    if not goToPath or #goToPath == 0 or hasReachedGoToPosition or goToPathCurrentWp == #goToPath then
        return false
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
        print("obj-avoidance enabled")
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
    AI.ResetMoveTo()
    print("obj-avoidance disabled")
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
            local polygon = objectAvoidance.polygon or AI.PathFinding.createCircularPolygon({
                x = px,
                y = py,
                z = pz
            }, 50)

            local obstacles = {}
            for i, guid in ipairs(objectAvoidance.objGuids) do
                local obj
                if type(guid) == "string" then
                    obj = AI.GetObjectInfoByGUID(guid)
                else
                    obj = AI.GetObjectInfoByGUID(guid.guid)
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
            local iterations = 250
            if targetVector then
                local gridSize = 1.0
                if AI.CalcDistance(px, py, targetVector.x, targetVector.y) > 40 then
                    gridSize = 3.0
                elseif AI.CalcDistance(px, py, targetVector.x, targetVector.y) <= 20 then
                    gridSize = 0.5
                end
                local facing = AI.CalcFacing(targetVector.x, targetVector.y, px, py)
                local nTx, nTy = targetVector.x + (objectAvoidance.targetVectorMinDistance * math.cos(facing)),
                    targetVector.y + (objectAvoidance.targetVectorMinDistance * math.sin(facing))
                -- print('obj-avoidance generating safe path to targetVector')

                path = CalculatePathWhileAvoidingPFP(GetCurrentMapID(), AI.PathFinding.Vector3.new(px, py, pz),
                    AI.PathFinding.Vector3.new(nTx, nTy, targetVector.z), obstacles, gridSize, iterations)
                if type(path) ~= "table" or #path == 0 then
                    print('objAvoidance:: failed to generate safe path to targetVector')
                end
            end
            if type(path) ~= "table" or #path == 0 then
                path = FindSafeLocationInPolygonGreedy(GetCurrentMapID(), AI.PathFinding.Vector3.new(px, py, pz),
                    obstacles, polygon, objectAvoidance.gridSize, safeDist, iterations)
                -- path = FindSafeLocationInPolygonAStar(GetCurrentMapID(), AI.PathFinding.Vector3.new(px, py, pz),
                --     obstacles, polygon, objectAvoidance.gridSize, safeDist, ternary(objectAvoidance.gridSize > 1.0,
                --         iterations, iterations))
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

    local dist = AI.GetDistanceTo(wp.x, wp.y)
    -- print("dist to MoveTo:" .. dist .. " totalWp: " .. totalWp);
    local diff = 1
    -- if goToPathCurrentWp < totalWp then
    --     diff = 0.5
    -- end
    if AI.GetSpeed() > 7 then
        diff = 3
    end
    local bossMod = findEnabledBossModule()

    if dist <= diff then
        -- reached coordinates
        if goToPathCurrentWp >= totalWp then
            if AI.IsMoving() then
                AI.StopMoving()
            end
            wp.endTime = GetTime()
            hasReachedGoToPosition = true
            if type(wp.onArrival) == "function" then
                wp.onArrival(bossMod, nil, wp, true)
            end
            goToPath = nil
            -- SetCVar('autoInteract', 0)
            -- print("final destination  wp " .. goToPathCurrentWp)
            return true
        else
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
    if (GetCVar('autoInteract') ~= 1) then
        SetCVar('autoInteract', 1)
    end

    ClickToMove(wp.x, wp.y, wp.z)
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
            AI.SetMoveToPosition(x, y, z)
        end
    end

    -- Perform object avoidance wp generation
    if objectAvoidance ~= nil then
        if tickTime > (objectAvoidance.lastCheckTime + 0.5) then
            if coroutine.status(objectAvoidancePathGenerator) ~= "dead" then
                local resumeAttempt, path = coroutine.resume(objectAvoidancePathGenerator)
                -- print("resumeAttempt, path " .. tostring(resumeAttempt), path, coroutine.status(objectAvoidancePathGenerator))
                if resumeAttempt then
                    if path and type(path) == "table" then
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
                if AI.GetDistanceTo(soulwell[1].x, soulwell[1].y) <= 4 then
                    soulwell[1]:InteractWith()
                else
                    AI.SetMoveTo(soulwell[1].x, soulwell[1].y, soulwell[1].z)
                end
            end
            lastSoulwellCheckTime = tickTime + 1
        end
        -- fish/great feast
        if tickTime > lastFishFeastCheckTime and (not AI.HasBuff("drink") or not AI.HasBuff("food")) and
            (AI.GetBuffDuration("well fed") < 3400 or AI.GetUnitPowerPct() < 100 or AI.GetUnitHealthPct() < 100) then
            local feasts = AI.FindNearbyGameObjects("fish feast", "great feast")
            if #feasts > 0 and feasts[1].distance <= 20 then
                if AI.GetDistanceTo(feasts[1].x, feasts[1].y) <= 5.5 then
                    feasts[1]:InteractWith()
                else
                    AI.SetMoveTo(feasts[1].x, feasts[1].y, feasts[1].y, 1, function()
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
    if cd == nil or cd == 0 or (tick - cd) < 3 then
        AI.RegisterPendingAction(function()
            if AI.CanCastSpell(spell, target, true) then
                AI.StopCasting()
            end
            return AI.CastSpell(spell, target)
        end, null, spell)
    end
end

function AI.ExecuteDpsMethod(isAoE)
    if executeDpsMethod == nil then
        executeDpsMethod = {
            isAoE = isAoE
        }
    end
    executeDpsMethod.isAoE = isAoE == true
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
        print(PREFIX .. " AUTO_DPS ON")
        return true
    else
        AI.AUTO_DPS = false
        print(PREFIX .. " AUTO_DPS OFF")
        return true
    end
end

function AI.toggleAoEMode()
    -- if AI.AUTO_AOE then
    --     AI.AUTO_AOE = false
    --     -- AI.Print("auto-AOE OFF")
    -- else
    --     AI.AUTO_AOE = true
    --     -- AI.Print("auto-AOE ON")
    -- end
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

function AI.TestPathFinding()
    local mapId = GetCurrentMapID()
    local allies = AI.GetRaidOrPartyMemberUnits()
    local obstacles = {}
    for i, ally in ipairs(allies) do
        if UnitName(ally) ~= UnitName("player") then
            local info = AI.GetObjectInfo(ally)
            table.insert(obstacles, {
                x = info.x,
                y = info.y,
                z = info.z,
                radius = 10
            })
        end
    end
    local cx, cy, cz = AI.GetPosition()
    local tx, ty, tz = AI.GetPosition("target");
    -- MalowUtils_PrintScrollable("generating path " .. table2str({
    --     mapId = mapId,
    --     cx = cx,
    --     cy = cy,
    --     cz = cz,
    --     tx = tx,
    --     ty = ty,
    --     tz = tz,
    --     obstacles = obstacles
    -- }))

    local gridSize = 0.5
    local steps = 500
    if AI.CalcDistance(cx, cy, tx, ty) > 40 then
        -- gridSize = 3
    end

    local path = CalculatePathWhileAvoidingPFP(mapId, AI.PathFinding.Vector3.new(cx, cy, cz),
        AI.PathFinding.Vector3.new(tx, ty, tz), obstacles, gridSize, steps)
    if path and type(path) == "table" then
        print(table2str(path))
        AI.SetMoveToPath(path)
    else
        print("failed to generate AStar path")
    end
end

function AI.TestObjectAvoidance()
    local allies = AI.GetRaidOrPartyMemberUnits()
    local guids = {}
    for i, ally in ipairs(allies) do
        if UnitName(ally) ~= UnitName("player") then
            table.insert(guids, UnitGUID(ally))
        end
    end
    return AI.SetObjectAvoidance({
        guids = guids,
        radius = 10,
        safeDistance = 3,
        gridSize = 1
    })
end

function AI.TestDetourNavigation()
    local mapId = GetCurrentMapID()
    local cx, cy, cz = AI.GetPosition()
    local tx, ty, tz = AI.GetPosition("target");
    print("generating path " .. table2str({
        mapId = mapId,
        cx = cx,
        cy = cy,
        cz = cz,
        tx = tx,
        ty = ty,
        tz = tz
    }))
    local path = CalculatePathToDetour(mapId, AI.PathFinding.Vector3.new(cx, cy, cz),
        AI.PathFinding.Vector3.new(tx, ty, tz))

    if path and type(path) == "table" then
        print(table2str(path))
        AI.SetMoveToPath(path)
    else
        print("failed to generate path")
    end
end

function AI.TestDetourNavigationObjectAvoidance()
    local mapId = GetCurrentMapID()
    local allies = AI.GetRaidOrPartyMemberUnits()
    local obstacles = {}
    for i, ally in ipairs(allies) do
        if UnitName(ally) ~= UnitName("player") then
            local info = AI.GetObjectInfo(ally)
            table.insert(obstacles, {
                x = info.x,
                y = info.y,
                z = info.z,
                radius = 10
            })
        end
    end
    local cx, cy, cz = AI.GetPosition()
    local tx, ty, tz = AI.GetPosition("target");
    -- MalowUtils_PrintScrollable("generating path " .. table2str({
    --     mapId = mapId,
    --     cx = cx,
    --     cy = cy,
    --     cz = cz,
    --     tx = tx,
    --     ty = ty,
    --     tz = tz,
    --     obstacles = obstacles
    -- }))
    local gridSize = 3.5
    local steps = 500
    if AI.CalcDistance(cx, cy, tx, ty) > 40 then
        gridSize = 7
    end

    local path = CalculatePathWhileAvoidingAStar(mapId, AI.PathFinding.Vector3.new(cx, cy, cz),
        AI.PathFinding.Vector3.new(tx, ty, tz), obstacles, gridSize, steps)
    if path and type(path) == "table" then
        print(table2str(path))
        AI.SetMoveToPath(path, 0.7, function()
            print("Will Current path intersect obstacles " .. tostring(AI.IsCurrentPathSafeFromObstacles(obstacles)))
        end)
    else
        print("failed to generate AStar path")
    end
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
f:RegisterEvent("CHAT_MSG_MONSTER_YELL")
f:RegisterEvent("CHAT_MSG_MONSTER_EMOTE")
f:RegisterEvent("CHAT_MSG_MONSTER_PARTY")
f:RegisterEvent("CHAT_MSG_MONSTER_WHISPER")
f:RegisterEvent("UNIT_DIED")
f:RegisterEvent("UNIT_AURA")
f:RegisterEvent("UNIT_DESTROYED")
f:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
f:SetScript("OnEvent", onEvent)
