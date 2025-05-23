local rad45 = 0.785398
local rad90 = 1.570796
local rad22_5 = 0.3926991
local rad10 = 0.1745329
local rad5 = rad10 / 2
local rad025 = rad5 / 2
local pi2 = math.pi * 2
local oldPriorityTargetFn = nil

local stoneWarder = MosDefBossModule:new({
    name = "Archavon Warder",
    creatureId = {32353},
    onUpdate = function(self)
        if AI.HasDebuff("rock shower") then
            local allies = AI.GetRaidOrPartyMemberUnits()
            for i,a in ipairs(allies) do
                if not AI.HasDebuff("rock shower", a) and not AI.HasMoveTo() then
                    local ax,ay = AI.GetPosition(a)
                    AI.MoveTo(ax, ay)
                end        
            end    
        end
    end,
    onStop = function(self)
    end
})

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
        -- AI.DISABLE_DRAIN = true
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
    end,
    onUpdate = function(self)
        if AI.IsPriest() then
            if AI.IsUnitValidFriendlyTarget(AI.Config.tank) and AI.GetUnitHealthPct(AI.Config.tank) <= 50 and
                not AI.HasDebuff("weakened soul", AI.Config.tank) and AI.CastSpell("power word: shield", AI.Config.tank) then
                return true
            end
        end
    end,
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
        AI.Config.startHealOverrideThreshold = 95
        if not AI.IsValidOffensiveUnit() then
            TargetUnit("koralon")
        end
        local tX, tY = AI.GetPosition(AI.GetPrimaryTank())
        local r = 10
        local theta = AI.CalcFacing(tX, tY, AI.GetPosition("player"))
        if AI.IsTank() then
            AI.MustCastSpell("hand of salvation", AI.GetPrimaryHealer())
        end
        if not AI.IsTank() then
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
        if AI.HasDebuff("flaming cinder") and not AI.HasMoveTo() and not AI.IsTank() then
            local p = self:findSafeSpot()
            --print("safe spot "..table2str(p))
            if p then
                AI.SetMoveTo(p.x, p.y)
            end 
        end
        -- if AI.IsHealer() and self.meteorFistsTarget then
        --     if AI.IsShaman() and AI.DoCastSpellChain(self.meteorFistsTarget, "riptide", "chain heal") then
        --         return true
        --     end
        -- end
    end,
    isSpotSafeFromCinders = function(x, y, cinderlist)
        for i, o in ipairs(cinderlist) do            
            if AI.CalcDistance(x, y, o.x, o.y) <= (o.radius *2) then --add 2.0 to the radius to account for weird aoes that still hit you despite being the radius away
                return false
            end
        end
        return true
    end,
    findClosestPointInList = function(pointList)
        local dist = 100
        local point = nil
        for i, d in ipairs(pointList) do
            if AI.GetDistanceTo(d.x, d.y) <= dist then
                point = d
                dist = AI.GetDistanceTo(d.x, d.y)
            end
        end
        return point
    end,
    findSafeSpot = function(self)
        local tankX, tankY = AI.GetPosition(AI.GetPrimaryTank())
        local cinders = AI.FindNearbyDynamicObjects("flaming cinder")
        --print(table2str(cinders))
        local x, y, z = AI.GetPosition("player")
        local theta = AI.CalcFacing(tankX, tankY, x, y)
        local points = {}        
        for angle = theta - math.pi, theta + math.pi, rad5 do
            local nAngle = normalizeAngle(angle)
            for r = 1, 10, 1 do
                local nX, nY = tankX + r * math.cos(nAngle), tankY + r * math.sin(nAngle)
                if self.isSpotSafeFromCinders(nX, nY, cinders) then
                    table.insert(points, {
                        x = nX,
                        y = nY,
                        z = z
                    })
                end
            end
        end
        if #points > 0 then
            return self.findClosestPointInList(points)
        end
        return nil
    end,
    meteorFistsTarget = nil,
})

function koralon:SPELL_AURA_APPLIED(args)
    if strcontains(args.spellName, "flaming cinder") and AI.IsPriest() then
    end

    if strcontains(args.spellName, "meteor fists") then
        self.meteorFistsTarget = args.target
        if AI.IsDps() and not AI.HasMoveTo() then
            local x, y = AI.GetPosition(AI.GetPrimaryTank())
            if AI.GetDistanceTo(x, y) > 10 then
                local p = self:findSafeSpot()
                if p then
                    AI.SetMoveTo(p.x, p.y)
                end                                
            end
        end            
    end
end

function koralon:SPELL_AURA_REMOVED(args)
    if strcontains(args.spellName, "meteor fists") then
        self.meteorFistsTarget = nil
    end
end


function koralon:SPELL_DAMAGE(args)
    if args.spellName:lower() == "meteor fists" then
        if AI.IsDps() and not AI.HasMoveTo() then
            local x, y = AI.GetPosition(AI.GetPrimaryTank())
            if AI.GetDistanceTo(x, y) > 10 then
                local p = self:findSafeSpot()
                if p then
                    AI.SetMoveTo(p.x, p.y)
                end                                
            end
        end
        if AI.IsPriest() then
            AI.MustCastSpell("power word: shield", args.target)
        end   
    end
end

AI.RegisterBossModule(koralon)
