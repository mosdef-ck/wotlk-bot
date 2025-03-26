local oldPriorityTargetFn = nil
local rad30 = 0.5235988
local rad22_5 = 0.3926991
local rad10 = 0.1745329
local rad5 = 0.08726646
local pi2 = math.pi * 2
local pi = math.pi
local rad45 = 0.785398
local rad90 = 1.570796

local function normalizeAngle(angle)
    if angle > pi2 then
        angle = angle - pi2
    elseif angle < 0.0 then
        angle = angle + pi2
    end
    return angle
end

local function findClosestPointInList(pointList)
    local dist = 100
    local point = nil
    for i, d in ipairs(pointList) do
        if AI.GetDistanceTo(d.x, d.y) < dist then
            point = d
            dist = AI.GetDistanceTo(d.x, d.y)
        end
    end
    return point
end

-- ulduar
local ulduar = MosdefZoneModule:new({
    zoneName = "Ulduar",
    zoneId = 530,
    onEnter = function(self)
        AI.PRE_DO_DPS = function(isAoE)
            if AI.IsInVehicle() then
                if AI.IsValidOffensiveUnit() and not AI.HasMoveToPosition() then
                    AI.SetFacingUnit("target")
                    local dist = AI.GetDistanceTo(AI.GetPosition("target"))
                    if dist > 100 then
                        AI.SetDesiredAimAngle(0.524377)
                    elseif dist > 90 then
                        AI.SetDesiredAimAngle(0.4176137)
                    elseif dist > 70 then
                        AI.SetDesiredAimAngle(0.276313)
                    elseif dist > 50 then
                        AI.SetDesiredAimAngle(0.125593)
                    elseif dist > 30 then
                        AI.SetDesiredAimAngle(0.03139)
                    elseif dist > 15 then
                        AI.SetDesiredAimAngle(-0.19468)
                    end
                elseif not AI.IsValidOffensiveUnit() then
                    local vehicle = (UnitName("playerpet") or ""):lower()
                    local angle = 0.35212010
                    if vehicle == "salvaged siege turret" then
                        angle = 0.25119984
                    end
                    AI.SetDesiredAimAngle(angle)
                    if not AI.IsTank() then
                        local tankPet = AI.GetObjectInfo(AI.GetPrimaryTank() .. "-pet")
                        if tankPet and tankPet.facing then
                            AI.SetFacing(tankPet.facing)
                        end
                    end
                end

                local vehicle = (UnitName("playerpet") or ""):lower()
                if vehicle == "salvaged siege turret" then
                    AI.UsePossessionSpell("fire cannon")
                end
                if vehicle == "salvaged siege engine" and AI.IsValidOffensiveUnit() and
                    CheckInteractDistance("target", 3) then
                    -- AI.UsePossessionSpell("ram")
                end
                if vehicle == "salvaged demolisher" then
                    if UnitPower("playerpet") > 10 and AI.IsValidOffensiveUnit() and AI.GetTargetStrength() > 3 then
                        AI.UsePossessionSpell("hurl pyrite barrel")
                    else
                        AI.UsePossessionSpell("hurl boulder")
                    end
                end
                if vehicle == "salvaged demolisher mechanic seat" then
                    AI.SetDesiredAimAngle(0.2037674)
                    AI.UsePossessionSpell("anti-air rocket")
                end

                if vehicle == "salvaged chopper" and CheckInteractDistance("target", 3) then
                    AI.UsePossessionSpell("sonic horn")
                end
                return true
            end
            return false
        end

    end,
    onLeave = function(self)
        AI.PRE_DO_DPS = nil
    end
})
AI.RegisterZoneModule(ulduar)

local ironMender = MosDefBossModule:new({
    name = "Iron Mender",
    creatureId = {34198, 34199, 34190},
    onStart = function(self)
        if AI.IsTank() then
            TargetUnit("iron mender")
            local nearbyMender = AI.FindYWithinXOf("target", "iron mender", 20)
            if #nearbyMender > 0 and not nearbyMender[1].isDead and not AI.IsUnitCC(nearbyMender[1]) then
                nearbyMender[1]:Focus()
                SetRaidTarget("focus", 1)
            end
        end
    end,
    onStop = function(self)
    end,
    onUpdate = function(self)
        if AI.IsDps() then
            local menders = AI.FindNearbyObjectsByName("iron mender")
            local markedMender = nil
            for i, o in ipairs(menders) do
                if o.raidTargetIndex and not o.isDead and not AI.IsUnitCC(o) then
                    markedMender = o
                end
            end
            if markedMender and markedMender.guid ~= UnitGUID("target") then
                markedMender:Focus()
                if AI.IsShaman() then
                    return AI.CastSpell("hex", "focus")
                end
                if AI.IsMage() then
                    return AI.CastSpell("polymorph", "focus")
                end
                if AI.IsWarlock() then
                    AI.RegisterPendingAction(function()
                        if not markedMender.isDead and not AI.IsUnitCC(markedMender) then
                            return AI.CastSpell("fear", "focus")
                        end
                        return true
                    end, 4, "CC_IRON_MENDER")
                end
            end
        end
        return false
    end
})
AI.RegisterBossModule(ironMender)

-- winter revenant
local winterRevenant = MosDefBossModule:new({
    name = "Winter Revenant",
    creatureId = {34134, 34135},
    onStart = function(self)
        if AI.IsPriest() then
            CancelUnitBuff("player", "vampiric embrace")
        end
    end
})
AI.RegisterBossModule(winterRevenant)

---flame leviathan
local flameLeviathan = MosDefBossModule:new({
    name = "Flame Leviathan",
    creatureId = {33113},
    onStart = function(self)
        if UnitName("focus") ~= "Flame Leviathan" then
            TargetUnit("Flame Leviathan")
            FocusUnit("target")
        end
    end,
    onStop = function(self)
        self.pursuedTarget = nil
    end,
    onUpdate = function(self)
        -- run from leviathan if we're being pursued
        if AI.IsPossessing() then
            local vehicle = UnitName("playerpet") or ""
            if UnitName("focus") ~= "Flame Leviathan" then
                TargetUnit("Flame Leviathan")
                FocusUnit("target")
            end
            local lX, lY = AI.GetPosition("focus")
            local pX, pY = AI.GetPosition("player")
            local distToLeviathan = AI.GetDistanceToUnit("focus")
            if self.pursuedTarget and vehicle ~= "Salvaged Demolisher" and vehicle:lower() == self.pursuedTarget:lower() and
                not AI.HasMoveToPosition() and (distToLeviathan == 0 or distToLeviathan < 70) then
                local points = {}
                local facing = AI.CalcFacing(self.centerX, self.centerY, pX, pY)
                for theta = facing, facing + pi2, rad5 do
                    local nX = self.centerX + self.r * math.cos(theta)
                    local nY = self.centerY + self.r * math.sin(theta)
                    if not AI.DoesLineIntersect(pX, pY, nX, nY, lX, lY, 40) then
                        table.insert(points, {
                            x = nX,
                            y = nY
                        })
                    end
                end
                if #points > 0 then
                    local i = math.random(1, #points)
                    AI.SetMoveTo(points[i].x, points[i].y)
                end
            end

            if self.pursuedTarget and AI.HasMoveTo() and AI.IsFacingTowardsDestination() then
                if strcontains(self.pursuedTarget, "siege") and strcontains(vehicle, "siege") and
                    AI.FindPossessionSpellSlot("steam rush") and AI.UsePossessionSpell("steam rush") then
                    return true
                end

                if strcontains(self.pursuedTarget, "demolisher") and strcontains(vehicle, "demolisher") and
                    AI.FindPossessionSpellSlot("increased speed") and AI.UsePossessionSpell("increased speed") then
                    return true
                end
                if strcontains(self.pursuedTarget, "chopper") and AI.FindPossessionSpellSlot("tar") and
                    AI.UsePossessionSpell("tar") then
                    return true
                end
            end

            if vehicle == "Salvaged Demolisher" and AI.GetUnitPowerPct("playerpet") <= 25 then
                local pyrite = AI.FindNearbyObjectsByName("liquid pyrite")
                if #pyrite and pyrite[1].distance <= 50 then
                    pyrite[1]:Target()
                end
                if UnitName("target") == "Liquid Pyrite" and AI.UsePossessionSpell("grab crate", "target") then
                    return true
                end
            end
            return false
        end
    end,
    pursuedTarget = nil,
    lastGrabTime = 0,
    centerX = 273.52764892578,
    centerY = -34.417301177979,
    r = 108
})

function flameLeviathan:SPELL_CAST_SUCCESS(args)
    if AI.IsPossessing() then
        if args.spellName:lower() == "pursued" then
            local target = args.target:lower()
            self.pursuedTarget = target
        end

        if args.spellName:lower() == "battery ram" then
            local vehicle = UnitName("playerpet"):lower()
            local target = args.target:lower()
            if (MaloWUtils_StrContains(target, "demolisher") and MaloWUtils_StrContains(vehicle, "demolisher")) or
                (MaloWUtils_StrContains(target, "siege") and MaloWUtils_StrContains(vehicle, "siege")) then
                if AI.FindPossessionSpellSlot("shield generator") ~= nil then
                    AI.UsePossessionSpell("shield generator")
                end
            end
        end
    end
end

function flameLeviathan:SPELL_AURA_APPLIED(args)
    if AI.IsPossessing() then
        if args.spellName:lower() == "pursued" then
            local target = args.target:lower()
            self.pursuedTarget = target
        end

        if args.spellName:lower() == "battering ram" then
            local vehicle = UnitName("playerpet"):lower()
            local target = args.target:lower()
            if (MaloWUtils_StrContains(target, "demolisher") and MaloWUtils_StrContains(vehicle, "demolisher")) or
                (MaloWUtils_StrContains(target, "siege") and MaloWUtils_StrContains(vehicle, "siege")) then
                if AI.FindPossessionSpellSlot("shield generator") ~= nil then
                    AI.UsePossessionSpell("shield generator")
                end
            end
        end
    end
end

function flameLeviathan:SPELL_DAMAGE(args)
    if AI.IsPossessing() then
        if args.spellName:lower() == "flame vents" or args.spellName:lower() == "battering ram" then
            local vehicle = UnitName("playerpet"):lower()
            local target = args.target:lower()
            if (MaloWUtils_StrContains(target, "demolisher") and MaloWUtils_StrContains(vehicle, "demolisher")) or
                (MaloWUtils_StrContains(target, "siege") and MaloWUtils_StrContains(vehicle, "siege")) then
                if AI.FindPossessionSpellSlot("shield generator") ~= nil then
                    AI.UsePossessionSpell("shield generator")
                end
            end
        end
    end
end

function flameLeviathan:SPELL_AURA_REMOVED(args)
    -- if args.spellName:lower() == "pursued" then
    --     if self.pursuedTarget == UnitName("playerpet") and AI.HasMoveToPosition() then
    --         AI.ResetMoveToPosition()
    --         AI.StopMoving()
    --     end
    --     self.pursuedTarget = nil
    -- end
end

AI.RegisterBossModule(flameLeviathan)

-- ignis

local ignis = MosDefBossModule:new({
    name = "Ignis The Furnace Master",
    creatureId = {33118},
    onStart = function(self)
        TargetUnit("ignis")
        if UnitName("focus") ~= "Ignis The Furnace Master" then
            FocusUnit("target")
        end
        if AI.IsDps() then
            AI.SetMoveTo(self.dpsX, self.dpsY)
        end

    end,
    onEnd = function(self)
        self.slaggedTarget = nil
    end,
    onUpdate = function(self)
        if AI.IsDps() and AI.IsValidOffensiveUnit("target") and AI.HasDebuff("Brittle", "target") then
            if AI.IsWarlock() and AI.CastSpell("Searing Pain", "target") then
                return true
            end
            if AI.IsPriest() and AI.CastSpell("Mind Blast", "target") or AI.CastSpell("mind flay", "target") then
                return true
            end
            if AI.IsShaman() and AI.CastSpell("lightning bolt", "target") then
                return true
            end

            if AI.IsMage() and AI.CastSpell("arcane blast", "target") then
                return true
            end
        end
        if AI.IsHealer() and AI.IsShaman() then
            if self.slaggedTarget ~= nil and AI.GetUnitHealthPct(self.slaggedTarget) <= 80 and
                (AI.CastSpell("riptide", self.slaggedTarget) or AI.CastSpell("healing wave", self.slaggedTarget)) then
                return true
            end
        end
        if AI.IsPriest() and self.slaggedTarget ~= nil and not AI.HasDebuff("weakened soul", self.slaggedTarget) and
            AI.CastSpell("power word: shield", self.slaggedTarget) then
            return true
        end

        if AI.IsWarlock() and not AI.HasBuff("demonic circle: summon") and AI.CastSpell("demonic circle: summon") then
            return true
        end

        if AI.IsMage() and AI.HasDebuff("slag pot") and AI.CastSpell("fire ward") then
            return true
        end
        return false
    end,
    dpsX = 633.15985107422,
    dpsY = 304.99789428711,
    slaggedTarget = nil
})

function ignis:SPELL_AURA_APPLIED(args)
    if args.spellName:lower() == "slag pot" then
        self.slaggedTarget = args.target
        if args.target == UnitName("player") then
            AI.DISABLE_CDS = true
            if AI.IsWarlock() and AI.HasBuff("demonic circle: summon") then
                AI.RegisterPendingAction(function()
                    return AI.CastSpell("demonic circle: teleport")
                end, 1)
            end
            if AI.IsMage() then
                local healer = AI.GetPrimaryHealer()
                AI.RegisterPendingAction(function()
                    if not AI.HasDebuff("slag pot") then
                        return true
                    end
                    local hx, hy = AI.GetPosition(healer)
                    local tX, tY = AI.GetPosition("focus")
                    local facing = AI.GetObjectInfo("focus").facing
                    local success = false
                    if AI.IsPointWithinCone(hx, hy, tX, tY, facing, math.pi) then
                        success = AI.CastSpell("blink")
                        if success then
                            AI.SetMoveTo(self.dpsX, self.dpsY)
                        end
                    end
                    return success
                end, 1)
            end
        end
    end
end

function ignis:SPELL_AURA_REMOVED(args)
    if args.spellName:lower() == "slag pot" then
        self.slaggedTarget = nil
        if args.target == UnitName("player") then
            AI.DISABLE_CDS = false
            if AI.IsDps() then
                AI.SetMoveToPosition(self.dpsX, self.dpsY)
            end
        end
    end
end
AI.RegisterBossModule(ignis)

--- kologarn

local kologarn = MosDefBossModule:new({
    name = "Kologarn",
    creatureId = {32930, 32933, 32934},
    onStart = function(self)
        if AI.IsDpsPosition(1) then
            AI.SetMoveToPosition(self.dps1x, self.dps1y)
        end
        if AI.IsDpsPosition(2) then
            AI.SetMoveToPosition(self.dps2x, self.dps2y)
        end
        if AI.IsDpsPosition(3) then
            AI.SetMoveToPosition(self.dps3x, self.dps3y)
        end
        if AI.IsHealer() then
            AI.SetMoveToPosition(self.healerx, self.healery)
        end

        AI.RegisterPendingAction(function()
            TargetUnit("right arm")
            return true
        end, 15, "TARGET_RIGHT_ARM")
    end,
    onStop = function(self)
    end,
    onUpdate = function(self)
        if AI.IsShaman() and AI.IsHealer() and self.gripTarget and AI.GetUnitHealthPct(self.gripTarget) <= 70 and
            AI.CastSpell("healing wave", self.gripTarget) then
            return true
        end

        if AI.IsPriest() and self.gripTarget and not AI.HasDebuff("weakened soul", self.gripTarget) and
            AI.CastSpell("power word: shield", self.gripTarget) then
            return true
        end

        if AI.IsWarlock() and not AI.HasBuff("demonic circle: summon") and AI.CastSpell("demonic circle: summon") then
            return true
        end

        if AI.IsDps() then
            local eyebeam = AI.FindNearbyObjectsByName("eyebeam")
            if #eyebeam > 0 then
                local x, y = AI.GetPosition("player")
                local facingToPlayer = AI.CalcFacing(eyebeam[1].x, eyebeam[1].y, x, y)
                if GetTime() > self.eyeEvadeTime then
                    local eyeFacing = eyebeam[1].facing
                    if eyeFacing > math.pi * 2 then
                        eyeFacing = eyeFacing - math.pi * 2
                    elseif eyeFacing < 0.0 then
                        eyeFacing = eyeFacing + math.pi * 2
                    end
                    local diff = math.abs(eyeFacing - facingToPlayer)
                    -- print("eyebeam facing " .. eyeFacing .. " toplr facing:" .. facingToPlayer .. " diff:" .. diff)
                    if (eyebeam[1].distance <= 3 and diff <= 0.5) and not AI.HasMoveToPosition() then
                        if AI.IsDpsPosition(1) then
                            AI.SetMoveToPosition(self.dps1evadeX, self.dps1evadeY, 3)
                        elseif AI.IsDpsPosition(2) then
                            AI.SetMoveToPosition(self.dps2evadeX, self.dps2evadeY, 3)
                        elseif AI.IsDpsPosition(3) then
                            AI.SetMoveToPosition(self.dps3evadeX, self.dps3evadeY, 3)
                        end
                        AI.DISABLE_CDS = true
                        self.eyeEvadeTime = GetTime() + 5
                    end
                end
            elseif self.gripTarget == nil and not AI.HasMoveToPosition() then
                if AI.IsDpsPosition(1) and AI.GetDistanceTo(self.dps1x, self.dps1y) > 1 then
                    AI.SetMoveToPosition(self.dps1x, self.dps1y)
                elseif AI.IsDpsPosition(2) and AI.GetDistanceTo(self.dps2x, self.dps2y) > 1 then
                    AI.SetMoveToPosition(self.dps2x, self.dps2y)
                elseif AI.IsDpsPosition(3) and AI.GetDistanceTo(self.dps3x, self.dps3y) > 1 then
                    AI.SetMoveToPosition(self.dps3x, self.dps3y)
                end
            end

            if #eyebeam == 0 then
                AI.DISABLE_CDS = false
            end
        end
        return false
    end,
    gripTarget = nil,
    dps1x = 1767.7006835938,
    dps1y = -3.4941546916962,
    dps2x = 1783.7899169922,
    dps2y = -3.9541857242584,
    dps3x = 1767.5830078125,
    dps3y = -20.168651580811,
    healerx = 1775.6156005859,
    healery = 12.006954193115,
    eyeEvadeTime = 0,

    dps1evadeX = 1751.0971679688,
    dps1evadeY = -4.2991757392883,
    dps2evadeX = 1779.3424072266,
    dps2evadeY = 11.131150245667,
    dps3evadeX = 1767.7554931641,
    dps3evadeY = -45.019351959229
})

function kologarn:SPELL_DAMAGE(args)
    if args.spellName == "Focused Eyebeam" and args.target == UnitName("player") and AI.IsDps() and
        not AI.HasMoveToPosition() and GetTime() > self.eyeEvadeTime then
        if AI.IsDpsPosition(1) then
            AI.SetMoveToPosition(self.dps1evadeX, self.dps1evadeY, 2)
        elseif AI.IsDpsPosition(2) then
            AI.SetMoveToPosition(self.dps2evadeX, self.dps2evadeY, 2)
        elseif AI.IsDpsPosition(3) then
            AI.SetMoveToPosition(self.dps3evadeX, self.dps3evadeY, 2)
        end
        self.eyeEvadeTime = GetTime() + 10
    end
end

function kologarn:SPELL_AURA_APPLIED(args)
    if args.spellName:lower() == "stone grip" then
        -- AI.SayRaid("I'm gripped")
        self.gripTarget = args.target
        TargetUnit("right arm")
        if UnitName("player") == args.target then
            AI.DISABLE_CDS = true
            AI.ResetMoveTo()
        end
    end
end

function kologarn:SPELL_AURA_REMOVED(args)
    if args.spellName:lower() == "stone grip" then
        TargetUnit("kologarn")
        AI.DISABLE_CDS = false
        self.gripTarget = nil
        if args.target == UnitName("player") then
            -- self.eyeEvadeTime = GetTime() + 10
            local mod = self
            AI.RegisterPendingAction(function()
                if AI.IsDpsPosition(1) and not AI.HasMoveToPosition() then
                    AI.SetMoveToPosition(mod.dps1x, mod.dps1y)
                end
                if AI.IsDpsPosition(2) and not AI.HasMoveToPosition() then
                    if AI.HasBuff("demonic circle: summon") and AI.CastSpell("demonic circle: teleport") then
                        return true
                    else
                        AI.SetMoveToPosition(mod.dps2x, mod.dps2y)
                    end
                end
                if AI.IsDpsPosition(3) and not AI.HasMoveToPosition() then
                    AI.SetMoveToPosition(mod.dps3x, mod.dps3y)
                end
                return true
            end, 0.5, "MOVE_BACK_TO_POSITION")
        end

        AI.RegisterPendingAction(function()
            TargetUnit("right arm")
            return true
        end, 16, "TARGET_ARM")
    end
end

AI.RegisterBossModule(kologarn)

-- razorscale
local razorscale = MosDefBossModule:new({
    name = "Razorscale",
    creatureId = {33186, 33210},
    onStart = function(self)
        AI.DISABLE_CDS = true
        if AI.IsDpsPosition(1) then
            AI.SetMoveToPosition(self.dps1x, self.dps1y)
        end
        if AI.IsDpsPosition(2) then
            AI.SetMoveToPosition(self.dps2x, self.dps2y)
        end
        if AI.IsDpsPosition(3) then
            AI.SetMoveToPosition(self.dps3x, self.dps3y)
        end
        if AI.IsHealer() then
            AI.SetMoveToPosition(self.healerx, self.healery)
        end
    end,
    onStop = function(self)
        AI.DISABLE_CDS = false
    end,
    onUpdate = function(self)
        if AI.IsValidOffensiveUnit() then
            AI.DISABLE_CDS = UnitName("target") ~= "Razorscale"
        end

        if not AI.IsTank() then
            local flames = AI.FindNearbyObjectsByName("devouring flame stalker")
            if #flames > 0 then
                if flames[1].distance < 9 and not AI.HasMoveToPosition() and GetTime() > self.lastEvadeTime + 5 then
                    print("devouring flame on me, moving out")
                    local angleFacing = AI.CalcFacing(self.fightx, self.fighty, self.startx, self.starty)
                    -- 90degree cone                  
                    local spots = {}
                    for theta = angleFacing - (rad45 + rad10), angleFacing + (rad45 + rad10), rad5 do
                        if theta > pi2 then
                            theta = theta - pi2
                        elseif theta < 0.0 then
                            theta = theta + pi2
                        end
                        for r = 15, 31, 1 do
                            local nX, nY = self.fightx + (r * math.cos(theta)), self.fighty + (r * math.sin(theta))
                            if self.isSpotSafeFromAllFlames(nX, nY, flames, flames[1].guid) then
                                table.insert(spots, {
                                    x = nX,
                                    y = nY
                                })
                            end
                        end
                    end
                    local p = nil
                    if #spots > 0 then
                        p = findClosestPointInList(spots)
                    end
                    if p then
                        AI.SetMoveToPosition(p.x, p.y)
                    else
                        AI.SetMoveToPosition(self.startx, self.starty)
                    end
                    self.lastEvadeTime = GetTime()
                end
            end
        end
    end,
    startx = 585.35375976563,
    starty = -134.66996765137,
    fightx = 586.56292724609,
    fighty = -172.1799621582,
    dps1x = 601.53082275391,
    dps1y = -148.0544128418,
    dps2x = 591.90020751953,
    dps2y = -144.25395202637,
    healerx = 581.53515625,
    healery = -144.49114990234,
    dps3x = 573.20922851563,
    dps3y = -145.37928771973,
    lastEvadeTime = 0,
    isSpotSafeFromAllFlames = function(x, y, flameList, ignoreGuid)
        local cX, cY = AI.GetPosition()
        for i, o in ipairs(flameList) do
            if AI.CalcDistance(x, y, o.x, o.y) < 9 or
                (o.guid ~= ignoreGuid and AI.DoesLineIntersect(cX, cY, x, y, o.x, o.y, 8)) then
                return false
            end
        end
        return true
    end

})

function razorscale:CHAT_MSG_MONSTER_YELL(s, t)
    if strcontains(s, "grounded") then
        if not AI.IsTank() then
            local tank = AI.GetPrimaryTank()
            local tX, tY = AI.GetPosition(tank)
            local flames = AI.FindNearbyObjectsByName("devouring flame stalker")
            local angle = AI.GetFacingForPosition(self.fightx, self.fighty) + math.pi
            local spots = {}
            for theta = angle - rad90, angle + rad90, rad5 do
                for r = 1, 13, 1 do
                    local nX, nY = self.fightx + r * math.cos(theta), self.fighty + r * math.sin(theta)
                    if self.isSpotSafeFromAllFlames(nX, nY, flames, nil) then
                        table.insert(spots, {
                            x = nX,
                            y = nY
                        })
                    end
                end
            end
            if #spots > 0 then
                local p = findClosestPointInList(spots)
                if p then
                    AI.SetMoveTo(p.x, p.y)
                end
            else
                AI.SetMoveToPosition(self.fightx, self.fighty)
            end
        end
    end
end

function razorscale:CHAT_MSG_RAID_BOSS_EMOTE(s, t)
    if MaloWUtils_StrContains(s, "deep breath") then
        if not AI.IsTank() then
            local tX, tY = AI.GetPosition(AI.GetPrimaryTank())
            AI.SetMoveTo(tX, tY)
        end
    end
end

AI.RegisterBossModule(razorscale)

-- auriaya
local auriaya = MosDefBossModule:new({
    name = "auriaya",
    creatureId = {33515, 34014},
    onStart = function(self)
        TargetUnit("auriaya")
        FocusUnit("target")
        AI.DISABLE_WARLOCK_CURSE = true
        local x, y = AI.GetPosition("player")
        self.startx = x
        self.starty = y
    end,
    onEnd = function(self)
        AI.DISABLE_WARLOCK_CURSE = false
    end,
    onUpdate = function(self)
        if AI.IsPriest() and not AI.HasMyBuff("fear ward", AI.GetPrimaryHealer()) and
            AI.CastSpell("fear ward", AI.GetPrimaryHealer()) then
            return true
        end

        if AI.IsWarlock() then
            if UnitName("focus") ~= "Auriaya" then
                TargetUnit("auriaya")
                FocusUnit("target")
            end
            if not AI.HasMyDebuff("curse of the elements", "focus") and GetTime() > self.lastScreechTime + 3 and
                AI.CastSpell("curse of the elements", "focus") then
                return true
            end
        end

    end,
    startx = nil,
    starty = nil,
    lastScreechTime = 0
})

function auriaya:SPELL_AURA_REMOVED(args)
    if args.spellName == "Terrifying Screech" and args.target == UnitName("player") then
        if UnitName("focus") ~= "Auriaya" then
            TargetUnit("auriaya")
            FocusUnit("target")
        end
        if AI.IsCasting("focus") then
            -- if AI.IsShaman() then
            --     AI.MustCastSpell("wind shear", "focus")
            -- end
            if AI.IsPaladin() and AI.GetDistanceToUnit("focus") <= 3 then
                AI.MustCastSpell("hammer of justice", "focus")
            end

            if AI.IsPriest() then
                AI.MustCastSpell("shadow shear", "focus")
            end

            if AI.IsMage() then
                AI.MustCastSpell("counterspell", "focus")
            end

        end

        if not AI.IsTank() and not AI.HasMoveTo() and AI.GetDistanceTo(self.startx, self.starty) >= 3 then
            local mod = self
            AI.RegisterPendingAction(function()
                AI.SetMoveTo(mod.startx, mod.starty)
                return true
            end, 1, "MOVE_BACK_TO_START")

        end
    end
end

function auriaya:UNIT_SPELLCAST_START(caster, spellName)
    if spellName:lower() == "sentinel blast" then
        if UnitName("focus") ~= "Auriaya" then
            TargetUnit("auriaya")
            FocusUnit("target")
        end
        if AI.IsPaladin() then
            AI.MustCastSpell("hammer of justice", "focus")
        end
        -- if AI.IsShaman() then
        --     AI.MustCastSpell("wind shear", "focus")
        -- end
        if AI.IsMage() then
            AI.MustCastSpell("counterspell", "focus")
        end
        if AI.IsPriest() then
            AI.MustCastSpell("shadow shear", "focus")
        end
    end

    if spellName:lower() == "terrifying screech" then
        self.lastScreechTime = GetTime()
        if AI.IsWarlock() then
            AI.MustCastSpell("curse of tongues", "focus")
        end
    end
end

AI.RegisterBossModule(auriaya)

-- xt
local xt = MosDefBossModule:new({
    name = "xt-002 deconstructor",
    creatureId = {33293},
    onStart = function(self)
    end,
    onStop = function(self)
    end,
    onUpdate = function(self)
    end
})

function xt:SPELL_AURA_APPLIED(args)
    if args.spellName == "Gravity Bomb" or args.spellName == "Searing Light" then
        if AI.IsPriest() and not AI.HasDebuff("weakened soul", args.target) then
            AI.RegisterPendingAction(function()
                return AI.CastSpell("power word: shield", args.target)
            end)
        end
    end
end

AI.RegisterBossModule(xt)

-- assembly of iron
local assemblyOfIron = MosDefBossModule:new({
    name = "Assembly of Iron",
    creatureId = {32867, 32857, 32927},
    onStart = function(self)
    end,
    onStop = function(self)
    end,
    onUpdate = function(self)
    end
})

-- thorim
local thorim = MosDefBossModule:new({
    name = "Thorim",
    creatureId = {32865, 32882, 32886},
    onStart = function(self)
        local mod = self
        oldPriorityTargetFn = AI.do_PriorityTarget
        AI.do_PriorityTarget = function()
            if mod.thorimDropped then
                return false
            end
            if UnitName("player") ~= mod.gauntletLeader and UnitName("player") ~= mod.follower then
                TargetUnit("dark rune evoker")
                if AI.IsTank() then
                    if not AI.IsValidOffensiveUnit() or not AI.CanHitTarget() then
                        TargetNearestEnemy()
                    end
                else
                    AssistUnit(AI.Config.tank)
                end
                return true
            else
                if UnitName("player") == mod.gauntletLeader then
                    TargetUnit("runic colossus")
                    if not AI.IsValidOffensiveUnit() or not AI.CanHitTarget() then
                        TargetUnit("ancient rune giant")
                        if not AI.IsValidOffensiveUnit() or not AI.CanHitTarget() then
                            AssistUnit(AI.Config.tank)
                        end
                    end
                end
                if UnitName("player") == mod.follower then
                    AssistUnit(mod.gauntletLeader)
                end
                return true
            end
            return false
        end
        -- guy going into tunnel
        AI.PRE_DO_DPS = function(isAoe)

            if mod.thorimDropped then
                return false
            end

            if UnitName("player") ~= mod.gauntletLeader and UnitName("player") ~= mod.follower then
                return false
            else
                if self.gauntletStarted and not self.thorimDropped then
                    AI.DO_DPS(false)
                    return true
                end
            end
            return false
        end

        if AI.IsPriest() then
            AI.AUTO_CLEANSE = false
        end
    end,
    onStop = function(self)
        if oldPriorityTargetFn ~= nil then
            AI.do_PriorityTarget = oldPriorityTargetFn
        end
        AI.PRE_DO_DPS = nil
        AI.AUTO_CLEANSE = true
    end,
    onUpdate = function(self)
        if not self.thorimDropped and UnitName("player") == self.follower then
            if AI.GetDistanceTo(AI.GetPosition(self.gauntletLeader)) > 2 then
                local x, y = AI.GetPosition(self.gauntletLeader)
                AI.SetMoveTo(x, y)
            end
        end

        if self.thorimDropped then
            if UnitName("focus") ~= "Thorim" then
                TargetUnit("Thorim")
                FocusUnit("target")
            end
            local orbs = AI.FindNearbyObjectsByName("thunder orb")
            if #orbs > 0 and AI.IsDps() and not AI.HasMoveTo() then
                local thorim = AI.GetObjectInfo("target")
                if thorim then
                    local px, py = AI.GetPosition("player")
                    for i, o in ipairs(orbs) do
                        if o:HasAura(62186) then
                            local thorimFacingOrb = AI.CalcFacing(thorim.x, thorim.y, o.x, o.y)

                            local isPlrWithinCone = AI.IsPointWithinCone(px, py, thorim.x, thorim.y, thorimFacingOrb,
                                rad90)
                            if isPlrWithinCone and not AI.HasMoveTo() then
                                -- we are in danger zone
                                if AI.IsDpsPosition(1) then
                                    AI.SetMoveToPosition(self.dps1Safex, self.dps1Safey)
                                end
                                if AI.IsDpsPosition(2) then
                                    AI.SetMoveToPosition(self.dps2Safex, self.dps2Safey)
                                end
                                if AI.IsDpsPosition(3) then
                                    AI.SetMoveToPosition(self.dps3Safex, self.dps3Safey)
                                end

                                if AI.IsHealer() then
                                    local facing = AI.GetFacingForUnit("target")
                                    AI.SetMoveTo(thorim.x + 3 * math.cos(facing), thorim.y + 3 * math.sin(facing))
                                end

                                AI.RegisterPendingAction(function()
                                    if AI.IsDpsPosition(1) and AI.GetDistanceTo(self.dpsSpot1X, self.dpsSpot1Y) > 1 then
                                        AI.SetMoveToPosition(self.dpsSpot1X, self.dpsSpot1Y)
                                    end
                                    if AI.IsDpsPosition(2) and AI.GetDistanceTo(self.dpsSpot2X, self.dpsSpot2Y) > 1 then
                                        AI.SetMoveToPosition(self.dpsSpot2X, self.dpsSpot2Y)
                                    end
                                    if AI.IsDpsPosition(3) and AI.GetDistanceTo(self.dpsSpot3X, self.dpsSpot3Y) > 1 then
                                        AI.SetMoveToPosition(self.dpsSpot3X, self.dpsSpot3Y)
                                    end
                                    return true
                                end, 8, "RETURN_TO_POSITION")
                            end
                        end
                    end
                end
            end

            if AI.IsPriest() and AI.CleanseRaid("Dispel Magic", "Magic") then
                return true
            end

            if AI.IsMage() and AI.HasMoveTo() and AI.IsFacingTowardsDestination() and AI.CastSpell("blink") then
                return true
            end
        end
    end,
    gauntletLeader = "Mosdeflocka",
    follower = "Mosdeffmage",

    dpsSpot1X = 2126.8469238281,
    dpsSpot1Y = -277.53002929688,

    dpsSpot2X = 2149.1362304688,
    dpsSpot2Y = -277.14944458008,

    dpsSpot3X = 2145.6552734375,
    dpsSpot3Y = -249.17782592773,

    healerX = 2145.5891113281,
    healerY = -268.9655456543,

    tankX = 2136.5803222656,
    tankY = -262.69729614258,

    thorimDropped = false,
    gauntletStarted = false,

    dps1Safex = 2138.654296875,
    dps1Safey = -281.4342956543,
    dps2Safex = 2129.2443847656,
    dps2Safey = -280.47311401367,
    dps3Safex = 2153.9934082031,
    dps3Safey = -269.09017944336
})

function thorim:SPELL_AURA_APPLIED(args)
    if args.spellName:lower() == "nitro boosts" then
        -- AI.Print("nitro boosts on " .. args.caster)
        if (args.target == self.gauntletLeader or args.caster == self.gauntletLeader) and UnitName("player") ==
            self.follower then
            AI.UseInventorySlot(8)
        end
    end
end

function thorim:CHAT_MSG_MONSTER_YELL(text, monster)
    if strcontains(text, "interlopers") then
        self.gauntletStarted = true
        if AI.IsPriest() then
            CancelUnitBuff("player", "vampiric embrace")
        end
    end
    if monster == "Thorim" and MaloWUtils_StrContains(text:lower(), "you dare challenge") then
        self.thorimDropped = true
        TargetUnit("Thorim")
        AI.ResetMoveTo()
        if UnitName("player") == self.follower then
            FollowUnit(self.gauntletLeader)
        end
        if AI.IsDps() then
            AI.RegisterPendingAction(function()
                if AI.IsDpsPosition(1) and AI.GetDistanceTo(self.dpsSpot1X, self.dpsSpot1Y) > 1 then
                    AI.SetMoveToPosition(self.dpsSpot1X, self.dpsSpot1Y)
                end
                if AI.IsDpsPosition(2) and AI.GetDistanceTo(self.dpsSpot2X, self.dpsSpot2Y) > 1 then
                    AI.SetMoveToPosition(self.dpsSpot2X, self.dpsSpot2Y)
                end
                if AI.IsDpsPosition(3) and AI.GetDistanceTo(self.dpsSpot3X, self.dpsSpot3Y) > 1 then
                    AI.SetMoveToPosition(self.dpsSpot3X, self.dpsSpot3Y)
                end
                return true
            end, 10, "MOVE_TO_BATTLEPOSITIONS")
        elseif AI.IsTank() then
            AI.SetMoveToPosition(self.tankX, self.tankY)
        end
    end
end

AI.RegisterBossModule(thorim)

-- freya
local freya = MosDefBossModule:new({
    name = "Freya",
    creatureId = {32906},
    onStart = function(self)
        oldPriorityTargetFn = AI.do_PriorityTarget
        if UnitName("focus") ~= "Freya" then
            TargetUnit("Freya")
            FocusUnit("target")
        end
        AI.do_PriorityTarget = function()
            return AI.DoTargetChain("strengthened iron roots", "eonar's gift")
        end

        if AI.IsPriest() then
            CancelUnitBuff("player", "vampiric embrace")
        end

        if AI.IsHealer() then
            AI.AUTO_CLEANSE = false
        end
    end,
    onStop = function(self)
        if oldPriorityTargetFn ~= nil then
            AI.do_PriorityTarget = oldPriorityTargetFn
        end
    end,
    onUpdate = function(self)
        if UnitName("focus") ~= "Freya" then
            TargetUnit("Freya")
            FocusUnit("target")
        end
        if not AI.IsTank() then
            local natureBombs = AI.FindNearbyObjectsByName("nature bomb")
            if AI.IsDps() and AI.GetDistanceTo(AI.GetPosition("target")) > 40 and #natureBombs == 0 then
                local tX, tY = AI.GetPosition("target")
                local cX, cY = AI.GetPosition("player")
                local r = 40
                local facing = AI.CalcFacing(tX, tY, cX, cY)
                local nX, nY = tX + r * math.cos(facing), tY + r * math.sin(facing)
                AI.SetMoveToPosition(nX, nY)
            end
            local spores = AI.FindNearbyObjectsByName("healthy spore")
            if #spores > 0 and (UnitName("target") == "Ancient Conservator" and not AI.HasBuff("potent pheromones")) and
                not AI.HasMoveTo() then
                print("moving towards mushroom for buff")
                AI.SetMoveToPosition(spores[1].x, spores[1].y)
            end

            if #natureBombs > 0 and natureBombs[1].distance <= 13 and not AI.HasMoveTo() then
                print("nature bomb on me, moving out")
                local freyaX, freyaY = AI.GetPosition("focus")
                local angleFacing = AI.CalcFacing(freyaX, freyaY, natureBombs[1].x, natureBombs[1].y)
                local spots = {}
                for theta = angleFacing, angleFacing + pi2, rad5 do
                    if theta < 0.0 then
                        theta = theta + pi2
                    elseif theta > pi2 then
                        theta = theta - pi2
                    end
                    for r = 3, 40, 1 do
                        local x, y = r * math.cos(theta), r * math.sin(theta)
                        local nX, nY = freyaX + x, freyaY + y
                        if self.isPointSafeFromBombs(nX, nY, natureBombs) then
                            table.insert(spots, {
                                x = nX,
                                y = nY
                            })
                        end
                    end
                end

                if #spots > 0 then
                    local p = self.findClosestPointInList(spots)
                    if p then
                        AI.SetMoveToPosition(p.x, p.y)
                    end
                end
            end
        end
        return false
    end,
    isPointSafeFromBombs = function(x, y, bombList)
        local cX, cY = AI.GetPosition("player")
        for i, o in ipairs(bombList) do
            if AI.CalcDistance(x, y, o.x, o.y) <= 13 then
                return false
            end
        end
        return true
    end,
    findClosestPointInList = function(pointList)
        local dist = 100
        local point = nil
        for i, d in ipairs(pointList) do
            if AI.GetDistanceTo(d.x, d.y) < dist then
                point = d
                dist = AI.GetDistanceTo(d.x, d.y)
            end
        end
        return point
    end
})

AI.RegisterBossModule(freya)

local icicleRadius = 6
-- hodir
local hodir = MosDefBossModule:new({
    name = "Hodir",
    creatureId = {32845, 32938},
    onStart = function(self)
        if AI.IsTank() then
            AI.ALLOW_AUTO_REFACE = false
        end
        oldPriorityTargetFn = AI.do_PriorityTarget
        AI.do_PriorityTarget = function()
            if AI.IsDps() then
                local frozenVeesha = AI.FindYWithinXOf("veesha", "flash freeze", 1)
                if #frozenVeesha > 0 and frozenVeesha[1].health > 0 then
                    frozenVeesha[1]:Target()
                    if AI.GetDistanceTo(frozenVeesha[1].x, frozenVeesha[1].y) > 40 then
                        local facing = AI.GetFacingForPosition(frozenVeesha[1].x, frozenVeesha[1].y) + math.pi
                        local r = 40
                        local x, y = AI.GetPosition("player")
                        AI.SetMoveTo(x + r * math.cos(facing), y + r * math.sin(facing))
                        print("moving closer to veesha")
                    end
                else
                    TargetUnit("flash freeze")
                end
                if AI.IsValidOffensiveUnit() and AI.GetDistanceTo(AI.GetPosition("target")) <= 40 and UnitName("target") ==
                    "Flash Freeze" then
                    return true
                end
            end
            return false
        end

        AI.PRE_DO_DPS = function(isAoE)
            if AI.IsDps() and UnitName("target") == "Flash Freeze" then
                if AI.IsWarlock() and AI.CastSpell("shadow bolt", "target") then
                    return true
                end
                if AI.IsPriest() and AI.CastSpell("mind blast", "target") or AI.CastSpell("mind flay", "target") then
                    return true
                end
                if AI.IsShaman() and AI.CastSpell("lightning bolt", "target") then
                    return true
                end
            end
            return false
        end
    end,
    onStop = function(self)
        AI.ALLOW_AUTO_REFACE = true
        AI.PRE_DO_DPS = nil
    end,
    onUpdate = function(self)
        if AI.IsDps() or AI.IsHealer() then
            local nearbyObjects = AI.GetNearbyObjects(100)
            local closestToastyFire = nil
            local closestIcicle = nil
            local closestSnowpackedIcicle = nil
            local closestSnowpackedIcicleTarget = nil
            local icicles = {}
            local fires = {}
            local snowpackedIcicles = {}
            local fireMage = nil
            local torGreycloud = nil
            local hodir = nil
            local tank = AI.GetObjectInfo(AI.GetPrimaryTank())
            local cX, cY = AI.GetPosition("player")
            local teamList = AI.GetRaidOrPartyMemberUnits()
            for i, o in ipairs(nearbyObjects) do
                if o.name:lower() == "toasty fire" then
                    table.insert(fires, o)
                    if closestToastyFire == nil then
                        closestToastyFire = o
                    end
                end
                if o.name:lower() == "icicle" then
                    table.insert(icicles, o)
                    if not closestIcicle then
                        closestIcicle = o
                    end
                end
                if o.name:lower() == "snowpacked icicle" then
                    table.insert(snowpackedIcicles, o)
                    if not closestSnowpackedIcicle then
                        closestSnowpackedIcicle = o
                    end
                end

                if o.name:lower() == "snowpacked icicle target" and closestSnowpackedIcicleTarget == nil then
                    closestSnowpackedIcicleTarget = o
                end
                if strcontains(o.name, "veesha") then
                    fireMage = o
                end
                if strcontains(o.name, "hodir") then
                    hodir = o
                end
                if strcontains(o.name, "greycloud") then
                    torGreycloud = o
                end
            end

            if AI.HasDebuff("Freeze") or fireMage == nil then
                return false
            end

            if closestSnowpackedIcicleTarget and closestSnowpackedIcicleTarget.distance >= 10 and not AI.HasMoveTo() then
                local angleFacing = AI.CalcFacing(closestSnowpackedIcicleTarget.x, closestSnowpackedIcicleTarget.y,
                    fireMage.x, fireMage.y)
                -- 180 degree cone
                local points = {}
                for theta = angleFacing - rad90, angleFacing + rad90, rad10 do
                    if theta < 0.0 then
                        theta = theta + pi2
                    elseif theta > pi2 then
                        theta = theta - pi2
                    end
                    for r = 1, 8, 1 do
                        local x, y = r * math.cos(theta), r * math.sin(theta)
                        local nX, nY = closestSnowpackedIcicleTarget.x + x, closestSnowpackedIcicleTarget.y + y
                        table.insert(points, {
                            x = nX,
                            y = nY
                        })
                    end
                end
                local p = self.findClosestPointInList(points)
                if p then
                    print("moving onto snow packed padding")
                    AI.SetMoveToPosition(p.x, p.y)
                end
            elseif closestSnowpackedIcicle and not closestSnowpackedIcicleTarget then
                if closestSnowpackedIcicle.distance <= 10 and not AI.HasMoveTo() then
                    -- print("flash freeze on me, moving out")
                    local angleFacing = AI.CalcFacing(closestSnowpackedIcicle.x, closestSnowpackedIcicle.y, fireMage.x,
                        fireMage.y)
                    -- 180 degree cone
                    local points = {}
                    for theta = angleFacing - rad90, angleFacing + rad90, rad10 do
                        if theta < 0.0 then
                            theta = theta + pi2
                        elseif theta > pi2 then
                            theta = theta - pi2
                        end
                        for r = 12, 20, 1 do
                            local x, y = r * math.cos(theta), r * math.sin(theta)
                            local nX, nY = closestSnowpackedIcicle.x + x, closestSnowpackedIcicle.y + y
                            if self.isPointFarEnoughFromSnowpackedIcicles(nX, nY, snowpackedIcicles) then
                                table.insert(points, {
                                    x = nX,
                                    y = nY
                                })
                            end
                        end
                    end
                    local p = self.findClosestPointInList(points)
                    if p then
                        AI.SetMoveToPosition(p.x, p.y)
                        print("moving to avoid flash freeze")
                    end

                end
            elseif closestIcicle ~= nil and closestIcicle.distance < icicleRadius and not AI.HasMoveToPosition() then
                -- print("icicle above me.");
                local targetToMoveAround = closestIcicle
                -- local targetToMoveAround = fireMage

                if closestToastyFire and not AI.HasBuff("toasty fire") then
                    local rI = math.random(1, #fires)
                    targetToMoveAround = fires[rI]
                    -- targetToMoveAround = closestToastyFire
                end

                local angleToTarget = AI.CalcFacing(targetToMoveAround.x, targetToMoveAround.y, cX, cY)
                if AI.CalcDistance(targetToMoveAround.x, targetToMoveAround.y, self.centerX, self.centerY) >
                    AI.GetDistanceTo(self.centerX, self.centerY) then
                    angleToTarget =
                        AI.CalcFacing(self.centerX, self.centerY, targetToMoveAround.x, targetToMoveAround.y)
                end

                local points = {}
                for theta = angleToTarget - rad90, angleToTarget + rad90, rad5 do
                    local rStart, rEnd = 8, 15
                    if targetToMoveAround == closestIcicle then
                        rStart, rEnd = icicleRadius + 1, 15
                    end
                    for r = rStart, rEnd, 1 do
                        if theta < 0.0 then
                            theta = theta + pi2
                        elseif theta > pi2 then
                            theta = theta - pi2
                        end
                        local x, y = r * math.cos(theta), r * math.sin(theta)
                        local nX, nY = targetToMoveAround.x + x, targetToMoveAround.y + y
                        if self.isPointFarEnoughFromTeammates(nX, nY, teamList) and
                            self.isPointFarEnoughFromFires(nX, nY, fires) and
                            not self.doesLineIntersectAnyFires(cX, cY, nX, nY, fires) and
                            AI.CalcDistance(nX, nY, fireMage.x, fireMage.y) > icicleRadius and
                            -- AI.CalcDistance(nX, nY, self.centerX, self.centerY) <= self.divertFromCenterR and
                            not self.doesLineIntersectAnyIcicles(cX, cY, nX, nY, icicles, closestIcicle.guid) then
                            table.insert(points, {
                                x = nX,
                                y = nY
                            })
                        end
                    end
                end

                local p = self.findClosestPointInList(points)
                if p then
                    AI.SetMoveToPosition(p.x, p.y)
                    print("moving to avoid icicle")
                else
                    print("no safe icicle point so moving to tank location")
                    local r = icicleRadius
                    local facing = AI.CalcFacing(tank.x, tank.y, cX, cY)
                    AI.SetMoveToPosition(tank.x + r * math.cos(facing), tank.y + r * math.sin(facing))
                end
                return false
            elseif not AI.HasMoveTo() and not AI.HasBuff("toasty fire") and AI.GetDebuffCount("biting cold") >= 3 and
                closestToastyFire then
                -- if we don't have toasty fire buff, move to closest toasty fire
                local points = {}
                for i, fireToUse in ipairs(fires) do
                    local angleToTarget = AI.CalcFacing(fireToUse.x, fireToUse.y, cX, cY)
                    if AI.CalcDistance(fireToUse.x, fireToUse.y, self.centerX, self.centerY) >
                        AI.GetDistanceTo(self.centerX, self.centerY) then
                        angleToTarget = AI.CalcFacing(self.centerX, self.centerY, fireToUse.x, fireToUse.y)
                    end
                    for theta = angleToTarget - rad90, angleToTarget + rad90, rad5 do
                        for r = icicleRadius + 1, 13, 1 do
                            if theta < 0.0 then
                                theta = theta + pi2
                            elseif theta > pi2 then
                                theta = theta - pi2
                            end
                            local x, y = r * math.cos(theta), r * math.sin(theta)
                            local nX, nY = fireToUse.x + x, fireToUse.y + y
                            if self.isPointFarEnoughFromTeammates(nX, nY, teamList) and
                                -- self.isPointFarEnoughFromFires(nX, nY, fires) and
                                not self.doesLineIntersectAnyFires(cX, cY, nX, nY, fires) and
                                not self.doesLineIntersectAnyIcicles(cX, cY, nX, nY, icicles) and
                                AI.CalcDistance(nX, nY, fireMage.x, fireMage.y) > icicleRadius then
                                table.insert(points, {
                                    x = nX,
                                    y = nY
                                })
                            end
                        end
                    end
                end

                local p = self.findClosestPointInList(points)
                if p then
                    print("No toasty fire buff, moving towards it")
                    AI.SetMoveToPosition(p.x, p.y)
                else
                    print("no safe toasty-fire point so moving to tank location")
                    local r = 0.5
                    local facing = AI.CalcFacing(tank.x, tank.y, cX, cY)
                    AI.SetMoveToPosition(tank.x + r * math.cos(facing), tank.y + r * math.sin(facing))
                end
                return false
            elseif not closestSnowpackedIcicle and not closestSnowpackedIcicleTarget and
                (not closestIcicle or closestIcicle.distance >= icicleRadius) and not AI.HasMoveTo() then
                if AI.IsDps() then
                    if self.stormPowerPlayer and (not AI.HasBuff("storm power") and not AI.HasBuff("storm cloud")) then
                        local stormcloudPlr = AI.GetObjectInfo(self.stormPowerPlayer)
                        if stormcloudPlr and AI.GetDistanceTo(stormcloudPlr.x, stormcloudPlr.y) > 4 and
                            not self.doesLineIntersectAnyIcicles(cX, cY, stormcloudPlr.x, stormcloudPlr.y, icicles, nil) then
                            AI.SetMoveTo(stormcloudPlr.x, stormcloudPlr.y)
                            self.isHeadedTowardsStormPlr = true
                            print("moving to storm power plr")
                        end
                    elseif AI.IsDpsPosition(2) and not AI.HasBuff("starlight") and AI.GetDistanceToUnit(torGreycloud) <
                        5 then
                        print("moving to tor greycloud for starlight")
                        AI.SetMoveTo(torGreycloud.x, torGreycloud.y)
                    end
                end
            end
        end
        return false
    end,
    isPointFarEnoughFromTeammates = function(x, y, teamList)
        for i, o in ipairs(teamList) do
            local tX, tY = AI.GetPosition(o)
            if UnitGUID(o) ~= UnitGUID("player") and AI.CalcDistance(x, y, tX, tY) < 1 then
                return false
            end
        end
        return true
    end,
    isPointFarEnoughFromFires = function(x, y, fireList)
        for i, o in ipairs(fireList) do
            if AI.CalcDistance(x, y, o.x, o.y) < icicleRadius then
                return false
            end
        end
        return true
    end,
    isPointFarEnoughFromSnowpackedIcicles = function(x, y, icicleList)
        for i, o in ipairs(icicleList) do
            if AI.CalcDistance(x, y, o.x, o.y) <= 10 then
                return false
            end
        end
        return true
    end,
    doesLineIntersectAnyFires = function(x1, y1, x2, y2, fireList)
        for i, o in ipairs(fireList) do
            if AI.DoesLineIntersect(x1, y1, x2, y2, o.x, o.y, 0.5) then
                return true
            end
        end
        return false
    end,
    doesLineIntersectAnyIcicles = function(x1, y1, x2, y2, icicleList, ignoreGuid)
        for i, o in ipairs(icicleList) do
            if o.guid ~= ignoreGuid and AI.DoesLineIntersect(x1, y1, x2, y2, o.x, o.y, icicleRadius) then
                return true
            end
        end
        return false
    end,
    findClosestPointInList = function(pointList)
        local dist = 100
        local point = nil
        for i, d in ipairs(pointList) do
            if AI.GetDistanceTo(d.x, d.y) < dist then
                point = d
                dist = AI.GetDistanceTo(d.x, d.y)
            end
        end
        return point
    end,
    centerX = 2000.7666015625,
    centerY = -233.83085632324,
    divertFromCenterR = 30,
    isHeadedTowardsStormPlr = nil,
    stormPowerPlayer = nil
})

function hodir:SPELL_AURA_APPLIED(args)
    if args.spellName:lower() == "storm cloud" then
        self.stormPowerPlayer = args.target
        print(args.target .. " is storm cloud plr")
    end
    if args.spellName:lower() == "storm power" then
        self.isHeadedTowardsStormPlr = nil
    end
end

function hodir:SPELL_AURA_REMOVED(args)
    if args.spellName:lower() == "storm cloud" then
        self.stormPowerPlayer = nil
        self.isHeadedTowardsStormPlr = false
        -- print(args.target .. " is no longer storm cloud  plr")
    end
end

function hodir:SPELL_DAMAGE(args)
    if args.spellName == "Ice Shards" and args.target == UnitName("player") then
        AI.ResetMoveTo()
    end
end

function hodir:SPELL_CAST_START(args)
    if args.spellName:lower() == "Starlight" then
        print("Starlight has been cast " .. table2str(args))
    end
end
function hodir:SPELL_CAST_SUCCESS(args)
    if args.spellName:lower() == "Starlight" then
        print("Starlight has been cast " .. table2str(args))
    end
end

function hodir:CHAT_MSG_RAID_BOSS_EMOTE(s, t)
    -- print("CHAT_MSG_RAID_BOSS_EMOTE " .. s)
    if MaloWUtils_StrContains(s, "flash freeze") then
        AI.ResetMoveTo()
    end
    if strcontains(s, "frozen") then
        if not AI.IsTank() then
            local veesha = AI.FindNearbyObjectsByName("veesha")
            if #veesha > 0 and veesha[1].distance > 10 then
                local facing = AI.CalcFacing(veesha[1].x, veesha[1].y, self.centerX, self.centerY)
                local r = 10
                local points = {}
                for theta = facing - rad45, facing + rad45, rad10 do
                    table.insert(points, {
                        x = veesha[1].x + r * math.cos(theta),
                        y = veesha[1].y + r * math.sin(theta)
                    })
                end
                if #points > 0 then
                    local i = math.random(1, #points)
                    AI.SetMoveTo(points[i].x, points[i].y)
                end
            end
        end
    end
end

AI.RegisterBossModule(hodir)

-- faceless horror
local facelessHorror = MosDefBossModule:new({
    name = "Faceless Horror",
    creatureId = {33772},
    onStart = function(self)
    end,
    onStop = function(self)
    end,
    onUpdate = function(self)
        -- check for MC
        if self.mcUnit ~= nil and GetTime() > self.ccTimeout then
            local mod = self
            if UnitName("player") ~= self.mcUnit and AI.IsDps() then
                if AI.IsWarlock() then
                    AI.RegisterPendingAction(function()
                        if not AI.IsUnitCC(mod.mcUnit) then
                            mod.ccTimeout = GetTime() + 10
                            return AI.CastSpell("fear", mod.mcUnit)
                        end
                    end, 3, "CC_MC_UNIT")
                end

                if AI.IsMage() and not AI.IsUnitCC(mod.mcUnit) and AI.CastSpell("polymorph", mod.mcUnit) then
                    self.ccTimeout = GetTime() + 10
                    return true
                end

                if AI.IsShaman() and not AI.IsUnitCC(mod.mcUnit) and AI.CastSpell("hex", mod.mcUnit) then
                    self.ccTimeout = GetTime() + 10
                    return true
                end
            end
        end

        if not AI.IsTank() and AI.IsValidOffensiveUnit() and AI.GetDistanceTo(AI.GetPosition("target")) > 30 then
            local angle = AI.GetFacingForPosition(AI.GetPosition("target")) + math.pi
            local r = 30
            local x, y = r * math.cos(angle), r * math.sin(angle)
            local tX, tY = AI.GetPosition("target")
            AI.SetMoveToPosition(tX + x, tY + y)
        end
    end,
    mcUnit = nil,
    ccTimeout = 0
})

function facelessHorror:SPELL_CAST_START(args)
    if args.spellName:lower() == "Shadow Crash" and args.target == UnitName("player") then
        AI.SayRaid("shadow crash on me")
    end
end

function facelessHorror:SPELL_CAST_SUCCESS(args)
    if args.spellName:lower() == "Shadow Crash" and args.target == UnitName("player") then
        AI.SayRaid("shadow crash on me")
    end
end
function facelessHorror:SPELL_AURA_APPLIED(args)
    if args.spellName:lower() == "dominate mind" then
        self.mcUnit = args.target
    end
end
function facelessHorror:SPELL_AURA_REMOVED(args)
    if args.spellName:lower() == "dominate mind" then
        self.mcUnit = nil
    end
end

AI.RegisterBossModule(facelessHorror)

-- general vezax
local vezax = MosDefBossModule:new({
    name = "General Vezax",
    creatureId = {33271},
    onStart = function(self)
        AI.USE_MANA_REGEN = false
        AI.PRE_DO_DPS = function(isAoE)
            if not AI.IsDps() then
                return false
            end

            local shouldNotDps = true
            shouldNotDps = not AI.HasDebuff("shadow crash")
            return shouldNotDps
        end

        AI.do_PriorityTarget = function()
            return AI.DoTargetChain("saronite animus")
        end

        AI.Config.startHealOverrideThreshold = 50
    end,
    onStop = function(self)
        AI.USE_MANA_REGEN = true
        AI.PRE_DO_DPS = nil
        AI.Config.startHealOverrideThreshold = 100
    end,
    onUpdate = function(self)
        local tick = GetTime()
        -- clean up crashes
        for i = #self.crashes, 1, -1 do
            if tick > self.crashes[i].time + 20 then
                table.remove(self.crashes, i)
            end
        end
        if tick > self.lastCrashTime and AI.IsDps() and #self.crashes > 0 then
            if not AI.HasDebuff("shadow crash") and not AI.HasDebuff("mark of the faceless") and
                not AI.HasMoveToPosition() then
                local closestCrash = self.findClosestPointInList(self.crashes)
                if closestCrash then
                    print("moving into shadow crash impact area")
                    AI.SetMoveTo(closestCrash.x, closestCrash.y)
                end
            end
        end

        if AI.IsPriest() and AI.HasDebuff("shadow crash") then
            local tank = AI.GetPrimaryTank()
            if not AI.HasDebuff("weakened soul", tank) and AI.CastSpell("power word: shield", tank) then
                return true
            end
        end

        if AI.HasDebuff("mark of the faceless") and not AI.HasMoveTo() then
            local spots = {}
            local closestAlly, distToAlly = AI.GetClosestAlly()
            if closestAlly and distToAlly <= 18 then
                print("I have mark, moving to avoid allies")
                local angle = AI.GetFacingForUnit(closestAlly) + math.pi
                local cX, cY = AI.GetPosition(closestAlly)
                for theta = angle - rad90, angle + rad90, rad5 do
                    if theta > pi2 then
                        theta = theta - pi2
                    elseif theta < 0.0 then
                        theta = theta + pi2
                    end
                    for r = 19, 25, 1 do
                        local x, y = r * math.cos(theta), r * math.sin(theta)
                        local nX, nY = cX + x, cY + y
                        table.insert(spots, {
                            x = nX,
                            y = nY
                        })
                    end
                end
            end
            if #spots > 0 then
                local p = self.findClosestPointInList(spots)
                AI.SetMoveTo(p.x, p.y)
            end
        end
    end,
    lastCrashTime = 0,
    animus = false,
    crashes = {},
    findClosestPointInList = function(pointList)
        local dist = 500
        local point = nil
        for i, d in ipairs(pointList) do
            if AI.GetDistanceTo(d.x, d.y) <= dist then
                point = d
                dist = AI.GetDistanceTo(d.x, d.y)
            end
        end
        return point
    end,
    isFarEnoughFromAllies = function(x, y, allies)
        for i, a in ipairs(allies) do
            local aX, aY = AI.GetPosition(a)
            if UnitGUID(a) ~= UnitGUID("player") and AI.CalcDistance(x, y, aX, aY) <= 18 then
                return false
            end
        end
        return true
    end
})

function vezax:SPELL_CAST_START(args)
    if args.spellName:lower() == "searing flames" then
        if AI.IsDps() and (AI.IsPriest() or AI.IsShaman() or AI.IsMage()) then
            local cd = 0
            if AI.IsShaman() or AI.IsMage() then
                cd = 1
            end
            AI.RegisterPendingAction(function()
                if UnitName("focus") ~= "General Vezax" then
                    TargetUnit("General Vezax")
                    FocusUnit("target")
                end
                if AI.IsCasting("focus") then
                    if AI.IsCasting() then
                        AI.StopCasting()
                    end
                    return AI.CastSpell(AI.GetInterruptSpell(), "focus")
                end
                return true
            end, cd, "INTERRUPT_SEARING_FLAMES")
        end
    end
end

function vezax:SPELL_CAST_SUCCESS(args)
    if args.spellName:lower() == "shadow crash" then
        if UnitName("focus") ~= "General Vezax" then
            TargetUnit("General")
            FocusUnit("target")
        end
        local sX, sY = AI.GetPosition(args.target)
        local gX, gY = AI.GetPosition("focus")
        local distToTarget = AI.CalcDistance(gX, gY, sX, sY)
        local speed = 10.0 -- from Shadow Crash spell.dbc
        local secondsToImpact = math.ceil(distToTarget / speed) -- calculation that the server does to determine impact time        
        self.lastCrashTime = GetTime() + secondsToImpact
        table.insert(self.crashes, {
            x = sX,
            y = sY,
            time = self.lastCrashTime
        })
        local mod = self
        local cX, cY = AI.GetPosition()
        if AI.GetDistanceTo(sX, sY) <= 11 and not AI.IsTank() then
            print("evading shadow crash")
            local allies = AI.GetRaidOrPartyMemberUnits()
            local angle = AI.GetFacingForPosition(AI.GetPosition("target"))
            local points = {}
            for theta = angle - rad90, angle + rad90, rad45 do
                if theta > pi2 then
                    theta = theta - pi2
                elseif theta < 0.0 then
                    theta = theta + pi2
                end
                for r = 13, 40, 1 do
                    local x, y = r * math.cos(theta), r * math.sin(theta)
                    local nX, nY = sX + x, sY + y
                    if not AI.HasDebuff("mark of the faceless") or self.isFarEnoughFromAllies(nX, nY, allies) then
                        table.insert(points, {
                            x = nX,
                            y = nY
                        })
                    end
                end
                local p = self.findClosestPointInList(points)
                AI.SetMoveToPosition(p.x, p.y)
            end
        end
    end
end

function vezax:SPELL_AURA_APPLIED(args)
    if args.spellName:lower() == "mark of the faceless" and UnitName("player") == args.target then
        local spots = {}
        local closestAlly, distToAlly = AI.GetClosestAlly()
        if closestAlly and distToAlly <= 18 then
            print("I have mark, moving to avoid allies")
            local angle = AI.GetFacingForUnit(closestAlly) + math.pi
            local cX, cY = AI.GetPosition(closestAlly)
            for theta = angle - rad90, angle + rad90, rad5 do
                if theta > pi2 then
                    theta = theta - pi2
                elseif theta < 0.0 then
                    theta = theta + pi2
                end
                for r = 19, 25, 1 do
                    local x, y = r * math.cos(theta), r * math.sin(theta)
                    local nX, nY = cX + x, cY + y
                    table.insert(spots, {
                        x = nX,
                        y = nY
                    })
                end
            end
        end
        if #spots > 0 then
            local p = self.findClosestPointInList(spots)
            AI.SetMoveTo(p.x, p.y)
        end
    end
end

function vezax:SPELL_DAMAGE(args)
    if args.spellName:lower() == "shadow crash" and UnitName("player") == args.target then
        AI.ResetMoveTo()
    end
end

function vezax:CHAT_MSG_RAID_BOSS_EMOTE(s, t)
    if strcontains(s, "merging into a") then
        self.animus = true
        AI.Config.startHealOverrideThreshold = 100
    end
end

AI.RegisterBossModule(vezax)

-- twilight adherent
local twilightAdherent = MosDefBossModule:new({
    name = "Twilight Adherent",
    creatureId = {33818, 33822, 33819, 33820, 33824, 33838},
    onStart = function(self)
        if AI.IsTank() then
            TargetUnit("Twilight Adherent")
            local frostMage = AI.FindNearbyObjectsByName("twilight frost mage")
            if #frostMage > 0 and not frostMage[1].isDead and not AI.IsUnitCC(frostMage[1]) then
                frostMage[1]:Focus()
                SetRaidTarget("focus", 2)
            end
        end
    end,
    onStop = function(self)
    end,
    onUpdate = function(self)
        if AI.IsDps() then
            local frostMage = AI.FindNearbyObjectsByName("twilight frost mage")
            local markedMage = nil
            for i, o in ipairs(frostMage) do
                if o.raidTargetIndex and not o.isDead and not AI.IsUnitCC(o) then
                    markedMage = o
                end
            end

            if markedMage and markedMage.guid ~= UnitGUID("target") then
                markedMage:Focus()
                -- if AI.IsWarlock() then
                --     AI.RegisterPendingAction(function()
                --         if not markedMage.isDead and not AI.IsUnitCC(markedMage) then
                --             return AI.CastSpell("fear", "focus")
                --         end
                --         return false
                --     end, 3, "CC_ADHERENT")
                -- end

                if AI.IsShaman() and AI.CastSpell("hex", "focus") then
                    return true
                end

                if AI.IsMage() and AI.CastSpell("polymorph", "focus") then
                    return true
                end
            end
        end
    end
})
AI.RegisterBossModule(twilightAdherent)

local guardianLasher = MosDefBossModule:new({
    name = "Guardian Lasher",
    creatureId = {33430, 33431},
    onStart = function(self)
        if AI.IsPriest() then
            CancelUnitBuff("player", "vampiric embrace")
        end
        AI.Config.startHealOverrideThreshold = 50
    end,
    onStop = function(self)
        AI.Config.startHealOverrideThreshold = 100
    end
})
AI.RegisterBossModule(guardianLasher)

--
-- local chamberOverseer = MosDefBossModule:new({
--     name = "Chamber Overseer",
--     creatureId = {34197},
--     onStart = function(self)
--     end,
--     onStop = function(self)
--     end,
--     onUpdate = function(self)
--         local devices = AI.FindNearbyObjectsByName("displacement")
--         if #devices > 0 and not AI.IsTank() then
--             if devices[1].distance <= 5 then
--                 -- print("Displacement Device on me")
--                 local facing = GetPlayerFacing() + math.pi
--                 if facing > math.pi * 2 then
--                     facing = facing - math.pi * 2
--                 end
--                 AI.SetFacing(facing)
--                 MoveForwardStart()
--             end
--         end
--     end
-- })

-- AI.RegisterBossModule(chamberOverseer)

-- mimiron
local mimiron = MosDefBossModule:new({
    name = "Mimiron",
    creatureId = {33350, 33432},
    onStart = function(self)
        if AI.IsTank() then
            AI.ALLOW_AUTO_REFACE = false
        end
        oldPriorityTargetFn = AI.do_PriorityTarget
        AI.do_PriorityTarget = function()
            return AI.DoTargetChain("assault bot", "aerial command unit")
        end
        AI.Config.startHealOverrideThreshold = 95
    end,
    onStop = function(self)
        AI.ALLOW_AUTO_REFACE = true
        AI.do_PriorityTarget = oldPriorityTargetFn
        AI.Config.startHealOverrideThreshold = 100
    end,
    onUpdate = function(self)
        if AI.IsDps() then
            local healer = AI.GetPrimaryHealer()
            if healer and AI.GetDistanceTo(AI.GetPosition(healer)) > 1 then
                -- print("too far from healer, moving towards")
                local x, y = AI.GetPosition(healer)
                AI.SetMoveToPosition(x, y)
            end
        end

        if AI.IsPriest() then

            if self.plasmaTarget ~= nil and not AI.HasDebuff("weakened soul", self.plasmaTarget) and
                AI.CastSpell("power word: shield", self.plasmaTarget) then
                return true
            end
            local criticalTarget, missingHp = AI.GetMostDamagedFriendly("power word: shield")
            if criticalTarget and AI.GetUnitHealthPct(criticalTarget) <= 10 and
                not AI.HasDebuff("weakened soul", criticalTarget) then
                if AI.IsCasting() then
                    AI.StopCasting()
                end
                if AI.CastSpell("power word: shield", criticalTarget) then
                    return true
                end
            end
        end

        if AI.IsHealer() and self.plasmaTarget ~= nil and AI.GetUnitHealthPct(self.plasmaTarget) <= 80 then
            if AI.IsShaman() and AI.CastSpell("riptide", self.plasmaTarget) or
                AI.CastSpell("healing wave", self.plasmaTarget) then
                return true
            end
        end

        if AI.IsMage() and not AI.HasMyBuff("fire ward") and AI.CastSpell("fire ward") then
            return true
        end

        if AI.IsHealer() or AI.IsTank() then
            local rocket = AI.FindNearbyObjectsByName("rocket strike")
            if #rocket > 0 and rocket[1].distance <= 3 and not AI.HasMoveTo() then
                print('evading rocket')
                local facing = AI.GetFacingForPosition(self.centerx, self.centery)
                local theta = facing - rad90
                local r = 7
                local pX, pY = AI.GetPosition("player")
                local nX, nY = pX + r * math.cos(theta), pY + r * math.sin(theta)
                AI.SetMoveTo(nX, nY)
            end
        end

        if AI.IsTank() and AI.IsValidOffensiveUnit() and UnitCastingInfo("target") == "Shock Blast" and
            not AI.HasMoveTo() and AI.GetDistanceToUnit("target") < 20 then
            AI.StopCasting()
            print("avoiding shock blast")
            local facing = GetPlayerFacing() + math.pi
            local r = 20
            local x, y = r * math.cos(facing), math.sin(facing)
            local cX, cY = AI.GetPosition()
            local nX, nY = cX + x, cY + y
            AI.SetMoveTo(nX, nY, 0.5, function()
                AI.SetFacingUnit("target")
            end)
        end
        return false
    end,
    plasmaTarget = nil,
    centerx = 2745.083984375,
    centery = 2569.5290527344
})

function mimiron:SPELL_AURA_APPLIED(args)
    if args.spellName == "Plasma Blast" then
        self.plasmaTarget = args.target
    end
end

function mimiron:SPELL_AURA_REMOVED(args)
    if args.spellName == "Plasma Blast" then
        self.plasmaTarget = nil
    end
end

function mimiron:SPELL_CAST_START(args)
    if args.spellName == "Shock Blast" or args.spellId == 63631 then
        if AI.IsTank() and not AI.HasMoveToPosition() then
            AI.StopCasting()
            print("avoiding shock blast")
            local facing = GetPlayerFacing() + math.pi
            local r = 20
            local x, y = r * math.cos(facing), math.sin(facing)
            local cX, cY = AI.GetPosition()
            local nX, nY = cX + x, cY + y
            AI.SetMoveTo(nX, nY, 0.5, function()
                AI.SetFacingUnit("target")
            end)
        end
    end

    if args.spellName == "plasma blast" then
        if AI.IsPriest() then
            AI.RegisterPendingAction(function()
                local tank = AI.GetPrimaryTank()
                if not AI.HasDebuff("weakened soul", tank) then
                    return AI.CastSpell("power word: shield", tank)
                end
                return false
            end, null, "SHIELD_TANK")
        end
    end
end

function mimiron:SPELL_CAST_SUCCESS(args)
    if args.spellId == 63414 or args.spellName == "spinning up" then
        if AI.IsTank() and AI.IsValidOffensiveUnit() then
            AI.SayRaid("Mimiron is spinning up")
            local pi2 = math.pi * 2
            local target = GetObjectInfo("target")
            if target.facing ~= nil then
                local angleBehind = target.facing + math.pi + rad22_5
                if angleBehind > pi2 then
                    angleBehind = angleBehind - pi2
                elseif angleBehind < 0.0 then
                    angleBehind = angleBehind + pi2
                end
                local r = 3
                local x, y = r * math.cos(angleBehind), r * math.sin(angleBehind)
                local nX, nY = target.x + x, target.y + y
                AI.SetMoveToPosition(nX, nY)
            end
        end
    end
end

AI.RegisterBossModule(mimiron)

local yoggSaron = MosDefBossModule:new({
    name = "Yogg-Saron",
    creatureId = {33288, 33134, 33136},
    onStart = function(self)
        oldPriorityTargetFn = AI.do_PriorityTarget
        AI.do_PriorityTarget = function()
            if self:isDescentTeam() then
                if self.illusionShattered then
                    TargetUnit("brain")
                    return true

                end
                if self.usedDescentPortal then
                    TargetNearestEnemy()
                    return true
                end

            end
            if self.phase == 2 then
                TargetUnit("Constrictor")
                if AI.IsValidOffensiveUnit() and UnitName("target") == "Constrictor Tentacle" and
                    AI.GetDistanceTo(AI.GetPosition("target")) <= 40 then
                    return true
                end
                if not AI.IsValidOffensiveUnit() then
                    TargetNearestEnemy()
                end
            end
            return false
        end
        AI.PRE_DO_DPS = function(isAoE)
            if self.phase == 3 then
                if not AI.IsValidOffensiveUnit() then
                    TargetUnit("yogg")
                elseif MaloWUtils_StrContains(UnitName("target"):lower(), "yogg") and AI.IsChanneling("target") then
                    return true
                end
            end

            if self:isDescentTeam() and AI.IsValidOffensiveUnit() and self.usedDescentPortal and
                not self.illusionShattered then
                if AI.IsWarlock() and not AI.HasMyDebuff("corruption") and AI.CastSpell("corruption", "target") then
                    return true
                end
                if AI.IsPriest() and not AI.HasMyDebuff("shadow word: pain") and AI.CastSpell("shadow word: pain") then
                    return true
                end
            end
            return false
        end

        if AI.IsMage() then
            -- AI.AUTO_CLEANSE = false
        end
    end,
    onEnd = function(self)
        AI.do_PriorityTarget = oldPriorityTargetFn
    end,
    onUpdate = function(self)
        if AI.HasBuff("flash freeze") or AI.HasDebuff("squeeze") or AI.HasDebuff("malady of the mind") then
            return true
        end

        if (AI.IsMage() and AI.CleanseRaid("Remove Curse", "Curse")) or
            (AI.IsPriest() and AI.CleanseRaid("Dispel Magic", "Magic")) then
            return true
        end

        if self.phase == 2 and AI.IsShaman() and not AI.HasTotemOut("3") and AI.CastSpell("cleansing totem") then
            return true
        end

        -- have paladin self cleanse in p2
        if AI.IsPaladin() and self.phase == 2 then
            if AI.GetUnitPowerPct() > 20 and AI.CleanseSelf("Cleanse", "Disease", "Magic", "Poison") then
                return true
            end
        end

        if AI.IsPaladin() and AI.AUTO_DPS and AI.IsValidOffensiveUnit() and UnitName("target") == "Constrictor Tentacle" then
            if AI.GetDistanceTo(AI.GetPosition("target")) > 3 and not AI.HasMoveToPosition() then
                local x, y = AI.GetPosition("target")
                AI.SetMoveTo(x, y, 1)
                print("moving to melee-range of constrictor")
            end
        end
        if self.phase == 2 then
            if self:isDescentTeam() then
                if self.portalToUse and not self.doesPortalExist(self.portalToUse) then
                    self.portalToUse = nil
                end
                if self.portalToUse and AI.GetDistanceTo(self.portalToUse.x, self.portalToUse.y) <= 4 then
                    print("taking brain portal")
                    self.portalToUse:Interact()
                    self.usedDescentPortal = true
                    self.portalToUse = nil
                    AI.ResetMoveToPosition()
                    AI.StopMoving()
                end
            end
        elseif self.phase == 3 then
            if self:isDescentTeam() then
                if self.usedDescentPortal and self.portalToUse and
                    AI.GetDistanceTo(self.portalToUse.x, self.portalToUse.y) <= 4 then
                    print("taking escape portal")
                    AI.ResetMoveToPosition()
                    AI.StopMoving()
                    self.portalToUse:Interact()
                    self.portalToUse = nil
                    self.usedDescentPortal = false
                    self.illusionShattered = false

                    local tank = AI.GetPrimaryTank()
                    local tx, ty = AI.GetPosition(tank)
                    if not AI.HasMoveToPosition() then
                        AI.SetMoveToPosition(tx, ty)
                    end
                end
            end

            if UnitName("focus") ~= "Yogg-Saron" then
                TargetUnit("yogg")
                FocusUnit("target")
            end
            if AI.IsChanneling("focus") then
                local facing = AI.GetFacingForPosition(AI.GetPosition("focus")) + math.pi
                AI.SetFacing(facing)
                -- print("lunatic Gaze, facing away from boss")
            end
        end
        return false
    end,
    phase = 1,
    descentDps1 = "mosdeflocka",
    descentDps2 = "mosdefswp",
    portalToUse = nil,
    illusionShattered = false,
    usedDescentPortal = false,
    portalsOpen = false,
    isDescentTeam = function(self)
        return UnitName("player"):lower() == self.descentDps1 or UnitName("player"):lower() == self.descentDps2
    end,
    doesPortalExist = function(portal)
        local portals = AI.FindNearbyObjectsByName("descend into madness")
        for i, o in ipairs(portals) do
            if portal.guid == o.guid then
                return true
            end
        end
        return false
    end
})

function yoggSaron:CHAT_MSG_MONSTER_YELL(text, monster)
    if MaloWUtils_StrContains(text:lower(), "lucid dream") then
        self.phase = 2
        print("Entering phase 2")
    end

    if MaloWUtils_StrContains(text:lower(), "true face of death") then
        self.phase = 3
        AI.toggleAutoDps(false)
        print("Entering phase 3")
        if self:isDescentTeam() and self.illusionShattered then
            local escapePortal = AI.FindNearbyObjectsByName("flee to the surface")
            if #escapePortal > 0 then
                self.portalToUse = escapePortal[1]
                if AI.GetDistanceTo(escapePortal[1].x, escapePortal[1].y) > 5 then
                    print("moving to escape portal");
                    AI.SetMoveToPosition(escapePortal[1].x, escapePortal[1].y)
                end
            end
        end
        if not self:isDescentTeam() then
            local tank = AI.GetPrimaryTank()
            if not AI.IsTank() then
                AI.SetMoveToPosition(AI.GetPosition(tank))
            end
        end
    end
end

function yoggSaron:CHAT_MSG_RAID_BOSS_EMOTE(s, t)
    if MaloWUtils_StrContains(s, "illusion shatters") then
        print("illusion shattered")
        -- AI.toggleAutoDps(false)
        self.illusionShattered = true
        if self:isDescentTeam() then
            local brain = AI.FindNearbyObjectsByName("brain of")
            if #brain > 0 then
                brain[1]:Target()
            else
                print("could not find/target brain of yogg-saron")
            end
        end
    end

    if MaloWUtils_StrContains(s, "open into") then
        AI.ResetMoveTo()
        self.portalsOpen = true
        self.usedDescentPortal = false
        self.illusionShattered = false
        local mod = self
        AI.RegisterPendingAction(function()
            mod.portalsOpen = false
            return true
        end, 25, "PORTALS_CLOSED")

        if self:isDescentTeam() then
            local mod = self
            AI.RegisterPendingAction(function()
                local portals = AI.FindNearbyObjectsByName("descend into madness")
                if #portals == 2 then
                    if AI.IsPriest() then
                        AI.RegisterPendingAction(function()
                            return not AI.HasMyBuff("abolish disease", self.descentDps1) and
                                       AI.CastSpell("abolish disease", self.descentDps1)
                        end, null, "CLEANSE_DESCENDER_1")
                        AI.RegisterPendingAction(function()
                            return not AI.HasMyBuff("abolish disease", self.descentDps2) and
                                       AI.CastSpell("abolish disease", self.descentDps2)
                        end, null, "CLEANSE_DESCENDER_2")
                    end
                    if AI.IsWarlock() then
                        AI.RegisterPendingAction(function()
                            return AI.CastSpell("shadow ward")
                        end, null, "SHADOW_WARD")
                    end
                    if UnitName("player"):lower() == self.descentDps1 and not AI.HasMoveToPosition() then
                        local portal = portals[1]
                        self.portalToUse = portal
                        if AI.GetDistanceTo(portal.x, portal.y) > 4 then
                            print("dps1 to move to brain portal")
                            -- AI.SetMoveToPosition(portal.x, portal.y)
                        else
                            print("dps1 already at portal")
                        end
                    end
                    if UnitName("player"):lower() == self.descentDps2 and not AI.HasMoveToPosition() then
                        local portal = portals[2]
                        AI.RegisterPendingAction(function()
                            AI.CastSpell("power word: shield", "player")
                            local x, y = AI.GetPosition()
                            local deathorbs = AI.FindNearbyObjectsByName("death orb")
                            if #deathorbs > 0 then
                                for i, orb in ipairs(deathorbs) do
                                    if AI.DoesLineIntersect(x, y, portal.x, portal.y, orb.x, orb.y, 3) then
                                        return false
                                    end
                                end
                            end
                            if AI.GetDistanceTo(portal.x, portal.y) > 4 then
                                print("dps2 moving to brain portal")
                                AI.SetMoveToPosition(portal.x, portal.y)
                                self.portalToUse = portal
                            end
                            return true
                        end, 5, "MOVE_TO_PORTAL")
                    end
                end
                --- Move to escape portals when it's time(5s before induce madness finishes)
                local mod = self
                AI.RegisterPendingAction(function()
                    if mod.phase == 2 then
                        print("Brain will finish casting Induce Madness in 10s")
                        local escapePortal = AI.FindNearbyObjectsByName("flee to the surface")
                        if #escapePortal > 0 then
                            if AI.GetDistanceTo(escapePortal[1].x, escapePortal[1].y) > 5 then
                                print("moving to escape portal");
                                AI.SetMoveToPosition(escapePortal[1].x, escapePortal[1].y)
                            end
                            AI.RegisterPendingAction(function()
                                if mod.phase == 2 then
                                    print("using escape portal");
                                    AI.ResetMoveToPosition()
                                    AI.StopMoving()
                                    escapePortal[1]:Interact()
                                    mod.usedDescentPortal = false
                                    mod.illusionShattered = false
                                    AI.RegisterPendingAction(function()
                                        local tank = AI.GetPrimaryTank()
                                        local tx, ty = AI.GetPosition(tank)
                                        if not AI.HasMoveToPosition() then
                                            AI.SetMoveToPosition(tx, ty)
                                        end
                                        return true
                                    end, 1, "MOVE_BACK_TO_TANK")
                                end
                                return true
                            end, 6, "ESCAPE_BRAIN")
                        end
                    end
                    return true
                end, 50, "MOVE_TO_ESCAPE_PORTALS")

                return true
            end, 1, "REACT_TO_PORTALS")
        end
        if not self:isDescentTeam() then
            AI.toggleAutoDps(true)

            AI.RegisterPendingAction(function()
                local constrictors = AI.FindNearbyObjectsByName("Constrictor")
                if #constrictors == 0 then
                    local wells = AI.FindNearbyObjectsByName("sanity well")
                    local deathorbs = AI.FindNearbyObjectsByName("death orb")
                    if #deathorbs == 0 and #wells > 0 and not AI.HasMoveToPosition() then
                        print("no constrictors, moving to sanity well while brain phase")
                        if AI.GetDistanceTo(wells[1].x, wells[1].y) > 2 then
                            AI.SetMoveToPosition(wells[1].x, wells[1].y)
                            return true
                        else
                            print("Already at well")
                            return true
                        end
                    end
                end
                return false
            end)

        end
    end
end

function yoggSaron:SPELL_AURA_APPLIED(args)
    if args.spellName == "Squeeze" and not self:isDescentTeam() and self.portalsOpen then
        AI.ResetMoveToPosition()
        AI.StopMoving()
        TargetUnit("constrictor")
    end
end

function yoggSaron:SPELL_AURA_REMOVED(args)
    if args.spellName == "Squeeze" and not self:isDescentTeam() and self.portalsOpen then
        local wells = AI.FindNearbyObjectsByName("sanity well")
        if #wells > 0 and not AI.HasMoveToPosition() and AI.GetDistanceTo(wells[1].x, wells[1].y) > 3 then
            print("constrictors killed, resuming moving back to sanity well")
            AI.SetMoveToPosition(wells[1].x, wells[1].y)
        end
    end
end

function yoggSaron:SPELL_CAST_SUCCESS(args)
    if args.spellName:lower() == "induce madness" then
        AI.toggleAutoDps(false)
    end
    if args.spellName:lower() == "lunatic gaze" and not self.usedDescentPortal then
        if UnitName("focus") ~= "Yogg-Saron" then
            TargetUnit("yogg")
            FocusUnit("target")
        end
        local facing = AI.GetFacingForPosition(AI.GetPosition("focus")) + math.pi
        AI.SetFacing(facing)
        print("lunatic Gaze, facing away from boss")
    end
end

AI.RegisterBossModule(yoggSaron)
