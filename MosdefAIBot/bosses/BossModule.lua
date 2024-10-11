-- boss module base
MosDefBossModule = {
    name = "",
    creatureId = {},
    enabled = false,
    onStart = function()
        AI.Print("onStart filler")
    end,
    onStop = function()
        AI.Print("onStop filler")
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

            if AI.IsValidOffensiveUnit("target") then
                return true
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
    onStart = function()
        AI.Print("Engaging Keristrasza")
    end,
    onStop = function()
    end,
    onUpdate = function()
        -- jump when we have more than 2 stacks of intense cold
        if AI.GetDebuffCount("intense cold") >= 2 then
            JumpOrAscendStart()
        end
        return false
    end
})

AI.RegisterBossModule(Keristrasza)

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
            TargetUnit("Sartharion")

            if AI.IsValidOffensiveUnit("target") then
                return true
            end

            return false
        end
    end,
    onStop = function()
        -- AI.Print("Sartharion done")
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
            else
                return false
            end
            return false
        end

        if not AI.IsTank() then
            if AI.IsValidOffensiveUnit("target") and UnitName("target"):lower() == "vesperon" then
                AI.SetMoveToPosition(self.vespPortalX, self.vespPortalY)
            end
            if AI.IsValidOffensiveUnit("target") and UnitName("target"):lower() == "shadron" then
                AI.SetMoveToPosition(self.shadronPortalX, self.shadronPortalY)
            end
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

