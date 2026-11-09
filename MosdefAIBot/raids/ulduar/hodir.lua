local icicleRadius = 7
local oldPriorityTargetFn = nil
-- hodir
local hodir = MosDefBossModule:new({
    name = "Hodir",
    creatureId = {32845, 32938},
    onStart = function(self)
        if AI.IsTank() then
            AI.ALLOW_AUTO_REFACE = false
        end
        AI.DISABLE_DRAIN = true
        oldPriorityTargetFn = AI.do_PriorityTarget

        self.nextFlashFreezeTime = GetTime() + 50
        self.lastMoveToStarlightTime = 0
        self.lastTargetingTime = GetTime()
        AI.Config.useHealingWaveOnToons = true

        AI.do_PriorityTarget = function()
            if AI.IsDps() and AI.IsValidOffensiveUnit() and UnitName("target") == "Flash Freeze" then
                return true
            end
            if AI.IsDps() and GetTime() > self.lastTargetingTime + 0.5 then
                self.lastTargetingTime = GetTime()
                local obstacles = {}
                if self.activeIcicle then
                    table.insert(obstacles, self.activeIcicle)
                end
                local frozenblazeweaver = AI.FindUnitYWithinXOf("blazeweaver", "flash freeze", 1)
                local flameCuffs = AI.FindUnitYWithinXOf("flamecuffs", "flash freeze", 1)
                local fireMage = #frozenblazeweaver > 0 and frozenblazeweaver[1] or
                                     (#flameCuffs > 0 and flameCuffs[1] or nil)
                if fireMage and not fireMage.isDead then
                    fireMage:Target()
                    if fireMage.distance > 35 and not AI.HasMoveTo() then
                        local p = AI.PathFinding.FindSafeSpotInCircle(fireMage, 35, obstacles, 0)
                        if p then
                            if AI.PathFinding.MoveSafelyTo(p, obstacles) then
                                print("moving closer to blazeweaver")
                            else
                                print('failed to move to blazeweaver')
                            end
                        else
                            print('no safe spot to blazeweaver')
                        end
                    end
                    return true
                else
                    if AI.IsDps() and not AI.HasBuff("bloodlust") then
                        local freezes = AI.FindNearbyUnitsByName("flash freeze")
                        for i, o in ipairs(freezes) do
                            if not o.isDead then
                                o:Target()
                                if AI.IsValidOffensiveUnit() and AI.GetDistanceToUnit("target") > 35 and
                                    not AI.HasMoveTo() then
                                    local info = AI.GetObjectInfo("target")
                                    local p = AI.PathFinding.FindSafeSpotInCircle(info, 35, obstacles, 0)
                                    if p then
                                        if AI.PathFinding.MoveSafelyTo(p, obstacles) then
                                            print('successfully moved to freeze target')
                                        else
                                            print('failed to move to freeze target')
                                        end
                                    else
                                        print('no safe spot to freeze target')
                                    end
                                end
                                return true
                            end
                        end
                    end
                end
            end
            return false
        end

        AI.PRE_DO_DPS = function(isAoE)
            if AI.IsDps() and UnitName("target") == "Flash Freeze" then
                if AI.IsWarlock() and AI.DoCastSpellChain("target", "corruption", "shadow bolt") then
                    return true
                end
                if AI.IsPriest() then
                    AI.DoCastSpellChain("target", "mind blast", "shadow word: death", "mind flay")
                    return true
                end
                if AI.IsShaman() and AI.DoCastSpellChain("target", "flame shock", "lava burst", "lightning bolt") then
                    return true
                end
                if AI.IsMage() and AI.DoCastSpellChain("target", "living bomb", "fire blast", "frostfire bolt") then
                    return true
                end
            end
            return false
        end
    end,
    onStop = function(self)
        AI.ALLOW_AUTO_REFACE = true
        AI.PRE_DO_DPS = nil
        AI.do_PriorityTarget = oldPriorityTargetFn
    end,
    onUpdate = function(self)

        -- if AI.GetRunSpeed() ~= 14 then
        --     local speed = AI.GetRunSpeed() > 14 and AI.GetRunSpeed() or 14
        --     AI.SetRunSpeed(speed)
        -- end
        local tick = GetTime()
        if not AI.IsTank() then
            if AI.HasDebuff("Freeze") or AI.HasDebuff("flash freeze") then
                return false
            end
            if AI.IsHealer() and AI.IsCasting() then
                return false
            end
            local obstacles = {}

            if self.isCastingFlashFreeze then
                return false
            end
            if self.activeIcicle then
                table.insert(obstacles, self.activeIcicle)
            end

            if AI.HasMoveTo() then
                return false
            end

            local combatReach = tonumber(AI.GetObjectInfo("player").combatReach)
            local bestFire = self:getBestToastyFire()
            local starlight = self:getBestStarlight()
            local fireMage = self:getFireMage()
            local cX, cY = AI.GetPosition()

            if starlight and starlight.distance > starlight.radius and GetTime() > self.lastMoveToStarlightTime + 10 then
                local dist = AI.CalcDistance(cX, cY, starlight.x, starlight.y)
                local speed = AI.GetRunSpeed()
                local time = dist / speed
                local nextFreezeTime = self.nextFlashFreezeTime - GetTime()
                if time + 1 >= nextFreezeTime then
                    local p = AI.PathFinding.FindSafeSpotInCircle(starlight, starlight.radius, {}, 0)
                    if p then
                        AI.SetMoveTo(p.x, p.y)
                        self.lastMoveToStarlightTime = GetTime()
                        print('moving to starlight before flash freeze')
                        return
                    end
                end
            end

            -- if bestFire and bestFire.distance < icicleRadius then
            --     bestFire.radius = icicleRadius + 1
            --     table.insert(obstacles, bestFire)
            --     local p = AI.PathFinding.FindSafeSpotInCircle(bestFire, 12, obstacles, 0)
            --     if p then
            --         print('too close to toasty fire')
            --         AI.SetMoveTo(p.x, p.y)
            --         -- self:MoveTeamTo(p)                 
            --     end
            -- else
            local debuffCount = AI.HasDebuff("damage shirt aura") and 2 or 3
            if not AI.HasBuff("toasty fire") and AI.GetDebuffCount("biting cold") >= debuffCount and bestFire and
                (tick > self.icicleSummonTime + 1 and tick <= self.icicleSummonTime + 4) then
                bestFire.radius = icicleRadius + combatReach
                table.insert(obstacles, bestFire)
                if fireMage then
                    fireMage.radius = icicleRadius + combatReach
                    table.insert(obstacles, fireMage)
                end
                local p = AI.PathFinding.FindSafeSpotInCircle(bestFire, 11, obstacles, 0)
                if p then
                    print('headed for toasty fire')
                    AI.SetMoveTo(p.x, p.y)
                    -- self:MoveTeamTo(p)
                else
                    print("no safe point to toasty fire")
                end
            elseif AI.GetDebuffCount("biting cold") <= debuffCount and
                (tick > self.icicleSummonTime + 1 and tick <= self.icicleSummonTime + 4) then
                if AI.IsDps() then
                    -- if self.stormPowerPlayer and (not AI.HasBuff("storm power") and not AI.HasBuff("storm cloud")) and
                    --     GetTime() > self.lastMoveToStormPlrTime + 2 then
                    --     local stormcloudPlr = AI.GetObjectInfo(self.stormPowerPlayer)
                    --     -- v2 path finding
                    --     if stormcloudPlr and AI.GetDistanceTo(stormcloudPlr.x, stormcloudPlr.y) <= 15 then
                    --         local p = AI.PathFinding.FindSafeSpotInCircle(stormcloudPlr, icicleRadius, obstacles, 0)
                    --         if p then
                    --             AI.SetMoveTo(p.x, p.y)
                    --             self.lastMoveToStormPlrTime = GetTime()
                    --             print("moving to storm power plr")
                    --         else
                    --             print('no safe spot to storm power player')
                    --         end
                    --     end
                    -- else
                    if AI.IsDps(1, 2) and not AI.HasBuff("starlight") and GetTime() > self.lastMoveToStarlightTime + 2 then
                        local starlight = self:getBestStarlight()
                        if starlight then
                            local p = AI.PathFinding.FindSafeSpotInCircle(starlight, 1, obstacles, 0)
                            if p then
                                AI.SetMoveTo(p.x, p.y)
                                print("moving to starlight for buff")
                                self.lastMoveToStarlightTime = GetTime()
                                local unitName = UnitName("player")
                                AI.SendAddonMessage('to-starlight', unitName)
                            else
                                print('no safe spot to starlight')
                            end
                        end
                    end
                end
            end
        end
        return false
    end,

    getBestToastyFire = function(self)
        local combatReach = tonumber(AI.GetObjectInfo("player").combatReach)
        local fires = AI.FindNearbyDynamicObjects("toasty fire");
        local mage = self:getFireMage()
        local starlights = AI.FindNearbyDynamicObjects("starlight")
        local activeIcicle = self.activeIcicle
        if #fires == 0 or not mage then
            return nil
        end
        local bestDist = 100
        local x, y = AI.GetPosition("player")
        local bestFire = nil
        if #starlights == 0 then
            for i, o in ipairs(fires) do
                if AI.CalcDistance(mage.x, mage.y, o.x, o.y) < bestDist and
                    (not activeIcicle or AI.CalcDistance(o.x, o.y, activeIcicle.x, activeIcicle.y) > icicleRadius +
                        combatReach) then
                    bestDist = AI.CalcDistance(mage.x, mage.y, o.x, o.y)
                    bestFire = o
                end
            end
        else
            local bestStarlight = nil
            local bestStarlightDist = 100
            for i, star in ipairs(starlights) do
                if AI.CalcDistance(star.x, star.y, mage.x, mage.y) < bestStarlightDist and
                    (not activeIcicle or AI.CalcDistance(star.x, star.y, activeIcicle.x, activeIcicle.y) > icicleRadius +
                        combatReach) then
                    bestStarlightDist = AI.CalcDistance(star.x, star.y, mage.x, mage.y)
                    bestStarlight = star
                end
            end
            if not bestStarlight then
                return nil
            end
            for i, o in ipairs(fires) do
                if AI.CalcDistance(bestStarlight.x, bestStarlight.y, o.x, o.y) < bestDist and
                    (not activeIcicle or AI.CalcDistance(o.x, o.y, activeIcicle.x, activeIcicle.y) > icicleRadius +
                        combatReach) then
                    bestDist = AI.CalcDistance(bestStarlight.x, bestStarlight.y, o.x, o.y)
                    bestFire = o
                end
            end
        end
        return bestFire
    end,
    getBestStarlight = function(self)
        local combatReach = tonumber(AI.GetObjectInfo("player").combatReach)
        local starlights = AI.FindNearbyDynamicObjects("starlight")
        local bestFire = self:getBestToastyFire()
        local fireMage = self:getFireMage()
        local activeIcicle = self.activeIcicle
        if #starlights == 0 then
            return nil
        end
        local bestDist = 100
        local x, y = AI.GetPosition("player")
        local bestStarlight = nil
        local objToUse = bestFire and bestFire or fireMage
        for i, o in ipairs(starlights) do
            if AI.CalcDistance(o.x, o.y, x, y) <= 15 and
                (not activeIcicle or AI.CalcDistance(o.x, o.y, activeIcicle.x, activeIcicle.y) > icicleRadius +
                    combatReach) then
                if AI.CalcDistance(o.x, o.y, objToUse.x, objToUse.y) < bestDist then
                    bestDist = AI.CalcDistance(o.x, o.y, objToUse.x, objToUse.y)
                    bestStarlight = o
                    o.radius = 3
                end
            end
        end
        return bestStarlight
    end,
    getFireMage = function(self)
        local frozenblazeweaver = AI.FindNearbyUnitsByName("blazeweaver", "flamecuffs")
        if #frozenblazeweaver > 0 then
            return frozenblazeweaver[1]
        end
        return nil
    end,
    centerX = 2000.7666015625,
    centerY = -233.83085632324,
    platformZ = 432.68695068359,
    stormPowerPlayer = nil,
    lastMoveToStarlightTime = 0,
    lastMoveToStormPlrTime = 0,
    icicleSummonTime = 0,
    activeIcicle = nil,
    isCastingFlashFreeze = false,
    nextFlashFreezeTime = 0,
    teamA = {AI.GetPrimaryHealer(), AI.GetDpsPositionName(2)},
    teamB = {AI.GetDpsPositionName(1), AI.GetDpsPositionName(3)}
})

function hodir:GetMyTeam()
    local myName = UnitName("player")
    for i, name in ipairs(self.teamA) do
        if strcontains(name, myName) then
            return self.teamA
        end
    end
    return self.teamB
end

function hodir:MoveTeamTo(p)
    local team = self:GetMyTeam()
    for i, name in ipairs(team) do
        AI.SendAddonMessage('move-team-to', name, p.x, p.y, p.z)
    end
end

function hodir:ON_ADDON_MESSAGE(from, cmd, params)
    -- print("hodir:ON_ADDON_MESSAGE " .. cmd .. " " .. params)
    if strcontains(cmd, "to-starlight") then
        local unitName = params
        -- print(unitName .. " is headed to starlight")
        if unitName ~= UnitName("player") then
            self.lastMoveToStarlightTime = GetTime()
        end
    end
end

function hodir:SPELL_AURA_APPLIED(args)
    if args.spellName:lower() == "storm cloud" then
        self.stormPowerPlayer = args.target
        print(args.target .. " is storm cloud plr")
    end
    if args.spellName:lower() == "storm power" then
        -- self.isHeadedTowardsStormPlr = nil
    end
    if args.target == UnitName("player") then
        -- print("APPLIED " .. args.spellName )
        if AI.HasDebuff("damage shirt aura") and
            (AI.GetDebuffCount("biting cold") > 2) then
            AI.SayRaid("I have > 2 stacks of Biting Cold, mission failed")
        end
    end
end

function hodir:SPELL_AURA_APPLIED_DOSE(args)
    if args.target == UnitName("player") then
        -- print("APPLIED_DOSE " .. args.spellName .. " " .. args.arg2)
        if AI.HasDebuff("damage shirt aura") and
            (AI.GetDebuffCount("biting cold") > 2) then
            AI.SayRaid("I have > 2 stacks of Biting Cold, mission failed")
        end
    end
end

function hodir:SPELL_AURA_REMOVED(args)
    if args.spellName:lower() == "storm cloud" then
        self.stormPowerPlayer = nil
        -- self.isHeadedTowardsStormPlr = false
        -- print(args.target .. " is no longer storm cloud  plr")
    end
end

function hodir:SPELL_DAMAGE(args)
    if args.spellName == "Ice Shards" and args.target == UnitName("player") then
        AI.ResetMoveTo()
    end
    if args.target == UnitName("player") and (args.spellId == 62038 or args.spellId == 62188) and AI.HasDebuff("damage shirt aura") then
        if AI.GetDebuffCount("biting cold") > 2 then
            AI.SayRaid("I have > 2 stacks of Biting Cold, mission failed")
        end
    end
end

function hodir:CHAT_MSG_RAID_BOSS_EMOTE(s, t)
    -- print("CHAT_MSG_RAID_BOSS_EMOTE " .. s)
    if strcontains(s, "frozen") then
        self.lastIcicleDodgeTime = GetTime()
        if not AI.IsTank() then
            local mage = self:getFireMage()
            if mage then
                local obstacles = {}
                if self.activeIcicle then
                    table.insert(obstacles, self.activeIcicle)
                end
                local p = AI.PathFinding.FindSafeSpotInCircle(mage, 11, obstacles, 0)
                AI.SetMoveTo(p.x, p.y)
            end
        end
    end
end

function hodir:SMSG_SPELL_CAST_GO2(args)
    -- summon Icicle
    if args.spellId == 62234 and not AI.IsTank() then
        self.icicleSummonTime = GetTime()
        local combatReach = tonumber(AI.GetObjectInfo("player").combatReach)
        AI.RegisterPendingAction(function(self)
            if AI.HasDebuff("flash freeze") then
                return true
            end
            self.activeIcicle = AI.FindUnitClosestToXYZ(AI.PathFinding.Vector3
                                                            .new(args.dest.x, args.dest.y, args.dest.z), 33169) -- npc id: 33169(icicle)
            -- print("active icicle " .. (self.activeIcicle and self.activeIcicle.guid or "nil"))
            if not self.activeIcicle then
                print("no active icicle near coords, ignoring...")
                return true
            end
            self.activeIcicle.radius = icicleRadius
            -- not close to falling icicle, nothing to do.
            if self.activeIcicle.distance > self.activeIcicle.radius + combatReach then
                return true
            end
            if AI.IsHealer() and AI.IsCasting() then -- finish casting if healer before moving
                return false
            end

            -- Calculate where to go to dodge
            local targetToMoveAround = self.activeIcicle
            local bestFire = self:getBestToastyFire()
            local starlight = AI.IsDps() and self:getBestStarlight() or nil
            local mage = self:getFireMage()
            local obstacles = {self.activeIcicle}
            if mage then
                mage.radius = icicleRadius + combatReach
                table.insert(obstacles, mage)
            end
            if bestFire then
                targetToMoveAround = bestFire
                bestFire.radius = icicleRadius + combatReach
                table.insert(obstacles, bestFire)
            end
            if AI.GetDebuffCount("biting cold") <= 2 and starlight then
                targetToMoveAround = starlight
            end
            local p = AI.PathFinding.FindSafeSpotInCircle(targetToMoveAround,
                targetToMoveAround == starlight and 1 or 11, obstacles, 0)
            if not p then
                print("failed to find safe spot around " .. targetToMoveAround.guid .. ", trying other target")
                targetToMoveAround = self.activeIcicle
                p = AI.PathFinding.FindSafeSpotInCircle(targetToMoveAround, 11, obstacles, 0)
                if not p then
                    print("failed to find safe spot around icicle, giving up")
                    return false
                end
            end
            -- print('dodging icicle')
            AI.SetMoveTo(p.x, p.y)
            return true
        end, 0.5, "DODGE_ICICLE")
    end
    -- ice shards cast by icicle
    if args.spellId == 62457 then
        -- print("icicle shards down")
        self.activeIcicle = nil
    end

    -- icicle summons 'snowpacked icicle'(during flash freeze)
    if args.spellId == 62462 and not AI.IsTank() then
        local combatReach = tonumber(AI.GetObjectInfo("player").combatReach)
        self.isCastingFlashFreeze = true
        if AI.HasDebuff("Freeze") or AI.HasDebuff("flash freeze") then
            return false
        end
        AI.RegisterOneShotAction(function(self)
            print("hodir is casting flash freeze")
            -- npc id: 33173(snow packed icicle)
            local snowpackedIcicles = AI.FindNearbyUnitsByName(33173)
            local r = 9 + combatReach
            for i, o in ipairs(snowpackedIcicles) do
                o.radius = r
            end
            if #snowpackedIcicles > 0 and snowpackedIcicles[1].distance <= r then
                local p = AI.PathFinding.FindSafeSpotInCircle(snowpackedIcicles[1], 20, snowpackedIcicles, 0)
                if p then
                    AI.SetMoveTo(p.x, p.y)
                    print("moving to avoid flash freeze")
                else
                    print('no safe spot to avoid flash freeze')
                end
            end
        end, 0.5, "DODGE_FLASH_FREEZE")
    end

    -- snowdrift, summons 'snowpacked icicle target'
    -- 65370 ice shards by snowpacked
    if args.spellId == 65370 and not AI.IsTank() then
        local combatReach = tonumber(AI.GetObjectInfo("player").combatReach)

        if AI.HasDebuff("Freeze") or AI.HasDebuff("flash freeze") then
            return false
        end
        AI.RegisterOneShotAction(function(self)
            -- print("snowdrift cast")
            local snowpackedIcicleTargets = AI.FindNearbyUnitsByName(33174) -- npc id: 33174(snowpacked icicle target)
            for i, o in ipairs(snowpackedIcicleTargets) do
                o.radius = 9 + combatReach
            end
            local starlights = AI.FindNearbyDynamicObjects("starlight")
            local bestStarlight = nil
            local bestsnowPacked = nil
            local cx, cy = AI.GetPosition("player")
            for i, snow in ipairs(snowpackedIcicleTargets) do
                for i, o in ipairs(starlights) do
                    if #snowpackedIcicleTargets > 0 and
                        AI.DoCirclesOverlap(o.x, o.y, o.radius, snow.x, snow.y, snow.radius) then
                        bestStarlight = o
                        bestsnowPacked = snow
                        break
                    end
                end
            end
            if AI.IsDps() and bestStarlight and bestStarlight.distance <= 15 and bestStarlight.distance > 3 then
                local p = AI.PathFinding.FindSafeSpotInCircle(bestStarlight, 1, {}, 0)
                AI.SetMoveTo(p.x, p.y)
                print("moving onto starlight post flash-freeze")
            elseif #snowpackedIcicleTargets > 0 and snowpackedIcicleTargets[1].distance > 3 then
                local p = AI.PathFinding.FindSafeSpotInCircle(snowpackedIcicleTargets[1], 3, {}, 0)
                AI.SetMoveTo(p.x, p.y)
                print("moving onto snow packed padding")
            end
        end, 0.5, "MOVE_ONTO_SNOW_PACKED_PADDING")
    end

    -- flash freeze 
    if args.spellId == 61968 then
        self.isCastingFlashFreeze = false
        self.nextFlashFreezeTime = GetTime() + 50
    end

    if args.spellId == 62188 and strcontains(args.target, UnitName("player")) and AI.HasDebuff("damage shirt aura") then
        if AI.GetDebuffCount("biting cold") >= 2 then
            AI.SayRaid("at 2+ stacks of Biting Cold, move immediately")
        end
    end
end

AI.RegisterBossModule(hodir)
