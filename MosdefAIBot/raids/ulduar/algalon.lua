local algalon = MosDefBossModule:new({
    name = "Algalon The Observer",
    creatureId = {32871},
    onStart = function(self)
        if AI.IsTank() then
            AI.ALLOW_AUTO_REFACE = false
        end
        AI.DISABLE_PRIEST_DISPERSION = true
        -- AI.Config.startHealOverrideThreshold = 90
        AI.Config.manaTideThreshold = 20

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
                    self:MoveSafelyToSpot(p.x, p.y, p.z)
                end
            end

            if AI.IsTank() and AI.IsValidOffensiveUnit() and strcontains(UnitName("target"), "collapsing") then
                local info = AI.GetObjectInfo("target")
                if not info or not info.raidTargetIndex then
                    SetRaidTarget("target", 7)
                    -- AI.SendAddonMessage('set-focused-target', UnitGUID("target"))
                end
            end
        end
        AI.do_PriorityTarget = function()
            if not AI.IsTank() then
                local stars = AI.FindNearbyUnitsByName("collapsing star")
                for i, o in ipairs(stars) do
                    if not o.isDead and o.raidTargetIndex then
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
        local tick = GetTime()
        if not AI.IsTank() then
            local stars = AI.FindNearbyUnitsByName("collapsing star")
            local blackHoles = self:GetBlackHoles()
            local riskyStars = {}
            for i, o in ipairs(stars) do
                if o.distance <= 10 and not o.isDead and o.health <= 30000 then
                    table.insert(riskyStars, o)
                end
            end
            if tick > self.lastCosmicSmashTime + 5 and #riskyStars > 0 and not AI.HasMoveTo() then
                local obstacles = self:GetObstacles(true)
                local p = AI.PathFinding.FindSafeSpotInCircle(AI.GetPrimaryTank(), 35, obstacles, 5)
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
        if AI.IsHealer() and not AI.HasDebuff("black hole") then
            if AI.GetDistanceToUnit(AI.GetPrimaryTank()) > 30 and not AI.IsCasting() and not AI.HasMoveTo() and tick >
                self.lastCosmicSmashTime + 5 and tick > self.bigBangTime + 8 then
                local obstacles = self:GetObstacles(true)
                local p = AI.PathFinding.FindSafeSpotInCircle(AI.GetPrimaryTank(), 30, obstacles, 1)
                if p then
                    -- print('moving to tank')
                    if not AI.PathFinding.MoveSafelyTo(p, obstacles) then
                        print('failed to move to tank')
                    end
                else
                    print('no safe spot from dying collapsing star')
                end
            end
        end

        -- if AI.IsPriest() and tick < self.bigBangTime + 8 and (tick - self.bigBangTime) > 5 then
        --     print('tanking big bang with dispersion')
        --     if not AI.HasDebuff("weakened soul") and AI.CanCastSpell("power word: shield", "player", true) and
        --         AI.CastSpell("power word: shield") then
        --         -- print("casting power word: shield")
        --         return true
        --     end
        --     if not AI.HasBuff("dispersion") and AI.CanCastSpell("dispersion", nil, true) and AI.CastSpell("dispersion") then
        --         print("no dispersion, casting it")
        --         return true
        --     end
        -- end

        if self.blackHoleToUse then
            local holes = self:GetBlackHoles()
            local isValid = false
            if holes then
                for i, o in ipairs(holes) do
                    if o.guid == self.blackHoleToUse.guid then
                        isValid = true
                        break
                    end
                end

                if not isValid then
                    print('black hole is invalid, moving to new one')
                    self.blackHoleToUse = holes[1]
                end
            end
            if not AI.HasMoveTo() then
                local obstacles = self:GetObstacles(false)
                local p = AI.PathFinding.FindSafeSpotInCircle(self.blackHoleToUse, 3, obstacles)
                if p then
                    AI.PathFinding.MoveSafelyTo(p, obstacles)
                end
            end
        end
    end,
    cachedBlackHoles = nil,
    bigBangTime = 0,
    isPhasedPunched = false,
    lastCosmicSmashTime = 0,
    blackHoleToUse = nil
})

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
        return true
    else
        return true
    end
    return false
end

function algalon:ON_ADDON_MESSAGE(from, cmd, params)
    if from ~= UnitName("player") and cmd == "move-to" then
        if not AI.IsTank() then
            print("received move-to from " .. from .. " with params: " .. params)
            local p = AI.PathFinding.Vector3.new(splitstr3(params, ","))
            local obstacles = self:GetObstacles(true)
            local source = AI.GetObjectInfo(AI.GetPrimaryHealer())
            -- if close enough to healer, then ignore asteroid in path finding. otherwise include it
            if source:GetDistanceToUnit("player") <= 5 then
                table_removeif(obstacles, function(o)
                    return strcontains(o.name, "stalker asteroid")
                end)
            end
            if not AI.PathFinding.MoveSafelyTo(p, obstacles) then
                for r = 20, 30, 5 do
                    p = AI.PathFinding.FindSafeSpotInCircle(AI.GetPrimaryTank(), r, self:GetObstacles(true))
                    if p then
                        if AI.PathFinding.MoveSafelyTo(p, obstacles) then
                            return
                        else
                            print('failed to move safely r:' .. r)
                        end
                    else
                        print('no safe spot r:' .. r)
                    end
                end
                p = AI.PathFinding.Vector3.new(AI.GetPosition(AI.GetPrimaryTank()))
                AI.SetMoveTo(p.x, p.y)
            end
        end
    end
end

function algalon:CHAT_MSG_RAID_BOSS_EMOTE(s)
    if strcontains(s, "cosmic smash") then
        self.lastCosmicSmashTime = GetTime()
        -- print("cosmic smash coming")
        if not AI.IsTank() then
            AI.StopMoving()
        end
        AI.RegisterOneShotAction(function(self)
            if AI.IsHealer() then
                local obstacles = self:GetObstacles(true)
                table_removeif(obstacles, function(o)
                    return strcontains(o.name, "stalker asteroid")
                end)
                for r = 30, 40, 5 do
                    local p = AI.PathFinding.FindSafeSpotInCircle(AI.GetPrimaryTank(), r, self:GetObstacles(true))
                    if p then
                        if not AI.IsHealer() then
                            AI.StopCasting()
                        end
                        if AI.PathFinding.MoveSafelyTo(p, obstacles) then
                            if AI.IsHealer() then
                                AI.SendAddonMessage("move-to", p.x, p.y, p.z)
                            end
                            return
                        else
                            print('failed to move safely r:' .. r)
                        end
                    else
                        print('no safe spot found r:' .. r)
                    end
                end
                local tx, ty, tz = AI.GetPosition(AI.GetPrimaryTank())
                AI.SetMoveTo(tx, ty)
                AI.SendAddonMessage("move-to", tx, ty, tz)
            end
        end, 0.5)
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
        o.radius = 15
        table.insert(obstacles, o)
    end
    if includeHoles and holes then
        for i, o in ipairs(holes) do
            o.radius = 8
            table.insert(obstacles, o)
        end
    end
    for i, o in ipairs(collapsingStars) do
        if not o.isDead and o.health <= 30000 then
            o.radius = 10
            table.insert(obstacles, o)
        end
    end
    return obstacles
end

function algalon:SPELL_AURA_APPLIED(args)
    if strcontains(args.spellName, "black hole") and args.target == UnitName("player") then
        if self.blackHoleToUse then
            self.blackHoleToUse = nil
        end
        if GetTime() > self.lastCosmicSmashTime + 5 then
            if AI.IsMage() then
                AI.MustCastSpell("invisibility")
            end
            if AI.IsPriest() then
                AI.MustCastSpell("fade")
            end
        end
        AI.RegisterOneShotAction(function(self)
            if not self then
                return
            end
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
                local p = AI.PathFinding.FindSafeSpotInCircle("player", 20, obstacles, 1)
                if p then
                    AI.SetMoveTo(p.x, p.y)
                else
                    AI.PathFinding.MoveToSafeLocationWithinPolygon(nil, obstacles, 1)
                end
            end
        end, 0.2)

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
        -- print("algalon casting big bang")
        -- AI.ClearObjectAvoidance()
        local stars = AI.FindNearbyUnitsByName("collapsing star")
        for i, o in ipairs(stars) do
            if not o.isDead and o.raidTargetIndex then
                o:Target()
                SetRaidTarget("target", 0)
            end
        end
        local holes = self:GetBlackHoles()
        self.cachedBlackHoles = holes
        if not AI.IsTank() then
            if holes then
                AI.RegisterPendingAction(function(self)
                    if not AI.IsHealer() or not AI.IsCasting() then
                        local holes = self:GetBlackHoles()
                        local obstacles = self:GetObstacles(false)
                        if holes then
                            local asteroids = AI.FindNearbyUnitsByName("stalker asteroid")
                            if #asteroids == 0 and GetTime() > self.lastCosmicSmashTime + 5 then
                                self.blackHoleToUse = holes[1]
                            else
                                local bestHole = nil
                                for i, o in ipairs(holes) do
                                    if AI.CalcDistance(o.x, o.y, asteroids[1].x, asteroids[1].y) >= 15 and
                                        AI.PathFinding.CanMoveSafelyTo(o, obstacles) then
                                        bestHole = o
                                        break
                                    end
                                end
                                if bestHole then
                                    self.blackHoleToUse = bestHole
                                else
                                    print('no best blackhole could be determined, using closest one')
                                    self.blackHoleToUse = holes[1]
                                end
                            end
                            self.cachedBlackHoles = holes
                            AI.ResetMoveTo()
                            return true
                        end
                    end
                    return false
                end)
            end
        end

    end
end

AI.RegisterBossModule(algalon)
