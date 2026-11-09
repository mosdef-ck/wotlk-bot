local algalon = MosDefBossModule:new({
    name = "Algalon The Observer",
    creatureId = {32871},
    onStart = function(self)
        if AI.IsTank() then
            AI.ALLOW_AUTO_REFACE = false
        end
        AI.DISABLE_PRIEST_DISPERSION = true
        AI.DISABLE_DRAIN = true
        AI.DISABLE_PET_AA = true
        -- AI.Config.startHealOverrideThreshold = 90
        AI.Config.manaTideThreshold = 20
        AI.Config.judgementToUse = "judgement of light"
        AI.FocusUnit("algalon")
        AI.Config.useHealingWaveOnToons = true

        AI.PRE_DO_DPS = function(isAoE)
            if GetTime() < self.bigBangTime + 8 then
                -- prevent dps when big bang to ensure proper movement
                return true
            end
            if AI.IsDps() and AI.IsValidOffensiveUnit() and AI.GetDistanceToUnit("target") > 35 and not AI.HasMoveTo() and
                GetTime() > self.lastCosmicSmashTime + 5 then
                local obstacles = self:GetObstacles(true)
                local p = AI.PathFinding.FindSafeSpotInCircle("target", 30, obstacles, 3)
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
            RunMacroText(
                "/petattack [target=focus, exists]; /stopmacro [target=focus, exists]; /petattack [target=target, exists]")
            local stars = AI.FindNearbyUnitsByName("collapsing star")
            for i, o in ipairs(stars) do
                if not o.isDead and o.raidTargetIndex then
                    if UnitGUID("focus") ~= o.guid then
                        o:Focus()
                    end
                    if AI.IsDpsPosition(3) then
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
        local combatReach = AI.GetObjectInfo("player").combatReach
        if AI.GetRunSpeed() < 20 then
            local speed = 20
            AI.SetRunSpeed(AI.GetRunSpeed() > speed and AI.GetRunSpeed() or speed)
        end
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
            if AI.GetDistanceToUnit(AI.GetPrimaryTank()) > 35 and not AI.IsCasting() and not AI.HasMoveTo() and tick >
                self.lastCosmicSmashTime + 5 and tick > self.bigBangTime + 8 then
                local obstacles = self:GetObstacles(true)
                local p = AI.PathFinding.FindSafeSpotInCircle(AI.GetPrimaryTank(), 35, obstacles, combatReach)
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
            local targetHp = AI.IsHeroicRaidOrDungeon() and 40000 or 30000
            if not AI.HasMoveTo() then
                -- and (not AI.IsHealer() or UnitHealth(AI.GetPrimaryTank()) >= targetHp) then
                local obstacles = self:GetObstacles(false)
                local speed = AI.GetRunSpeed()
                local distanceToHole = AI.GetDistanceToUnit(self.blackHoleToUse)
                local timeToHole = (distanceToHole / speed) + 0.5
                local timeToCosmicImpact = self.lastCosmicSmashTime + 5
                if tick - self.lastCosmicSmashTime <= 5 and timeToHole < timeToCosmicImpact then
                    print("we can get to hole b4 cosmic smash impact, going!")
                    obstacles = {}
                end
                local p = AI.PathFinding.FindSafeSpotInCircle(self.blackHoleToUse, 1, obstacles, 0)
                if p then
                    AI.PathFinding.MoveSafelyTo(p, obstacles)
                    print("moving into black hole")
                else
                    print("failed to find safe point to black hole")
                end
            end
        end

        if AI.IsPriest() and AI.IsCasting("focus") and (GetTime() - self.bigBangTime) > 5 and
            not AI.HasBuff("dispersion") then
            if AI.CanCast("dispersion") and AI.CastSpell("dispersion") then
                print("casted dispersion")
            end
        end

        if AI.IsDps() then
            AI.UseInventorySlot(13)
            AI.UseInventorySlot(14)
            AI.UseInventorySlot(10)
        end
    end,
    cachedBlackHoles = nil,
    bigBangTime = 0,
    isPhasedPunched = false,
    lastCosmicSmashTime = 0,
    blackHoleToUse = nil,
    p2 = false
})

function algalon:CHAT_MSG_MONSTER_YELL(s)
    if strcontains(s, "behold the tools") then
        self.p2 = true
        print("algalon phase 2 started")
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
            if source:GetDistanceToUnit("player") <= 20 then
                table_removeif(obstacles, function(o)
                    return strcontains(o.name, "stalker asteroid")
                end)
            end
            if not AI.PathFinding.MoveSafelyTo(p, obstacles) then
                for r = 20, 40, 2 do
                    p = AI.PathFinding.FindSafeSpotInCircle(AI.GetPrimaryHealer(), r, self:GetObstacles(true))
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
                for r = 1, 30, 5 do
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
    local bHoles = AI.FindNearbyUnitsByName("black hole", "worm hole")
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
        o.radius = 14
        table.insert(obstacles, o)
    end
    if includeHoles and holes then
        for i, o in ipairs(holes) do
            o.radius = 9
            table.insert(obstacles, o)
        end
    end
    for i, o in ipairs(collapsingStars) do
        if not o.isDead and o.health <= 30000 then
            o.radius = 9
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
        AI.FocusUnit("algalon")
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
            -- if AI.IsPriest() or AI.IsHealer() then
            --     local spell = AI.IsHealer() and "power word: shield" or "riptide"
            --     AI.MustCastSpell(spell, AI.GetPrimaryTank())
            -- end
            if AI.IsPriest() then
                AI.StopCasting()
                AI.RegisterPendingAction(function(self)
                    return AI.CastSpell("dispersion")
                end, 5, "SHIELD_THEN_DISPERSION")
            elseif holes then
                -- if AI.IsHealer() then
                --     AI.MustCastSpell("riptide", AI.GetDpsPositionName(1))
                -- end
                AI.RegisterPendingAction(function(self)
                    if (not AI.IsHealer() or (not AI.IsCasting() or UnitHealth(AI.GetPrimaryTank()) > 40000)) then
                        local holes = self:GetBlackHoles()
                        local obstacles = self:GetObstacles(false)
                        if holes then
                            -- local asteroids = AI.FindNearbyUnitsByName("stalker asteroid")
                            local bestHole = nil
                            local bestDist = 100
                            local tx, ty = AI.GetPosition(AI.GetPrimaryTank())
                            for i, o in ipairs(holes) do
                                local dist = AI.CalcDistance(o.x, o.y, tx, ty)
                                if dist < bestDist then
                                    bestDist = dist
                                    bestHole = o
                                end
                            end
                            if bestHole then
                                self.blackHoleToUse = bestHole
                            else
                                print('no best blackhole could be determined, using closest one ' .. holes[1].guid)
                                self.blackHoleToUse = holes[1]
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
