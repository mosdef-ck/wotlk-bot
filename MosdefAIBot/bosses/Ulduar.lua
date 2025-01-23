local oldPriorityTargetFn = nil
-- ulduar
local ulduar = MosdefZoneModule:new({
    zoneName = "Ulduar",
    zoneId = 530,
    onEnter = function(self)
        AI.PRE_DO_DPS = function(isAoE)
            if AI.IsPossessing() then
                local vehicle = UnitName("playerpet"):lower()
                if vehicle == "salvaged siege turret" then
                    AI.UsePossessionSpell("fire cannon")
                end
                if vehicle == "salvaged siege engine" and AI.IsValidOffensiveUnit() and
                    CheckInteractDistance("target", 3) then
                    -- AI.UsePossessionSpell("ram")
                end
                if vehicle == "salvaged demolisher" then
                    AI.UsePossessionSpell("hurl boulder")
                end
                if vehicle == "salvaged demolisher mechanic seat" then
                    AI.UsePossessionSpell("mortar")
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
        if AI.IsDps() and AI.IsShaman() then
            TargetUnit("iron mender")
            FocusUnit("target")
        end        
    end,
    onStop = function(self)
    end,
    onUpdate = function(self)                
        if AI.IsDps() and AI.IsShaman() then
            if AI.IsValidOffensiveUnit("focus") and UnitName("focus") == "Iron Mender" and UnitName("target") ~= UnitName("focus") then
                if not AI.HasMyDebuff("hex", "focus") and AI.CastSpell("hex", "focus") then
                    return true
                end
            end
        end
        return false
    end
})
AI.RegisterBossModule(ironMender)

---flame leviathan
local flameLeviathan = MosDefBossModule:new({
    name = "Flame Leviathan",
    creatureId = {33133},
    onStart = function(self)
        table.insert(self.kitingCoords, {
            x = 0.48437607288361,
            y = 0.45492431521416
        })
        table.insert(self.kitingCoords, {
            x = 0.46509671211243,
            y = 0.45603519678116
        })

        table.insert(self.kitingCoords, {
            x = 0.46337622404099,
            y = 0.41991719603539
        })

        table.insert(self.kitingCoords, {
            x = 0.46148499846458,
            y = 0.36728382110596
        })

        table.insert(self.kitingCoords, {
            x = 0.5203600525856,
            y = 0.36551189422607
        })

        table.insert(self.kitingCoords, {
            x = 0.52104651927948,
            y = 0.45636928081512
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
            if vehicle == self.pursuedTarget and not AI.HasMoveToPosition() and vehicle ~= "Salvaged Demolisher" then
                local nextWp = self.kitingCoords[self.currentCoord]
                AI.SetMoveToPosition(nextWp.x, nextWp.y)
                -- AI.SayRaid(pet .. " moving to next wp " .. self.currentCoord)
                self.currentCoord = self.currentCoord + 1
                if self.currentCoord > 6 then
                    self.currentCoord = 1
                end
            end

            if self.pursuedTarget then
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
        end
    end,
    kitingCoords = {},
    currentCoord = 1,
    pursuedTarget = nil,
    lastGrabTime = 0
})

function flameLeviathan:SPELL_AURA_APPLIED(args)
    if AI.IsPossessing() then
        if args.spellName:lower() == "pursued" then
            local target = args.target:lower()
            if target == "salvaged siege turret" then
                self.pursuedTarget = "Salvaged Siege Engine"
            elseif target == "salvaged demolisher mechanic seat" then
                self.pursuedTarget = "Salvaged Demolisher"
            else
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
    if args.spellName:lower() == "pursued" then
        if self.pursuedTarget == UnitName("playerpet") and AI.HasMoveToPosition() then
            AI.ResetMoveToPosition()
            AI.StopMoving()
        end
        self.pursuedTarget = nil
    end
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
        if AI.IsValidOffensiveUnit("focus") and AI.HasBuff("Brittle", "focus") and AI.IsDps() then
            if AI.IsWarlock() and AI.CastSpell("Searing Pain", "focus") then
                return true
            end
            if AI.IsPriest() and AI.CastSpell("Mind Blast", "focus") or AI.CastSpell("mind flay", "focus") then
                return true
            end
            if AI.IsShaman() and AI.CastSpell("lightning bolt", "focus") then
                return true
            end
        end

        if AI.IsValidOffensiveUnit() and AI.GetTargetStrength() > 3 and AI.GetUnitHealthPct("target") < 50 then
            if AI.IsShaman() and AI.CastSpell("fire elemental totem") then
                return true
            end
        end
    end,
    dpsX = 0.38907530903816,
    dpsY = 0.24367982149124
})

function ignis:SPELL_AURA_APPLIED(args)
    if args.spellName:lower() == "slag pot" and args.target == UnitName("player") then
        AI.DISABLE_CDS = true
        if AI.IsWarlock() and AI.HasBuff("demonic circle: summon") then
            AI.RegisterPendingAction(function()
                return AI.CastSpell("demonic circle: teleport")
            end, 1)
        end
    end
end

function ignis:SPELL_AURA_REMOVED(args)
    if args.spellName:lower() == "slag pot" and args.target == UnitName("player") then
        AI.DISABLE_CDS = false
        if AI.IsDps() then
            AI.SetMoveToPosition(self.dpsX, self.dpsY, 0.001)
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
        if AI.IsPriest() then
            AI.RegisterPendingAction(function()
                return AI.CastSpell("power word: shield", args.target)
            end, null, "PWD_")
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
    creatureId = {32865, 32882, 32886 },
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
        if not self.thorimDropped and UnitName("player") == self.follower and GetTime() >
            self.lastFollowerCastTime + 5 then
            FollowUnit(self.gauntletLeader)
            self.lastFollowCheck = GetTime()
        end
    end,
    gauntletLeader = "Mosdeflocka",
    follower = "Mosdefelsham",
    lastFollowerCastTime = GetTime(),
    dpsSpot1X = 0.68881529569626,
    dpsSpot1Y = 0.46194833517075,
    dpsSpot2X = 0.70337265729904,
    dpsSpot2Y = 0.48592105507851,
    dpsSpot3X = 0.69410991668701,
    dpsSpot3Y = 0.50704175233841,
    thorimDropped = false
})

function thorim:SPELL_AURA_APPLIED(args)
    if args.spellName:lower() == "nitro boosts" then
        AI.Print("nitro boosts on "..args.caster)
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
                if AI.IsDpsPosition(1) and AI.GetDistanceTo(self.dpsSpot1X, self.dpsSpot1Y) > 0.003 then
                    AI.SetMoveToPosition(self.dpsSpot1X, self.dpsSpot1Y)
                end
                if AI.IsDpsPosition(2) and AI.GetDistanceTo(self.dpsSpot2X, self.dpsSpot2Y) > 0.003 then
                    AI.SetMoveToPosition(self.dpsSpot2X, self.dpsSpot2Y)
                end
                if AI.IsDpsPosition(3) and AI.GetDistanceTo(self.dpsSpot3X, self.dpsSpot3Y) > 0.003 then
                    AI.SetMoveToPosition(self.dpsSpot3X, self.dpsSpot3Y)
                end
                return true
            end, 5, "MOVE_TO_BATTLEPOSITIONS")
        end
        if AI.IsTank() then
            TargetUnit("Thorim")
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
            if AI.IsWarlock() then
                TargetUnit("Flash Freeze")
                if AI.IsValidOffensiveUnit() and UnitName("target") == "Flash Freeze" and AI.CanHitTarget() then
                    PetAttack()
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
        if AI.IsTank() then
            AI.ALLOW_AUTO_REFACE = true
        end
        AI.PRE_DO_DPS = nil
    end,
    onUpdate = function(self)
        -- if AI.IsDps() and AI.GetDistanceTo(AI.GetPosition(AI.GetPrimaryHealer())) > 0.009 then
        --     AI.SetMoveToPosition(AI.GetPosition(AI.GetPrimaryHealer()))
        -- end
    end
})

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
                end, 3, "CC_MC_UNIT")
            end
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
            shouldNotDps = not AI.HasDebuff("shadow crash") or AI.HasDebuff("mark of the faceless")
            return shouldNotDps
        end
    end,
    onStop = function(self)
        AI.USE_MANA_REGEN = true
        AI.PRE_DO_DPS = nil
    end,
    onUpdate = function(self)
        if UnitName("target") == "General Vezax" then
            local castingSpell = UnitCastingInfo("target")
            if castingSpell ~= nil and castingSpell:lower() == "searing flames" and AI.IsShaman() and
                AI.CastSpell("wind shear", "target") then
                return true
            end
        end
    end,
    dpsX = 0.56397753953934,
    dpsY = 0.50638669729233,
    safeX = 0.54336738586426,
    safeY = 0.49238538742065
})

function vezax:SPELL_AURA_APPLIED(args)
    if args.spellName:lower() == "mark of the faceless" and args.target == UnitName("player") and AI.IsDps() then
        AI.SetMoveToPosition(self.safeX, self.safeY)
    end
end

function vezax:SPELL_AURA_REMOVED(args)
    if args.spellName:lower() == "mark of the faceless" and args.target == UnitName("player") and AI.IsDps() then
        AI.SetMoveToPosition(self.dpsX, self.dpsY)
    end
end

function vezax:SPELL_CAST_START(args)
    if args.spellName:lower() == "searing flames" then
        if AI.IsShaman() and AI.IsDps() then
            AI.RegisterPendingAction(function()
                -- if AI.IsCasting() then
                --     AI.StopCasting()
                -- end
                if UnitName("focus") ~= "General Vezax" then
                    TargetUnit("General Vezax")
                    FocusUnit("target")
                end
                return AI.CastSpell("wind shear", "focus")
                -- return true
            end, null, "INTERRUPT_SEARING_FLAMES")
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
                    if UnitName("target") ~= UnitName("focus") and not AI.HasMyDebuff("fear", "focus") and
                        not AI.HasDebuff("hex", "focus") then
                        return AI.CastSpell("fear", "focus")
                    end
                end, null, "CC_ADHERENT")
            end

            if AI.IsDps() and AI.IsShaman() then
                AI.RegisterPendingAction(function()
                    if UnitName("target") ~= UnitName("focus") and not AI.HasMyDebuff("hex", "focus") and
                        not AI.HasDebuff("fear", "focus") then
                        return AI.CastSpell("hex", "focus")
                    end
                end, 3, "CC_ADHERENT")
            end
        end
    end
})
AI.RegisterBossModule(twilightAdherent)

-- mimiron
local mimiron = MosDefBossModule:new({
    name = "Mimiron",
    creatureId = {33350},
    onStart = function(self)
        if AI.IsTank() then
            AI.ALLOW_AUTO_REFACE = false
        end
    end,
    onStop = function(self)
        AI.ALLOW_AUTO_REFACE = true
    end
})

AI.RegisterBossModule(mimiron)
