local algalon = MosDefBossModule:new({
    name = "Algalon The Observer",
    creatureId = {32871},
    onStart = function(self)
        if AI.IsTank() then
            AI.ALLOW_AUTO_REFACE = false
        end
        AI.DISABLE_PRIEST_DISPERSION = true
        AI.PRE_DO_DPS = function(isAoE)
            if GetTime() < self.bigBangTime + 8 then
                -- prevent dps when big bang to ensure proper movement
                return true
            end
            if AI.IsDps() and AI.IsValidOffensiveUnit() and AI.GetDistanceToUnit("target") > 35 and not AI.HasMoveTo() and
                GetTime() > self.lastCosmicSmashTime + 5 then
                local obstacles = self:GetObstacles(true)
                local p = AI.PathFinding.FindSafeSpotInCircle("target", 30, obstacles, 5)
                if p then
                    self:MoveSafelyToSpot(p.x, p.y, p.z, true)
                else
                    local tx, ty, tz = AI.GetPosition("target")
                    self:MoveSafelyToSpotWithin(30, tx, ty, tz, false)
                end
            end

            if AI.IsTank() and AI.IsValidOffensiveUnit() and strcontains(UnitName("target"), "collapsing") then
                local info = AI.GetObjectInfo("target")
                if not info or not info.raidTargetIndex then
                    SetRaidTarget("target", 7)
                end
            end
        end
        AI.do_PriorityTarget = function()
            if not AI.IsTank() then
                local stars = AI.FindNearbyUnitsByName("collapsing star")
                for i, o in ipairs(stars) do
                    if not o.isDead and o.raidTargetIndex and o.distance > 10 then
                        o:Target()
                        return true
                    end
                end
            end
            return false
        end

        if AI.IsHeroicRaidOrDungeon() and not AI.HasBuff("lesser flask of resistance") and not AI.IsTank() then
            AI.UseContainerItem("lesser flask of resistance")
        end
    end,
    onEnd = function(self)
        AI.DISABLE_PRIEST_DISPERSION = false
        AI.PRE_DO_DPS = nil
        AI.do_PriorityTarget = nil
        AI.ALLOW_AUTO_REFACE = true
    end,
    onUpdate = function(self)
        if not AI.IsTank() then
            local stars = AI.FindNearbyUnitsByName("collapsing star")
            local blackHoles = self:GetBlackHoles()
            local riskyStars = {}
            for i, o in ipairs(stars) do
                if o.distance <= 15 and not o.isDead and o.health <= 10000 then
                    o.radius = 13
                    table.insert(riskyStars, o)
                end
            end
            if GetTime() > self.lastCosmicSmashTime + 5 and #riskyStars > 0 and not AI.HasMoveTo() then
                local obstacles = self:GetObstacles(true)
                local p = AI.PathFinding.FindSafeSpotInCircle(AI.GetPrimaryTank(), 30, obstacles, 5)
                if p then
                    print('dodging dying collapsing star')
                    if not AI.PathFinding.MoveSafelyTo(p, obstacles) then
                        print('moving directly to dodge star')
                        AI.SetMoveTo(p.x, p.y);
                    end
                else
                    print('no safe spot from dying collapsing star')
                end
            end
        end

    end,
    cachedBlackHoles = nil,
    bigBangTime = 0,
    isPhasedPunched = false,
    lastCosmicSmashTime = 0
})

function algalon:ON_ADDON_MESSAGE(from, cmd, params)
    if from ~= UnitName("player") and cmd == "move-to" then
        if not AI.IsTank() then
            print("received move-to from " .. from .. " with params: " .. params)
            local p = AI.PathFinding.Vector3.new(splitstr3(params, ","))
            local obstacles = self:GetObstacles(true)
            table_removeif(obstacles, function(o)
                return strcontains(o.name, "stalker asteroid")
            end)
            AI.PathFinding.MoveSafelyTo(p, obstacles)
        end
    end
end

function algalon:MoveSafelyToSpotWithin(r, tx, ty, tz, ignoreBlackHoles, force)
    local x, y = AI.GetPosition()
    local facing = AI.CalcFacing(tx, ty, x, y)
    if AI.CalcDistance(x, y, tx, ty) > r then
        local nx, ny = tx + r * math.cos(facing), ty + r * math.sin(facing)
        return self:MoveSafelyToSpot(nx, ny, tz, ignoreBlackHoles, force)
    else
        AI.StopMoving()
    end
    return true
end

function algalon:MoveSafelyToSpot(tx, ty, tz, ignoreBlackholes, force)
    local startp = AI.PathFinding.Vector3.new(AI.GetPosition())
    local endp = AI.PathFinding.Vector3.new(tx, ty, tz)
    local obstacles = self:GetObstacles(not ignoreBlackholes)
    if not AI.PathFinding.MoveSafelyTo(endp, obstacles) and force then
        AI.SetMoveTo(tx, ty)
    end
    return false
end

function algalon:CHAT_MSG_RAID_BOSS_EMOTE(s)
    if strcontains(s, "cosmic smash") then
        self.lastCosmicSmashTime = GetTime()
        print("cosmic smash coming")
        AI.StopMoving()
        AI.RegisterOneShotAction(function(self)
            if AI.IsHealer() or AI.IsTank() then
                local obstacles = self:GetObstacles(true)
                local p = AI.PathFinding.FindSafeSpotInCircle(AI.GetPrimaryTank(), 30, obstacles, 3)
                if p then
                    table_removeif(obstacles, function(o)
                        return strcontains(o.name, "stalker asteroid")
                    end)
                    AI.PathFinding.MoveSafelyTo(p, obstacles)
                    if AI.IsHealer() then
                        AI.SendAddonMessage("move-to", p.x, p.y, p.z)
                    end
                end
            end
        end, 1)
    end
end

function algalon:GetBlackHoles()
    local bHoles = AI.FindNearbyUnitsByName("black hole")
    if #bHoles > 0 then
        return bHoles
    end
    return nil
end

function algalon:GetDarkMatters()
    local darkMatters = AI.FindNearbyUnitsByName("dark matter")
    if #darkMatters > 0 then
        return darkMatters
    end
    return nil
end

function algalon:GetObstacles(includeHoles)
    local asteroids = AI.FindNearbyUnitsByName("stalker asteroid")
    local holes = algalon:GetBlackHoles()
    local collapsingStars = AI.FindNearbyUnitsByName("collapsing star")
    local obstacles = {}
    for i, o in ipairs(asteroids) do
        o.radius = 13
        table.insert(obstacles, o)
    end
    if includeHoles and holes then
        for i, o in ipairs(holes) do
            o.radius = 13
            table.insert(obstacles, o)
        end
    end
    for i, o in ipairs(collapsingStars) do
        if not o.isDead and o.health <= 10000 then
            o.radius = 13
            table.insert(obstacles, o)
        end
    end
    return obstacles
end

function algalon:SPELL_AURA_APPLIED(args)
    if strcontains(args.spellName, "black hole") and args.target == UnitName("player") then
        -- AI.RegisterOneShotAction(function(self)
        -- print("i'm in the black hole, moving away from black holes")
        local obstacles = self.cachedBlackHoles
        if not obstacles then
            obstacles = {}
            local x, y, z = AI.GetPosition()
            table.insert(obstacles, {
                x = x,
                y = y,
                z = z
            })

        end
        if obstacles then
            for i, o in ipairs(obstacles) do
                o.guid = nil
                o.radius = 10
            end
            local p = AI.PathFinding.FindSafeSpotInCircle("player", 20, obstacles, 3)
            if p then
                AI.SetMoveTo(p.x, p.y)
            else
                AI.PathFinding.MoveToSafeLocationWithinPolygon(nil, obstacles, 3)
            end
        end
        -- end, 0.2)

    end
end

function algalon:SPELL_AURA_REMOVED(args)
    if strcontains(args.spellName, "black hole") and args.target == UnitName("player") then
        self.cachedBlackHoles = nil
        if AI.IsTank() then
            TargetUnit("algalon")
        end
    end
end

function algalon:SPELL_CAST_START(args)
    if strcontains(args.spellName, "big bang") then
        self.bigBangTime = GetTime()
        print("algalon casting big bang")
        AI.ClearObjectAvoidance()
        if AI.IsPriest() then
            -- local tx, ty = AI.GetPosition("target")            
            AI.RegisterOneShotAction(function(self)
                print('tanking big bang with dispersion')
                AI.StopCasting()
                AI.MustCastSpell("power word: shield", "player")
                AI.MustCastSpell("dispersion")
                self.cachedBlackHoles = self:GetBlackHoles()
            end, 5)
        else
            local holes = self:GetBlackHoles()
            self.cachedBlackHoles = holes
            if not AI.IsTank() then
                if holes then
                    AI.RegisterPendingAction(function(self)
                        if not AI.IsHealer() or not AI.IsCasting() then
                            local holes = self:GetBlackHoles()
                            if holes then
                                self:MoveSafelyToSpotWithin(1, holes[1].x, holes[1].y, holes[1].z, false, true)
                                self.cachedBlackHoles = holes
                                return true
                            end
                        end
                        return false
                    end)
                end
            end
        end
    end
end

AI.RegisterBossModule(algalon)