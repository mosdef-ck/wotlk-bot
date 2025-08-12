local lichking = MosDefBossModule:new({
    name = "Lich King",
    id = 36597,
    onStart = function(self)
        AI.Print("Entering Lich King fight")
        AI.RegisterPendingAction(function()
            if AI.IsValidOffensiveUnit("target") and UnitName("target"):lower() == "lich king" then
                AI.SetMoveTo(0, 0) -- Move to the center of the room
            end
        end, 0.1, "MOVE_TO_LICH_KING")
    end,
    onStop = function(self)
        AI.Print("Leaving Lich King fight")
        AI.UnregisterPendingAction("MOVE_TO_LICH_KING")
    end,
    onUpdate = function(self)
    end,
    arenaCenterP = AI.PathFinding.Vector3.new(505.83477783203, -2125.6162109375, 840.85699462891),
    arenaRadiusStart = 64,
    arenaRadiusEnd = 40,
})