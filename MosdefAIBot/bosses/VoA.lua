local rad45 = 0.785398
local rad90 = 1.570796
local rad22_5 = 0.3926991
local rad10 = 0.1745329
local pi2 = math.pi *2
local oldPriorityTargetFn = nil

local stoneWarder = MosDefBossModule:new({
    name = "Archavon Warder",
    creatureId = {32353}
})

function stoneWarder:SPELL_AURA_APPLIED(args)
    if not AI.IsTank() and args.target == UnitName("player") and args.spellName:lower() == "rock shower" then
        for i, unit in ipairs(AI.GetRaidOrPartyMemberUnits()) do
            if UnitIsPlayer(unit) and not AI.HasDebuff("rock shower", unit) and not AI.IsTanking(unit, "target") then
                local x, y = AI.GetPosition(unit)
                AI.SetMoveToPosition(x, y)
                break
            end
        end
    end
end

AI.RegisterBossModule(stoneWarder)

--
local archavon = MosDefBossModule:new({
    name = "Archavon The Stone Watcher",
    creatureId = {31125},
    impaledTarget = nil,
    shardTarget = nil,
    onStart = function(self)
    end,
    onStop = function(self)
    end,
    onUpdate = function(self)
        if AI.IsHealer() and self.shardTarget ~= nil or self.impaledTarget ~= nil then
            if AI.GetUnitHealthPct(self.shardTarget or self.impaledTarget) <= 80 and
                AI.CastSpell("lesser healing wave", self.shardTarget or self.impaledTarget) then
                return true
            end
        end
        if AI.IsTank() and AI.HasBuff("enrage", "target") and AI.CastSpell("Hand of Reckoning", "target") then
            return true
        end
        if AI.IsShaman() and AI.IsValidOffensiveUnit() and AI.GetUnitHealthPct("target") < 90 and
            AI.CastSpell("fire elemental totem") then
            return true
        end
        return false
    end
})

function archavon:SPELL_AURA_APPLIED(args)
    if args.spellName:lower() == "rock shards" then
        self.shardTarget = args.target
    end
    if args.spellName:lower() == "impale" then
        AI.SayRaid("I'm impaled")
        self.impaledTarget = args.target
    end
end

function archavon:SPELL_AURA_REMOVED(args)
    if args.spellName:lower() == "rock shards" then
        self.shardTarget = nil
    end
    if args.spellName:lower() == "impale" then
        self.impaledTarget = nil
    end
end

AI.RegisterBossModule(archavon)

-- emalon
local emalon = MosDefBossModule:new({
    name = "Emalon the Storm Watcher",
    creatureId = {33993},
    onStart = function(self)
        AI.DISABLE_DRAIN = true
        if UnitName("target") ~= "Emalon the Storm Watcher" then
            TargetUnit("emalon")
        end
        local tX, tY = AI.GetPosition(AI.GetPrimaryTank())
        local pX, pY = AI.GetPosition("player")
        local r = 18
        local theta = AI.CalcFacing(tX, tY, pX, pY)
        if AI.IsHealer() or AI.IsDps() then
            AI.RegisterPendingAction(function()
                if AI.IsHealer() then
                    AI.SetMoveTo(tX + r * math.cos(theta), tY + r * math.sin(theta))
                end
                if AI.IsDpsPosition(1) then
                    theta = theta + rad90 * 1
                    AI.SetMoveTo(tX + r * math.cos(theta), tY + r * math.sin(theta))
                end
                if AI.IsDpsPosition(2) then
                    theta = theta + rad90 * 2
                    AI.SetMoveTo(tX + r * math.cos(theta), tY + r * math.sin(theta))
                end
                if AI.IsDpsPosition(3) then
                    theta = theta + rad90 * 3
                    AI.SetMoveTo(tX + r * math.cos(theta), tY + r * math.sin(theta))
                end
                return true
            end, 1, "MOVE_TO_BATTLESTATIONS")
        end
    end,
    onEnd = function(self)
        AI.DISABLE_DRAIN = false
    end,
    onUpdate = function(self)
        if AI.IsPriest() then
            if AI.IsUnitValidFriendlyTarget(AI.Config.tank) and AI.GetUnitHealthPct(AI.Config.tank) <= 50 and
                not AI.HasDebuff("weakened soul", AI.Config.tank) and AI.CastSpell("power word: shield", AI.Config.tank) then
                return true
            end
        end
    end,
    cinderSpots = {}
})

function emalon:SPELL_CAST_START(args)
    if not AI.IsTank() and args.spellName:lower() == "lightning nova" then
        if UnitName("target") ~= "Emalon the Storm Watcher" then
            TargetUnit("emalon")
        end
        if AI.GetDistanceTo("target") <= 18 then
            local tX, tY = AI.GetPosition("target")
            local facing = AI.GetFacingForPosition(AI.GetPosition("target")) + math.pi
            local r = 18
            local nX, nY = tX + r * math.cos(facing), tY + r * math.sin(facing)
            AI.SetMoveTo(nX, nY, null, function()
                AI.SetFacingUnit("target")
            end)
        end
    end
end

AI.RegisterBossModule(emalon)

local koralon = MosDefBossModule:new({
    name = "Koralon the Flame Watcher",
    creatureId = {35013},
    onStart = function(self)
        if not AI.IsValidOffensiveUnit() then
            TargetUnit("koralon")
        end
        local tX, tY = AI.GetPosition(AI.GetPrimaryTank())
        local r = 13
        local theta = AI.CalcFacing(tX, tY, AI.GetPosition("player"))
        if AI.IsTank() then
            AI.RegisterPendingAction(function()
                return AI.CastSpell("hand of salvation", AI.GetPrimaryHealer())
            end, null)
        end
        if AI.IsHealer() or AI.IsDps() then
            AI.RegisterPendingAction(function()
                if AI.IsHealer() then
                    AI.SetMoveTo(tX + r * math.cos(theta), tY + r * math.sin(theta))
                end
                if AI.IsDpsPosition(1) then
                    theta = theta + rad90 * 1
                    AI.SetMoveTo(tX + r * math.cos(theta), tY + r * math.sin(theta))
                end
                if AI.IsDpsPosition(2) then
                    theta = theta + rad90 * 2
                    AI.SetMoveTo(tX + r * math.cos(theta), tY + r * math.sin(theta))
                end
                if AI.IsDpsPosition(3) then
                    theta = theta + rad90 * 3
                    AI.SetMoveTo(tX + r * math.cos(theta), tY + r * math.sin(theta))
                end
                return true
            end, 1, "MOVE_TO_BATTLESTATIONS")
        end
    end,
    onStop = function(self)
    end,
    onUpdate = function(self)
        for i = #self.cinderSpots, 1, -1 do
            if GetTime() > self.cinderSpots[i].time + 20 then
                table.remove(self.cinderSpots, i)
            end
        end
    end,
    cinderSpots = {},
    isSpotSafeFromOtherCinders = function(x, y, cinderlist)
        local pX, pY = AI.GetPosition("player")
        for i, o in ipairs(cinderlist) do
            if AI.CalcDistance(x,y, o.x, o.y) <= 8 then
                return false                            
            end
        end
        return true
    end,
    findClosestPointInList = function(pointList)
        local dist = 100
        local point = nil
        for i, d in ipairs(pointList) do
            if AI.GetDistanceTo(d.x, d.y) < dist then
                point = d
                dist = AI.GetDistanceTo(d.x, d.y)
            end
        end
        return point
    end
})

function koralon:SPELL_AURA_APPLIED(args)
    if args.spellName == "Flaming Cinder" then
        local tX, tY = AI.GetPosition(args.target)
        table.insert(self.cinderSpots, {
            x = tX,
            y = tY,
            time = GetTime()
        })

        if args.target == UnitName("player") and not AI.HasMoveTo() and not AI.IsTank() then
            local tX, tY = AI.GetPosition(AI.GetPrimaryTank())
            local x, y = AI.GetPosition("player")
            local theta = AI.CalcFacing(tX, tY, x, y)
            local points = {}
            for angle = theta, theta + pi2, (rad10/2) do
                if angle > pi2 then
                    angle = angle - pi2
                elseif angle < 0 then
                    angle = angle + pi2
                end
                for r = 3, 13, 1 do
                    local nX, nY = tX + r * math.cos(angle), tY + r * math.sin(angle)
                    if self.isSpotSafeFromOtherCinders(nX, nY, self.cinderSpots) then
                        table.insert(points, {
                            x = nX,
                            y = nY
                        })
                    end
                end
            end
            if #points > 0 then
                local p = self.findClosestPointInList(points)
                AI.SetMoveTo(p.x, p.y)
            end
        end
        
    end
end

AI.RegisterBossModule(koralon)
