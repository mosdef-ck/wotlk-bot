local oldPriorityTargetFn = nil
local oldPreDpsFn = nil
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

-- ulduar
local ulduar = MosdefZoneModule:new({
    zoneName = "Ulduar",
    zoneId = 530,
    onEnter = function(self)
        AI.PRE_DO_DPS = function(isAoE)
            if AI.IsInVehicle() then
                if AI.IsValidOffensiveUnit() and not AI.HasMoveTo() then
                    if AI.ALLOW_AUTO_REFACE then
                        AI.SetFacingUnit("target")
                    end
                elseif not AI.IsValidOffensiveUnit() then
                    local vehicle = (UnitName("playerpet") or ""):lower()
                    local angle = 0.35212010
                    if vehicle == "salvaged siege turret" then
                        angle = 0.25119984
                    end
                    VehicleAimRequestNormAngle(angle)
                    if not AI.IsTank() then
                        local tankPet = AI.GetObjectInfo(AI.GetPrimaryTank() .. "-pet")
                        if tankPet and tankPet.facing then
                            AI.SetFacing(tankPet.facing)
                        end
                    end
                end

                local vehicle = (UnitName("playerpet") or ""):lower()
                if strcontains(vehicle, "salvaged siege turret") then
                    AI.CastVehicleSpellOnDestination("fire cannon", "target")
                    -- AI.CastVehicleSpellOnDestination("anti-air rocket", "target")
                    -- AI.UsePossessionSpell("fire cannon")
                end
                if strcontains(vehicle, "salvaged siege engine") and AI.IsValidOffensiveUnit() and
                    AI.GetDistanceTo("target") <= 3 then
                    -- AI.UsePossessionSpell("ram")
                end
                if vehicle == "salvaged demolisher" then
                    if UnitPower("playerpet") <= 40 then
                        local pyrite = AI.FindNearbyUnitsByName("liquid pyrite")
                        if #pyrite > 0 and pyrite[1].distance <= 40 then
                            if AI.CastVehicleSpellOnTarget("grab crate", pyrite[1].guid) then
                                -- print("grabbing pyrite")
                                return true
                            end
                        end
                    end
                    if UnitPower("playerpet") > 10 and AI.IsValidOffensiveUnit() and AI.GetTargetStrength() > 3 and
                        (AI.GetDebuffCount("blue pyrite", "target") < 10 or
                            AI.GetDebuffDuration("blue pyrite", "target") <= 2) then
                        -- AI.UsePossessionSpell("hurl pyrite barrel")
                        AI.CastVehicleSpellOnDestination("hurl pyrite barrel", "target")
                    end
                    AI.CastVehicleSpellOnDestination("hurl boulder", "target")
                    -- AI.UsePossessionSpell("hurl boulder")

                end
                if vehicle == "salvaged demolisher mechanic seat" then
                    local closestLift = nil
                    if UnitPower("playerpet") <= 40 then
                        local lifts = AI.FindNearbyUnitsByName(33214)
                        local closestLift = nil
                        for i, o in ipairs(lifts) do
                            if not o.isDead and o.distance <= 70 and o.isAttackable then
                                closestLift = o
                                break
                            end
                        end
                    end
                    -- VehicleAimRequestNormAngle(0.2037674)
                    -- AI.SetDesiredAimAngle(0.2037674)
                    -- AI.UsePossessionSpell("anti-air rocket")
                    AI.CastVehicleSpellOnDestination("anti-air rocket", closestLift and closestLift or "target")
                    AI.CastVehicleSpellOnDestination("mortar", "target")
                end

                if vehicle == "salvaged chopper" and AI.GetDistanceToUnit("target") <= 30 then
                    AI.UsePossessionSpell("sonic horn")
                    AI.UsePossessionSpell("tar")
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
            if not strcontains(UnitName("target"), "iron mender") then
                AI.DoTargetChain("iron mender")
                -- TargetUnit("iron mender")
            end
            local nearbyMender = AI.FindUnitYWithinXOf("target", "iron mender", 50)
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
                if o.raidTargetIndex and not o.isDead and not AI.IsUnitCC(o) and not o:HasAura("polymorph") then
                    markedMender = o
                end
            end
            if markedMender and markedMender.guid ~= UnitGUID("target") then
                markedMender:Focus()
                if AI.IsShaman() and AI.IsSpellInRange("hex", "focus") then
                    return AI.CastSpell("hex", "focus")
                end
                if AI.IsMage() and AI.IsSpellInRange("polymorph", "focus") then
                    return AI.CastSpell("polymorph", "focus")
                end
                if AI.IsWarlock() then
                    AI.RegisterOneShotAction(function()
                        if not markedMender.isDead and not AI.IsUnitCC(markedMender) and
                            AI.IsSpellInRange("fear", "focus") then
                            return AI.CastSpell("fear", "focus")
                        end
                    end, 4, "CC_IRON_MENDER")
                end
            end
        end
        return false
    end
})

function ironMender:SPELL_CAST_START(args)
    if strcontains(args.spellName, "electro") then
        print("electro shock coming")
        TargetUnit(args.caster)
        AI.DoStaggeredInterrupt()
    end
end
AI.RegisterBossModule(ironMender)

local chamberOverseer = MosDefBossModule:new({
    name = "Chamber Overseer",
    creatureId = {34197},
    onStart = function(self)
        AI.Config.startHealOverrideThreshold = 90
    end,
    onEnd = function(self)
        AI.Config.startHealOverrideThreshold = 100
    end
})
AI.RegisterBossModule(chamberOverseer)

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
        AI.FocusUnit("flame leviathan")
        oldPreDpsFn = AI.PRE_DO_DPS
        AI.PRE_DO_DPS = function(isAoE)
            AI.FocusUnit("flame leviathan")
            return oldPreDpsFn(isAoE)
        end
    end,
    onStop = function(self)
        self.pursuedTarget = nil
        AI.PRE_DO_DPS = oldPreDpsFn
    end,
    onUpdate = function(self)
        -- run from leviathan if we're being pursued
        if AI.IsInVehicle() then
            AI.FocusUnit("flame leviathan")
            -- AI.ALLOW_AUTO_REFACE = not self:IsMyVehiclePursued() or not self:AmIDriver()
            AI.ALLOW_AUTO_REFACE = false

            local vehicle = (UnitName("playerpet") or ""):lower()
            if AI.HasDebuff("pursued", "playerpet") and self.pursuedTarget ~= vehicle then
                -- broadcast to other bots in raid that we're being pursued
                AI.SendAddonMessage("i-am-pursued", vehicle)
            else
                local target = AI.GetObjectInfo("focustarget")
                if AI.IsTank() and target and self.pursuedTarget ~= target.name:lower() then
                    AI.SendAddonMessage("i-am-pursued", target.name:lower())
                end
            end

            local flameLeviathan = AI.FindNearbyUnitsByName(33113)[1]
            local pX, pY = AI.GetPosition("playerpet")
            local distToLeviathan = flameLeviathan.distance
            -- print(vehicle .. " dist to leviathan: " .. distToLeviathan)
            if vehicle ~= "salvaged demolisher" and self:IsMyVehiclePursued() and self:AmIDriver() and
                not AI.HasMoveTo() and distToLeviathan <= 50 then
                local points = {}
                local facing = AI.CalcFacing(self.centerX, self.centerY, pX, pY)
                for theta = facing, facing + pi2, rad5 do
                    local nX = self.centerX + self.r * math.cos(theta)
                    local nY = self.centerY + self.r * math.sin(theta)
                    if not AI.DoesLineIntersect(pX, pY, nX, nY, flameLeviathan.x, flameLeviathan.y, 40) then
                        table.insert(points, {
                            x = nX,
                            y = nY
                        })
                    end
                end
                print("leviathan too close")
                local p = findClosestPointInList(points)
                if p then
                    print("evading leviathan")
                    AI.SetMoveTo(p.x, p.y)
                end
            end

            if self.pursuedTarget and self:IsMyVehiclePursued() then
                if AI.HasMoveTo() and AI.IsFacingTowardsDestination() and AI.FindPossessionSpellSlot("steam rush") and
                    AI.UsePossessionSpell("steam rush") then
                    return true
                end

                if AI.FindPossessionSpellSlot("increased speed") and not self.hasIncreasedSpeed and
                    AI.UsePossessionSpell("increased speed") then
                    return true
                end
                if self:IsMyVehiclePursued() and AI.FindPossessionSpellSlot("tar") and AI.UsePossessionSpell("tar") then
                    return true
                end
            end
            return false
        end
    end,
    pursuedTarget = nil,
    lastGrabTime = 0,
    centerX = 274.53591918945,
    centerY = -30.948907852173,
    r = 100,
    hasIncreasedSpeed = false
})

function flameLeviathan:CHAT_MSG_RAID_BOSS_EMOTE(s, t)
    -- print("flame leviathan emote: " .. s)
    -- if strcontains(s, "pursues") then
    --     local target = string.match(s, "pursues ([%w]+)")
    --     -- print("extracted target from emote: " .. (target or "N/A"))
    --     if target then
    --         self.pursuedTarget = UnitName(target .. "-pet"):lower()
    --         print("Vehicle " .. self.pursuedTarget .. " is being pursued from emote")
    --     end
    -- end
end

-- function flameLeviathan:SPELL_CAST_SUCCESS(args)
--     if AI.IsInVehicle() and args.spellId == 62374 then
--         local target = args.target:lower()
--         self.pursuedTarget = target
--         print("Vehicle " .. target .. " is being pursued")

--     end
-- end

function flameLeviathan:SPELL_AURA_APPLIED(args)
    -- if AI.IsInVehicle() then
    --     if args.spellName:lower() == "pursued" then
    --         local target = args.target:lower()
    --         self.pursuedTarget = target
    --         print("vehicle " .. self.pursuedTarget .. " is being pursued by aura")
    --     end
    -- end
    if args.spellName:lower() == "increased speed" then
        self.hasIncreasedSpeed = true
        print("increased speed active")
    end
end

function flameLeviathan:SPELL_AURA_REMOVED(args)
    if args.spellName:lower() == "increased speed" then
        self.hasIncreasedSpeed = false
        print("increased speed removed")
    end
end

function flameLeviathan:SPELL_DAMAGE(args)
    if AI.IsInVehicle() then
        if args.spellName:lower() == "flame vents" or args.spellName:lower() == "battering ram" then
            local vehicle = UnitName("playerpet"):lower()
            local target = args.target:lower()
            if (strcontains(target, "demolisher") and strcontains(vehicle, "demolisher")) or
                (strcontains(target, "siege") and strcontains(vehicle, "siege")) then
                if AI.FindPossessionSpellSlot("shield generator") then
                    AI.RegisterPendingAction(function(self)
                        return AI.UsePossessionSpell("shield generator")
                    end)
                end
            end
        end
    end
end

function flameLeviathan:IsMyVehiclePursued()
    if not AI.IsInVehicle() then
        return false
    end
    local vehicle = UnitName("playerpet"):lower()
    if not self.pursuedTarget then
        return false
    end
    if strcontains(self.pursuedTarget, "siege") and strcontains(vehicle, "siege") then
        return true
    end
    if strcontains(self.pursuedTarget, "demolisher") and strcontains(vehicle, "demolisher") then
        return true
    end
    if strcontains(self.pursuedTarget, "chopper") and strcontains(vehicle, "chopper") then
        return true
    end
    return false
end

function flameLeviathan:AmIDriver()
    if not AI.IsInVehicle() then
        return false
    end
    local vehicle = UnitName("playerpet"):lower()
    if vehicle == "salvaged siege engine" or vehicle == "salvaged demolisher" or vehicle == "salvaged chopper" then
        return true
    end

    return false
end

function flameLeviathan:ON_ADDON_MESSAGE(from, cmd, args)
    if cmd == "i-am-pursued" and args and self.pursuedTarget ~= args:lower() then
        self.pursuedTarget = args:lower()
        print("vehicle " .. self.pursuedTarget .. " is being pursued from addon message")
    end
end

AI.RegisterBossModule(flameLeviathan)

-- ignis

local ignis = MosDefBossModule:new({
    name = "Ignis The Furnace Master",
    creatureId = {33118},
    onStart = function(self)
        AI.FocusUnit("ignis")
        if AI.IsDps() then
            AI.SetMoveTo(self.dpsX, self.dpsY)
        end
        AI.useHealingWaveOnToons = true
        if AI.IsHeroicRaidOrDungeon() and not AI.HasBuff("lesser flask of resistance") and not AI.IsTank() then
            AI.UseContainerItem("lesser flask of resistance")
        end
    end,
    onStop = function(self)
        self.slaggedTarget = nil
        AI.useHealingWaveOnToons = false
    end,
    onUpdate = function(self)
        if AI.IsDps() and AI.IsValidOffensiveUnit("target") and AI.HasDebuff("Brittle", "target") then
            if AI.IsWarlock() then
                AI.CastSpell("Searing Pain", "target")
                return true
            end
            if AI.IsPriest() then
                AI.DoCastSpellChain("mind blast", "shadow word: death", "mind flay")
                return true
            end
            if AI.IsShaman() and AI.CastSpell("lightning bolt", "target") then
                return true
            end

            if AI.IsMage() then
                AI.CastSpell("ice lance", "target")
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

        if AI.IsHealer() and self.slaggedTarget ~= nil and AI.GetUnitHealthPct(self.slaggedTarget) <= 70 and
            AI.CastSpell("healing wave", self.slaggedTarget) then
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
        print("slag pot applied to " .. args.target)
        self.slaggedTarget = args.target
        if args.target == UnitName("player") then
            AI.DISABLE_CDS = true
            if AI.IsWarlock() then
                AI.RegisterPendingAction(function()
                    return AI.CastSpell("demonic circle: teleport")
                end, 2)
            end
            if AI.IsMage() then
                AI.RegisterPendingAction(function()
                    if not AI.HasDebuff("slag pot") then
                        return true
                    end
                    local hx, hy = AI.GetPosition(AI.GetPrimaryHealer())
                    local ignis = AI.FindNearbyUnitsByName("ignis")[1]
                    local facing = ignis.facing
                    local success = false
                    if AI.IsPointWithinCone(hx, hy, ignis.x, ignis.y, facing, rad90) then
                        success = AI.CastSpell("blink")
                        if success then
                            AI.SetMoveTo(self.dpsX, self.dpsY)
                        end
                    end
                    return success
                end, 2)
            end
            if AI.IsPriest() and AI.CanCastSpell("dispersion") then
                AI.RegisterPendingAction(function()
                    if not AI.HasDebuff("slag pot") then
                        return true
                    end
                    return AI.CastSpell("dispersion")
                end, 2)
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
            AI.SetMoveTo(self.healerP.x, self.healerP.y)
        end

        self.nextRightArmTargetTime = GetTime() + 25
        local mod = self
        AI.FocusUnit("kologarn")

        oldPriorityTargetFn = AI.do_PriorityTarget
        AI.do_PriorityTarget = function(self)
            local time = GetTime()
            if time >= mod.nextRightArmTargetTime and AI.GetUnitHealthPct("focus") >= 10 then
                TargetUnit("right arm")
                return AI.IsValidOffensiveUnit()
            end
            return false
        end
        if AI.IsHeroicRaidOrDungeon() and not AI.HasBuff("lesser flask of resistance") and not AI.IsTank() then
            AI.UseContainerItem("lesser flask of resistance")
        end
        AI.useHealingWaveOnToons = true
        AI.Config.startHealOverrideThreshold = 80
    end,
    onStop = function(self)
        AI.do_PriorityTarget = oldPriorityTargetFn
        AI.useHealingWaveOnToons = false
    end,
    onUpdate = function(self)
        if AI.IsUnitValidFriendlyTarget(self.gripTarget) then
            local hpct = AI.GetUnitHealthPct(self.gripTarget)
            -- print("kolo grip target " .. self.gripTarget .. " hpct: " .. hpct)
            if AI.IsHealer() and UnitHealth(self.gripTarget) <= 20000 and ((AI.HasBuff("tidal waves") and AI.CastSpell("healing wave", self.gripTarget)) or AI.CastSpell("chain heal", self.gripTarget)) then
                print("healing kolo grip target " .. self.gripTarget)
                return true
            end
            if AI.IsTank() and hpct <= 20 and AI.CastSpell("hand of protection", self.gripTarget) then
                print("casting hand of protection on kolo grip target " .. self.gripTarget)
                return true
            end
            if AI.IsPriest() and self.gripTarget and not AI.HasDebuff("weakened soul", self.gripTarget) and
                AI.CastSpell("power word: shield", self.gripTarget) then
                return true
            end
        end

        if AI.IsWarlock() and not AI.HasBuff("demonic circle: summon") and AI.CastSpell("demonic circle: summon") then
            return true
        end

        if AI.IsDps() then
            local eyebeam = AI.FindNearbyUnitsByName("eyebeam")
            if #eyebeam > 0 then
                local x, y = AI.GetPosition("player")
                if GetTime() > self.eyeEvadeTime then
                    local eyeFacing = eyebeam[1].facing
                    if (eyebeam[1].distance <= 5 -- and diff <= 0.5
                    and AI.IsPointWithinCone(x, y, eyebeam[1].x, eyebeam[1].y, eyeFacing, rad5)) and
                        not AI.HasMoveToPosition() then
                        if AI.IsDpsPosition(1) then
                            AI.SetMoveToPosition(self.dps1evadeX, self.dps1evadeY)
                        elseif AI.IsDpsPosition(2) then
                            AI.SetMoveToPosition(self.dps2evadeX, self.dps2evadeY)
                        elseif AI.IsDpsPosition(3) then
                            AI.SetMoveToPosition(self.dps3evadeX, self.dps3evadeY)
                        end
                        AI.DISABLE_CDS = true
                        self.eyeEvadeTime = GetTime() + 10
                    end
                end
            elseif self.gripTarget == nil and not AI.HasMoveToPosition() then
                if AI.IsDpsPosition(1) and AI.GetDistanceTo(self.dps1x, self.dps1y) > 2 and not AI.IsCasting() then
                    AI.SetMoveToPosition(self.dps1x, self.dps1y)
                elseif AI.IsDpsPosition(2) and AI.GetDistanceTo(self.dps2x, self.dps2y) > 2 and not AI.IsCasting() then
                    AI.SetMoveToPosition(self.dps2x, self.dps2y)
                elseif AI.IsDpsPosition(3) and AI.GetDistanceTo(self.dps3x, self.dps3y) > 2 and not AI.IsCasting() then
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
    dps1x = 1767.3546142578,
    dps1y = -3.7860882282257,
    dps2x = 1783.7899169922,
    dps2y = -3.9541857242584,
    dps3x = 1767.5830078125,
    dps3y = -20.168651580811,
    -- healerx = 1775.3013916016,
    -- healery = -12.071847915649,
    eyeEvadeTime = 0,

    dps1evadeX = 1751.0971679688,
    dps1evadeY = -4.2991757392883,
    dps2evadeX = 1767.8189697266,
    dps2evadeY = 9.3519926071167,
    dps3evadeX = 1767.7554931641,
    dps3evadeY = -45.019351959229,
    healerP = AI.PathFinding.Vector3.new(1775.3013916016, -12.071847915649, 448.80682373047)
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
        print("stone grip applied to " .. args.target)
        TargetUnit("right arm")
        if UnitName("player") == args.target then
            AI.DISABLE_CDS = true
            AI.ResetMoveTo()
        end
        if AI.IsHealer() then
            AI.MustCastSpell("riptide", args.target)
        end
    end
    if args.spellName:lower() == "overhead smash" and AI.IsHeroicRaidOrDungeon() and AI.IsTank() and
        AI.GetUnitHealthPct("player") < 70 then
        if AI.CanCastSpell("hand of salvation", "player", true) then
            AI.MustCastSpell("hand of salvation", "player", true)
        elseif AI.CanCastSpell("divine protection", "player", true) then
            AI.MustCastSpell("divine protection", "player", true)
        end
    end
end

function kologarn:SPELL_AURA_REMOVED(args)
    if args.spellName:lower() == "stone grip" then
        print("stone grip removed from " .. args.target)
        TargetUnit("kologarn")
        AI.DISABLE_CDS = false
        self.gripTarget = nil
        self.nextRightArmTargetTime = GetTime() + 20
        if args.target == UnitName("player") then
            -- self.eyeEvadeTime = GetTime() + 10
            local mod = self
            AI.RegisterOneShotAction(function()
                if AI.IsDpsPosition(1) then
                    AI.SetMoveToPosition(mod.dps1x, mod.dps1y)
                end
                if AI.IsDpsPosition(2) then
                    if AI.HasBuff("demonic circle: summon") and AI.CastSpell("demonic circle: teleport") then
                        return true
                    else
                        AI.SetMoveToPosition(mod.dps2x, mod.dps2y)
                    end
                end
                if AI.IsDpsPosition(3) then
                    AI.SetMoveToPosition(mod.dps3x, mod.dps3y)
                end
                return true
            end, 0.5, "MOVE_BACK_TO_POSITION")
        end
    end
end

function kologarn:SMSG_SPELL_CAST_GO2(args)
    if args.spellId == 64753 then
        -- print("arm respawned " .. (args.caster or "N/A"))
        self.nextRightArmTargetTime = GetTime() + 30
    end
    if (strcontains(args.spellName, "overhead smash tremor") or strcontains(args.spellName, "overhead smash")) and
        AI.IsCasting() then
        print("stopping casting to prevent silence")
        AI.StopCasting()
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
    end,
    startx = 585.35375976563,
    starty = -134.66996765137,    
    fightx = 586.56292724609,
    fighty = -172.1799621582,
    fightP = AI.PathFinding.Vector3.new(581.09814453125, -162.14776611328, 391.51715087891),
    dps1x = 601.53082275391,
    dps1y = -148.0544128418,
    dps2x = 591.90020751953,
    dps2y = -144.25395202637,
    healerx = 581.53515625,
    healery = -144.49114990234,
    dps3x = 573.20922851563,
    dps3y = -145.37928771973,
})

function razorscale:moveToSafeSpot(dest)
    print("moving to safe spot")
    local flames = AI.FindNearbyUnitsByName(34188, "devouring flame stalker")
    if dest then
        table.insert(flames, {
            x = dest.x,
            y = dest.y,
            z = dest.z,
            radius = 9
        })
    end
    if #flames > 0 and not AI.HasMoveTo() then
        print("devouring flame on me, moving out")
        local p = AI.PathFinding.FindSafeSpotWithinRadiusCorridor({
            x = self.fightx,
            y = self.fighty,
            z = dest.z
        }, 10, 40, flames, 5)
        if p then
            AI.SetMoveTo(p.x, p.y)
        else
            AI.SetMoveTo(self.startx, self.starty)
        end
    end
end

function razorscale:CHAT_MSG_MONSTER_YELL(s, t) 
    if strcontains(s, "grounded") then
        if not AI.IsTank() then
            local flames = AI.FindNearbyUnitsByName(34188, "devouring flame stalker")
            local p = AI.PathFinding.FindSafeSpotInCircle(AI.PathFinding.Vector3.new(AI.GetPosition(AI.GetPrimaryTank())), 15, flames, 1)
            if p then
                AI.SetMoveTo(p.x, p.y)

            else
                AI.SetMoveToPosition(self.fightx, self.fighty)
            end
        end
    end
end

function razorscale:CHAT_MSG_RAID_BOSS_EMOTE(s, t)
    if strcontains(s, "deep breath") then
        if not AI.IsTank() then
            local tX, tY = AI.GetPosition(AI.GetPrimaryTank())
            AI.SetMoveTo(tX, tY)
        end
    end
end

function razorscale:SMSG_SPELL_CAST_GO2(args)
    if args.spellId == 63236 then
        print("devouring flame incoming at " .. (args.dest and (args.dest.x .. ", " .. args.dest.y) or "N/A"))
        if not AI.IsTank() and AI.GetDistanceTo(args.dest.x, args.dest.y) <= 9 then
            self:moveToSafeSpot(args.dest)
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
            -- if not AI.HasMyDebuff("curse of the elements", "focus") and GetTime() > self.lastScreechTime + 3 and
            --     AI.CastSpell("curse of the elements", "focus") then
            --     return true
            -- end
        end

    end,
    startx = nil,
    starty = nil,
    lastScreechTime = 0
})

function auriaya:SPELL_AURA_REMOVED(args)
    if args.spellName == "Terrifying Screech" and args.target == UnitName("player") then
        AI.FocusUnit("auriaya")
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
                if AI.IsHealer() and AI.GetUnitHealthPct(AI.GetPrimaryTank()) <= 50 then
                    return false
                end
                AI.SetMoveTo(mod.startx, mod.starty)
                return true
            end, 1, "MOVE_BACK_TO_START")

        end
    end
end

function auriaya:UNIT_SPELLCAST_START(caster, spellName)
    if spellName:lower() == "sentinel blast" then
        AI.FocusUnit("auriaya")
        AI.DoStaggeredInterrupt()
    end

    if spellName:lower() == "terrifying screech" then
        self.lastScreechTime = GetTime()
        if AI.IsWarlock() then
            AI.MustCastSpell("curse of tongues", "focus")
        end
    end
end

AI.RegisterBossModule(auriaya)

local xtMobs = MosDefBossModule:new({
    name = "xt-002 deconstructor mobs",
    creatureId = {34269, 34273, 34267, 34271},
    onStart = function(self)
    end,
    onStop = function(self)
    end,
    onUpdate = function(self)
    end
})

function xtMobs:SPELL_CAST_START(args)
    if strcontains(args.spellName, "matrix") then
        -- print("defense matrix incoming")
        if AI.IsDps() then
            local delay = 0
            if AI.IsDpsPosition(2) then
                delay = 0.5
            elseif AI.IsDpsPosition(3) then
                delay = 1
            end
            AI.RegisterOneShotAction(function()
                AI.StopCasting()
                TargetUnit(args.caster)
                if AI.IsCasting("target") and AI.UseInventorySlot(6) or AI.UseContainerItem("saronite bomb") then
                    CastCursorAOESpell(AI.GetPosition("target"))
                end
            end, delay)
        end
    end
end
AI.RegisterBossModule(xtMobs)

-- xt
local xt = MosDefBossModule:new({
    name = "xt-002 deconstructor",
    creatureId = {33293},
    onStart = function(self)
        AI.Config.starFormationRadius = 17
    end,
    onStop = function(self)
    end,
    onUpdate = function(self)
    end
})

function xt:SPELL_AURA_APPLIED(args)
    if args.spellName == "Gravity Bomb" or args.spellName == "Searing Light" then
        if AI.IsHeroicRaidOrDungeon() and AI.IsPriest() and not AI.HasDebuff("weakened soul", args.target) then
            AI.MustCastSpell("power word: shield", args.target)
        end
    end
end

AI.RegisterBossModule(xt)

-- assembly of iron
local assemblyOfIron = MosDefBossModule:new({
    name = "Assembly of Iron",
    creatureId = {32867, 32857, 32927},
    onStart = function(self)
        AI.DISABLE_DRAIN = true
        if AI.IsHealer() then
            AI.AUTO_CLEANSE = false
        end
        -- if AI.IsDps() then
        --     AI.FocusUnit("brundir")
        -- end
        AI.do_PriorityTarget = function()
            if AI.IsTank() then
                TargetUnit("steelbreaker")
                return true
            else
                if self:IsBrundirActive() then
                    TargetUnit("stormcaller brundir")
                    return AI.IsValidOffensiveUnit()
                elseif self:IsMolgeimActive() then
                    TargetUnit("runemaster molgeim")
                    return AI.IsValidOffensiveUnit()
                end
            end
            return false
        end
        AI.PRE_DO_DPS = function(isAoe)
            -- local tick = GetTime()
            -- if AI.IsDps() and AI.IsValidOffensiveUnit() then
            --     if AI.GetDistanceToUnit("target") > 40 and not self.tendrilsActive and not AI.HasMoveTo() and tick >
            --         self.lastOverloadTime + 7 then
            --         local obstacles = self:GetRunesOfDeath()
            --         local p = AI.PathFinding.FindSafeSpotInCircle("target", 35, obstacles)
            --         if p then
            --             AI.PathFinding.MoveSafelyTo(p, obstacles)
            --         end
            --     end
            -- end
            return false
        end
    end,
    onStop = function(self)
        AI.PRE_DO_DPS = nil
    end,
    onUpdate = function(self)
        local tick = GetTime()
        local deathRunes = self:GetRunesOfDeath()
        local brundir = AI.FindNearbyUnitsByName("brundir")
        if self:IsBrundirActive() then
            local brundirObj = brundir[1]
            if not brundirObj:IsCasting() and brundir[1].targetGUID ~= self.lastBrundirTarget then
                self.lastBrundirTarget = brundir[1].targetGUID or self.lastBrundirTarget
                print("brundir target:" .. (self.lastBrundirTarget or "N/A"))
            end
        else
            self.lastBrundirTarget = nil
        end
        if AI.IsDps() then
            local runeOfPower = self:findRuneOfPower()
            if runeOfPower and
                (AI.HasBuffOrDebuff("rune of power") or (#brundir > 0 and brundir[1]:HasAura("rune of power"))) and
                not AI.HasMoveTo() and not self.tendrilsActive and GetTime() >= self.lastOverloadTime + 7 then
                if self:IsBrundirActive() and self.lastBrundirTarget == UnitGUID("player") then
                    AI.SendAddonMessage("mark-me")
                    -- print("brundir in rune of power, moving out")
                    -- runeOfPower.radius = 8
                    -- local obstacles = self:GetRunesOfDeath()
                    -- table.insert(obstacles, runeOfPower)
                    -- local p = AI.PathFinding.FindSafeSpotInCircle(AI.GetPrimaryHealer(), 25, obstacles, 3)
                    -- AI.SetMoveTo(p.x, p.y)
                    -- return false
                    -- if p then
                    --     AI.PathFinding.MoveSafelyTo(p, self:GetRunesOfDeath())
                    --     return false
                    -- end
                end
            end
        end
        if AI.IsDps() and tick > self.lastOverloadTime + 7 and not self.tendrilsActive and not AI.HasMoveTo() and
            not AI.HasBuff("rune of power") then
            local runeOfPower = self:findRuneOfPower()
            local tx, ty = AI.GetPosition(AI.GetPrimaryTank())
            local runeToUse
            if runeOfPower and runeOfPower.distance > 5 and
                (#deathRunes == 0 or AI.CalcDistance(runeOfPower.x, runeOfPower.y, deathRunes[1].x, deathRunes[1].y) >
                    deathRunes[1].radius) and
                (not self:IsBrundirActive() or self.lastBrundirTarget ~= UnitGUID("player")) then
                print("moving to rune of power")
                AI.PathFinding.MoveSafelyTo(runeOfPower, self:GetRunesOfDeath())
                return false
            end
        end

        if AI.IsMage() and self:IsMolgeimActive() and
            AI.FindNearbyUnitsByName("runemaster molgeim")[1]:HasAura("shield of runes") and not AI.HasMoveTo() then
            local molgeim = AI.FindNearbyUnitsByName("runemaster molgeim")[1]
            AI.FocusUnit("runemaster molgeim")
            AI.CastSpell("spellsteal", "focus")
        end
        return false
    end,
    lastOverloadTime = 0,
    tendrilsActive = false,
    centerP = AI.PathFinding.Vector3.new(1587.4993896484, 119.86359405518, 427.26727294922),
    r = 39,
    lastBrundirTarget = nil
})

function assemblyOfIron:findRuneOfPower()
    local runeOfpower = AI.FindNearbyDynamicObjects("rune of power")
    if #runeOfpower > 0 then
        return runeOfpower[1]
    else
        runeOfpower = AI.FindNearbyUnitsByName("rune of power")
        for i, r in ipairs(runeOfpower) do
            if r:HasAura("rune of power") then
                return r
            end
        end
    end
    return nil
end

function assemblyOfIron:GetRunesOfDeath()
    local runes = AI.FindNearbyDynamicObjects("rune of death")
    return runes
end

function assemblyOfIron:SPELL_AURA_APPLIED(args)
    if strcontains(args.spellName, "fusion punch") then
        if AI.IsPaladin() then
            AI.MustCastSpell("cleanse", args.target)
        end
    end
    if strcontains(args.spellName, "rune of death") and args.target == UnitName("player") then
        print("rune of death on me")
        local deathRunes = self:GetRunesOfDeath()
        if GetTime() < self.lastOverloadTime + 7 then
            local brundir = AI.FindNearbyUnitsByName("brundir")
            if #brundir > 0 then
                brundir[1].radius = 20
                table.insert(deathRunes, brundir[1])
            end
        end

        local p = AI.PathFinding.FindSafeSpotInCircle(AI.GetPrimaryHealer(), 30, deathRunes, 5)
        if p then

            AI.PathFinding.MoveSafelyTo(p, {})
        end
    end

    if strcontains(args.spellName, "lightning tendrils") then
        print("brundir lightning tendrils")
        self.tendrilsActive = true
        local brundir = AI.FindNearbyUnitsByName("brundir")
        if #brundir > 0 then
            if not AI.IsTank() then
                brundir[1].radius = 20
                local poly = AI.PathFinding.createCircularPolygon(self.centerP, self.r)
                AI.SetObjectAvoidance({
                    guids = brundir,
                    safeDistance = 3,
                    polygon = poly
                })
            end
        end
    end
end

function assemblyOfIron:SPELL_AURA_REMOVED(args)
    local tick = GetTime()
    if strcontains(args.spellName, "lightning tendrils") then
        AI.ClearObjectAvoidance()
        self.tendrilsActive = false
        if AI.IsHealer() then
            AI.RegisterPendingAction(function(self)
                if not AI.IsCasting() then
                    local p = AI.PathFinding.FindSafeSpotInCircle(AI.GetPrimaryTank(), 25, {})
                    if p then
                        AI.PathFinding.MoveSafelyTo(p, {})
                        return true
                    end
                end
            end)
        elseif not AI.IsTank() then
            local p = AI.PathFinding.FindSafeSpotInCircle(AI.GetPrimaryHealer(), 25, {})
            if p then
                AI.PathFinding.MoveSafelyTo(p, {})
            end
        end
    end
end

function assemblyOfIron:CHAT_MSG_RAID_BOSS_EMOTE(s, t)
    if strcontains(s, "begins to overload") then
        self.lastOverloadTime = GetTime()
        if not AI.IsTank() then
            if AI.HasObjectAvoidance() then
                AI.ClearObjectAvoidance()
            end
            local brundir = AI.FindNearbyUnitsByName("brundir")
            if #brundir > 0 and brundir[1].distance <= 22 then
                -- local runeOfPower = self:findRuneOfPower()
                -- if AI.IsDps() and runeOfPower and
                --     AI.CalcDistance(runeOfPower.x, runeOfPower.y, brundir[1].x, brundir[1].y) > 22 then
                --     AI.PathFinding.MoveSafelyTo(runeOfPower, self:GetRunesOfDeath())
                --     return;
                -- end
                -- if rune of power is not safe, move a safe spot around the healer's location                
                local obstacles = self:GetRunesOfDeath()
                brundir[1].radius = 20
                table.insert(obstacles, brundir[1])
                local p = AI.PathFinding.FindSafeSpotInCircle(AI.GetPrimaryHealer(), 30, obstacles, 5)
                if p then
                    AI.PathFinding.MoveSafelyTo(p, obstacles)
                end
            end
        end
    end
end

function assemblyOfIron:IsBrundirActive()
    local brundir = AI.FindNearbyUnitsByName("stormcaller brundir")
    return #brundir > 0 and not brundir[1].isDead and brundir[1].isAttackable
end

function assemblyOfIron:IsMolgeimActive()
    local molgeim = AI.FindNearbyUnitsByName("runemaster molgeim")
    return #molgeim > 0 and not molgeim[1].isDead and molgeim[1].isAttackable
end

function assemblyOfIron:ON_ADDON_MESSAGE(from, cmd, params)
    if AI.IsTank() and cmd == "mark-me" then
        local info = AI.GetObjectInfo(from)
        if info and info.raidTargetIndex ~= 1 then
            SetRaidTarget(from, 1)
        end
    end
end

function assemblyOfIron:SMSG_SPELL_CAST_GO2(args)
    if args.spellId == 61974 or args.spellId == 63513 or args.spellId == 61974 then
        print("molgeim has cast Rune Of Power")
    end
end

AI.RegisterBossModule(assemblyOfIron)

-- thorim
local thorim = MosDefBossModule:new({
    name = "Thorim",
    creatureId = {32865, 32882, 32886},
    onStart = function(self)
        local mod = self
        AI.AUTO_CLEANSE = false
        AI.AUTO_PURGE = false
        AI.DISABLE_DRAIN = true
        AI.Config.useHealingWaveOnToons = true
        AI.do_PriorityTarget = function()
            local gLeaderName = AI.GetDpsPositionName(mod.gauntletLeaderPos)
            local followerName = AI.GetDpsPositionName(mod.followerPos)
            if mod.thorimDropped or not mod.gauntletStarted then
                return false
            end
            if not mod:IsGauntletTeam() then
                if AI.IsTank() then
                    if not AI.IsValidOffensiveUnit() then
                        TargetNearestEnemy()
                    end
                else
                    TargetUnit("dark rune evoker")
                    if not AI.IsValidOffensiveUnit() then
                        AssistUnit(AI.GetPrimaryTank())
                    end
                end
                return true
            else
                if UnitName("player") == gLeaderName then
                    TargetUnit("runic colossus")
                    if not AI.IsValidOffensiveUnit() or not AI.CanHitTarget() then
                        TargetUnit("ancient rune giant")
                        if not AI.IsValidOffensiveUnit() or not AI.CanHitTarget() then
                            AssistUnit(AI.GetPrimaryTank())
                        end
                    end
                end
                if UnitName("player") == followerName then
                    AssistUnit(gLeaderName)
                end
                return true
            end
            return false
        end
        -- guy going into tunnel
        AI.PRE_DO_DPS = function(isAoe)
            local gLeaderName = AI.GetDpsPositionName(mod.gauntletLeaderPos)
            local followerName = AI.GetDpsPositionName(mod.followerPos)
            if mod.thorimDropped or not self.gauntletStarted then
                return false
            end

            if AI.IsPriest() and self:IsGauntletTeam() and not mod.thorimDropped and not AI.HasDebuff("weakened soul") and
                not AI.HasBuff("power word: shield") and AI.CastSpell("power word: shield", "player") then
                return true
            end

            if not mod:IsGauntletTeam() then
                return false
            else
                if mod.gauntletStarted and not mod.thorimDropped then
                    AI.DO_DPS(false)
                    return true
                end
            end
            return false
        end

        AI.AUTO_CLEANSE = false

        if AI.IsHeroicRaidOrDungeon() and not AI.HasBuff("flask of the frost wyrm") and not AI.IsTank() then
            AI.UseContainerItem("flask of the frost wyrm")
        end
    end,
    onStop = function(self)
        if oldPriorityTargetFn ~= nil then
            AI.do_PriorityTarget = oldPriorityTargetFn
        end
        AI.PRE_DO_DPS = nil
        AI.AUTO_CLEANSE = true
        AI.AUTO_PURGE = true
    end,
    onUpdate = function(self)
        -- if AI.GetRunSpeed() < 10 then
        --     AI.SetRunSpeed(10)
        -- end
        local gLeaderName = AI.GetDpsPositionName(self.gauntletLeaderPos)
        local followerName = AI.GetDpsPositionName(self.followerPos)
        if self.gauntletStarted and not self.thorimDropped and UnitName("player") == followerName then
            if AI.GetDistanceTo(AI.GetPosition(gLeaderName)) > 2 then
                FollowUnit(gLeaderName)
                -- local x, y = AI.GetPosition(gLeaderName)
                -- AI.SetMoveTo(x, y)
            end
        end

        if self.thorimDropped then
            if UnitName("focus") ~= "Thorim" then
                AI.FocusUnit("thorim")
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
                                    local r = 2 -- move 2 places behind thorim w/ the orb
                                    local x = thorim.x + r * math.cos(angleBehindThorim)
                                    local y = thorim.y + r * math.sin(angleBehindThorim)
                                    AI.SetMoveTo(x, y)
                                end

                                if AI.HasDebuff("frost nova") or AI.HasDebuff("frostbolt") then
                                    AI.SendAddonMessage("cleanse-me")
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
                                end, 6, "RETURN_TO_POSITION")
                            end
                        end
                    end
                end
            end

            if AI.IsMage() and AI.HasMoveTo() and AI.IsFacingTowardsDestination() and AI.CastSpell("blink") then
                return true
            end
        end
    end,
    gauntletLeaderPos = 2,
    followerPos = 0,

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
    dps3Safey = -269.09017944336,
    gauntletEnter = AI.PathFinding.Vector3.new(2165.8608398438, -262.71313476563, 419.33630371094),
    gauntletEngageStart = AI.PathFinding.Vector3.new(2136.9272460938, -258.97180175781, 419.84603881836)
})

function thorim:ON_ADDON_MESSAGE(from, cmd, params)
    if cmd == "cleanse-me" and (AI.IsPaladin() or AI.IsPriest()) then
        AI.RegisterPendingAction(function()
            -- print("cleansing " .. from)
            local spell = AI.IsPaladin() and "cleanse" or "dispel magic"
            return not AI.UnitHasDebuffOfType(from, "magic") or AI.CleanseFriendly(spell, from)
        end)
    end
end

function thorim:IsGauntletTeam()
    return AI.IsDpsPosition(self.gauntletLeaderPos) or AI.IsDpsPosition(self.followerPos)
end

function thorim:SPELL_AURA_APPLIED(args)
    if args.spellName:lower() == "nitro boosts" then
        -- AI.Print("nitro boosts on " .. args.caster)
        local gLeaderName = AI.GetDpsPositionName(self.gauntletLeaderPos)
        local followerName = AI.GetDpsPositionName(self.followerPos)
        if (args.target == gLeaderName or args.caster == gLeaderName) and UnitName("player") == followerName then
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
        if self:IsGauntletTeam() then
            local gate = AI.FindNearbyGameObjects("dark iron portcullis", "194560")
            if #gate > 0 and gate[1].state ~= 0 then
                gate[1]:SetGoState(0)
            else
                print("gauntlet gate not found")
            end
            AI.SetMoveTo(self.gauntletEnter.x, self.gauntletEnter.y)
        elseif not AI.IsTank() then
            AI.SetMoveTo(self.gauntletEngageStart.x, self.gauntletEngageStart.y)
        end
    end
    if monster == "Thorim" and strcontains(text:lower(), "you dare challenge") then
        self.thorimDropped = true
        AI.AUTO_CLEANSE = false
        TargetUnit("Thorim")
        AI.ResetMoveTo()
        local gLeaderName = AI.GetDpsPositionName(self.gauntletLeaderPos)
        local followerName = AI.GetDpsPositionName(self.followerPos)
        if UnitName("player") == followerName then
            FollowUnit(gLeaderName)
        end
        if AI.IsDps() then
            if AI.IsPriest() then
                AI.MustCastSpell("vampiric embrace")
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
        AI.FocusUnit("freya")
        -- AI.do_PriorityTarget = function()
        --     return AI.DoTargetChain("strengthened iron roots")
        -- end

        if AI.IsPriest() then
            CancelUnitBuff("player", "vampiric embrace")
        end

        if AI.IsHealer() then
            AI.AUTO_CLEANSE = false
        end

        AI.PRE_DO_DPS = function(self)
            if AI.IsDps() then
                if AI.IsValidOffensiveUnit() and strcontains("Eonar's Gift", UnitName("target")) then
                    if AI.IsPriest() and AI.DoCastSpellChain("target", "mind blast", "shadow word: death", "mind flay") then
                        return true
                    end
                end
            end
            return false
        end
    end,
    onStop = function(self)
    end,
    onUpdate = function(self)
        -- if AI.GetRunSpeed() < 10 then
        --     AI.SetRunSpeed(10)
        -- end
        if UnitName("focus") ~= "Freya" then
            AI.FocusUnit("freya")
        end
        local allies = AI.GetRaidOrPartyMemberUnits()
        if not AI.IsTank() then
            local natureBombs = AI.FindNearbyUnitsByName("nature bomb")
            if AI.IsDps() and AI.GetDistanceTo(AI.GetPosition("target")) > 40 and #natureBombs == 0 then
                local p = AI.PathFinding.FindSafeSpotInCircle("target", 30)
                if p then
                    AI.SetMoveTo(p.x, p.y)
                end
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
                            AI.SetMoveTo(spore.x, spore.y)
                            return false
                        end
                    end
                end
            end

        end
        return false
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

function freya:CHAT_MSG_RAID_BOSS_EMOTE(s)
    if strcontains(s, "begins to grow") and AI.IsTank() then
        AI.RegisterOneShotAction(function()
            -- print("targeting eonar's gift")
            AI.DoTargetChain(33228)
        end, 2)
    end
end

function freya:SPELL_AURA_APPLIED(args)
    -- if args.spellName:lower() == "nature's fury" and UnitName("player") == args.target and not AI.IsTank() then
    --     local spores = AI.FindNearbyUnitsByName("healthy spore")
    --     if #spores > 0 then
    --         print("avoiding allies coz of nature's fury")
    --         local allies = AI.GetRaidOrPartyMemberUnits()
    --         for i, spore in ipairs(spores) do
    --             if self.isFarEnoughFromAllies(spore.x, spore.y, allies) then
    --                 AI.SetMoveToPosition(spore.x, spore.y)
    --                 return
    --             end
    --         end
    --     end
    -- end
end

function freya:SPELL_AURA_REMOVED(args)
    -- attuned to nature being removed
    if args.spellId == 62519 then
        print("phase 2 started")
        if AI.IsDps() then
            AI.RegisterPendingAction(function(self)
                if not AI.IsCasting() then
                    print("moving to healer's position for phase 2")
                    local hx, hy = AI.GetPosition(AI.GetPrimaryHealer())
                    AI.SetMoveTo(hx, hy)
                    return true
                end
            end)
        end
        if AI.IsPriest() and not AI.HasBuff("vampiric embrace") then
            AI.MustCastSpell("vampiric embrace")
        end
    end
end

function freya:SMSG_SPELL_CAST_START2(args)
    -- if args.spellName == "Tidal Wave" then
    --     print(args.caster .. " is casting tidal wave")
    --     if not AI.IsTank() then
    --         TargetUnit(args.caster)
    --         AI.DoStaggeredInterrupt()
    --     end
    -- end
end
function freya:SMSG_SPELL_CAST_GO2(args)
    -- nature bomb inc
    if args.spellId == 64648 and AI.IsHealer() then
        print("nature bomb inc")
        AI.RegisterOneShotAction(function(self)
            local natureBombs = AI.FindNearbyUnitsByName("nature bomb")
            for i, o in ipairs(natureBombs) do
                o.radius = 15
            end
            AI.FocusUnit("freya")
            local p = AI.PathFinding.FindSafeSpotInCircle("focus", 25, natureBombs, 1)
            print("dodging nature bombs")
            AI.SetMoveTo(p.x, p.y)
            AI.SendAddonMessage("move-to", p.x, p.y)
        end, 1);
    end

    if (args.spellId == 64587 or args.spellId == 64650) and AI.IsDps() then
        AI.RegisterPendingAction(function(self)
            if not AI.IsCasting() then
                print("moving to healer's position after bomb explosion")
                local hx, hy = AI.GetPosition(AI.GetPrimaryHealer())
                AI.SetMoveTo(hx, hy)
                return true
            end
        end)
    end
end

function freya:ON_ADDON_MESSAGE(from, cmd, params)
    if cmd == "move-to" and AI.IsDps() then
        print("moving to nature bomb dodge spot")
        local x, y = strsplit(",", params)
        x = tonumber(x)
        y = tonumber(y)
        AI.SetMoveTo(x, y)
    end
end

AI.RegisterBossModule(freya)

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
        if self.mcUnit and AI.IsValidOffensiveUnit(self.mcUnit) and not strcontains(UnitName("player"), self.mcUnit) and
            AI.IsDps() and (not AI.IsUnitCC(self.mcUnit) and not AI.HasDebuff("polymorph", self.mcUnit)) then
            if AI.IsWarlock() or AI.IsMage() then
                local delay = AI.IsWarlock() and 2 or 0
                AI.RegisterPendingAction(function(self)
                    if AI.IsUnitCC(self.mcUnit) or AI.HasDebuff("polymorph", self.mcUnit) then
                        return true
                    end
                    local spell = AI.IsWarlock() and "fear" or "polymorph"
                    return AI.CastSpell(spell, self.mcUnit)
                end, delay, "CC_MC_UNIT")
            end
        end

        if not AI.IsTank() and not AI.HasMoveTo() and AI.IsValidOffensiveUnit() and
            AI.GetDistanceTo(AI.GetPosition("target")) > 20 then
            local p = AI.PathFinding.FindSafeSpotInCircle("target", 15)
            if p then
                print("moving closer to horror")
                AI.SetMoveTo(p.x, p.y)
            end
        end
    end,
    mcUnit = nil,
    ccTimeout = 0
})

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
        TargetUnit("General Vezax")
        FocusUnit("target")
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
        local bestCrash = self:findBestCrashSite()
        if tick > self.lastCrashTime and AI.IsDps() and bestCrash then
            if not AI.HasDebuff("shadow crash") and not AI.HasDebuff("mark of the faceless") and
                not AI.HasMoveToPosition() and not AI.HasObjectAvoidance() then

                print("moving into shadow crash impact area")
                AI.SetMoveTo(bestCrash.x, bestCrash.y)
            end
        end

        if AI.IsPriest() and AI.HasDebuff("shadow crash") then
            local tank = AI.GetPrimaryTank()
            if not AI.HasDebuff("weakened soul", tank) and AI.CastSpell("power word: shield", tank) then
                return true
            end
        end
    end,
    lastCrashTime = 0,
    animus = false,
    markedPlayer = nil,
    findClosestPointInList = function(pointList)
        return findClosestPointInList(pointList)
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
            -- return info:GetDistanceTo(x, y) > 18
            return AI.CalcDistance(x, y, info.x, info.y) > 18
        end
        return true
    end
})

function vezax:findBestCrashSite()
    local crashes = AI.FindNearbyDynamicObjects("shadow crash")
    if #crashes == 0 then
        return nil
    end
    local gx, gy = AI.GetPosition("focus")
    for i, o in ipairs(crashes) do
        if o:GetDistanceTo(gx, gy) <= 35 then
            return o
        end
    end
    return nil
end

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
        if not AI.IsTank() then
            local destX, destY = AI.GetMoveToFinalDestination()
            if AI.GetDistanceTo(sX, sY) <= 12 or (AI.HasMoveTo() and AI.CalcDistance(sX, sY, destX, destY) <= 12) then
                print("evading shadow crash")
                local allies = AI.GetRaidOrPartyMemberUnits()
                local angle = AI.CalcFacing(sX, sY, gX, gY)
                local points = {}
                if AI.HasDebuff("mark of the faceless") then
                    for theta = angle - rad90, angle + rad90, rad5 do
                        local ntheta = normalizeAngle(theta)
                        for r = 15, 40, 1 do
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
end

function vezax:SPELL_AURA_APPLIED(args)
    if args.spellName:lower() == "mark of the faceless" then
        self.markedPlayer = args.target
        if UnitName("player") == args.target then
            local obstacles = AI.GetAlliesAsObstacles(18)
            AI.SetObjectAvoidance({
                guids = obstacles,
                safeDistance = 3,
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

