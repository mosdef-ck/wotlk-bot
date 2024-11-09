-- boss module base
MosDefBossModule = {
    name = "",
    creatureId = {},
    enabled = false,
    onStart = function()
    end,
    onStop = function()
    end,
    onUpdate = function()
    end,
    RegisterEvent = function(self, evt)
        if type(self.events) ~= "table" then
            self.events = {}
        end
        table.insert(self.events, evt)
    end
}

function MosDefBossModule:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self
    return o
end

local bossTrainingDummyModule = MosDefBossModule:new({
    name = "Boss Training Dummy",
    onStart = function()
        AI.toggleAutoDps(true)
    end,
    onStop = function()
        AI.toggleAutoDps(false)
    end,
    onUpdate = function()
        return true
    end
})

-- AI.RegisterBossModule(bossTrainingDummyModule)

--- DUNGEON BOSSES
local oldPriorityTargetFn = nil

local heraldVolazjModule = MosDefBossModule:new({
    name = "Herald Volazj",
    onStart = function()
        AI.Print("Engaging Herald Volazj")
        oldPriorityTargetFn = AI.do_PriorityTarget
        AI.do_PriorityTarget = function()
            for i = 1, 3 do
                if UnitName("target") == "Herald Volazj" then
                    ClearTarget()
                    TargetNearestEnemy()
                end
            end

            if AI.IsValidOffensiveUnit("target") then
                return true
            end

            TargetUnit("Herald Volazj")

            if AI.IsValidOffensiveUnit("target") then
                return true
            end

            return false
        end
        -- AI.toggleAutoDps(true)
    end,
    onStop = function()
        AI.Print("Herald Volazj is dead!")
        if oldPriorityTargetFn ~= nil then
            AI.do_PriorityTarget = oldPriorityTargetFn
        end
        AI.toggleAutoDps(false)
    end,
    onUpdate = function()
        -- return not AI.IsHealer()
        local class = AI.GetClass():lower()
        if class == "shaman" and AI.IsValidOffensiveUnit("target") and UnitName("target"):lower() ~= "Herald Volazj" and
            AI.CastSpell("fire elemental totem") then
            return true
        end
        return false
    end
})

AI.RegisterBossModule(heraldVolazjModule)

-- Ichoron
local ichoron = MosDefBossModule:new({
    name = "ichoron",
    onStart = function()
        AI.Print("Engaging ichoron")
        oldPriorityTargetFn = AI.do_PriorityTarget
        AI.do_PriorityTarget = function()
            if not AI.IsTank() then
                TargetUnit("Ichor Globule")
                if AI.IsValidOffensiveUnit("target") and CheckInteractDistance("target", 2) then
                    return true
                end
            end
            TargetUnit("ichoron")
            return AI.IsValidOffensiveUnit("target")
        end
    end,
    onStop = function()
        if oldPriorityTargetFn ~= nil then
            AI.do_PriorityTarget = oldPriorityTargetFn
        end
    end,
    onUpdate = function()
        return false
    end
})

AI.RegisterBossModule(ichoron)

---- Sartharion
local sartharionBossMod = MosDefBossModule:new({
    name = "Sartharion",
    safeX = 0.50792020559311,
    safeY = 0.50132244825363,
    onStart = function()
        AI.Print("Engaging Sartharion")
        oldPriorityTargetFn = AI.do_PriorityTarget
        AI.do_PriorityTarget = function()
            if not AI.IsTank() then
                TargetUnit("lava blaze")
                if AI.IsValidOffensiveUnit("target") then
                    return true
                end
            end
            return false
        end
    end,
    onStop = function()
        if oldPriorityTargetFn ~= nil then
            AI.do_PriorityTarget = oldPriorityTargetFn
        end
    end
})

AI.RegisterBossModule(sartharionBossMod)

-- OS
local obsidianSanctum = MosDefBossModule:new({
    name = "Shadron/Tenebron/Vesperon",
    creatureId = {30449, 30452, 30451},
    vespPortalX = 0.53218305110931,
    vespPortalY = 0.60250127315521,
    shadronPortalX = 0.52992987632751,
    shadronPortalY = 0.33822014927864,
    onStart = function(self)
        -- AI.Print("Engaged OS boss")
        oldPriorityTargetFn = AI.do_PriorityTarget
        AI.do_PriorityTarget = function()
            if AI.HasDebuff("twilight shift") then
                TargetUnit("disciple")
                if AI.IsValidOffensiveUnit("target") then
                    return true
                end
                TargetUnit("twilight egg")
                if AI.IsValidOffensiveUnit("target") then
                    return true
                end
            end
            return false
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
AI.RegisterBossModule(obsidianSanctum)

-- grand magus
local grandMagus = MosDefBossModule:new({
    name = "Grand Magus Telestra",
    creatureId = {26731},
    onStart = function(self)
    end,
    onEnd = function(self)
    end,
    onUpdate = function(self)
    end
})

function grandMagus:UNIT_SPELLCAST_START(caster, spellName)
    local class = AI.GetClass():lower()
    if class == "warlock" and spellName == "Critter" then
        if AI.IsCasting() then
            AI.StopCasting()
            AI.StopMoving()
        end
        if not AI.HasMyDebuff("Fear", "target") and AI.CastSpell("fear", caster) then
            AI.SayRaid("Fearing " .. caster)
        end
    end
end

AI.RegisterBossModule(grandMagus)

--
local anomalous = MosDefBossModule:new({
    name = "Anomalus",
    creatureId = {26763},
    onStart = function(self)
        oldPriorityTargetFn = AI.do_PriorityTarget
        AI.do_PriorityTarget = function()
            TargetUnit("chaotic rift")
            return AI.IsValidOffensiveUnit("target") and CheckInteractDistance("target", 4)
        end
    end,
    onStop = function(self)
        if oldPriorityTargetFn ~= nil then
            AI.do_PriorityTarget = oldPriorityTargetFn
        end
    end
})

AI.RegisterBossModule(anomalous)

-- Keristrasza
local Keristrasza = MosDefBossModule:new({
    name = "Keristrasza",
    creatureId = {26723},
    onStart = function()
        AI.Print("Engaging Keristrasza")
    end,
    onStop = function()
    end,
    onUpdate = function()
        -- jump when we have more than 2 stacks of intense cold
        if AI.GetDebuffCount("intense cold") >= 3 and not AI.HasDebuff("crystallize") then
            JumpOrAscendStart()
        end
        return false
    end
})

AI.RegisterBossModule(Keristrasza)

-- Oculus
local leyguardian = MosDefBossModule:new({
    name = "Ley-Guardian Eregos",
    creatureId = {27656},
    onStart = function(self)
        self.oldDpsMethod = AI.DO_DPS
        AI.DO_DPS = function(isAoe)
            if AI.IsPossessing() then
                local pet = UnitName("playerpet"):lower()
                if pet == "ruby drake" and AI.UsePossessionSpell("searing wrath", "target") then
                    return
                elseif pet == "amber drake" then
                    if AI.IsValidOffensiveUnit() and MaloWUtils_StrContains(UnitName("target"), "Ley") then
                        if AI.IsCasting() or AI.IsCasting("playerpet") then
                            return true
                        end
                        if AI.GetMyDebuffCount("shock charge", "target") < 10 and
                            AI.UsePossessionSpell("temporal rift", "target") then
                            return true
                        elseif AI.GetMyDebuffCount("shock charge", "target") >= 10 then
                            if AI.IsCasting("playerpet") then
                                AI.StopCasting()
                            end
                            if AI.UsePossessionSpell("shock lance", "target") then
                                return true
                            end
                        end
                    elseif AI.UsePossessionSpell("shock lance", "target") then
                        return true
                    end
                elseif pet == "emerald drake" and AI.UsePossessionSpell("leeching poison", "target") then
                    return
                end
            else
                self.oldDpsMethod(isAoe)
            end
        end
    end,
    onStop = function(self)
        if self.oldDpsMethod ~= nil then
            AI.DO_DPS = self.oldDpsMethod
        end
    end,
    onUpdate = function()
        if not AI.IsPossessing() then
            return false
        end
        if AI.IsValidOffensiveUnit("target") and MaloWUtils_StrContains(UnitName("target"), "Ley") then
            local pet = UnitName("playerpet"):lower()
            if pet == "emerald drake" and AI.GetMyDebuffCount("leeching poison", "target") > 2 then
                local mostHurt = AI.GetMostDamagedFriendlyPet()
                if mostHurt and AI.GetUnitHealthPct(mostHurt) < 50 then
                    TargetUnit(mostHurt)
                    FocusUnit("target")
                    if AI.UsePossessionSpell("dream funnel", "focus") then
                        return true
                    end
                end
            end
            if pet == "amber drake" and AI.HasBuff("enraged assault", "target") then
                local delay = 0
                if AI.IsPriest() then
                    delay = 0
                elseif AI.IsWarlock() then
                    delay = 3
                else
                    delay = 6
                end
                AI.RegisterPendingAction(function()
                    if AI.IsValidOffensiveUnit("target") and not AI.HasDebuff("stop time", "target") then
                        return AI.HasPossessionSpellCooldown("stop time") or
                                   AI.UsePossessionSpell("stop time", "target")
                    end
                    return false
                end, delay, "TIME_STOP")
            end
        end
    end
})

AI.RegisterBossModule(leyguardian)
