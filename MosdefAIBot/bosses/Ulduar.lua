local oldPriorityTargetFn = nil

-- ulduar
local ulduar = MosdefZoneModule:new({
    zoneName = "Ulduar",
    zoneId = 530,
    onEnter = function(self)
        AI.PRE_DO_DPS = function(isAoE)
            if AI.IsPossessing() then
                local vehicle = UnitName("playerpet"):lower()
                if vehicle == "salvaged siege turret" and AI.UsePossessionSpell("fire cannon") then
                    return
                end
                if vehicle == "salvaged siege engine" and AI.IsValidOffensiveUnit() and
                    CheckInteractDistance("target", 3) and AI.UsePossessionSpell("ram") then
                    return
                end
                if vehicle == "salvaged demolisher" and AI.UsePossessionSpell("hurl boulder") then
                    return
                end
                if vehicle == "salvaged demolisher mechanic seat" and AI.UsePossessionSpell("mortar") then
                    return
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
            if AI.HasDebuff("pursued", "playerpet") and self.pursuedTarget ~= UnitName("playerpet") then
                self.pursuedTarget = UnitName("playerpet")
            end

            local pet = UnitName("playerpet") or ""
            if pet == self.pursuedTarget and not AI.HasMoveToPosition() then
                local nextWp = self.kitingCoords[self.currentCoord]
                AI.SetMoveToPosition(nextWp.x, nextWp.y)
                -- AI.SayRaid(pet .. " moving to next wp " .. self.currentCoord)
                self.currentCoord = self.currentCoord + 1
                if self.currentCoord > 6 then
                    self.currentCoord = 1
                end
            end

            local vehicle = (UnitName("playerpet") or ""):lower()

            if AI.HasDebuff("pursued", "playerpet") and AI.FindPossessionSpellSlot("steam rush") ~= nil and
                AI.UsePossessionSpell("steam rush") then
                return true
            end
            if AI.HasDebuff("pursued", "playerpet") and AI.FindPossessionSpellSlot("increase speed") and
                AI.UsePossessionSpell("increase speed") then
                return true
            end
            if AI.HasDebuff("pursued", "playerpet") and AI.FindPossessionSpellSlot("speed boost") and
                AI.UsePossessionSpell("speed boost") then
                return true
            end

            if vehicle == "salvaged demolisher" then
                if UnitPower("playerpet") <= 25 then
                    TargetUnit("liquid pyrite")
                end
                if UnitName("target") == "Liquid Pyrite" and self.lastGrabTime < GetTime() and
                    AI.UsePossessionSpell("grab crate", "target") then
                    -- AI.SayRaid("Grabbing pyrite")
                    self.lastGrabTime = GetTime() + 2
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
        if args.spellName:lower() == "pursued" and args.target == UnitName("playerpet") then
            -- AI.SayRaid("Im being pursued, running away!!!")
            self.pursuedTarget = UnitName("playerpet")
        end

        if args.spellName:lower() == "battery ram" and args.target == UnitName("playerpet") then
            if AI.FindPossessionSpellSlot("shield generator") ~= nil then
                AI.UsePossessionSpell("shield generator")
            end
        end
    end
end

function flameLeviathan:SPELL_DAMAGE(args)
    if AI.IsPossessing() then
        if args.spellName:lower() == "flame vents" and args.target == UnitName("playerpet") then
            if AI.FindPossessionSpellSlot("shield generator") ~= nil then
                AI.UsePossessionSpell("shield generator")
            end
        end
    end
end

function flameLeviathan:SPELL_AURA_REMOVED(args)
    if args.spellName:lower() == "pursued" and args.target == UnitName("playerpet") then
        -- AI.SayRaid("I'm no longer being pursued")
        self.pursuedTarget = nil
        if AI.HasMoveToPosition() then
            AI.ResetMoveToPosition()
            AI.StopMoving()
        end
    end
end

AI.RegisterBossModule(flameLeviathan)

-- ignis

local ignis = MosDefBossModule:new({
    name = "Ignis The Furnace Master",
    creatureId = {33118},
    onStart = function(self)
        oldPriorityTargetFn = AI.do_PriorityTarget
        AI.do_PriorityTarget = function()
            if UnitName("focus") ~= "Iron Construct" then
                TargetUnit("Iron Construct")
                if UnitName("target") == "Iron Construct" then
                    FocusUnit("target")
                end
            end
            TargetUnit("Ignis")
        end
    end,
    onEnd = function(self)
        if oldPriorityTargetFn ~= nil then
            AI.do_PriorityTarget = oldPriorityTargetFn
        end
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
    end,
    onStop = function(self)
    end,
    onUpdate = function(self)
        if self.gripTarget ~= nil and UnitName("target") ~= "Right Arm" then
            TargetUnit("right arm")
        end
        if AI.IsValidOffensiveUnit() and AI.GetTargetStrength() > 3 and AI.GetUnitHealthPct("target") < 90 then
            if AI.IsShaman() and AI.CastSpell("fire elemental totem") then
                return true
            end
        end
    end,
    gripTarget = nil
})

function kologarn:SPELL_AURA_APPLIED(args)
    if args.spellName:lower() == "stone grip" and args.target == UnitName("player") then
        -- AI.SayRaid("I'm gripped")
        self.gripTarget = UnitName("player")
    end
end

function kologarn:SPELL_AURA_REMOVED(args)
    if args.spellName:lower() == "stone grip" then
        self.gripTarget = nil
    end
end

AI.RegisterBossModule(kologarn)

-- razorscale
local razorscale = MosDefBossModule:new({
    name = "Razorscale",
    creatureId = {33186},
    onStart = function(self)
        AI.DISABLE_CDS = true
    end,
    onStop = function(self)
        AI.DISABLE_CDS = false
    end,
    onUpdate = function(self)
        if AI.IsValidOffensiveUnit() then
            if UnitName("target") == "Razorscale" then
                AI.DISABLE_CDS = false
                if AI.IsShaman() and AI.GetUnitHealthPct("target") <= 70 and AI.CanCastSpell("fire elemental totem") then
                    AI.RegisterPendingAction(function()
                        return AI.CastSpell("fire elemental totem")
                    end, null, "FIRE_ELEMENTAL")
                end
            else
                AI.DISABLE_CDS = true
            end
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
    creatureId = {32865, 32882},
    onStart = function(self)
        oldPriorityTargetFn = AI.do_PriorityTarget
        AI.do_PriorityTarget = function()
            if not AI.IsWarlock() then
                TargetUnit("dark rune evoker")
                if AI.IsValidOffensiveUnit() and not AI.CanHitTarget("target") then
                    TargetNearestEnemy()
                end
            else
                TargetNearestEnemy()
            end
            return AI.IsValidOffensiveUnit() and AI.CanHitTarget("target")
        end
    end,
    onStop = function(self)
        if oldPriorityTargetFn ~= nil then
            AI.do_PriorityTarget = oldPriorityTargetFn
        end
    end
})

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

