local valithria = MosDefBossModule:new({
    name = "Valithria Dreamwalker",
    creatureId = {36789, 37868},
    onStart = function(self)
        AI.FindNearbyUnitsByName("valithria dreamwalker")[1]:Focus()
        AI.Config.judgmentToUse = "judgement of light"
        AI.AUTO_CLEANSE = false
        if AI.IsHealer() then
            -- AI.Config.startHealOverrideThreshold = 60
            AI.doPost_Update = function()
                -- have the healer start healing valinthria once we get twisted nightmare stacks
                if AI.HasBuffOrDebuff("twisted nightmares") and AI.GetDistanceToUnit("focus") <= 40 and
                    AI.GetUnitHealthPct("focus") < 100 and not AI.IsMoving() then
                    local spell = AI.HasBuff("tidal waves") and "healing wave" or "chain heal"
                    if AI.CastSpell(spell, "focus") then
                        -- print("healing valithria")
                    end
                end
            end
        end

        AI.PRE_DO_DPS = function(isAoe)
            if AI.IsDps() and not AI.HasBuffOrDebuff("dream state") and AI.IsValidOffensiveUnit() and
                AI.GetDistanceToUnit("target") > 35 then
                local p = AI.PathFinding.FindSafeSpotInCircle("target", 35, self:GetObstacles(), 1)
                if p and not AI.HasMoveTo() then
                    AI.SetMoveTo(p.x, p.y)
                end
            end
        end

        -- AI.do_PriorityTarget = function()
        --     if not AI.IsTank() then
        --         return AI.DoTargetChain("blazing skeleton", "suppresser", "risen archmage")
        --     else
        --         return AI.DoTargetChain("blazing skeleton", "blistering zombie", "abomination")
        --     end
        -- end        
    end,
    onStop = function(self)
        AI.ALLOW_AUTO_REFACE = true
    end,
    onUpdate = function(self)
        if AI.IsHealer() and self.nextCloud then
            -- no dream state but we have a next cloud to go to, abort and return to field
            if not AI.HasBuffOrDebuff("dream state") then
                self.nextCloud = nil
                self.cloudList = {}
                print("dream state expired while in cloud, moving back to engage point")
                local p = AI.PathFinding.FindSafeSpotInCircle(AI.GetPrimaryTank(), 20, self:GetObstacles(), 1)
                local tx, ty, tz = AI.GetPosition(AI.GetPrimaryTank())
                AI.SetMoveTo(p.x, p.y, 370.0)
                AI.SendAddonMessage("move-back-to-engage")
                return
            end
            local cloud = AI.GetObjectInfoByGUID(self.nextCloud)
            if cloud then
                if AI.GetDistance3DToUnit(cloud) <= 1 and not self.timeWhenReachedCloud then
                    self.timeWhenReachedCloud = GetTime()
                end
                -- local isTankCritical = AI.GetUnitHealthPct(AI.GetPrimaryTank()) <= 30
                -- if isTankCritical then
                --     -- self.nextCloud = nil
                --     -- self.cloudList = {}
                --     if GetFollowTarget() == self.nextCloud then
                --         StopFollowing()
                --     end                   
                --     if AI.GetDistance3DToUnit(AI.GetPrimaryTank()) >= 35 then
                --         print("tank is in danger, aborting cloud exploreration")
                --         local p = AI.PathFinding.FindSafeSpotInCircle(AI.GetPrimaryTank(), 30, self:GetObstacles(), 1)
                --         local tx, ty, tz = AI.GetPosition(AI.GetPrimaryTank())
                --         AI.SetMoveTo(p.x, p.y)
                --     end
                --     -- AI.SendAddonMessage("move-back-to-engage")
                -- else
                --     SetFollowTarget(self.nextCloud)
                -- end
                SetFollowTarget(self.nextCloud)

                if self.timeWhenReachedCloud and GetTime() > self.timeWhenReachedCloud + 0.5 and AI.GetUnitHealthPct() >=
                    50 then
                    self:GoToNextCloud()
                    self.timeWhenReachedCloud = nil
                end
            else
                self:GoToNextCloud()
            end
        end
        if strcontains(UnitName("player"), self.dreamWalkerDps) and AI.HasBuffOrDebuff("dream state") and
            GetFollowTarget() ~= UnitGUID(AI.GetPrimaryHealer()) then
            SetFollowTarget(UnitGUID(AI.GetPrimaryHealer()))
        end
    end,
    dreamWalkerDps = "Mosdeflocka",
    cloudList = {},
    nextCloud = nil,
    startP = AI.PathFinding.Vector3.new(4235.9560546875, 2481.4431152344, 364.87030029297),
    engageP = AI.PathFinding.Vector3.new(4220.5712890625, 2485.0283203125, 364.87326049805),
    portalP = AI.PathFinding.Vector3.new(4225.06640625, 2491.7331542969, 420.841796875),
    dpsPos = AI.PathFinding.Vector3.new(4211.8828125, 2486.6313476563, 364.87322998047),
    startDreamP = nil,
    flySpeed = 14,
    timeWhenReachedCloud = nil,
    lastPortalOpenTime = 0,
    companionAtPortal = false,
    prePortalTime = 0,
})

function valithria:GetObstacles()
    local obstacles = AI.FindNearbyUnitsByName("column of frost", "mana void")
    for i, o in ipairs(obstacles) do
        if strcontains(o.name, "column of frost") then
            o.radius = normalizeObstacleRadius(4)
        else
            o.radius = normalizeObstacleRadius(6)
        end
    end
    return obstacles
end

function valithria:SPELL_AURA_APPLIED(args)
    if strcontains(args.spellName, "gut spray") and AI.IsTank() and args.target == UnitName("player") then
        AI.RegisterPendingAction(function(self)
            return AI.CleanseSelf("cleanse", "disease")
        end, 0, "VALITHRIA_CLEANSE_GUT_SPRAY")
    end
    -- if strcontains(args.spellName, "dream state") and UnitName("player") == args.target and AI.IsHealer() then
    --     print("i have dream state")
    -- end'
    -- We get frostbolt volley while in dream state(cleanse it asap)
    if strcontains(args.spellName, "frostbolt volley") and (AI.IsHealer() or AI.IsPriest()) and
        (UnitName("player") == args.target or args.target == UnitName(self.dreamWalkerDps)) then
        print("frostbolt on dream wlker, cleansing")
        AI.RegisterPendingAction(function(self)
            return AI.CleanseFriendly("dispel magic", args.target, "magic")
        end)
    end

    -- if (args.spellId == 71940 or args.spellId == 71941) and strcontains(args.target, UnitName("player")) and
    --     AI.IsHealer() then
    --     if AI.HasBuffOrDebuff("dream state") then
    --         self:GoToNextCloud()
    --         -- print("got stack of twisted nightmares")
    --         -- AI.RegisterPendingAction(function(self)
    --         --     if AI.GetUnitHealthPct("player") > 50 then
    --         --         self:GoToNextCloud()
    --         --         return true
    --         --     end
    --         -- end, 0.1, "VALITHRIA_GO_TO_NEXT_CLOUD")
    --     else
    --         self.nextCloud = nil
    --         self.cloudList = {}
    --         print("dream state expired while in cloud, moving back to engage point")
    --         local p = AI.PathFinding.FindSafeSpotInCircle(AI.GetPrimaryTank(), 20, self:GetObstacles(), 1)
    --         local tx, ty, tz = AI.GetPosition(AI.GetPrimaryTank())
    --         AI.SetMoveTo(p.x, p.y, 370.0)
    --         AI.SendAddonMessage("move-back-to-engage")
    --     end
    -- end
end

function valithria:SPELL_AURA_APPLIED_DOSE(args)
    -- print("valithria:SPELL_AURA_APPLIED_DOSE", args.spellId, args.spellName, args.target, args.amount, args.caster)
    -- if (args.spellId == 71940 or args.spellId == 71941) and strcontains(args.target, UnitName("player")) and
    --     AI.IsHealer() then
    --     if AI.HasBuffOrDebuff("dream state") then
    --         -- print("got stack of twisted nightmares")
    --         self:GoToNextCloud()
    --         --     AI.RegisterPendingAction(function(self)
    --         --         if AI.GetUnitHealthPct("player") > 50 then
    --         --             self:GoToNextCloud()
    --         --             return true
    --         --         end
    --         --     end, 0.1, "VALITHRIA_GO_TO_NEXT_CLOUD")
    --         -- end
    --     else
    --         self.nextCloud = nil
    --         self.cloudList = {}
    --         print("dream state expired while in cloud, moving back to engage point")
    --         local p = AI.PathFinding.FindSafeSpotInCircle(AI.GetPrimaryTank(), 20, self:GetObstacles(), 1)
    --         local tx, ty, tz = AI.GetPosition(AI.GetPrimaryTank())
    --         AI.SetMoveTo(p.x, p.y, 370.0)
    --         AI.SendAddonMessage("move-back-to-engage")
    --     end
    -- end
end

function valithria:SPELL_AURA_REMOVED(args)
    -- if (args.spellId == 70766 or strcontains(args.spellName, "dream state")) and UnitName("player") == args.target then
    --     print("dream state removed")
    --     AI.ResetMoveTo()
    --     self.cloudList = {}
    --     self.nextCloud = nil
    -- end

    if strcontains(args.spellName, "twisted nightmares") and AI.IsHealer() then
        print("twisted nightmares removed")
    end
end

function valithria:ON_ADDON_MESSAGE(from, cmd, args)
    if cmd == "move-to-portal" and strcontains(UnitName("player"), self.dreamWalkerDps) then
        print("moving to nightmare portal")
        local portal = AI.GetObjectInfoByGUID(args)
        if portal then
            AI.SetMoveTo(portal.x, portal.y)
        end
    end
    if cmd == "move-back-to-engage" and strcontains(UnitName("player"), self.dreamWalkerDps) then
        StopFollowing()
        local obstacles = self:GetObstacles()
        local tx, ty, tz = AI.GetPosition(AI.GetPrimaryTank())
        local p = AI.PathFinding.FindSafeSpotInCircle(AI.GetPrimaryTank(), 10, obstacles, 1)
        if p then
            AI.SetMoveTo(p.x, p.y, 370.0)
        end
    end
    -- if cmd == "companion-at-portal" then
    --     self.companionAtPortal = true
    -- end
end

function valithria:SMSG_SPELL_CAST_GO(spellId, spellName, casterGUID, targetGUID, src, dest)
    -- portal pre-effect
    if (spellId == 72480 or spellId == 72481 or spellId == 72482) and AI.IsHealer() and (AI.GetUnitHealthPct("focus") <=
        90 or AI.GetDebuffDuration("twisted nightmares") <= 10) then
        self.nextCloud = nil
        self.cloudList = {}
        self.companionAtPortal = false
        -- print("portals are preparing")
        AI.RegisterPendingAction(function(self)
            local skeletons = AI.FindNearbyUnitsByName("suppresser")
            -- only head to portals if there's no blazing skeles
            -- if #skeletons == 0 or skeletons[1].isDead then
            print("moving towards pre-portals")
            local portals = AI.FindNearbyUnitsByName(38429)
            if #portals >= 2 then
                AI.SetMoveTo(portals[1].x, portals[1].y)
                -- local closestPortal = self:FindNextClosestPortal(portals[1], portals)
                if #skeletons == 0 or skeletons[1].isDead then
                    AI.SendAddonMessage("move-to-portal", portals[2].guid)
                end
                return true
            end
            -- end
            self.prePortalTime = GetTime()
        end, 10, "VALITHRIA_PRE_PORTAL_OPEN")
    end

    -- portals actually summoned
    if spellId == 71987 and (AI.IsHealer() or UnitName("player") == self.dreamWalkerDps) and
        AI.GetUnitHealthPct("focus") <= 90 then
        self.lastPortalOpenTime = GetTime()
        self.nextCloud = nil
        self.cloudList = {}
        self.companionAtPortal = false
        AI.RegisterPendingAction(function(self)
            -- if AI.HasCTM() or (AI.IsHealer() and not self.companionAtPortal) then
            --     return false
            -- end
            if AI.HasCTM() then
                return false
            end
            print("actual portals summoned")
            local portals = AI.FindNearbyUnitsByName(38430)
            if #portals == 0 then
                print("no portals found")
                return true
            end
            if portals[1].distance <= 4.5 then
                portals[1]:InteractWith()
                -- if not AI.IsHealer() then
                --     AI.SendAddonMessage("companion-at-portal")
                -- end
            else
                AI.SetMoveTo(portals[1].x, portals[1].y, portals[1].z, 4.5, function()
                    portals[1]:InteractWith()
                    -- if not AI.IsHealer() then
                    --     AI.SendAddonMessage("companion-at-portal")
                    -- end
                end)
            end
            return true
        end, 0.1, "VALITHRIA_PORTALS_OPENED")
    end

    if spellId == 70766 and casterGUID == UnitGUID("player") then
        JumpOrAscendStart()
        if not AI.IsHealer() then
            SetFollowTarget(UnitGUID(AI.GetPrimaryHealer()))
        end
        local delay = AI.GetDebuffDuration("twisted nightmares") < 5 and 0.5 or 1
        AI.RegisterPendingAction(function(self)
            -- to stop us from continually ascending
            AscendStop()
            -- jump to launch the toon to flight(makes it faster to start flying to nightmare orbs)        
            if AI.IsHealer() and
                (AI.GetUnitHealthPct(AI.GetPrimaryTank()) >= 30 or AI.GetDistanceToUnit(AI.GetPrimaryTank()) >= 35) then
                local delay = AI.GetDebuffCount("twisted nightmares") > 20 and 5 or 0
                -- AI.RegisterPendingAction(function(self)
                --     -- don't start moving  towards clouds until our fellow dps buddy is close enough to us
                --     if AI.GetDistanceToUnit(self.dreamWalkerDps) <= 5 and
                --         AI.HasBuffOrDebuff("dream state", self.dreamWalkerDps) then
                --         AI.RegisterOneShotAction(function(self)
                --             self:MoveToClouds()
                --         end, delay, "VALITHRIA_MOVE_TO_CLOUDS")
                --         return true
                --     end
                -- end, 0, "WAIT_FOR_DPS")

                self:MoveToClouds()
                return true
            end
        end, delay)
    end

    if (spellId == 71179 or spellId == 70704) and not AI.IsTank() and not AI.HasBuffOrDebuff("dream state") then
        -- don't dodge if we waiting to use portal
        if (AI.IsHealer() or strcontains(UnitName("player"), self.dreamWalkerDps)) and GetTime() < self.prePortalTime + 5 then
            return
        end
        if AI.GetDistanceTo(dest.x, dest.y) <= 7 then
            print("avoid this", spellId, spellName, casterGUID, targetGUID, table2str(src), table2str(dest))

            AI.RegisterOneShotAction(function(self)
                local obstacles = self:GetObstacles()
                local p = AI.PathFinding.FindSafeSpotInCircle(self.engageP, 15, obstacles, 1)
                if p then
                    AI.SetMoveTo(p.x, p.y)
                end
            end, 0.1, "VALITHRIA_AVOID_OBSTACLE")
        end
    end
end

function valithria:MoveToClouds()
    local clouds = self:GenerateCloudsToMoveTo()
    self.cloudList = clouds
    self.nextCloud = nil
    self:GoToNextCloud()
end

function valithria:GoToNextCloud()
    if self.nextCloud then
        table_removeif(self.cloudList, function(c)
            return c == self.nextCloud
        end)
        self.nextCloud = nil
    end
    local duration = AI.GetDebuffDuration("dream state")
    local nextCloudGuid = #self.cloudList > 0 and self.cloudList[1] or nil
    local cloud = AI.GetObjectInfoByGUID(nextCloudGuid)
    local speed = self.flySpeed
    -- if cloud and AI.GetDistance3DToUnit(cloud) <= speed * duration then
    if cloud then
        self.nextCloud = cloud.guid
        print("moving to cloud: " .. self.nextCloud)
        SetFollowTarget(self.nextCloud)
    else
        print("exhausted cloud list moving back to engage point")
        local p = AI.PathFinding.FindSafeSpotInCircle(AI.GetPrimaryTank(), 10, self:GetObstacles(), 1)
        local tx, ty, tz = AI.GetPosition(AI.GetPrimaryTank())
        AI.SetMoveTo(p.x, p.y, 373.0, 0, function()
            AI.MustCastSpell("healing stream totem", nil)            
        end)
        AI.SendAddonMessage("move-back-to-engage")
    end
end

function valithria:GenerateCloudsToMoveTo()
    local start = AI.PathFinding.Vector3.new(AI.GetPosition())
    local clouds = AI.FindNearbyUnitsByName(38421, "nightmare cloud")
    local me = self
    table_removeif(clouds, function(c)
        -- return c.z < 380.0 or c.z > 388.0
        return c:GetDistanceTo(me.portalP.x, me.portalP.y) > 40
    end)
    local cloudGuids = {}
    -- try to grab a max of 5 clouds per dream state
    local maxCount = 5
    -- if AI.GetDebuffCount("twisted nightmares") > 20 then
    --     maxCount = 2
    -- end
    if #clouds > 0 then
        local count = 0
        local nextCloud = clouds[1]
        while count < maxCount and nextCloud do
            table.insert(cloudGuids, nextCloud.guid)
            count = count + 1
            table_removeif(clouds, function(c)
                return c == nextCloud
            end)
            -- nextCloud = self:FindNextClosestCloudTo(nextCloud, clouds)
            nextCloud = #clouds > 0 and clouds[#clouds] or nil
        end
    end
    return cloudGuids
end

function valithria:FindNextClosestCloudTo(currentCloud, cloudList)
    local closestCloud = nil
    local closestDistance = math.huge
    for i, cloud in ipairs(cloudList) do
        if cloud ~= currentCloud then
            local distance = AI.CalcDistance(currentCloud.x, currentCloud.y, cloud.x, cloud.y)
            if distance <= closestDistance then
                closestDistance = distance
                closestCloud = cloud
            end
        end
    end
    return closestCloud
end

function valithria:FindNextClosestPortal(currentPortal, portalList)
    local closestPortal = nil
    local closestDistance = math.huge
    for i, portal in ipairs(portalList) do
        if portal ~= currentPortal then
            local distance = AI.CalcDistance(currentPortal.x, currentPortal.y, portal.x, portal.y)
            if distance <= closestDistance then
                closestDistance = distance
                closestPortal = portal
            end
        end
    end
    return closestPortal
end

AI.RegisterBossModule(valithria)
