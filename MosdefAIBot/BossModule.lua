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
    creatureId = {29311},
    onStart = function()
        AI.do_PriorityTarget = function()
            if not AI.IsValidOffensiveUnit() then
                TargetNearestEnemy()
            end
        end
        -- AI.toggleAutoDps(true)
    end,
    onStop = function()
    end,
    onUpdate = function()       
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
                AI.DoTargetChain("Ichor Globule")
                return AI.IsValidOffensiveUnit("target") and AI.GetDistanceToUnit("target") <= 20
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

function Keristrasza:SPELL_AURA_APPLIED(args)
    if strcontains(args.spellName, "Crystallize") and AI.IsPriest() and AI.GetDebuffCount("intense cold") >= 5 then
        AI.RegisterPendingAction(function(self)
            return AI.CastAOESpell("mass dispel", "player")
        end)
    end
end

AI.RegisterBossModule(Keristrasza)

-- Oculus
local leyguardian = MosDefBossModule:new({
    name = "Ley-Guardian Eregos",
    creatureId = {27656},
    onStart = function(self)
        AI.FindNearbyUnitsByName("ley-guardian")[1]:Focus()
        AI.do_PriorityTarget = function()
            return AI.DoTargetChain("Ley-Guardian")
        end
        AI.PRE_DO_DPS = function(isAoe)
            if AI.IsPossessing() then
                local pet = UnitName("playerpet"):lower()
                if pet == "ruby drake" then
                    AI.DoTargetChain("Ley-Guardian")
                    if AI.IsValidOffensiveUnit() and AI.CastVehicleSpellOnTarget("searing wrath", "target") then
                        return true
                    end
                elseif pet == "amber drake" then
                    AI.DoTargetChain("Ley-Guardian")
                    if AI.IsValidOffensiveUnit() then
                        -- StopFollowing()
                        if AI.GetMyDebuffCount("shock charge", "target") < 10 and not AI.IsChanneling("playerpet") then
                            print("shock charge count " .. AI.GetMyDebuffCount("shock charge", "target"))
                            if AI.CastVehicleSpellOnTarget("temporal rift", "target") then
                                print("casting temporal rift")
                                return true
                            end
                        elseif AI.GetMyDebuffCount("shock charge", "target") >= 10 then
                            if AI.IsChanneling("playerpet") or AI.IsChanneling() then
                                print("stopping channeling")
                                AI.StopCasting()
                            end
                            if AI.CastVehicleSpellOnTarget("shock lance", "target") then
                                print("casting shock lance")
                                return true
                            end
                        end
                    end
                elseif pet == "emerald drake" then
                    -- StopFollowing()                    
                    if not AI.IsChanneling("playerpet") then
                        AI.DoTargetChain("Ley-Guardian")
                        if AI.GetMyDebuffCount("leeching poison", "target") > 2 then
                            local mostHurt = AI.GetMostDamagedFriendlyPet()
                            if mostHurt and AI.GetUnitHealthPct(mostHurt) <= 60 and
                                not strcontains(UnitName("target"), UnitName(mostHurt)) then
                                if AI.CastVehicleSpellOnTarget("dream funnel", mostHurt) then
                                    return true
                                end
                            end
                        elseif (AI.GetMyDebuffCount("leeching poison", "target") > 2 and
                            AI.CastVehicleSpellOnTarget("touch the nightmare", "target")) or
                            AI.CastVehicleSpellOnTarget("leeching poison", "target") then
                            return true
                        end
                        return true
                    end
                end
            end
        end
        return true
    end,
    onStop = function(self)
    end,
    onUpdate = function()
        local pet = UnitName("playerpet"):lower()
        AI.FindNearbyUnitsByName("ley-guardian")[1]:Focus()
        if not AI.IsPossessing() then
            return false
        end
        if AI.IsValidOffensiveUnit("target") then
            if pet == "emerald drake" and AI.GetMyDebuffCount("leeching poison", "focus") > 2 then
                local mostHurt = AI.GetMostDamagedFriendlyPet()
                if mostHurt and AI.GetUnitHealthPct(mostHurt) <= 90 then
                    if UnitName("target") ~= mostHurt then
                        TargetUnit(mostHurt)
                    end
                    if AI.CastVehicleSpellOnTarget("dream funnel", "target") then
                        return true
                    end
                end
            end
        end
    end
})

function leyguardian:SPELL_AURA_APPLIED(args)
    if strcontains(args.spellName, "enraged assault") and AI.IsDps() then
        local delay = 0
        if AI.IsDpsPosition(1) then
            delay = 0
        elseif AI.IsDpsPosition(2) then
            delay = 2
        else
            delay = 3
        end
        AI.RegisterPendingAction(function()
            AI.FindNearbyUnitsByName("ley-guardian")[1]:Focus()
            if not AI.HasPossessionSpellCooldown("stop time") then
                print("time stopping leyguardian")
                if AI.IsCasting("playerpet") or AI.IsChanneling("playerpet") then
                    AI.StopCasting()
                end
                return AI.CastVehicleSpellOnTarget("stop time", "player")
            end
            return true
        end, delay, "TIME_STOP")
    end
end

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
        AI.DISABLE_CDS = AI.IsValidOffensiveUnit() and
                             (not strcontains(UnitName("target"), "shadron") and
                                 not strcontains(UnitName("target"), "vesperon") and
                                 strcontains(UnitName("target"), "tenebron"))
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
