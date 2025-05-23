local icicleRadius = 6
local oldPriorityTargetFn = nil
-- hodir
local hodir = MosDefBossModule:new({
    name = "Hodir",
    creatureId = {32845, 32938},
    onStart = function(self)
        if AI.IsTank() then
            AI.ALLOW_AUTO_REFACE = false
        end
        oldPriorityTargetFn = AI.do_PriorityTarget
        AI.do_PriorityTarget = function()
            if AI.IsDps() and AI.IsValidOffensiveUnit() and UnitName("target") == "Flash Freeze" then
                return true
            end
            if AI.IsDps() then
                self.lastTargetingTime = GetTime()
                local obstacles = AI.FindNearbyUnitsByName("icicle")
                for i = #obstacles, 1, -1 do
                    obstacles[i].radius = icicleRadius
                    if obstacles[i].name:lower() ~= "icicle" then
                        table.remove(obstacles, i)
                    end
                end
                local frozenVeesha = AI.FindUnitYWithinXOf("veesha", "flash freeze", 1)
                if #frozenVeesha > 0 and not frozenVeesha[1].isDead then
                    frozenVeesha[1]:Target()
                    if frozenVeesha[1].distance > 40 and not AI.HasMoveTo() then
                        local p = AI.PathFinding.FindSafeSpotInCircle(frozenVeesha[1], 35, obstacles, 0)
                        if p then
                            if AI.PathFinding.MoveSafelyTo(p, obstacles) then
                                print("moving closer to veesha")
                            else
                                print('failed to move to veesha')
                            end
                        else
                            print('no safe spot to veesha')
                        end
                    end
                    return true
                else
                    if (AI.IsDpsPosition(2)) and not AI.HasBuff("bloodlust") then
                        local freezes = AI.FindNearbyUnitsByName("flash freeze")
                        for i, o in ipairs(freezes) do
                            if not o.isDead then
                                o:Target()
                                if AI.IsValidOffensiveUnit() and AI.GetDistanceToUnit("target") > 40 and not AI.HasMoveTo() then
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
                if AI.IsWarlock() and AI.DoCastSpellChain("target", "corruption", "Unstable corruption", "shadow bolt") then
                    return true
                end
                if AI.IsPriest() and AI.DoCastSpellChain("target", "mind blast", "shadow word: death", "mind flay") then
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
        if not AI.IsTank() then

            local nearbyObjects = AI.GetNearbyObjects(bit.bor(AI.ObjectTypeFlag.DynamicObject, AI.ObjectTypeFlag.Unit),
                "fire", "icicle", "veesha", "starlight")
            local closestToastyFire = nil
            local closestIcicle = nil
            local closestSnowpackedIcicle = nil
            local closestSnowpackedIcicleTarget = nil
            local icicles = {}
            local fires = {}
            local snowpackedIcicles = {}
            local fireMage = nil
            local starlights = {}
            local tank = AI.GetObjectInfo(AI.GetPrimaryTank())
            local cX, cY, cZ = AI.GetPosition("player")
            local teamList = AI.GetRaidOrPartyMemberUnits()
            for i, o in ipairs(nearbyObjects) do
                if strcontains(o.name, "toasty fire") then
                    o.radius = 0.5
                    table.insert(fires, o)
                    if closestToastyFire == nil then
                        closestToastyFire = o
                    end
                end
                if o.name and o.name:lower() == "icicle" then
                    o.radius = icicleRadius
                    table.insert(icicles, o)
                    if not closestIcicle then
                        closestIcicle = o
                    end
                end
                if strcontains(o.name, "snowpacked icicle") then
                    o.radius = 9
                    table.insert(snowpackedIcicles, o)
                    if not closestSnowpackedIcicle then
                        closestSnowpackedIcicle = o
                    end
                end

                if o.name and o.name:lower() == "snowpacked icicle target" and closestSnowpackedIcicleTarget == nil then
                    o.radius = 10
                    closestSnowpackedIcicleTarget = o
                end
                if strcontains(o.name, "veesha") then
                    fireMage = o
                end
                if o.spellName and strcontains(o.spellName, "starlight") then
                    table.insert(starlights, o)
                end
            end

            if AI.HasDebuff("Freeze") or AI.HasDebuff("flash freeze") then
                return false
            end
            if AI.IsHealer() and AI.IsCasting() then
                return false
            end

            --
            self:applyTargeting()

            if closestSnowpackedIcicleTarget and closestSnowpackedIcicleTarget.distance >
                closestSnowpackedIcicleTarget.radius and not AI.HasMoveTo() then
                local bestFire = nil
                for i, f in ipairs(fires) do
                    if AI.CalcDistance(f.x, f.y, closestSnowpackedIcicleTarget.x, closestSnowpackedIcicleTarget.y) <
                        closestSnowpackedIcicleTarget.radius then
                        bestFire = f
                        break
                    end
                end

                if bestFire then
                    local p = AI.PathFinding.FindSafeSpotInCircle(bestFire, 4, {})
                    if p then
                        print("moving onto fire that's on snow packed padding")
                        AI.SetMoveTo(p.x, p.y)
                    end
                else
                    local p = AI.PathFinding.FindSafeSpotInCircle(closestSnowpackedIcicleTarget,
                        closestSnowpackedIcicleTarget.radius - 1, {}, 0)
                    if p then
                        print("moving onto snow packed padding")
                        AI.SetMoveTo(p.x, p.y)
                    end
                end
            elseif closestSnowpackedIcicle and not closestSnowpackedIcicleTarget then
                if closestSnowpackedIcicle.distance <= closestSnowpackedIcicle.radius and not AI.HasMoveTo() then
                    -- print("flash freeze on me, moving out")

                    local p = AI.PathFinding.FindSafeSpotInCircle(closestSnowpackedIcicle,
                        closestSnowpackedIcicle.radius * 2, snowpackedIcicles, 1)
                    if p then
                        AI.SetMoveTo(p.x, p.y)
                        print("moving to avoid flash freeze")
                    else
                        print('no safe spot to avoid flash freeze')
                    end

                end
            elseif closestIcicle and closestIcicle.distance <= icicleRadius and not AI.HasMoveTo() then
                AI.SendAddonMessage('seen-icicle', UnitName("player"))
                -- local targetToMoveAround = closestIcicle
                local targetToMoveAround = fireMage

                local starlight = self.getBestStarlight()
                if closestToastyFire and not AI.HasBuff("toasty fire") and AI.GetDebuffCount("biting cold") >= 2 then
                    targetToMoveAround = self.getBestToastyFire()
                    if not targetToMoveAround then
                        targetToMoveAround = closestToastyFire
                    end
                elseif (AI.HasBuff("toasty fire") or AI.GetDebuffCount("biting cold") <= 1) and
                    not AI.HasBuff("starlight") and AI.IsDpsPosition(2, 3) and starlight then
                    targetToMoveAround = starlight
                end

                local p
                if targetToMoveAround == starlight then
                    p = AI.PathFinding.FindSafeSpotInCircle(targetToMoveAround, starlight.radius, icicles, 1)
                else
                    p = AI.PathFinding.FindSafeSpotInCircle(targetToMoveAround, 10, icicles, 1)
                end
                if p then
                    print("moving to avoid icicle")
                    AI.SetMoveTo(p.x, p.y)
                else
                    p = AI.PathFinding.FindSafeSpotInCircle(closestIcicle, 10, icicles, 1)
                    if p then
                        print("alt moving to avoid icicle")
                        AI.SetMoveTo(p.x, p.y)
                    else
                        print('no safe spot to avoid icicle')
                    end
                end
                return false
            elseif not AI.HasMoveTo() and not AI.HasBuff("toasty fire") and AI.GetDebuffCount("biting cold") >= 2 and
                closestToastyFire and GetTime() <= self.lastIcicleDodgeTime + 2 then

                local bestFire = self.getBestToastyFire()
                local fire = bestFire
                if not fire then
                    fire = closestToastyFire
                end
                local p = AI.PathFinding.FindSafeSpotInCircle(fire, 9, icicles, 0)
                if p then
                    print('headed for toasty fire')
                    AI.SetMoveTo(p.x, p.y)
                else
                    if fire == bestFire then
                        p = AI.PathFinding.FindSafeSpotInCircle(closestToastyFire, 9, icicles, 0)
                        if p then
                            print('headed for toasty fire')
                            AI.SetMoveTo(p.x, p.y)
                        else
                            print('no safe spot to toasty fire')
                        end
                    end
                end
                return false
            elseif not closestSnowpackedIcicle and not closestSnowpackedIcicleTarget and
                (not closestIcicle or closestIcicle.distance > icicleRadius) and not AI.HasMoveTo() and GetTime() <=
                self.lastIcicleDodgeTime + 2 then
                if AI.IsDps() then
                    if self.stormPowerPlayer and (not AI.HasBuff("storm power") and not AI.HasBuff("storm cloud")) then
                        local stormcloudPlr = AI.GetObjectInfo(self.stormPowerPlayer)
                        -- v2 path finding
                        if stormcloudPlr and AI.GetDistanceTo(stormcloudPlr.x, stormcloudPlr.y) <= 10 then
                            local p = AI.PathFinding.FindSafeSpotInCircle(stormcloudPlr, 5, icicles, 0, 0.5)
                            if p then
                                -- AI.SetMoveTo(p.x, p.y)
                                if AI.PathFinding.MoveSafelyTo(p, icicles) then
                                    print("moving to storm power plr")
                                end
                            else
                                print('no safe spot to storm power player')
                            end
                        end
                    elseif AI.IsDpsPosition(2, 3) and not AI.HasBuff("starlight") and GetTime() >
                        self.lastMoveToStarlightTime + 4 then
                        local starlight = self.getBestStarlight()
                        if starlight then
                            local p = AI.PathFinding.FindSafeSpotInCircle(starlight, starlight.radius, icicles, 0)
                            if p then
                                if AI.PathFinding.MoveSafelyTo(p, icicles) then
                                    print("moving to starlight for buff")
                                    self.lastMoveToStarlightTime = GetTime()
                                    local unitName = UnitName("player")
                                    AI.SendAddonMessage('to-starlight', unitName)
                                end
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
    isPointFarEnoughFromTeammates = function(x, y, teamList)
        for i, o in ipairs(teamList) do
            local tX, tY = AI.GetPosition(o)
            if UnitGUID(o) ~= UnitGUID("player") and AI.CalcDistance(x, y, tX, tY) <= 3 then
                return false
            end
        end
        return true
    end,
    isPointFarEnoughFromFires = function(x, y, fireList)
        for i, o in ipairs(fireList) do
            if AI.CalcDistance(x, y, o.x, o.y) <= icicleRadius then
                return false
            end
        end
        return true
    end,
    isPointFarEnoughFromSnowpackedIcicles = function(x, y, icicleList)
        for i, o in ipairs(icicleList) do
            if AI.CalcDistance(x, y, o.x, o.y) <= 10 then
                return false
            end
        end
        return true
    end,
    isPointSafeFromIcicles = function(x, y, icicleList)
        for i, o in ipairs(icicleList) do
            if AI.CalcDistance(x, y, o.x, o.y) <= icicleRadius then
                return false
            end
        end
        return true
    end,
    doesLineIntersectAnyFires = function(x1, y1, x2, y2, fireList)
        for i, o in ipairs(fireList) do
            if AI.DoesLineIntersect(x1, y1, x2, y2, o.x, o.y, 0.5) then
                return true
            end
        end
        return false
    end,
    doesLineIntersectAnyIcicles = function(x1, y1, x2, y2, icicleList, ignoreGuid)
        for i, o in ipairs(icicleList) do
            if o.guid ~= ignoreGuid and AI.DoesLineIntersect(x1, y1, x2, y2, o.x, o.y, icicleRadius) then
                return true
            end
        end
        return false
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
    end,
    getBestToastyFire = function()
        local fires = AI.FindNearbyDynamicObjects("toasty fire");
        local starlights = AI.FindNearbyDynamicObjects("starlight")
        local icicles = AI.FindNearbyDynamicObjects("icicle")
        if #fires == 0 then
            return nil
        end
        local bestDist = 100
        local x, y = AI.GetPosition("player")
        local bestFire = nil
        for i, o in ipairs(fires) do
            for i, icicle in ipairs(icicles) do
                if AI.CalcDistance(icicle.x, icicle.y, o.x, o.y) > icicleRadius then
                    local nearLight = false
                    for i, light in ipairs(starlights) do
                        if AI.CalcDistance(light.x, light.y, o.x, o.y) < 25 then
                            nearLight = true
                            break
                        end
                    end
                    if nearLight or AI.CalcDistance(o.x, o.y, x, y) < bestDist then
                        bestDist = AI.CalcDistance(o.x, o.y, x, y)
                        bestFire = o
                    end
                end
            end
        end
        return bestFire
    end,
    getBestStarlight = function()
        local starlights = AI.FindNearbyDynamicObjects("starlight")
        local fires = AI.FindNearbyDynamicObjects("toasty fire")
        if #starlights == 0 then
            return nil
        end
        local bestDist = 100
        local x, y = AI.GetPosition("player")
        local bestStarlight = nil
        for i, o in ipairs(starlights) do
            if AI.CalcDistance(o.x, o.y, x, y) <= 25 then
                -- for i, fire in ipairs(fires) do
                -- if AI.CalcDistance(fire.x, fire.y, o.x, o.y) <= 20 then
                if AI.CalcDistance(o.x, o.y, x, y) < bestDist then
                    bestDist = AI.CalcDistance(o.x, o.y, x, y)
                    bestStarlight = o
                end
                -- end
            end
        end
        return bestStarlight
    end,
    applyTargeting = function(self)
       
    end,
    centerX = 2000.7666015625,
    centerY = -233.83085632324,
    divertFromCenterR = 30,
    isHeadedTowardsStormPlr = nil,
    stormPowerPlayer = nil,
    lastMoveToStarlightTime = 0,
    lastTargetingTime = 0,
    lastIcicleDodgeTime = 0
})

function hodir:ON_ADDON_MESSAGE(from, cmd, params)
    -- print("hodir:ON_ADDON_MESSAGE " .. cmd .. " " .. params)
    if strcontains(cmd, "seen-icicle") and GetTime() > self.lastIcicleDodgeTime + 4 then
        self.lastIcicleDodgeTime = GetTime()
    end
    if strcontains(cmd, "to-starlight") then
        local unitName = params
        print(unitName .. " is headed to starlight")
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
        self.isHeadedTowardsStormPlr = nil
    end
end

function hodir:SPELL_AURA_REMOVED(args)
    if args.spellName:lower() == "storm cloud" then
        self.stormPowerPlayer = nil
        self.isHeadedTowardsStormPlr = false
        -- print(args.target .. " is no longer storm cloud  plr")
    end
end

function hodir:SPELL_DAMAGE(args)
    if args.spellName == "Ice Shards" and args.target == UnitName("player") then
        AI.ResetMoveTo()
    end
end

function hodir:CHAT_MSG_RAID_BOSS_EMOTE(s, t)
    -- print("CHAT_MSG_RAID_BOSS_EMOTE " .. s)
    if MaloWUtils_StrContains(s, "flash freeze") then
        AI.ResetMoveTo()
        self.lastIcicleDodgeTime = GetTime()
    end
    if strcontains(s, "frozen") then
        self.lastIcicleDodgeTime = GetTime()
        if not AI.IsTank() then
            local veesha = AI.FindNearbyUnitsByName("veesha")
            local icicles = AI.FindNearbyUnitsByName("icicle")
            for i = #icicles, 1, -1 do
                icicles[i].radius = icicleRadius
                if icicles[i].name:lower() ~= "icicle" then
                    table.remove(icicles, i)
                end
            end

            if #veesha > 0 then
                local p = AI.PathFinding.FindSafeSpotInCircle(veesha[1], 13, icicles, 0)
                if p then
                    if AI.PathFinding.MoveSafelyTo(p, icicles) then
                        print("moving to veesha")
                    else
                        print('failed to move to veesha')
                    end
                else
                    print('no safe spot to veesha')
                end
            end
        end
    end
end

AI.RegisterBossModule(hodir)
