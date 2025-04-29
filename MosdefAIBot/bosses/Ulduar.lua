local oldPriorityTargetFn = nil
local rad30 = 0.5235988
local rad22_5 = 0.3926991
local rad10 = 0.1745329
local rad5 = 0.08726646
local pi2 = math.pi * 2
local pi = math.pi
local rad45 = 0.785398
local rad90 = 1.570796
local rad100 = 1.745329
local rad120 = 2.094395
local rad135 = 2.356194

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
            local nearbyMender = AI.FindUnitYWithinXOf("target", "iron mender", 20)
            if #nearbyMender > 0 and not nearbyMender[1].isDead and not AI.IsUnitCC(nearbyMender[1]) then
                nearbyMender[1]:Focus()
                SetRaidTarget("focus", 7)
            end
        end
    end,
    onStop = function(self)
    end,
    onUpdate = function(self)
        if AI.IsDps() then
            local menders = AI.FindNearbyUnitsByName("iron mender")
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
                    AI.RegisterOneShotAction(function()
                        if not markedMender.isDead and not AI.IsUnitCC(markedMender) then
                            return AI.CastSpell("fear", "focus")
                        end
                    end, 5, "CC_IRON_MENDER")
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
                local pyrite = AI.FindNearbyUnitsByName("liquid pyrite")
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
            if AI.IsPriest() and AI.DoCastSpellChain("mind blast", "shadow word: death", "mind flay") then
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
                    local tX, tY = AI.GetPosition()
                    local facing = GetPlayerFacing()
                    local success = false
                    if AI.IsPointWithinCone(tX, tY, hx, hy, facing, math.pi) then
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
                AI.SetMoveTo(self.dpsX, self.dpsY)
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
            AI.SetMoveTo(self.dps1x, self.dps1y)
        end
        if AI.IsDpsPosition(2) then
            AI.SetMoveTo(self.dps2x, self.dps2y)
        end
        if AI.IsDpsPosition(3) then
            AI.SetMoveTo(self.dps3x, self.dps3y)
        end
        if AI.IsHealer() then
            AI.SetMoveTo(self.healerx, self.healery)
        end

        self.nextRightArmTargetTime = GetTime() + 13
        local mod = self

        oldPriorityTargetFn = AI.do_PriorityTarget
        AI.do_PriorityTarget = function(self)
            local time = GetTime()
            if time >= mod.nextRightArmTargetTime then
                TargetUnit("right arm")
                return AI.IsValidOffensiveUnit()
            end
            return false
        end
    end,
    onStop = function(self)
        AI.do_PriorityTarget = oldPriorityTargetFn
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
            local eyebeam = AI.FindNearbyUnitsByName("eyebeam")
            if #eyebeam > 0 then
                local x, y = AI.GetPosition("player")
                local facingToPlayer = AI.CalcFacing(eyebeam[1].x, eyebeam[1].y, x, y)
                if GetTime() > self.eyeEvadeTime then
                    local eyeFacing = eyebeam[1].facing

                    -- if AI.IsPointWithinCone(x, y, eyebeam[1].x, eyebeam[1].y, eyeFacing, rad30) then
                    -- if eyeFacing > math.pi * 2 then
                    --     eyeFacing = eyeFacing - math.pi * 2
                    -- elseif eyeFacing < 0.0 then
                    --     eyeFacing = eyeFacing + math.pi * 2
                    -- end
                    -- local diff = math.abs(eyeFacing - facingToPlayer)
                    -- print("eyebeam facing " .. eyeFacing .. " toplr facing:" .. facingToPlayer .. " diff:" .. diff)
                    if (eyebeam[1].distance <= 5 -- and diff <= 0.5
                    and AI.IsPointWithinCone(x, y, eyebeam[1].x, eyebeam[1].y, eyeFacing, rad22_5)) and
                        not AI.HasMoveToPosition() then
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
    nextRightArmTargetTime = 0,
    dps1x = 1767.7006835938,
    dps1y = -3.4941546916962,
    dps2x = 1783.7899169922,
    dps2y = -3.9541857242584,
    dps3x = 1767.5830078125,
    dps3y = -20.168651580811,
    healerx = 1775.3013916016,
    healery = -12.071847915649,
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
        self.nextRightArmTargetTime = GetTime() + 15
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
    end
end

function kologarn:UNIT_DIED(unit)
    if strcontains(unit, "right arm") then
        self.nextRightArmTargetTime = GetTime() + 60
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
            local flames = AI.FindNearbyUnitsByName("devouring flame stalker")
            if #flames > 0 then
                if flames[1].distance <= 9 and not AI.HasMoveTo() and GetTime() > self.lastEvadeTime + 5 then
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
                        AI.SetMoveTo(p.x, p.y)
                    else
                        AI.SetMoveTo(self.startx, self.starty)
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
            local flames = AI.FindNearbyUnitsByName("devouring flame stalker")
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
            if mod.thorimDropped or not mod.gauntletStarted then
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

            if mod.thorimDropped or not self.gauntletStarted then
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

        AI.AUTO_CLEANSE = false
    end,
    onStop = function(self)
        if oldPriorityTargetFn ~= nil then
            AI.do_PriorityTarget = oldPriorityTargetFn
        end
        AI.PRE_DO_DPS = nil
        AI.AUTO_CLEANSE = true
    end,
    onUpdate = function(self)
        if self.gauntletStarted and not self.thorimDropped and UnitName("player") == self.follower then
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
            local orbs = AI.FindNearbyUnitsByName("thunder orb")
            if #orbs > 0 and not AI.HasMoveTo() then
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
                                    local angleBehindThorim = thorimFacingOrb + math.pi
                                    local r = 1 -- move 2 places behind thorim w/ the orb
                                    local x = thorim.x + r * math.cos(angleBehindThorim)
                                    local y = thorim.y + r * math.sin(angleBehindThorim)
                                    AI.SetMoveTo(x, y)
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
                                end, 7, "RETURN_TO_POSITION")
                            end
                        end
                    end
                end
            end

            if AI.IsPriest() then
                local allies = AI.GetRaidOrPartyMemberUnits()
                for i, a in ipairs(allies) do
                    if AI.HasDebuff("frost nova", a) and AI.CastSpell("dispel magic", a) then
                        return true
                    end
                end
            end

            if AI.IsMage() and AI.HasMoveTo() and AI.IsFacingTowardsDestination() and AI.CastSpell("blink") then
                return true
            end
        end
    end,
    gauntletLeader = "Mosdeflocka",
    follower = "",

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
        if AI.IsHealer() then
            AI.AUTO_CLEANSE = false
        end
        if AI.IsDps() then
            if AI.IsPriest() then
                AI.MustCastSpell("vampiric embrace", "player")
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
        local allies = AI.GetRaidOrPartyMemberUnits()
        if not AI.IsTank() then
            local natureBombs = AI.FindNearbyUnitsByName("nature bomb")
            if AI.IsDps() and AI.GetDistanceTo(AI.GetPosition("target")) > 40 and #natureBombs == 0 then
                local tX, tY = AI.GetPosition("target")
                local cX, cY = AI.GetPosition("player")
                local r = 35
                local facing = AI.CalcFacing(tX, tY, cX, cY)
                local nX, nY = tX + r * math.cos(facing), tY + r * math.sin(facing)
                AI.SetMoveToPosition(nX, nY)
            end
            local spores = AI.FindNearbyUnitsByName("healthy spore")
            if #spores > 0 and (UnitName("target") == "Ancient Conservator" and not AI.HasBuff("potent pheromones")) and
                not AI.HasMoveTo() then
                print("moving towards mushroom for buff")
                if not AI.HasDebuff("nature's fury") then
                    AI.SetMoveToPosition(spores[1].x, spores[1].y)
                else
                    for i, spore in ipairs(spores) do
                        if self.isFarEnoughFromAllies(spore.x, spore.y, allies) then
                            AI.SetMoveToPosition(spore.x, spore.y)
                            return false
                        end
                    end
                end
            end

            if #natureBombs > 0 and natureBombs[1].distance <= 14 and not AI.HasMoveTo() then
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
                        AI.SetMoveTo(p.x, p.y)
                    end
                end
            end
        end
        return false
    end,
    isPointSafeFromBombs = function(x, y, bombList)
        local cX, cY = AI.GetPosition("player")
        for i, o in ipairs(bombList) do
            if AI.CalcDistance(x, y, o.x, o.y) <= 14 then
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
    end,
    isFarEnoughFromAllies = function(x, y, allies)
        for i, a in ipairs(allies) do
            local aX, aY = AI.GetPosition(a)
            if UnitGUID(a) ~= UnitGUID("player") and AI.CalcDistance(x, y, aX, aY) <= 10 then
                return false
            end
        end
        return true
    end
})

function freya:SPELL_AURA_APPLIED(args)
    if args.spellName:lower() == "nature's fury" and UnitName("player") == args.target and not AI.IsTank() then
        local spores = AI.FindNearbyUnitsByName("healthy spore")
        if #spores > 0 then
            print("avoiding allies coz of nature's fury")
            local allies = AI.GetRaidOrPartyMemberUnits()
            for i, spore in ipairs(spores) do
                if self.isFarEnoughFromAllies(spore.x, spore.y, allies) then
                    AI.SetMoveToPosition(spore.x, spore.y)
                    return
                end
            end
        end
    end
end

function freya:SPELL_CAST_START(args)
    if args.spellName == "Tidal Wave" then
        print(args.caster .. " is casting tidal wave")
        if not AI.IsTank() then
            TargetUnit(args.caster)
            AI.DoStaggeredInterrupt()
        end
    end
end

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
                local frozenVeesha = AI.FindUnitYWithinXOf("veesha", "flash freeze", 1)
                if #frozenVeesha > 0 and not frozenVeesha[1].isDead then
                    frozenVeesha[1]:Target()
                    if AI.GetDistanceTo(frozenVeesha[1].x, frozenVeesha[1].y) > 40 then
                        local facing = AI.GetFacingForPosition(frozenVeesha[1].x, frozenVeesha[1].y) + math.pi
                        local r = 40
                        local x, y = AI.GetPosition("player")
                        AI.SetMoveTo(x + r * math.cos(facing), y + r * math.sin(facing))
                        print("moving closer to veesha")
                    end
                    return true
                else
                    if AI.IsDpsPosition(1) then
                        local freezes = AI.FindNearbyUnitsByName("flash freeze")
                        for i, o in ipairs(freezes) do
                            if not o.isDead and o.distance <= 40 then
                                o:Target()
                                return true
                            end
                        end
                    end
                end
            end
            return false
        end

        AI.PRE_DO_DPS = function(isAoE)
            if AI.IsDps() and UnitName("target") == "Flash Freeze" then
                if AI.IsWarlock() and AI.DoCastSpellChain("target", "corruption", "shadow bolt") then
                    return true
                end
                if AI.IsPriest() and AI.DoCastSpellChain("target", "mind blast", "shadow word: death", "mind flay") then
                    return true
                end
                if AI.IsShaman() and AI.DoCastSpellChain("target", "flame shock", "lava burst", "lightning bolt") then
                    return true
                end
                if AI.IsMage() and AI.DoCastSpellChain("target", "living bomb", "fire blast", "scorch") then
                    return true
                end
            end
            return false
        end
    end,
    onStop = function(self)
        AI.ALLOW_AUTO_REFACE = true
        AI.PRE_DO_DPS = nil
        AI.do_PriorityTarget = oldPriorityTargetFn
    end,
    onUpdate = function(self)
        if not AI.IsTank() then
            local nearbyObjects = AI.GetNearbyObjects()
            local closestToastyFire = nil
            local closestIcicle = nil
            local closestSnowpackedIcicle = nil
            local closestSnowpackedIcicleTarget = nil
            local icicles = {}
            local fires = {}
            local snowpackedIcicles = {}
            local fireMage = nil
            local hodir = nil
            local starlights = {}
            local tank = AI.GetObjectInfo(AI.GetPrimaryTank())
            local cX, cY, cZ = AI.GetPosition("player")
            local teamList = AI.GetRaidOrPartyMemberUnits()
            for i, o in ipairs(nearbyObjects) do
                if strcontains(o.name, "toasty fire") then
                    table.insert(fires, o)
                    if closestToastyFire == nil then
                        closestToastyFire = o
                    end
                end
                if o.name and o.name:lower() == "icicle" then
                    table.insert(icicles, o)
                    if not closestIcicle then
                        closestIcicle = o
                    end
                end
                if strcontains(o.name, "snowpacked icicle") then
                    table.insert(snowpackedIcicles, o)
                    if not closestSnowpackedIcicle then
                        closestSnowpackedIcicle = o
                    end
                end

                if o.name and o.name:lower() == "snowpacked icicle target" and closestSnowpackedIcicleTarget == nil then
                    closestSnowpackedIcicleTarget = o
                end
                if strcontains(o.name, "veesha") then
                    fireMage = o
                end
                if strcontains(o.name, "hodir") then
                    hodir = o
                end
                if o.spellName and strcontains(o.spellName, "starlight") then
                    table.insert(starlights, o)
                end
            end

            if AI.HasDebuff("Freeze") then
                return false
            end

            if closestSnowpackedIcicleTarget and closestSnowpackedIcicleTarget.distance >= 10 and not AI.HasMoveTo() then
                local angleFacing = AI.CalcFacing(closestSnowpackedIcicleTarget.x, closestSnowpackedIcicleTarget.y,
                    fireMage.x, fireMage.y)
                -- 180 degree cone
                local points = {}
                for theta = angleFacing - rad90, angleFacing + rad90, rad10 do
                    local nTheta = normalizeAngle(theta)
                    for r = 1, 3, 1 do
                        local x, y = r * math.cos(nTheta), r * math.sin(nTheta)
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
                        local nTheta = normalizeAngle(theta)
                        for r = 12, 20, 1 do
                            local x, y = r * math.cos(nTheta), r * math.sin(nTheta)
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
            elseif closestIcicle and closestIcicle.distance <= icicleRadius and not AI.HasMoveTo() then
                -- print("icicle above me.");
                local targetToMoveAround = closestIcicle
                -- local targetToMoveAround = fireMage

                -- if closestToastyFire and not AI.HasBuff("toasty fire") then
                --     local rI = math.random(1, #fires)
                --     targetToMoveAround = fires[rI]
                --     -- targetToMoveAround = closestToastyFire
                -- end

                local angleToTarget = AI.CalcFacing(cX, cY, self.centerX, self.centerY)
                if AI.CalcDistance(targetToMoveAround.x, targetToMoveAround.y, self.centerX, self.centerY) >
                    AI.GetDistanceTo(self.centerX, self.centerY) then
                    angleToTarget =
                        AI.CalcFacing(targetToMoveAround.x, targetToMoveAround.y, self.centerX, self.centerY)
                end

                local points = {}
                for theta = angleToTarget - rad120, angleToTarget + rad120, rad5 do
                    local rStart, rEnd = 7.5, 13
                    if targetToMoveAround == closestIcicle then
                        rStart, rEnd = icicleRadius + 1.5, 13
                    end
                    for r = rStart, rEnd, 0.5 do
                        local ntheta = normalizeAngle(theta)
                        local x, y = r * math.cos(ntheta), r * math.sin(ntheta)
                        local nX, nY = targetToMoveAround.x + x, targetToMoveAround.y + y
                        if self.isPointFarEnoughFromTeammates(nX, nY, teamList) and
                            -- self.isPointFarEnoughFromFires(nX, nY, fires) and
                            not self.doesLineIntersectAnyFires(cX, cY, nX, nY, fires) and
                            -- AI.CalcDistance(nX, nY, fireMage.x, fireMage.y) > icicleRadius and
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
                    local angleToTarget = AI.CalcFacing(fireToUse.x, fireToUse.y, self.centerX, self.centerY)

                    for theta = angleToTarget - rad120, angleToTarget + rad120, rad5 do
                        local ntheta = normalizeAngle(theta)
                        for r = icicleRadius + 1, 13, 1 do
                            if theta < 0.0 then
                                theta = theta + pi2
                            elseif theta > pi2 then
                                theta = theta - pi2
                            end
                            local x, y = r * math.cos(ntheta), r * math.sin(ntheta)
                            local nX, nY = fireToUse.x + x, fireToUse.y + y
                            if self.isPointFarEnoughFromTeammates(nX, nY, teamList) and
                                -- self.isPointFarEnoughFromFires(nX, nY, fires) and
                                not self.doesLineIntersectAnyFires(cX, cY, nX, nY, fires) and
                                not self.doesLineIntersectAnyIcicles(cX, cY, nX, nY, icicles) -- and AI.CalcDistance(nX, nY, fireMage.x, fireMage.y) > icicleRadius 
                            then
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
                    print("no toasty fire buff, moving towards it")
                    AI.SetMoveToPosition(p.x, p.y)
                else
                    print("no safe toasty-fire point so moving to tank location")
                    local r = 0.5
                    local facing = AI.CalcFacing(tank.x, tank.y, cX, cY)
                    AI.SetMoveToPosition(tank.x + r * math.cos(facing), tank.y + r * math.sin(facing))
                end
                return false
            elseif not closestSnowpackedIcicle and not closestSnowpackedIcicleTarget and
                (not closestIcicle or closestIcicle.distance > icicleRadius) and not AI.HasMoveTo() then
                if AI.IsDps() and AI.GetDebuffCount("biting cold") <= 3 then
                    if self.stormPowerPlayer and (not AI.HasBuff("storm power") and not AI.HasBuff("storm cloud")) then
                        local stormcloudPlr = AI.GetObjectInfo(self.stormPowerPlayer)
                        if stormcloudPlr and AI.GetDistanceTo(stormcloudPlr.x, stormcloudPlr.y) > 5.5 and
                            not self.doesLineIntersectAnyIcicles(cX, cY, stormcloudPlr.x, stormcloudPlr.y, icicles, nil) then
                            AI.SetMoveTo(stormcloudPlr.x, stormcloudPlr.y)
                            self.isHeadedTowardsStormPlr = true
                            print("moving to storm power plr")
                        end
                    elseif not AI.HasBuff("starlight") and #starlights > 0 and starlights[1].distance <= 15 and
                        self.isPointFarEnoughFromTeammates(starlights[1].x, starlights[1].y, teamList) then
                        print("moving to starlight for buff")
                        AI.SetMoveTo(starlights[1].x, starlights[1].y)
                    end
                end
            end
        end
        return false
    end,
    isPointFarEnoughFromTeammates = function(x, y, teamList)
        for i, o in ipairs(teamList) do
            local tX, tY = AI.GetPosition(o)
            if UnitGUID(o) ~= UnitGUID("player") and AI.CalcDistance(x, y, tX, tY) <= icicleRadius then
                return false
            end
        end
        return true
    end,
    isPointFarEnoughFromFires = function(x, y, fireList)
        for i, o in ipairs(fireList) do
            if AI.CalcDistance(x, y, o.x, o.y) <= icicleRadius then
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
            if AI.DoesLineIntersect(x1, y1, x2, y2, o.x, o.y, 1.5) then
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
            local veesha = AI.FindNearbyUnitsByName("veesha")
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
            return AI.DoTargetChain("saronite animus", "vezax")
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
        local crashes = AI.FindNearbyDynamicObjects("shadow crash")
        if tick > self.lastCrashTime and AI.IsDps() and #crashes > 0 then
            if not AI.HasDebuff("shadow crash") and not AI.HasDebuff("mark of the faceless") and
                not AI.HasMoveToPosition() and not AI.HasObjectAvoidance() then
                local closestCrash = self.findClosestPointInList(crashes)
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

        -- if AI.HasDebuff("mark of the faceless") and not AI.HasMoveTo() then
        --     local spots = {}
        --     local gX, gY = AI.GetPosition("focus")
        --     local closestAlly, distToAlly = AI.GetClosestAlly()
        --     if closestAlly and distToAlly <= 18 then
        --         print("I have mark, moving to avoid allies")
        --         local cX, cY = AI.GetPosition(closestAlly)
        --         local angle = AI.CalcFacing(cX, cY, gX, gY)
        --         local allies = AI.GetRaidOrPartyMemberUnits()
        --         for theta = angle - rad90, angle + rad90, rad5 do
        --             local nTheta = normalizeAngle(theta)
        --             for r = 19, 25, 1 do
        --                 local x, y = r * math.cos(nTheta), r * math.sin(nTheta)
        --                 local nX, nY = cX + x, cY + y
        --                 if self.isFarEnoughFromAllies(nX, nY, allies) then
        --                     table.insert(spots, {
        --                         x = nX,
        --                         y = nY
        --                     })
        --                 end
        --             end
        --         end
        --     end
        --     if #spots > 0 then
        --         local p = self.findClosestPointInList(spots)
        --         AI.SetMoveTo(p.x, p.y)
        --     end
        -- end
    end,
    lastCrashTime = 0,
    animus = false,
    markedPlayer = nil,
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
    end,
    isFarEnoughFromMarkedPlayer = function(self, x, y)
        if self.markedPlayer == nil then
            return true
        end
        local info = AI.GetObjectInfo(self.markedPlayer)
        if info then
            return AI.CalcDistance(x, y, info.x, info.y) > 18
        end
        return true
    end
})

function vezax:SPELL_CAST_START(args)
    if args.spellName:lower() == "searing flames" then
        AI.DoStaggeredInterrupt()
    end
    if args.spellName:lower() == "surge of darkness" then
        AI.Config.startHealOverrideThreshold = 100
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
        local mod = self
        local cX, cY = AI.GetPosition()
        if AI.GetDistanceTo(sX, sY) <= 11 and not AI.IsTank() then
            print("evading shadow crash")
            local allies = AI.GetRaidOrPartyMemberUnits()
            local angle = AI.CalcFacing(sX, sY, gX, gY)
            local points = {}
            if AI.HasDebuff("mark of the faceless") then
                for theta = angle - rad90, angle + rad90, rad5 do
                    local ntheta = normalizeAngle(theta)
                    for r = 13, 40, 1 do
                        local x, y = r * math.cos(ntheta), r * math.sin(ntheta)
                        local nX, nY = sX + x, sY + y
                        if self.isFarEnoughFromAllies(nX, nY, allies) then
                            table.insert(points, {
                                x = nX,
                                y = nY
                            })
                        end
                    end
                end
            else
                for i, theta in ipairs({angle - rad90, angle + rad90}) do
                    local ntheta = normalizeAngle(theta)
                    for r = 13, 20, 1 do
                        local x, y = r * math.cos(ntheta), r * math.sin(ntheta)
                        local nX, nY = sX + x, sY + y
                        if self:isFarEnoughFromMarkedPlayer(nX, nY) then
                            table.insert(points, {
                                x = nX,
                                y = nY
                            })
                        end
                    end
                end
            end

            local p = self.findClosestPointInList(points)
            AI.SetMoveToPosition(p.x, p.y)
        end
    end
end

function vezax:SPELL_AURA_APPLIED(args)
    if args.spellName:lower() == "mark of the faceless" then
        self.markedPlayer = args.target
        if UnitName("player") == args.target then

            local allies = AI.GetRaidOrPartyMemberUnits()
            local obstacles = {}
            for i, a in ipairs(allies) do
                if UnitGUID(a) ~= UnitGUID("player") then
                    local info = AI.GetObjectInfo(a)
                    info.radius = 18
                    table.insert(obstacles, info)
                end
            end
            AI.SetObjectAvoidance({
                guids = obstacles,
                safeDistance = 1,
                gridSize = 5
            })
        end
    end
end

function vezax:SPELL_AURA_REMOVED(args)
    if args.spellName:lower() == "mark of the faceless" then
        self.markedPlayer = nil
        AI.ClearObjectAvoidance()
    end
    if args.spellName:lower() == "surge of darkness" and not self.animus then
        AI.Config.startHealOverrideThreshold = 50
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
            local frostMage = AI.FindNearbyUnitsByName("twilight frost mage")
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
            local frostMage = AI.FindNearbyUnitsByName("twilight frost mage")
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

                if AI.IsMage() and AI.CastSpell("polymorph", "focus") and GetTime() > self.ccCd then
                    self.ccCd = GetTime() + 5
                    return true
                end
            end
        end
    end,
    ccCd = 0
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

        if AI.IsHealer() and self.plasmaTarget then
            if AI.IsShaman() and AI.CastSpell("riptide", self.plasmaTarget) or
                AI.CastSpell("healing wave", self.plasmaTarget) then
                return true
            end
        end

        if AI.IsMage() and not AI.HasMyBuff("fire ward") and AI.CastSpell("fire ward") then
            return true
        end

        if AI.IsHealer() then
            local rocket = AI.FindNearbyUnitsByName("rocket strike")
            if #rocket > 0 and rocket[1].distance <= 3 and rocket[1]:HasAura("64064") and not AI.HasMoveTo() then
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
            print("mimiron spinning up")
            local pi2 = math.pi * 2
            local target = GetObjectInfo("target")
            if target.facing ~= nil then
                local angleBehind = target.facing + math.pi
                angleBehind = normalizeAngle(angleBehind)
                local r = 2
                local x, y = r * math.cos(angleBehind), r * math.sin(angleBehind)
                local nX, nY = target.x + x, target.y + y
                AI.SetMoveToPosition(nX, nY)
            end
        end
    end
end

AI.RegisterBossModule(mimiron)

-- local yoggFightAreaPolygon = {{
--     x = 1988.3841552734,
--     y = 0.81914699077606,
--     z = 325.94177246094
-- }, {
--     x = 2020.4310302734,
--     y = 17.84090423584,
--     z = 329.23315429688
-- }, {
--     x = 2057.8447265625,
--     y = -10.671962738037,
--     z = 332.16909790039
-- }, {
--     x = 2055.03515625,
--     y = -44.346775054932,
--     z = 331.8444519043
-- }, {
--     x = 2015.2801513672,
--     y = -71.150527954102,
--     z = 329.4658203125
-- }, {
--     x = 1992.8668212891,
--     y = -49.949775695801,
--     z = 325.48022460938
-- }, {
--     x = 2009.4018554688,
--     y = -26.272981643677,
--     z = 325.61602783203
-- }}

local yoggFightAreaPolygon = {{
    x = 1977.8753662109,
    y = -52.049556732178,
    z = 324.96905517578
}, {
    x = 1975.8239746094,
    y = -79.036811828613,
    z = 329.15621948242
}, {
    x = 1996.3413085938,
    y = -91.403045654297,
    z = 330.19497680664
}, {
    x = 2019.0654296875,
    y = -68.501243591309,
    z = 328.92037963867
}, {
    x = 2030.5631103516,
    y = -54.842628479004,
    z = 329.00997924805
}, {
    x = 2053.3598632813,
    y = -44.36323928833,
    z = 331.51644897461
}, {
    x = 2059.2114257813,
    y = -15.882532119751,
    z = 332.3782043457
}, {
    x = 2024.7449951172,
    y = 12.82525062561,
    z = 329.33810424805
}, {
    x = 2009.4055175781,
    y = 32.77600479126,
    z = 331.00936889648
}, {
    x = 1990.0318603516,
    y = 24.874994277954,
    z = 329.34487915039
}, {
    x = 1982.5721435547,
    y = 1.5592385530472,
    z = 325.41296386719
}, {
    x = 2004.9440917969,
    y = -20.725526809692,
    z = 325.52200317383
}, {
    x = 1995.4056396484,
    y = -41.379180908203,
    z = 324.88952636719
}}

local yoggSaron = MosDefBossModule:new({
    name = "Yogg-Saron",
    creatureId = {33288, 33134, 33136},
    onStart = function(self)
        local mod = self
        if not AI.IsTank() then
            AI.RegisterOneShotAction(function()
                local cx, cy, cz = AI.GetPosition()
                local path = CalculatePathToDetour(GetCurrentMapID(), AI.PathFinding.Vector3.new(cx, cy, cz),
                    AI.PathFinding.Vector3.new(self.dpsstartx, self.dpsstarty, self.dpsstartz))
                if path and type(path) == "table" then
                    print("moving to starting point")
                    AI.SetMoveToPath(path)
                else
                    print("moving directly to starting point")
                    AI.SetMoveTo(self.dpsstartx, self.dpsstarty)
                end
            end)
        end

        AI.Config.manaTideThreshold = 20

        oldPriorityTargetFn = AI.do_PriorityTarget

        AI.do_PriorityTarget = function()
            if AI.IsValidOffensiveUnit() and
                (AI.HasBuff("shadowy barrier", "target") or
                    (not mod:isDescentTeam() and strcontains("brain", UnitName("target")))) then
                return false
            end

            if mod.phase == 2 then
                if AI.IsTank() then
                    if AI.DoTargetChain("constrictor", "guardian", "corruptor", "tentacle") then
                        return true
                    end
                else
                    if mod:isDescentTeam() then
                        if mod.illusionShattered and mod.usedDescentPortal then
                            TargetUnit("brain")
                            return true

                        end
                        if mod.usedDescentPortal then
                            -- TargetNearestEnemy()
                            return true
                        end
                    end
                    AssistUnit(AI.GetPrimaryTank())
                    return AI.IsValidOffensiveUnit()
                end
            end

            if mod.phase == 3 then
                if UnitName("focus") ~= "Yogg-Saron" then
                    TargetUnit("yogg")
                    FocusUnit("target")
                end

                if not AI.IsTank() then
                    -- AssistUnit(AI.GetPrimaryTank())
                    if not AI.IsChanneling("focus") or (AI.GetDebuffCount("sanity") > 15 and AI.GetUnitHealthPct() > 50) then
                        TargetUnit("focus")
                        return true
                    else
                        if AI.DoTargetChain("tentacle") then
                            return true
                        end
                        AssistUnit(AI.GetPrimaryTank())
                    end
                end
            end
            return false
        end

        AI.PRE_DO_DPS = function(isAoE)
            local tick = GetTime()

            if AI.HasBuff("flash freeze") or AI.HasDebuff("squeeze") or AI.HasDebuff("malady of the mind") then
                return true
            end

            if self.phase == 3 then
                if strcontains(UnitName("target"), "yogg") and AI.GetDebuffCount("sanity") <= 15 and
                    (AI.IsChanneling("target") or math.abs(tick - self.nextLunaticGazeTime) <= 0.5) then
                    return true
                end
            end

            if self.phase == 2 and AI.IsValidOffensiveUnit() and not AI.HasBuff("shadowy barrier", "target") and
                not AI.IsTank() and AI.GetDistanceToUnit("target") > 40 and
                (not self.portalToUse and not self.usedDescentPortal) then
                local x, y, z = AI.GetPosition("target")
                local dist = ternary(AI.IsHealer(), 25, 35)
                if (not AI.IsHealer() or not AI.IsCasting()) and tick > self.lastPathTargetSetTime + 5 then
                    if AI.HasObjectAvoidance() then
                        AI.SetObjectAvoidanceTarget(UnitGUID("target"), dist)
                        self.lastPathTargetSetTime = tick
                    elseif not AI.HasMoveTo() or not AI.IsCurrentPathSafeFromObstacles(self:GetCurrentObstacles()) then
                        self:MoveSafelyToSpotWithin(dist, x, y, z, nil, "to range dps the target")
                        self.lastPathTargetSetTime = tick
                    end
                end
            end

            -- Paladin tank moves in-range to melee attack target
            if AI.IsTank() and AI.AUTO_DPS and AI.IsValidOffensiveUnit() and strcontains(UnitName("target"), "tentacle") and
                AI.GetDistanceToUnit("target") > 5 and tick > self.lastPathTargetSetTime + 5 then
                if AI.HasObjectAvoidance() then
                    AI.SetObjectAvoidanceTarget(UnitGUID("target"), 4.5)
                    self.lastPathTargetSetTime = tick
                elseif not AI.HasMoveTo() or not AI.IsCurrentPathSafeFromObstacles(self:GetCurrentObstacles()) then
                    local x, y, z = AI.GetPosition("target")
                    self:MoveSafelyToSpotWithin(4.5, x, y, z, nil, "to melee attack the target");
                    self.lastPathTargetSetTime = tick
                end
            end

            if self.usedDescentPortal and not self.illusionShattered then
                if AI.IsWarlock() and AI.DoCastSpellChain("target", "corruption") then
                    return true
                end
            end

            if AI.IsValidOffensiveUnit() and strcontains(UnitName("target"), "constrictor") then
                if AI.IsPriest() and AI.DoCastSpellChain("target", "mind blast", "shadow word: death", "mind flay") then
                    return true
                end
                if AI.IsWarlock() and AI.DoCastSpellChain("target", "corruption", "shadow bolt") then
                    return true
                end
                if AI.IsMage() and AI.DoCastSpellChain("target", "fire blast", "scorch") then
                    return true
                end
            end

            return false
        end
    end,
    onEnd = function(self)
        AI.do_PriorityTarget = oldPriorityTargetFn
    end,
    onUpdate = function(self)
        local tick = GetTime()
        if AI.HasBuff("flash freeze") or AI.HasDebuff("squeeze") or AI.HasDebuff("malady of the mind") then
            return true
        end

        if (AI.IsMage() and AI.CleanseRaid("Remove Curse", "Curse")) or
            (AI.IsPriest() and AI.CleanseRaid("Dispel Magic", "Magic")) or
            (AI.IsShaman() and AI.CleanseRaid("Cleanse Spirit", "Curse")) then
            return true
        end

        if AI.IsWarlock() and
            ((not self.illusionShattered and AI.GetUnitHealthPct() < 30) or AI.HasDebuff("sara's blessing")) and
            AI.CastSpell("shadow ward") then
            return true
        end

        -- have priest keep healer free of black plague
        if AI.IsPriest() and self.phase == 2 then
            local healer = AI.GetPrimaryHealer()
            if not AI.HasMyBuff("abolish disease", healer) and AI.HasDebuff("black plague", healer) and
                AI.CastSpell("abolish disease", healer) then
                return true
            end
        end

        if AI.IsShaman() then
            local totems = AI.FindNearbyUnitsByName("grounding totem")
            if not AI.HasMoveTo() and (#totems == 0 or totems[1].distance > 30) and AI.CastSpell("grounding totem") then
                return true
            end
            totems = AI.FindNearbyUnitsByName("cleansing totem")
            if self.phase == 2 and not AI.HasMoveTo() and (#totems == 0 or totems[1].distance > 30) and
                AI.CastSpell("cleansing totem") then
                return true
            end
        end

        -- have paladin self cleanse in p2
        if AI.IsPaladin() and self.phase >= 2 then
            if AI.GetUnitPowerPct() > 20 and AI.CleanseSelf("Cleanse", "Disease", "Magic", "Poison") then
                return true
            end
        end

        if self.phase == 2 then
            local deathorbs = AI.FindNearbyUnitsByName("death orb")
            if #deathorbs == 0 and AI.HasObjectAvoidance() and not self.maladyTarget and not self.usedDescentPortal then
                print("death orbs gone, clearing object avoidance")
                AI.ClearObjectAvoidance()
            end

            if self:isDescentTeam() then
                if self.portalToUse and not self.doesPortalExist(self.portalToUse) then
                    self.portalToUse = nil
                    print("portal to use no longer around")
                    if not AI.HasObjectAvoidance() and AI.HasMoveTo() then
                        AI.ResetMoveTo()
                    elseif AI.HasObjectAvoidance() then
                        AI.ClearObjectAvoidanceTarget()
                    end
                end
                if self.portalToUse then
                    if AI.GetDistanceTo(self.portalToUse.x, self.portalToUse.y) <= 5 and tick > self.squeezeExpireTime +
                        1 then
                        AI.ClearObjectAvoidance()
                        AI.ResetMoveTo()
                        self.portalToUse:InteractWith()
                        self.portalToUse = nil
                        if not self.usedDescentPortal then
                            print("taking brain portal")
                            if AI.IsWarlock() then
                                AI.USE_MANA_REGEN = false
                            end
                            if UnitName("player"):lower() == self.descentDps2 then -- face away from skulls upon teleporting
                                AI.RegisterOneShotAction(function(self)
                                    AI.SetFacing(GetPlayerFacing() + math.pi)
                                    if self.illusionShattered then
                                        print(
                                            "took brain portal after shattered illusion. Moving to brain attack vector")
                                        local brain = AI.FindNearbyUnitsByName("brain of")
                                        if #brain > 0 then
                                            brain[1]:Target()
                                        else
                                            print("could not find/target brain of yogg-saron")
                                        end
                                        local escapePortal = AI.FindNearbyGameObjects("flee to the surface")
                                        if #escapePortal > 0 then
                                            local path = CalculatePathToDetour(GetCurrentMapID(),
                                                AI.PathFinding.Vector3.new(AI.GetPosition()), AI.PathFinding.Vector3
                                                    .new(escapePortal[1].x, escapePortal[1].y, escapePortal[1].z))
                                            if type(path) == "table" and #path > 0 then
                                                print("moving to engage brain of yogg")
                                                AI.SetMoveToPath(path)
                                                AI.UseInventorySlot(8)
                                            else
                                                print("failed to generate path to brain of yogg")
                                            end
                                        else
                                            print("no escape portal found, something is wrong!")
                                        end
                                    end
                                end, 1)
                            end
                            AI.toggleAutoDps(false)
                        else
                            print("taking escape portal")
                            AI.toggleAutoDps(false)
                            self.illusionShattered = false
                            AI.RegisterOneShotAction(function(self)
                                self.lastPathTargetSetTime = 0
                            end, 0.5)
                        end
                        self.usedDescentPortal = (not self.usedDescentPortal)
                    elseif self.usedDescentPortal and not AI.HasMoveTo() then
                        print("moving to escape portal")
                        local path = CalculatePathToDetour(GetCurrentMapID(),
                            AI.PathFinding.Vector3.new(AI.GetPosition()), AI.PathFinding.Vector3
                                .new(self.portalToUse.x, self.portalToUse.y, self.portalToUse.z))
                        if path and type(path) == "table" then
                            AI.SetMoveToPath(path)
                        end
                    elseif not self.usedDescentPortal then
                        -- if we have object avoidance, let the portal as the target goal
                        if AI.HasObjectAvoidance() then
                            AI.SetObjectAvoidanceTarget(self.portalToUse.guid, 1)
                            self.lastPathTargetSetTime = tick
                        elseif not AI.HasMoveTo() or
                            (not AI.IsCurrentPathSafeFromObstacles(self:GetCurrentObstacles()) and tick >
                                self.lastPathGenerateTime) then
                            self:MoveSafelyToSpot(self.portalToUse.x, self.portalToUse.y, self.portalToUse.z, nil,
                                "Get to Brain Portal")
                            self.lastPathGenerateTime = tick + 1
                            self.lastPathTargetSetTime = tick
                        end
                    end
                end
            end

            if self.brainLinkCaster ~= nil and self.brainLinkVictim and UnitName("player") == self.brainLinkCaster and
                not self.portalToUse and not self.usedDescentPortal and not AI.IsHealer() and
                (not self.portalsOpen or
                    (UnitName(self.brainLinkVictim) ~= Unit(self.descentDps2) and UnitName(self.brainLinkVictim) ~=
                        UnitName(self.descentDps1))) then
                if AI.HasObjectAvoidance() then
                    AI.SetObjectAvoidanceTarget(UnitGUID(self.brainLinkVictim), 20)
                    self.lastPathTargetSetTime = tick
                else
                    if AI.GetDistanceToUnit(self.brainLinkVictim) > 20 and
                        (not AI.HasMoveTo() or tick > self.lastPathGenerateTime) then
                        local tx, ty, tz = AI.GetPosition(self.brainLinkVictim)
                        self:MoveSafelyToSpotWithin(20, tx, ty, tz, nil, " moving in-range of brain-link victim")
                        self.lastPathGenerateTime = tick + 0.5
                        self.lastPathTargetSetTime = tick
                    end
                end
            end
            if self.brainLinkVictim ~= nil and self.brainLinkCaster ~= nil and UnitName("player") ==
                self.brainLinkVictim and not self.portalToUse and not self.usedDescentPortal and not AI.IsHealer() and
                (not self.portalsOpen or
                    (UnitName(self.brainLinkCaster) ~= Unit(self.descentDps2) and UnitName(self.brainLinkCaster) ~=
                        UnitName(self.descentDps1))) then
                if AI.HasObjectAvoidance() then
                    AI.SetObjectAvoidanceTarget(UnitGUID(self.brainLinkCaster), 20)
                    self.lastPathTargetSetTime = tick
                else
                    if AI.GetDistanceToUnit(self.brainLinkCaster) > 20 and
                        (not AI.HasMoveTo() or tick > self.lastPathGenerateTime) then
                        local tx, ty, tz = AI.GetPosition(self.brainLinkCaster)
                        self:MoveSafelyToSpotWithin(20, tx, ty, tz, nil, " moving in-range of brain-link caster")
                        self.lastPathGenerateTime = tick + 0.5
                        self.lastPathTargetSetTime = tick
                    end
                end
            end
        elseif self.phase == 3 then
            --- Escaping yogg's brain after phase 3 starts
            if self.usedDescentPortal and self.portalToUse then
                if AI.GetDistanceTo(self.portalToUse.x, self.portalToUse.y) <= 5 then
                    print("taking escape portal due to phase 3")
                    AI.ResetMoveTo()
                    self.portalToUse:InteractWith()
                    self.portalToUse = nil
                    self.usedDescentPortal = false
                    self.illusionShattered = false
                    AI.RegisterOneShotAction(function(self)
                        AI.SetMoveTo(self.p3x, self.p3y, self.p3z)
                    end, 0.5)
                else
                    print("moving to escape portal due to phase 3")
                    local path = CalculatePathToDetour(GetCurrentMapID(), AI.PathFinding.Vector3.new(AI.GetPosition(),
                        AI.PathFinding.Vector3.new(self.portalToUse.x, self.portalToUse.y, self.portalToUse.z)))
                    if path and type(path) == "table" then
                        AI.SetMoveToPath(path)
                    end
                end
            end

            if UnitName("focus") ~= "Yogg-Saron" then
                TargetUnit("yogg")
                FocusUnit("target")
            end

            if ((math.abs(tick - self.nextLunaticGazeTime) <= 0.5) or AI.IsChanneling("focus")) and
                (AI.GetDebuffCount("sanity") <= 15 or AI.GetUnitHealthPct() < 50) and not AI.IsTank() then
                local facing = AI.GetFacingForPosition(AI.GetPosition("focus")) + math.pi
                AI.SetFacing(facing)
            end
        end
        return false
    end,
    phase = 1,
    descentDps1 = "mosdeflocka",
    descentDps2 = "mosdeffmage",
    portalToUse = nil,
    illusionShattered = false,
    usedDescentPortal = false,
    portalsOpen = false,
    lastPathGenerateTime = 0,
    lastPathTargetSetTime = 0,
    squeezeExpireTime = 0,
    centerx = 1980.1986083984,
    centery = -26.137254714966,
    centerz = 324.88958740234,
    dpsstartx = 2010.7935791016,
    dpsstarty = -32.513927459717,
    dpsstartz = 325.5881652832,
    p3x = 2008.7709960938,
    p3y = -34.256763458252,
    p3z = 325.3928527832,
    p3tankx = 2029.5695800781,
    p3tanky = -44.710132598877,
    p3tankz = 328.283203125,
    yoggRadius = 27.0,
    isDescentTeam = function(self)
        return UnitName("player"):lower() == self.descentDps1 or UnitName("player"):lower() == self.descentDps2
    end,
    maladyTarget = nil,
    brainLinkCaster = nil,
    brainLinkVictim = nil,
    doesPortalExist = function(portal)
        local portals = AI.FindNearbyObjectsOfTypeAndName(AI.ObjectTypeFlag.UnitsAndGameObjects, "descend into madness",
            "flee to the surface")
        for i, o in ipairs(portals) do
            if portal.guid == o.guid then
                return true
            end
        end
        return false
    end,
    nextLunaticGazeTime = 0
})

function yoggSaron:GetCurrentObstacles()
    local obstacles = AI.FindNearbyUnitsByName("death orb")
    for i, o in ipairs(obstacles) do
        o.radius = 10
    end
    -- if AI.IsDps() then
    --     local crushers = AI.FindNearbyUnitsByName("crusher")
    --     for i, o in ipairs(crushers) do
    --         o.radius = 6
    --         table.insert(obstacles, o)
    --     end
    -- end
    if self.maladyTarget ~= UnitName("player") and not self.squeezeTarget then
        local maladyOb = AI.GetObjectInfo(self.maladyTarget)
        if maladyOb then
            maladyOb.radius = 13
            table.insert(obstacles, maladyOb)
        end
    end
    return obstacles
end

function yoggSaron:MoveToSanityWell(force)
    if AI.GetDebuffCount("sanity") <= 50 or force then
        local well = AI.FindUnitYWithinXOf("thorim", "sanity well", 50)
        if #well > 0 and AI.GetDistanceTo(well[1].x, well[1].y) > 4 then
            self:MoveSafelyToSpot(well[1].x, well[1].y, well[1].z, "moving to sanity well")
            return true
        end
    end
    return false
end

function yoggSaron:MoveSafelyToSpotWithin(r, tx, ty, tz, force, reason)
    local x, y = AI.GetPosition()
    local facing = AI.CalcFacing(tx, ty, x, y)
    if AI.CalcDistance(x, y, tx, ty) > r then
        local nx, ny = tx + r * math.cos(facing), ty + r * math.sin(facing)
        return self:MoveSafelyToSpot(nx, ny, tz, force, reason)
    else
        AI.StopMoving()
    end
    return true
end

function yoggSaron:MoveSafelyToSpot(tx, ty, tz, force, reason)
    local startp = AI.PathFinding.Vector3.new(AI.GetPosition())
    local endp = AI.PathFinding.Vector3.new(tx, ty, tz)

    local obstacles = self:GetCurrentObstacles()
    local dist = startp:distanceTo(endp)

    local gridSize = 1
    if dist < 20 then
        gridSize = 0.5
    elseif dist > 40 then
        gridSize = 3.0
    end

    ---yogg sitting at the center, avoid him too
    -- table.insert(obstacles, {
    --     x = self.centerx,
    --     y = self.centery,
    --     z = self.centerz,
    --     radius = 22
    -- })

    local path = CalculatePathWhileAvoidingPFP(GetCurrentMapID(), startp, endp, obstacles, gridSize, 200)
    if type(path) == "table" and #path > 0 then
        print("moving safely due to " .. (reason or ""))
        AI.SetMoveToPath(path)
        return true
    else
        print("failed to gen safe path " .. (reason or ""))
        AI.StopMoving()
    end
    return false
end

function yoggSaron:SPELL_CAST_START(args)
    if strcontains(args.spellName, "dark volley") then
        print("dark volley/drain life casting")
        if not AI.IsTank() then
            local guardians = AI.FindNearbyUnitsByName("guardian")
            for i, o in ipairs(guardians) do
                if not o.isDead and (o.castingSpellId or o.channelingSpellId) then
                    o:Target()
                    AI.DoStaggeredInterrupt()
                    return
                end
            end
        end
    end
end

function yoggSaron:CHAT_MSG_MONSTER_YELL(text, monster)
    if strcontains(text, "lucid dream") then
        AI.AUTO_AOE = false
        self.phase = 2
        print("phase 2")
        if AI.IsHealer() then
            AI.toggleAutoDps(true)
        end
        AI.Config.startHealOverrideThreshold = 90
    end

    if strcontains(text, "true face of death") then
        self.phase = 3
        AI.toggleAutoDps(false)
        print("phase 3")
        self.nextLunaticGazeTime = GetTime() + 7
        if self.usedDescentPortal and self.illusionShattered then
            local escapePortal = AI.FindNearbyGameObjects("flee to the surface")
            if #escapePortal > 0 then
                self.portalToUse = escapePortal[1]
            end
        end
        if not self.usedDescentPortal then
            if AI.IsDps() then
                AI.SetMoveTo(self.p3x, self.p3y, self.p3z)
            else
                AI.SetMoveTo(self.p3tankx, self.p3tanky, self.p3tankz);
            end
        end
    end

    if strcontains(text, "tremble") then
        AI.RegisterOneShotAction(function(self)
            if not self.portalToUse and not self.usedDescentPortal then
                print("death rays inbound")
                local obstacles = self:GetCurrentObstacles()
                if #obstacles > 0 then
                    AI.SetObjectAvoidance({
                        guids = obstacles,
                        safeDistance = 3,
                        polygon = yoggFightAreaPolygon
                    })
                end
            end
        end, 2)
    end
end

function yoggSaron:CHAT_MSG_RAID_BOSS_EMOTE(s, t)
    if strcontains(s, "illusion shatters") then
        print("illusion shattered")
        AI.toggleAutoDps(true)
        AI.USE_MANA_REGEN = true
        self.illusionShattered = true
        if self.usedDescentPortal then
            local brain = AI.FindNearbyUnitsByName("brain of")
            if #brain > 0 then
                brain[1]:Target()
            else
                print("could not find/target brain of yogg-saron")
            end
            local escapePortal = AI.FindNearbyGameObjects("flee to the surface")
            if #escapePortal > 0 then
                local path = CalculatePathToDetour(GetCurrentMapID(), AI.PathFinding.Vector3.new(AI.GetPosition()),
                    AI.PathFinding.Vector3.new(escapePortal[1].x, escapePortal[1].y, escapePortal[1].z))
                if type(path) == "table" and #path > 0 then
                    print("moving to engage brain of yogg")
                    AI.SetMoveToPath(path)
                    AI.UseInventorySlot(8)
                else
                    print("failed to generate path to brain of yogg")
                end
            else
                print("no escape portal found, something is wrong!")
            end
        end
    end

    if strcontains(s, "portals open into") then
        self.portalsOpen = true
        self.usedDescentPortal = false
        self.illusionShattered = false
        local mod = self
        AI.RegisterOneShotAction(function(self)
            -- print("portals closed")
            mod.portalsOpen = false
        end, 25, "PORTALS_CLOSED")

        if AI.IsPriest() then
            AI.RegisterPendingAction(function()
                return AI.HasMyBuff("abolish disease", self.descentDps1) or
                           AI.CastSpell("abolish disease", self.descentDps1)
            end, nil, "CLEANSE_DESCENDER_1")
            AI.RegisterPendingAction(function()
                return AI.HasMyBuff("abolish disease", self.descentDps2) or
                           AI.CastSpell("abolish disease", self.descentDps2)
            end, nil, "CLEANSE_DESCENDER_2")

            AI.RegisterPendingAction(function(self)
                local healer = AI.GetPrimaryHealer()
                AI.CastSpell("power word: shield", healer)
                return self.illusionShattered
            end, nil, "BUBBLE_HEALER")
        end

        if self:isDescentTeam() then
            local portals = AI.FindNearbyUnitsByName("descend into madness")
            if #portals == 2 then
                if AI.IsWarlock() then
                    AI.MustCastSpell("shadow ward")
                end
                if strcontains(UnitName("player"), self.descentDps1) then
                    local portal = portals[1]
                    self.portalToUse = portal
                    AI.ResetMoveTo()
                    -- AI.SayRaid("descentDps1 portal set heading to it")
                    if AI.HasObjectAvoidance() then
                        AI.SetObjectAvoidanceTarget(self.portalToUse.guid, 0)
                        self.lastPathTargetSetTime = GetTime()
                    end
                end
                if strcontains(UnitName("player"), self.descentDps2) then
                    AI.RegisterOneShotAction(function(self)
                        local portals = AI.FindNearbyUnitsByName("descend into madness")
                        -- if AI.IsMage() then
                        --     AI.MustCastSpell("mana shield")
                        -- end
                        if #portals > 0 then
                            if #portals == 2 then
                                local dx, dy = AI.GetPosition(self.descentDps1)
                                local dist = 0
                                for i, o in ipairs(portals) do
                                    if AI.CalcDistance(dx, dy, o.x, o.y) > dist then
                                        dist = AI.CalcDistance(dx, dy, o.x, o.y)
                                        self.portalToUse = o
                                    end
                                end
                            else
                                self.portalToUse = portals[1]
                            end
                            AI.ResetMoveTo()
                            -- AI.SayRaid("descentDps2 portal set heading to it")
                            if AI.HasObjectAvoidance() then
                                AI.SetObjectAvoidanceTarget(self.portalToUse.guid, 0)
                                self.lastPathTargetSetTime = GetTime()
                            end
                        else
                            AI.SayRaid("descendDps2 rdy to take portal but no portal found")
                        end
                    end, 10)
                end
            end

            --- Move to escape portals when it's time(3s before induce madness finishes)
            AI.RegisterOneShotAction(function(self)
                if self.phase == 2 and self.usedDescentPortal then
                    print("brain will finish casting Induce Madness in 2s")
                    local escapePortal = AI.FindNearbyGameObjects("flee to the surface")
                    if #escapePortal > 0 then
                        self.portalToUse = escapePortal[1]
                    end
                end
            end, 58, "MOVE_TO_ESCAPE_PORTALS")
        end
        if not self:isDescentTeam() then
            AI.toggleAutoDps(true)
        end
    end

    if strcontains(s, "opens his mouth wide") then
        self.nextLunaticGazeTime = self.nextLunaticGazeTime + 1
    end
end

function yoggSaron:SPELL_AURA_APPLIED(args)
    if args.spellName == "Squeeze" then
        self.squeezeTarget = args.target
        if not self.portalToUse and not self.usedDescentPortal then
            if AI.IsPaladin() and strcontains(UnitName(args.target), AI.GetPrimaryHealer()) and
                AI.GetUnitHealthPct(args.target) <= 50 then
                print("healer has been squeeze, will try bubble")
                AI.MustCastSpell("hand of protection", args.target)
            end
            if AI.IsPriest() and not AI.HasDebuff("weakened soul", args.target) then
                AI.MustCastSpell("power word: shield", args.target)
            end
            TargetUnit("constrictor")
            local x, y, z = AI.GetPosition("target")
            local dist = ternary(AI.IsPaladin(), 4.5, 35)
            if AI.HasObjectAvoidance() then
                AI.SetObjectAvoidanceTarget(UnitGUID("target"), dist)
                self.lastPathTargetSetTime = GetTime()
            else
                self:MoveSafelyToSpotWithin(dist, x, y, z, nil, 'attack constrictor tentacle')
            end
        end
    end

    if strcontains(args.spellName, "malady of the mind") and args.target ~= UnitName("player") then
        if not self.portalToUse and not self.usedDescentPortal then
            self.maladyTarget = args.target
            -- if not AI.IsHealer() then
            print(args.target .. " has been afflicted by malady of the mind, avoiding")
            local obstacles = self:GetCurrentObstacles()
            AI.SetObjectAvoidance({
                guids = obstacles,
                polygon = yoggFightAreaPolygon,
                safeDistance = 3
            })
            -- end
        end
    end

    if strcontains(args.spellName, "brain link") then
        -- print("brain link applied on "..args.target)
        self.brainLinkCaster = args.target
        local allies = AI.GetRaidOrPartyMemberUnits()
        for i, a in ipairs(allies) do
            if UnitGUID(a) ~= UnitGUID(args.target) then
                local info = AI.GetObjectInfo(a)
                if info:HasAura("brain link") then
                    print(args.target .. " is brain linked to " .. UnitName(a))
                    self.brainLinkVictim = UnitName(a)
                    break
                end
            end
        end
    end
end

function yoggSaron:SPELL_AURA_REMOVED(args)
    if args.spellName == "Squeeze" then
        if args.target == UnitName("player") then
            self.squeezeExpireTime = GetTime()
        end
        self.squeezeTarget = nil
    end

    if args.spellName:lower() == "brain link" then
        self.brainLinkCaster = nil
        self.brainLinkVictim = nil
        -- AI.ClearObjectAvoidanceTarget()
    end

    if args.spellName:lower() == "malady of the mind" then
        self.maladyTarget = nil
        if not self.portalToUse and not self.usedDescentPortal then
            local obstacles = self:GetCurrentObstacles()
            if #obstacles == 0 and AI.HasObjectAvoidance() then
                AI.ClearObjectAvoidance()
            elseif not AI.HasObjectAvoidance() then
                AI.SetObjectAvoidance({
                    guids = obstacles,
                    polygon = yoggFightAreaPolygon,
                    safeDistance = 3
                })
            end
            if args.target == UnitName("player") then
                local healer = AI.GetPrimaryHealer()
                local closestAlly, dist = AI.GetClosestAlly(function(ally)
                    return UnitName(ally) ~= UnitName(self.descentDps1) and UnitName(ally) ~= UnitName(self.descentDps2)
                end)
                local targetToMoveTo = healer
                if AI.IsHealer() then
                    targetToMoveTo = closestAlly
                end
                local x, y, z = AI.GetPosition(targetToMoveTo)
                if AI.HasObjectAvoidance() then
                    AI.SetObjectAvoidanceTarget(UnitGUID(targetToMoveTo), 15)
                    self.lastPathTargetSetTime = GetTime()
                else
                    AI.RegisterPendingAction(function(self)
                        return self:MoveSafelyToSpotWithin(15, x, y, z, nil, "moving closer to ally")
                    end)
                end
            end
        end
    end
end

function yoggSaron:SPELL_CAST_SUCCESS(args)
    local time = GetTime()
    if args.spellName:lower() == "lunatic gaze" and not self.usedDescentPortal then
        if UnitName("focus") ~= "Yogg-Saron" then
            TargetUnit("yogg")
            FocusUnit("target")
        end
        if AI.GetDebuffCount("sanity") <= 15 or AI.GetUnitHealthPct() < 50 then
            local facing = AI.GetFacingForPosition(AI.GetPosition("focus")) + math.pi
            AI.SetFacing(facing)
        end
        self.nextLunaticGazeTime = time + 12
        -- print("lunatic gaze now:"..time.." Next  Cast:"..self.nextLunaticGazeTime)
    end
end

function yoggSaron:SPELL_DAMAGE(args)
    if args.spellName == "Brain Link" then
        self.brainLinkCaster = args.caster
        if args.caster ~= args.target then
            self.brainLinkVictim = args.target
        end
        -- print("brainlink caster:" .. args.caster .. " target:" .. args.target)
    end

    if args.spellName == "Erupt" then
        -- print("constrictor erupted on " .. args.target)
        if not self.portalToUse and not self.usedDescentPortal then
            TargetUnit("constrictor")
            local x, y, z = AI.GetPosition("target")
            local dist = ternary(AI.IsPaladin(), 4.5, 35)
            if AI.HasObjectAvoidance() then
                AI.SetObjectAvoidanceTarget(UnitGUID("target"), dist)
                self.lastPathTargetSetTime = GetTime()
            else
                self:MoveSafelyToSpotWithin(dist, x, y, z, nil, 'attack constrictor tentacle')
            end
        end
    end
end

AI.RegisterBossModule(yoggSaron)

local algalon = MosDefBossModule:new({
    name = "Algalon The Observer",
    creatureId = {32871},
    onStart = function(self)
    end,
    onEnd = function(self)
    end,
    onUpdate = function(self)
    end
})

function algalon:GetBlackHoles()
    local bHoles = AI.FindNearbyUnitsByName("black hole")
    if #bHoles > 0 then
        return bHoles
    end
    return nil
end

function algalon:GetDarkMatters()
    local darkMatters = AI.FindNearbyUnitsByName("unleashed dark matter")
    if #darkMatters > 0 then
        return darkMatters
    end
    return nil
end

function algalon:SPELL_CAST_START(args)
    if strcontains(args.spellName, "big bang") then
        print("Algalon casting big bang")

        if AI.IsPriest() and AI.CanCastSpell("dispersion", "player", true) then
            AI.RegisterOneShotAction(function()
                print('tanking big bang with dispersion')
                AI.MustCastSpell("dispersion")
            end, 5)
        elseif not AI.IsTank() then
            AI.RegisterPendingAction(function(self)
                if not AI.IsCasting() then
                    local holes = self:GetBlackHoles()
                    if #holes > 0 then
                        print('moving into black hole')
                        AI.SetMoveTo(holes[1].x, holes[1].y, holes[1].z, 1)
                    end
                end
                return false
            end)
        end
    end
end

AI.RegisterBossModule(algalon)
