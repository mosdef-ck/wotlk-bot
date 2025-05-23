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
    end,
    ON_ADDON_MESSAGE = function(self)
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
            return false
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

-- grand magus
local grandMagus = MosDefBossModule:new({
    name = "Grand Magus Telestra",
    creatureId = {26731},
    onStart = function(self)
    end,
    onEnd = function(self)
    end,
    onUpdate = function(self)
        if AI.IsWarlock() and UnitExists("focus") and AI.IsValidOffensiveUnit("focus") and
            not AI.HasMyDebuff("Fear", "focus") and AI.CastSpell("fear", "focus") then
            -- AI.SayRaid("Fearing " .. UnitName("focus"))
            return true
        end
        return false
    end
})

function grandMagus:SPELL_CAST_START(args)
    if args.spellName == "Critter" then
        TargetUnit(args.caster)
        FocusUnit("target")
        if AI.IsWarlock() and not AI.HasMyDebuff("fear", "focus") then
            AI.RegisterPendingAction(function()
                if UnitName("focus") ~= "Grand Magus Telestra" then
                    TargetUnit("Grand Magus Telestra")
                    FocusUnit("target")
                end
                if AI.CanCastSpell("fear", "focus") then
                    AI.StopCasting()
                end
                return AI.CastSpell("fear", "focus")
            end, null, "CC_THE_CCER")
        end
    end
end
function grandMagus:UNIT_SPELLCAST_START(caster, spellName)
    if spellName == "Critter" then
        TargetUnit(caster)
        FocusUnit("target")
        if AI.IsWarlock() and not AI.HasMyDebuff("fear", "focus") then
            AI.RegisterPendingAction(function()
                if UnitName("focus") ~= "Grand Magus Telestra" then
                    TargetUnit("Grand Magus Telestra")
                    FocusUnit("target")
                end
                if AI.CanCastSpell("fear", "focus") then
                    AI.StopCasting()
                end
                return AI.CastSpell("fear", "focus")
            end, null, "CC_THE_CCER")
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
        AI.PRE_DO_DPS = function(isAoe)
            if AI.IsPossessing() then
                local pet = UnitName("playerpet"):lower()
                if pet == "ruby drake" and AI.IsValidOffensiveUnit() and
                    AI.UsePossessionSpell("searing wrath", "target") then
                    return true
                elseif pet == "amber drake" then
                    if AI.IsValidOffensiveUnit() and MaloWUtils_StrContains(UnitName("target"), "Ley") then
                        if AI.IsCasting("playerpet") then
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
                elseif pet == "emerald drake" and AI.IsValidOffensiveUnit() and not AI.IsCasting("playerpet") and
                    AI.UsePossessionSpell("leeching poison", "target") then
                    return true
                end
            end
        end
        return true
    end,
    onStop = function(self)
    end,
    onUpdate = function()
        if not AI.IsPossessing() then
            return false
        end
        if AI.IsValidOffensiveUnit("target") and MaloWUtils_StrContains(UnitName("target"), "Ley") then
            local pet = UnitName("playerpet"):lower()
            if pet == "emerald drake" and AI.GetMyDebuffCount("leeching poison", "target") > 2 then
                local mostHurt = AI.GetMostDamagedFriendlyPet()
                if mostHurt and AI.GetUnitHealthPct(mostHurt) < 70 then
                    if UnitName("target") ~= mostHurt then
                        TargetUnit(mostHurt)
                    end
                    if AI.UsePossessionSpell("dream funnel", "target") then
                        TargetUnit("Ley")
                        return true
                    end
                end
            end
            if pet == "amber drake" and AI.HasBuff("enraged assault", "target") then
                local delay = 0
                if AI.IsDpsPosition(1) then
                    delay = 0
                elseif AI.IsDpsPosition(2) then
                    delay = 3
                else
                    delay = 6
                end
                AI.RegisterPendingAction(function()
                    if AI.IsValidOffensiveUnit("target") and not AI.HasDebuff("stop time", "target") then
                        return AI.HasPossessionSpellCooldown("stop time") or
                                   AI.UsePossessionSpell("stop time", "target")
                    end
                    return true
                end, delay, "TIME_STOP")
            end
        end
    end
})

AI.RegisterBossModule(leyguardian)

local prophetTharon = MosDefBossModule:new({
    name = "The Prophet Tharon'Ja",
    creatureId = {26632},
    onUpdate = function(self)
        if AI.HasDebuff("Gift of Tharon'ja") then
            if not AI.IsValidOffensiveUnit() then
                TargetUnit("the prophet")
            end
            if AI.IsTank() and not AI.IsTanking("player") and AI.CastSpell("taunt", "target") then
                return true
            end
            if AI.IsTanking("player") and AI.CastSpell("bone armor") then
                return true
            end
            if AI.CastSpell("touch of life", "target") or AI.CastSpell("slaying strike") then
                return true
            end
        end
        return false
    end
})

AI.RegisterBossModule(prophetTharon)

-- Sartharion

local sartharion = MosDefBossModule:new({
    name = "Sartharion",
    creatureId = {28860},
    onStart = function(self)
        AI.do_PriorityTarget = function()
            return AI.DoTargetChain("Acolyte of Vesperon")
        end
    end,
    onEnd = function(self)
    end,
    onUpdate = function(self)
        AI.DISABLE_CDS = AI.IsValidOffensiveUnit() and (not strcontains(UnitName("target"), "shadron") and not strcontains(UnitName("target"), "vesperon") and strcontains(UnitName("target"), "tenebron") )
        if AI.IsDps() and not self.portalOpen then
            local healer = AI.GetPrimaryHealer()
            if AI.GetDistanceToUnit(healer) > 3 then
                local hx, hy = AI.GetPosition(healer)
                AI.SetMoveTo(hx, hy)
            end
        end
    end,
    portalOpen = false
})

function sartharion:CHAT_MSG_RAID_BOSS_EMOTE(s, t)
    if strcontains(s, "vesperon disciple appears") then
        print("vesperon disciple appears")
        self.portalOpen = true
        if AI.IsDps() then
            local portal = AI.FindNearbyUnitsByName("twilight portal")
            if #portal > 0 then
                if portal[1].distance > 3 then
                    AI.SetMoveTo(portal[1].x, portal[1].y, 0.5, function()
                        portal[1]:Interact()
                    end)
                else
                    portal[1]:Interact()
                end
            end
        end
    end
end

function sartharion:CHAT_MSG_MONSTER_EMOTE(s, t)
    if strcontains(s, "vesperon disciple appears") then
        print("vesperon disciple appears")
        self.portalOpen = true
        if AI.IsDps() then
            local portal = AI.FindNearbyUnitsByName("twilight portal")
            if #portal > 0 then
                if portal[1].distance > 3 then
                    AI.SetMoveTo(portal[1].x, portal[1].y, 0.5, function()
                        portal[1]:Interact()
                    end)
                else
                    portal[1]:Interact()
                end
            end
        end
    end
end

AI.RegisterBossModule(sartharion)
