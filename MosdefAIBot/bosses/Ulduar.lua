local oldPriorityTargetFn = nil
-- ulduar
local ulduar = MosdefZoneModule:new({
    zoneName = "Ulduar",
    zoneId = 530,
    onEnter = function(self)
        AI.PRE_DO_DPS = function(isAoE)
            if AI.IsInVehicle() then
                if AI.IsValidOffensiveUnit() and not AI.HasMoveToPosition() then
                    if not AI.IsFacingTowards(AI.GetPosition("target")) then
                        AI.SetDesiredFacing(AI.GetFacingForPosition(AI.GetPosition("target")))
                    end
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
                    else
                        AI.SetDesiredAimAngle(-0.30458)
                    end
                elseif not AI.IsValidOffensiveUnit() then
                    local vehicle = (UnitName("playerpet") or ""):lower()
                    local angle = 0.35212010
                    if vehicle == "salvaged siege turret" then
                        angle = 0.25119984
                    end
                    AI.SetDesiredAimAngle(angle)
                end

                -- don't whiel
                if AI.HasDesiredFacing() then
                    return true
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
                    if UnitPower("playerpet") > 10 then
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
        if AI.IsDps() then
            TargetUnit("iron mender")
            FocusUnit("target")
        end
    end,
    onStop = function(self)
    end,
    onUpdate = function(self)
        if AI.IsDps() then
            if AI.IsShaman() and AI.IsValidOffensiveUnit("focus") and UnitName("focus") == "Iron Mender" and
                UnitName("target") ~= UnitName("focus") then
                if not AI.HasMyDebuff("hex", "focus") and AI.CastSpell("hex", "focus") then
                    return true
                end
            end
            if AI.IsWarlock() and AI.IsValidOffensiveUnit("focus") and UnitName("focus") == "Iron Mender" and
                UnitName("target") ~= UnitName("focus") and not AI.HasMyDebuff("fear", "focus") then
                AI.RegisterPendingAction(function()
                    if not AI.HasMyDebuff("fear", "focus") and not AI.HasDebuff("hex", "focus") then
                        return AI.CastSpell("fear", "focus")
                    end
                    return true
                end, 2, "CC_IRON_MENDER")
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
    creatureId = {33133},
    onStart = function(self)
        table.insert(self.kitingCoords, {
            x = 177.46096801758,
            y = 62.35523223877
        })
        table.insert(self.kitingCoords, {
            x = 268.52001953125,
            y = 67.713348388672
        })

        table.insert(self.kitingCoords, {
            x = 374.55169677734,
            y = 64.888778686523
        })

        table.insert(self.kitingCoords, {
            x = 379.05941772461,
            y = -21.141511917114
        })

        table.insert(self.kitingCoords, {
            x = 376.29214477539,
            y = -117.51584625244
        })

        table.insert(self.kitingCoords, {
            x = 291.72155761719,
            y = -123.76761627197
        })

        table.insert(self.kitingCoords, {
            x = 176.10855102539,
            y = -126.8282623291
        })

        table.insert(self.kitingCoords, {
            x = 168.18101501465,
            y = -58.606410980225
        })

        if UnitName("focus") ~= "Flame Leviathan" then
            TargetUnit("Flame")
            FocusUnit("target")
        end
    end,
    onStop = function(self)
        self.currentCoord = 1
        self.kitingCoords = {}
        self.pursuedTarget = nil
    end,
    onUpdate = function(self)
        -- run from leviathan if we're being pursued
        if AI.IsPossessing() then
            local vehicle = UnitName("playerpet") or ""
            local distToLeviathan = AI.GetDistanceTo(AI.GetPosition("target"))
            if vehicle ~= "Salvaged Demolisher" and vehicle == self.pursuedTarget and not AI.HasMoveToPosition() and
                (distToLeviathan == 0 or distToLeviathan < 60) then
                local nextWp = self.kitingCoords[self.currentCoord]
                AI.SetMoveToPosition(nextWp.x, nextWp.y)
                -- AI.SayRaid(vehicle .. " moving to next wp " .. self.currentCoord)
                self.currentCoord = self.currentCoord + 1
                if self.currentCoord > (#self.kitingCoords) then
                    self.currentCoord = 1
                end
            end

            if self.pursuedTarget and AI.IsFacingTowardsDestination() then
                if MaloWUtils_StrContains(self.pursuedTarget, "Siege") and MaloWUtils_StrContains(vehicle, "Siege") and
                    AI.FindPossessionSpellSlot("steam rush") and AI.UsePossessionSpell("steam rush") then
                    return true
                end

                if MaloWUtils_StrContains(self.pursuedTarget, "Demolisher") and
                    MaloWUtils_StrContains(vehicle, "Demolisher") and AI.FindPossessionSpellSlot("increase speed") and
                    AI.UsePossessionSpell("increase speed") then
                    return true
                end
                if MaloWUtils_StrContains(self.pursuedTarget, "Chopper") and AI.FindPossessionSpellSlot("tar") and
                    AI.UsePossessionSpell("tar") then
                    return true
                end
                if MaloWUtils_StrContains(self.pursuedTarget, "Chopper") and AI.FindPossessionSpellSlot("speed boost") and
                    AI.UsePossessionSpell("speed boost") then
                    return true
                end
            end

            if vehicle == "Salvaged Demolisher" then
                if UnitName("target") == "Liquid Pyrite" and self.lastGrabTime < GetTime() and
                    CheckInteractDistance("target", 1) and AI.UsePossessionSpell("grab crate", "target") then
                    self.lastGrabTime = GetTime() + 3
                    TargetLastEnemy()
                    return true
                end
            end
            return true
        end
    end,
    kitingCoords = {},
    currentCoord = 1,
    pursuedTarget = nil,
    lastGrabTime = 0
})

function flameLeviathan:SPELL_CAST_SUCCESS(args)
    if AI.IsPossessing() then
        if args.spellName:lower() == "pursued" then
            local target = args.target:lower()
            local vehicle = UnitName("playerpet"):lower()
            if target == "salvaged siege turret" then
                print("salvaged turret pursued, swapping to siege engine instead")
                self.pursuedTarget = "Salvaged Siege Engine"
            elseif target == "salvaged demolisher mechanic seat" then
                print("mechanic pursused swapping to demolisher")
                self.pursuedTarget = "Salvaged Demolisher"
            else
                target = args.target:lower()
                self.pursuedTarget = args.target
            end
            print(target .. " is being pursued")
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
            local vehicle = UnitName("playerpet"):lower()
            if target == "salvaged siege turret" then
                print("salvaged turret pursued, swapping to siege engine instead")
                self.pursuedTarget = "Salvaged Siege Engine"
            elseif target == "salvaged demolisher mechanic seat" then
                print("mechanic pursused swapping to demolisher")
                self.pursuedTarget = "Salvaged Demolisher"
            else
                print(args.target .. " is pursued")
                self.pursuedTarget = args.target
            end
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

function flameLeviathan:SPELL_DAMAGE(args)
    if AI.IsPossessing() then
        if args.spellName:lower() == "flame vents" then
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
    end,
    onEnd = function(self)
    end,
    onUpdate = function(self)
        if AI.IsValidOffensiveUnit("target") and AI.HasBuff("Brittle", "target") and AI.IsDps() then
            if AI.IsWarlock() and AI.CastSpell("Searing Pain", "target") then
                return true
            end
            if AI.IsPriest() and AI.CastSpell("Mind Blast", "target") or AI.CastSpell("mind flay", "target") then
                return true
            end
            if AI.IsShaman() and AI.CastSpell("lightning bolt", "target") then
                return true
            end
            if AI.IsHealer() and AI.IsShaman() then
                if self.slaggedTarget ~= nil and AI.GetUnitHealthPct(self.slaggedTarget) <= 50 and AI.CastSpell("riptide", self.slaggedTarget) or AI.CastSpell("lesser healing wave", self.slaggedTarget) then
                    return true
                end
                if not AI.HasBuff("water walking", "player") and AI.CastSpell("water walking", "player") then
                    return true
                end
            end
        end
    end,    
    dpsX = 633.41223144531,
    dpsY = 304.38931274414,
    slaggedTarget = nil
})

function ignis:SPELL_AURA_APPLIED(args)
    if args.spellName:lower() == "slag pot" then
        self.slaggedTarget = args.target
        if AI.IsPriest() then
            AI.RegisterPendingAction(function()
                return AI.CastSpell("power word: shield", args.target)
            end, null, "SHIELD_SLAGGER")
        end
        if AI.IsHealer() and AI.IsShaman() then
            AI.RegisterPendingAction(function()
                return AI.CastSpell("riptide", args.target)
            end, null, "HOT_SLAGGER")
        end
        if args.target == UnitName("player") then
            AI.DISABLE_CDS = true
            if AI.IsWarlock() and AI.HasBuff("demonic circle: summon") then
                AI.RegisterPendingAction(function()
                    return AI.CastSpell("demonic circle: teleport")
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
    creatureId = {32930},
    onStart = function(self)
        oldPriorityTargetFn = AI.do_PriorityTarget
        local bossMod = self
        AI.do_PriorityTarget = function()
            if bossMod.gripTarget ~= nil and UnitName("target") ~= "Right Arm" then
                TargetUnit("right arm")
            end
            if bossMod.gripTarget == nil and UnitName("target") ~= "Kologarn" then
                TargetUnit("kologarn")
            end
        end
    end,
    onStop = function(self)
    end,
    gripTarget = nil
})

function kologarn:SPELL_AURA_APPLIED(args)
    if args.spellName:lower() == "stone grip" then
        -- AI.SayRaid("I'm gripped")
        self.gripTarget = args.target
        TargetUnit("right arm")
    end
end

function kologarn:SPELL_AURA_REMOVED(args)
    if args.spellName:lower() == "stone grip" then
        self.gripTarget = nil
        TargetUnit("kologarn")
    end
end

AI.RegisterBossModule(kologarn)

-- razorscale
local razorscale = MosDefBossModule:new({
    name = "Razorscale",
    creatureId = {33186, 33210},
    onStart = function(self)
        AI.DISABLE_CDS = true
    end,
    onStop = function(self)
        AI.DISABLE_CDS = false
    end,
    onUpdate = function(self)
        if AI.IsValidOffensiveUnit() then
            AI.DISABLE_CDS = UnitName("target") ~= "Razorscale"
        end
    end
})
AI.RegisterBossModule(razorscale)

-- auriaya
local auriaya = MosDefBossModule:new({
    name = "auriaya",
    onStart = function(self)
        TargetUnit("auriaya")
        FocusUnit("target")
    end,
    onEnd = function(self)
    end,
    onUpdate = function(self)
        if AI.IsPriest() and not AI.HasMyBuff("fear ward", AI.GetPrimaryHealer()) and
            AI.CanCastSpell("fear ward", AI.GetPrimaryHealer()) and AI.CastSpell("fear ward", AI.GetPrimaryHealer()) then
            return true
        end
    end
})

function auriaya:UNIT_SPELLCAST_START(caster, spellName)
    if spellName:lower() == "sentinel blast" and AI.IsShaman() then
        AI.RegisterPendingAction(function()
            if UnitName("focus") ~= "Auriaya" then
                TargetUnit("auriaya")
                FocusUnit("target")
            end
            return not AI.HasDebuff("Terrifying Screech") and AI.CastSpell("wind shear", "focus")
        end, null, "INTERRUPT_SENTINEL_BLAST")
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
            end, 1, "PWD_")
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
                    TargetNearestEnemy()
                    if not AI.IsValidOffensiveUnit() or not AI.CanHitTarget() then
                        AssistUnit(AI.Config.tank)
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
                if AI.IsValidOffensiveUnit() and
                    (MaloWUtils_StrContains(UnitName("target"), "Colossus") or
                        MaloWUtils_StrContains(UnitName("target"), "Ancient")) then
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
            if AI.GetDistanceTo(AI.GetPosition(self.gauntletLeader)) > 4 then
                FollowUnit(self.gauntletLeader)
            end
        end
    end,
    gauntletLeader = "Mosdeflocka",
    follower = "Mosdefelsham",

    dpsSpot1X = 2126.2263183594,
    dpsSpot1Y = -272.3288269043,

    dpsSpot2X = 2128.0231933594,
    dpsSpot2Y = -253.1099395752,

    dpsSpot3X = 2143.5727539063,
    dpsSpot3Y = -255.19723510742,

    healerX = 2145.5891113281,
    healerY = -268.9655456543,

    tankX = 2136.5803222656,
    tankY = -262.69729614258,

    thorimDropped = false
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

function thorim:SPELL_CAST_SUCCESS(args)
    if args.caster == self.follower then
        self.lastFollowerCastTime = GetTime()
    end
end

function thorim:CHAT_MSG_MONSTER_YELL(text, monster)
    if monster == "Thorim" and MaloWUtils_StrContains(text:lower(), "you dare challenge") then
        self.thorimDropped = true
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
            end, 5, "MOVE_TO_BATTLEPOSITIONS")
        elseif AI.IsHealer() then
            AI.SetMoveToPosition(self.healerX, self.healerY)
        elseif AI.IsTank() then
            TargetUnit("Thorim")
            AI.SetMoveToPosition(self.tankX, self.tankY)
        end
    end
end

AI.RegisterBossModule(thorim)

-- freya
local freya = MosDefBossModule:new({
    name = "Freya",
    onStart = function(self)
        oldPriorityTargetFn = AI.do_PriorityTarget
        AI.do_PriorityTarget = function()
            TargetUnit("Eonar's Gift")
            return AI.IsValidOffensiveUnit() and UnitName("target") == "Eonar's Gift" and AI.CanHitTarget()
        end
    end,
    onStop = function(self)
        if oldPriorityTargetFn ~= nil then
            AI.do_PriorityTarget = oldPriorityTargetFn
        end
    end,
    onUpdate = function(self)
    end
})

AI.RegisterBossModule(freya)

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
                TargetUnit("Flash Freeze")
                if AI.IsValidOffensiveUnit() and UnitName("target") == "Flash Freeze" then
                    return true
                end
            end
            return false
        end

        AI.PRE_DO_DPS = function(isAoE)
            if AI.IsDps() and UnitName("target") == "Flash Freeze" then
                if AI.IsWarlock() and AI.CastSpell("searing pain", "target") then
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
            local pi2 = math.pi * 2
            local rad45 = 0.785398
            local nearbyObjects = GetNearbyObjects(80)
            local closestToastyFire = nil
            local farthestToastyFire = nil
            local closestIcicle = nil
            local closestSnowpackedIcicle = nil
            local closestSnowpackedIcicleTarget = nil
            local distToFire = 100
            local farDistToFire = 0
            local distToIcicle = 100
            local distToSnowpackedIcicle = 100
            local icicles = {}
            local fires = {}
            local fireMage = nil
            local hodir = nil
            local tank = nil
            for i, o in ipairs(nearbyObjects) do
                if o.name:lower() == "toasty fire" then
                    local dist = AI.GetDistanceTo(o.x, o.y)
                    table.insert(fires, o)
                    if dist < distToFire then
                        closestToastyFire = o
                        distToFire = AI.GetDistanceTo(o.x, o.y)
                    end
                    if dist > farDistToFire then
                        farthestToastyFire = o
                        farDistToFire = dist
                    end
                end
                if o.name:lower() == "icicle" then
                    table.insert(icicles, o)
                    if AI.GetDistanceTo(o.x, o.y) < distToIcicle then
                        closestIcicle = o
                        distToIcicle = AI.GetDistanceTo(o.x, o.y)
                    end
                end
                if o.name:lower() == "snowpacked icicle" then
                    if AI.GetDistanceTo(o.x, o.y) < distToSnowpackedIcicle then
                        closestSnowpackedIcicle = o
                        distToSnowpackedIcicle = AI.GetDistanceTo(o.x, o.y)
                    end
                end

                if o.name:lower() == "snowpacked icicle target" then
                    closestSnowpackedIcicleTarget = o
                end
                if MaloWUtils_StrContains(o.name:lower(), "veesha") then
                    fireMage = o
                end
                if MaloWUtils_StrContains(o.name:lower(), "hodir") then
                    hodir = o
                end
                if o.name:lower() == AI.Config.tank then
                    tank = o
                end
            end

            if closestSnowpackedIcicle ~= nil and closestSnowpackedIcicleTarget == nil then
                if AI.GetDistanceTo(closestSnowpackedIcicle.x, closestSnowpackedIcicle.y) <= 10 and
                    not AI.HasMoveToPosition() then
                    AI.SayRaid("Flash freeze on me, moving out")
                    local theta = AI.CalcFacing(fireMage.x, fireMage.y, closestSnowpackedIcicle.x,
                        closestSnowpackedIcicle.y)
                    -- local theta = AI.GetFacingForPosition(closestSnowpackedIcicle.x, closestSnowpackedIcicle.y)
                    local angles = {theta - (rad45 * 2), theta - rad45, theta, theta + rad45, theta + (rad45 * 2)}
                    local r = 12
                    local points = {}
                    for i, angle in ipairs(angles) do
                        local theta = angle
                        if theta < 0.0 then
                            theta = theta + pi2
                        elseif theta > pi2 then
                            theta = theta - pi2
                        end
                        local x, y = r * math.cos(theta), r * math.sin(theta)
                        local nX, nY = closestSnowpackedIcicle.x + x, closestSnowpackedIcicle.y + y
                        if AI.CalcDistance(nX, nY, self.centerX, self.centerY) <= self.divertFromCenterR then
                            table.insert(points, {
                                x = nX,
                                y = nY
                            })
                        end
                    end
                    local p = self.findClosestPointInList(points)
                    AI.SetMoveToPosition(p.x, p.y)
                    return false
                end
            elseif closestIcicle ~= nil and distToIcicle <= 5.5 and not AI.HasMoveToPosition() then
                AI.SayRaid("Icicle above me.");
                -- local targetToMoveAround = tank
                local targetToMoveAround = hodir
                if closestToastyFire ~= nil then
                    if self.targetFire == nil or not self.isValidFire(self.targetFire, fires) then
                        local rI = math.random(1, #fires)
                        self.targetFire = fires[rI]
                    end
                    targetToMoveAround = self.targetFire
                end
                local r = 13
                -- if targetToMoveAround == fireMage then
                --     r = 13
                -- end
                local angleToTarget = AI.GetFacingForPosition(targetToMoveAround.x, targetToMoveAround.y);

                local angles = {angleToTarget - (rad45 * 2), angleToTarget - rad45, angleToTarget,
                                angleToTarget + rad45, angleToTarget + (rad45 * 2)}

                -- local angles = {angleToTarget - rad45, angleToTarget, angleToTarget + rad45}

                local safeLocations = {}

                for i, angle in ipairs(angles) do
                    local theta = angle
                    if theta < 0.0 then
                        theta = theta + pi2
                    elseif theta > pi2 then
                        theta = theta - pi2
                    end
                    local x, y = r * math.cos(theta), r * math.sin(theta)
                    local nX, nY = targetToMoveAround.x + x, targetToMoveAround.y + y
                    if self.isPointSafeFromAllIcicles(nX, nY, icicles) and
                        AI.CalcDistance(nX, nY, self.centerX, self.centerY) <= self.divertFromCenterR then
                        table.insert(safeLocations, {
                            x = nX,
                            y = nY
                        })
                    end
                end
                if #safeLocations == 0 then
                    return false
                end
                local r = math.random(1, #safeLocations)
                AI.SetMoveToPosition(safeLocations[r].x, safeLocations[r].y)
                -- self.nextAvoidanceTime = GetTime() + 3
                return false
            elseif not AI.HasMoveToPosition() and not AI.HasBuff("toasty fire") and AI.GetDebuffCount("biting cold") >=
                3 then
                -- if we don't have toasty fire buff, move to closest toasty fire
                if closestToastyFire then
                    if self.targetFire == nil or not self.isValidFire(self.targetFire, fires) then
                        local rI = math.random(1, #fires)
                        self.targetFire = fires[rI]
                    end
                    local fireToUse = self.targetFire
                    local angleToTarget = AI.GetFacingForPosition(fireToUse.x, fireToUse.y);
                    local angles = {angleToTarget - (rad45 * 2), angleToTarget - rad45, angleToTarget,
                                    angleToTarget + rad45, angleToTarget + (rad45 * 2)}
                    local r = 13
                    local points = {}
                    for i, angle in ipairs(angles) do
                        local theta = angle
                        if theta < 0.0 then
                            theta = theta + pi2
                        elseif theta > pi2 then
                            theta = theta - pi2
                        end
                        local x, y = r * math.cos(theta), r * math.sin(theta)
                        local nX, nY = fireToUse.x + x, fireToUse.y + y
                        if self.isPointSafeFromAllIcicles(nX, nY, icicles) and
                            AI.CalcDistance(nX, nY, self.centerX, self.centerY) <= self.divertFromCenterR then
                            table.insert(points, {
                                x = nX,
                                y = nY
                            })
                        end
                    end
                    if #points == 0 then
                        return false
                    end

                    local p = self.findClosestPointInList(points)
                    AI.SayRaid("No toasty fire buff, moving towards it")
                    AI.SetMoveToPosition(p.x, p.y)
                    return false
                end
            end
        end
        return false
    end,
    isPointSafeFromAllIcicles = function(x, y, icicleList)
        for i, o in ipairs(icicleList) do
            if AI.CalcDistance(x, y, o.x, o.y) <= 5.5 then
                return false
            end
        end
        return true
    end,
    isPointFarEnoughFromFires = function(x, y, fireList)
        for i, o in ipairs(fireList) do
            if AI.CalcDistance(x, y, o.x, o.y) < 5.5 then
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
    isValidFire = function(fireO, listOfFires)
        if not fireO then
            return false
        end
        for i, o in ipairs(listOfFires) do
            if o.guid == fireO.guid then
                return true
            end
        end
        return false
    end,
    centerX = 2000.7666015625,
    centerY = -233.83085632324,
    divertFromCenterR = 35,
    nextIcicleCheck = 0,
    avoidedIcicles = {},
    targetFire = nil,
    nextAvoidanceTime = 0
})

function hodir:CHAT_MSG_RAID_BOSS_EMOTE(s, t)
    -- print("CHAT_MSG_RAID_BOSS_EMOTE " .. s)
    if MaloWUtils_StrContains(s, "Flash") then
        AI.ResetMoveToPosition()
    end
    if MaloWUtils_StrContains(s, "Frozen") then
        AI.ResetMoveToPosition()
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
        if self.mcUnit ~= nil then
            local mod = self
            if UnitName("player") ~= self.mcUnit and AI.IsDps() then
                if AI.IsWarlock() then
                    AI.RegisterPendingAction(function()
                        if not AI.HasMyDebuff("fear", mod.mcUnit) and not AI.HasDebuff("hex", mod.mcUnit) then
                            return AI.CastSpell("fear", mod.mcUnit)
                        end
                    end, null, "CC_MC_UNIT")
                end

                AI.RegisterPendingAction(function()
                    if not AI.HasMyDebuff("hex", mod.mcUnit) and not AI.HasDebuff("fear", mod.mcUnit) then
                        return AI.CastSpell("hex", mod.mcUnit)
                    end
                end, 5, "CC_MC_UNIT")
            end
        end

        if not AI.IsTank() and AI.IsValidOffensiveUnit() and AI.GetDistanceTo(AI.GetPosition("target")) > 40 then
            local angle = AI.GetFacingForPosition(AI.GetPosition("target"))
            local r = 20
            local x, y = r * math.cos(angle), r * math.sin(angle)
            local cX, cY = AI.GetPosition()
            AI.SetMoveToPosition(cX + x, cY + y)
        end
    end,
    mcUnit = nil
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

        AI.Config.startTankHealThreshold = 50
    end,
    onStop = function(self)
        AI.USE_MANA_REGEN = true
        AI.PRE_DO_DPS = nil
        AI.Config.startTankHealThreshold = 100
    end,
    onUpdate = function(self)
        if UnitName("target") == "General Vezax" then
            local castingSpell = UnitCastingInfo("target")
            if castingSpell ~= nil and castingSpell:lower() == "searing flames" and AI.IsShaman() and
                AI.CastSpell("wind shear", "target") then
                return true
            end
        end
        if GetTime() > self.lastCrashTime + 4 and AI.IsDps() then
            if not AI.HasDebuff("shadow crash") and not AI.HasDebuff("mark of the faceless") and
                (self.crashX and self.crashY) and not AI.HasMoveToPosition() then
                AI.SetMoveToPosition(self.crashX, self.crashY)
            end
        end

        if AI.IsPriest() and AI.HasDebuff("shadow crash") then
            local tank = AI.GetPrimaryTank()
            if not AI.HasDebuff("weakened soul", tank) and AI.CastSpell("power word: shield", tank) then
                return true
            end
        end
    end,
    crashX = nil,
    crashY = nil,
    lastCrashTime = 0,
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

function vezax:SPELL_AURA_APPLIED(args)
    if args.spellName:lower() == "mark of the faceless" and args.target == UnitName("player") and
        not AI.HasMoveToPosition() then
        local allies = AI.GetRaidOrPartyMemberUnits()
        local pi2 = math.pi * 2
        local rad45 = 0.785398
        local spots = {}
        local closestAlly = nil
        local distToAlly = 100
        if not AI.IsValidOffensiveUnit() then
            TargetUnit("General")
        end
        for i, ally in ipairs(allies) do
            if AI.GetDistanceTo(ally) < distToAlly then
                distToAlly = AI.GetDistanceTo(ally)
                closestAlly = ally
            end
        end
        if distToAlly < 15 then
            local r = 16
            local angle = AI.GetFacingForPosition(AI.GetPosition("target"))
            local angles = {angle - rad45 * 2, angle + math.pi, angle + rad45 * 2}
            for i, a in ipairs(angles) do
                if a > pi2 then
                    a = a - pi2
                elseif a < 0.0 then
                    a = a + pi2
                end
                local x, y = r * math.cos(a), r * math.sin(a)
                local cX, cY = AI.GetPosition()
                local nX, nY = cX + x, cY + y
                table.insert(spots, {
                    x = nX,
                    y = nY
                })
            end
        end
        if #spots > 0 then
            local p = self.findClosestPointInList(spots)
            AI.SetMoveToPosition(p.x, p.y)
        end
    end
end

function vezax:SPELL_CAST_START(args)
    if args.spellName:lower() == "searing flames" then
        if AI.IsShaman() and AI.IsDps() then
            AI.RegisterPendingAction(function()
                if AI.IsCasting() then
                    AI.StopCasting()
                end
                if UnitName("focus") ~= "General Vezax" then
                    TargetUnit("General Vezax")
                    FocusUnit("target")
                end
                return AI.CastSpell("wind shear", "focus")
            end, null, "INTERRUPT_SEARING_FLAMES")
        end
    end
end

function vezax:SPELL_CAST_SUCCESS(args)
    if args.spellName:lower() == "shadow crash" then
        local sX, sY = AI.GetPosition(args.target)
        self.crashX = sX
        self.crashY = sY
        self.lastCrashTime = GetTime()
        local mod = self
        if AI.GetDistanceTo(sX, sY) <= 11 and not AI.IsTank() and not AI.HasMoveToPosition() then
            AI.SayRaid("Evading shadow crash")
            if not AI.IsValidOffensiveUnit() then
                TargetUnit("General")
            end
            local pi2 = math.pi * 2
            local rad45 = 0.785398
            local angle = AI.GetFacingForPosition(AI.GetPosition("target"))
            local angles = {angle - rad45, angle, angle + rad45}
            local points = {}
            for i, a in ipairs(angles) do
                if a > pi2 then
                    a = a - pi2
                elseif a < 0.0 then
                    a = a + pi2
                end
                local r = 13
                local x, y = r * math.cos(a), r * math.sin(a)
                local cX, cY = AI.GetPosition()
                local nX, nY = cX + x, cY + y
                table.insert(points, {
                    x = nX,
                    y = nY
                })
            end
            local p = self.findClosestPointInList(points)
            AI.SetMoveToPosition(p.x, p.y)
        end
    end
end

AI.RegisterBossModule(vezax)

-- twilight adherent
local twilightAdherent = MosDefBossModule:new({
    name = "Twilight Adherent",
    creatureId = {33818, 33822, 33819, 33820, 33824, 33838},
    onStart = function(self)
        TargetUnit("twilight frost mage")
        FocusUnit("target")
    end,
    onStop = function(self)
    end,
    onUpdate = function(self)
        if AI.IsValidOffensiveUnit("focus") and UnitName("focus") == "Twilight Frost Mage" then
            -- fear is causing them to run into other mods
            if AI.IsWarlock() then
                AI.RegisterPendingAction(function()
                    if UnitName("focus") ~= "Twilight Frost Mage" then
                        return true
                    end
                    if UnitName("target") ~= UnitName("focus") and not AI.HasMyDebuff("fear", "focus") and
                        not AI.HasDebuff("hex", "focus") then
                        return AI.CastSpell("fear", "focus")
                    end
                end, 5, "CC_ADHERENT")
            end

            if AI.IsDps() and AI.IsShaman() then
                AI.RegisterPendingAction(function()
                    if UnitName("focus") ~= "Twilight Frost Mage" then
                        return true
                    end
                    if UnitName("target") ~= UnitName("focus") and not AI.HasMyDebuff("hex", "focus") and
                        not AI.HasDebuff("fear", "focus") then
                        return AI.CastSpell("hex", "focus")
                    end
                end, null, "CC_ADHERENT")
            end
        end
    end
})
AI.RegisterBossModule(twilightAdherent)

--
local chamberOverseer = MosDefBossModule:new({
    name = "Chamber Overseer",
    creatureId = {34197},
    onStart = function(self)
    end,
    onStop = function(self)
    end,
    onUpdate = function(self)
        local devices = AI.FindNearbyObjectsByName("displacement")
        if #devices > 0 and not AI.IsTank() then
            if devices[1].distance <= 5 then
                -- print("Displacement Device on me")
                local facing = GetPlayerFacing() + math.pi
                if facing > math.pi * 2 then
                    facing = facing - math.pi * 2
                end
                AI.SetFacing(facing)
                MoveForwardStart()
            end
        end
    end
})

AI.RegisterBossModule(chamberOverseer)

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
            if not AI.IsValidOffensiveUnit() then
                TargetNearestEnemy()
            end
            return false
        end
    end,
    onStop = function(self)
        AI.ALLOW_AUTO_REFACE = true
        AI.do_PriorityTarget = oldPriorityTargetFn
    end,
    onUpdate = function(self)
        if AI.IsDps() then
            local healer = AI.GetPrimaryHealer()
            if healer and AI.GetDistanceTo(AI.GetPosition(healer)) > 1 then
                if AI.IsCasting() then
                    AI.StopCasting()
                end
                -- print("too far from healer, moving towards")
                AI.SetMoveToPosition(AI.GetPosition(healer))
            end
        end

        if AI.IsPriest() then
            local criticalTarget, missingHp = AI.GetMostDamagedFriendly("power word: shield")
            if criticalTarget and AI.GetUnitHealthPct(criticalTarget) <= 40 and
                not AI.HasDebuff("weakened soul", criticalTarget) then
                if AI.IsCasting() then
                    AI.StopCasting()
                end
                if AI.CastSpell("power word: shield", criticalTarget) then
                    return true
                end
            end
        end
        return false
    end
})

function mimiron:SPELL_CAST_SUCCESS(args)
    if args.spellId == 63414 or args.spellName == "spinning up" then
        if AI.IsTank() and AI.IsValidOffensiveUnit() then
            AI.SayRaid("Mimiron is spinning up")
            local pi2 = math.pi * 2
            local target = GetObjectInfo("target")
            if target.facing ~= nil then
                local angleBehind = target.facing + math.pi
                if angleBehind > pi2 then
                    angleBehind = angleBehind - pi2
                elseif angleBehind < 0.0 then
                    angleBehind = angleBehind + pi2
                end
                local r = 2
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
            TargetUnit("Constrictor")
            if AI.IsValidOffensiveUnit() and UnitName("target") == "Constrictor Tentacle" and AI.CanHitTarget() then
                return true
            end
            TargetUnit("Corruptor Tentacle")
            if AI.IsValidOffensiveUnit() and UnitName("target") == "Corruptor Tentacle" and AI.CanHitTarget() then
                return true
            end
            TargetUnit("Crusher Tentacle")
            if AI.IsValidOffensiveUnit() and UnitName("target") == "Crusher Tentacle" and AI.CanHitTarget() then
                return true
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
    end,
    onEnd = function(self)
        AI.do_PriorityTarget = oldPriorityTargetFn
    end,
    onUpdate = function(self)
        if AI.HasBuff("flash freeze") then
            return true
        end
        if self.phase == 2 then
            if self:isDescentTeam() then
                if self.portalToUse and AI.GetDistanceTo(self.portalToUse.x, self.portalToUse.y) <= 5 then
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
                    AI.GetDistanceTo(self.portalToUse.x, self.portalToUse.y) <= 5 then
                    print("taking escape portal")
                    self.portalToUse:Interact()
                    self.portalToUse = nil
                    self.usedDescentPortal = false
                    self.illusionShattered = false
                    AI.ResetMoveToPosition()
                    AI.StopMoving()
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
    end,
    phase = 1,
    descentDps1 = "mosdeflocka",
    descentDps2 = "mosdefswp",
    portalToUse = nil,
    illusionShattered = false,
    usedDescentPortal = false,
    isDescentTeam = function(self)
        return UnitName("player"):lower() == self.descentDps1 or UnitName("player"):lower() == self.descentDps2
    end
})

function yoggSaron:CHAT_MSG_MONSTER_YELL(text, monster)
    if MaloWUtils_StrContains(text:lower(), "lucid dream") then
        self.phase = 2
        print("Entering phase 2")
    end

    if MaloWUtils_StrContains(text:lower(), "true face of death") then
        self.phase = 3
        print("Entering phase 3")
        if self:isDescentTeam() and self.usedDescentPortal then
            local escapePortal = AI.FindNearbyObjectsByName("flee to the surface")
            if #escapePortal > 0 then
                self.portalToUse = escapePortal[1]
                if AI.GetDistanceTo(escapePortal[1]) > 5 then
                    print("moving to escape portal");
                    AI.SetMoveToPosition(escapePortal[1].x, escapePortal[1].y)
                end
            end
        end
        AI.RegisterPendingAction(function()
            local tank = AI.GetPrimaryTank()
            if not AI.IsTank() then
                AI.SetMoveToPosition(AI.GetPosition(tank))
            end
            return true
        end, 5, "GROUP_UP")
    end
end

function yoggSaron:CHAT_MSG_RAID_BOSS_EMOTE(s, t)
    if MaloWUtils_StrContains(s, "illusion shatters") then
        print("illusion shattered")
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
        self.usedDescentPortal = false
        self.illusionShattered = false
        if self:isDescentTeam() then
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
                if UnitName("player"):lower() == self.descentDps1 and not AI.HasMoveToPosition() then
                    local portal = portals[1]
                    self.portalToUse = portal
                    if AI.GetDistanceTo(portal.x, portal.y) > 4 then
                        print("dps1 moving to brain portal")
                        AI.SetMoveToPosition(portal.x, portal.y)
                    end
                end
                if UnitName("player"):lower() == self.descentDps2 and not AI.HasMoveToPosition() then
                    local portal = portals[2]
                    self.portalToUse = portal
                    AI.RegisterPendingAction(function()
                        AI.CastSpell("power word: shield", "player")
                        if AI.GetDistanceTo(portal.x, portal.y) > 4 then
                            print("dps2 moving to brain portal")
                            AI.SetMoveToPosition(portal.x, portal.y)
                        end
                        return true
                    end, 10, "MOVE_TO_PORTAL")
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
                            print("using escape portal");
                            AI.ResetMoveToPosition()
                            AI.StopMoving()
                            escapePortal[1]:Interact()
                            mod.usedDescentPortal = false
                            mod.illusionShattered = false
                            return true
                        end, 8, "ESCAPE_BRAIN")
                    end
                end
                return true
            end, 50, "MOVE_TO_ESCAPE_PORTALS")
        end
        if not self:isDescentTeam() then
            local constrictors = AI.FindNearbyObjectsByName("Constrictor")
            if #constrictors == 0 then
                print("no constrictors, moving to sanity well while brain phase")
                local wells = AI.FindNearbyObjectsByName("sanity well")
                if #wells > 0 and not AI.HasMoveToPosition() then
                    AI.SetMoveToPosition(wells[1].x, wells[1].y)
                end
            else
                print("constrictors around, can't move to well yet")
            end
        end
    end
end

function yoggSaron:SPELL_CAST_SUCCESS(args)
    if args.spellName:lower() == "lunatic gaze" then
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
