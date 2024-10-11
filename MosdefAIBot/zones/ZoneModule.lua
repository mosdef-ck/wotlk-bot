--
MosdefZoneModule = {
	zoneName = "",
	zoneId = nil,
}

function MosdefZoneModule:new(o)
	o = o or {}
	setmetatable(o, self)
	self.__index = self
	return o
end

 local oldPriorityTarget = nil

function MosdefZoneModule:onEnter()
	AI.Print("entering zone ".. self.zoneName)
	oldPriorityTarget = AI.do_PriorityTarget
	AI.do_PriorityTarget = function ()
		TargetUnit("web wrap")
		if not AI.IsValidOffensiveUnit("target") then
			TargetLastEnemy()
		end
	end
end
function MosdefZoneModule:onLeave()
	AI.Print("leaving zone "..self.zoneName)
	AI.do_PriorityTarget = oldPriorityTarget
end


-- 534/Azjol-nerub
local azjobNerub = MosdefZoneModule:new({
	zoneName = "Azjol-Nerub",
	zoneId = 534,
})

AI.RegisterZoneModule(azjobNerub)

