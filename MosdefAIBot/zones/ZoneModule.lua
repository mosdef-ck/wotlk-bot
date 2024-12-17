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
                if pet == "ruby drake" and AI.UsePossessionSpell("searing wrath", "target") then
                    return
                elseif pet == "amber drake" and AI.UsePossessionSpell("shock lance", "target") then
                    return
                elseif pet == "emerald drake" and AI.UsePossessionSpell("leeching poison", "target") then
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
        AI.PRE_DO_DPS = nil
        if self.oldMountMethod ~= nil then
            AI.DO_MOUNT = self.oldMountMethod
        end
    end
})
AI.RegisterZoneModule(oculus)

