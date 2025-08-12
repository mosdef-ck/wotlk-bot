--
MosdefZoneModule = {
    zoneName = "",
    zoneId = nil,
    onEnter = function(self)
        AI.Print("entering zone " .. self.zoneName)
    end,
    onLeave = function(self)
        AI.Print("leaving zone " .. self.zoneName)
    end
}

function MosdefZoneModule:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self
    return o
end

local oldPriorityTarget = nil

-- 534/Azjol-nerub
local azjobNerub = MosdefZoneModule:new({
    zoneName = "Azjol-Nerub",
    zoneId = 534,
    onEnter = function(self)
        oldPriorityTarget = AI.do_PriorityTarget
        AI.do_PriorityTarget = function()
            TargetUnit("web wrap")
            return AI.IsValidOffensiveUnit("target") and UnitName("target"):lower() == "web wrap"
        end
    end,
    onLeave = function(self)
        AI.do_PriorityTarget = oldPriorityTarget
    end
})

AI.RegisterZoneModule(azjobNerub)

local oculus = MosdefZoneModule:new({
    zoneName = "Oculus",
    zoneId = 529,
    oldMountMethod = nil,
    onEnter = function(self)
        self.oldMountMethod = AI.DO_MOUNT
        AI.PRE_DO_DPS = function(isAoE)
            if AI.IsPossessing() then
                local pet = UnitName("playerpet"):lower()
                if pet == "ruby drake" and AI.CastVehicleSpellOnTarget("searing wrath", "target") then
                    return
                elseif pet == "amber drake" and AI.CastVehicleSpellOnTarget("shock lance", "target") then
                    return
                elseif pet == "emerald drake" and AI.CastVehicleSpellOnTarget("leeching poison", "target") then
                    return
                end
                return true
            end
            return false
        end

        AI.DO_MOUNT = function()
            if not AI.IsPossessing() then
                RunMacroText("/use amber essence")
                RunMacroText("/use ruby essence")
                RunMacroText("/use emerald essence")
            else
                VehicleExit()
            end
        end
    end,
    onLeave = function(self)
        -- print("leaving Oculus, resetting mount method and pre DPS function")
        AI.PRE_DO_DPS = nil
        if self.oldMountMethod ~= nil then
            AI.DO_MOUNT = self.oldMountMethod
        end
    end
})
AI.RegisterZoneModule(oculus)

local toc = MosdefZoneModule:new({
    zoneName = "Trial of the Champion",
    zoneId = 543,
    onEnter = function(self)
        AI.PRE_DO_DPS = function(isAoE)
            if AI.IsPossessing() then
                -- print('PRE-DO-DPS battleWorg')
                local pet = UnitName("playerpet")
                if strcontains(pet, "battleworg") then
                    if not AI.IsTank() then
                        SetFollowTarget(UnitGUID(AI.GetPrimaryTank()))
                    end
                    if AI.GetDistanceToUnit("target") > 5.5 and AI.CastVehicleSpellOnTarget("charge", "target") then
                        return true
                    end
                    if AI.HasBuff("defend", "target") and AI.CastVehicleSpellOnTarget("shield-breaker", "target") then
                        return true
                    end
                    if AI.CastVehicleSpellOnTarget("defend", "player") or
                        AI.CastVehicleSpellOnTarget("thrust", "target") then
                        return true
                    end
                end
            end
            return false
        end
    end,
    onLeave = function(self)
        AI.PRE_DO_DPS = nil
    end
})

function toc:ON_ADDON_MESSAGE(from, cmd, args)
end

AI.RegisterZoneModule(toc)
