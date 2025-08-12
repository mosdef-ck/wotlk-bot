local oldPriorityTargetFn = nil
local rad30 = 0.5235988
local rad22_5 = 0.3926991
local rad10 = 0.1745329
local rad5 = 0.08726646
local pi2 = math.pi * 2
local pi = math.pi
local rad45 = 0.785398
local rad90 = 1.570796
local rad100 = 1.745329
local rad120 = 2.094395
local rad135 = 2.356194

local icc = MosdefZoneModule:new({
    zoneName = "Icecrown Citadel",
    zoneId = 605,
    onEnter = function(self)
        oldPriorityTargetFn = AI.do_PriorityTarget
        AI.do_PriorityTarget = function(isAoE)
            if not AI.IsTank() then
                return AI.DoTargetChain("web wrap")
            end
        end
    end,
    onLeave = function(self)
        AI.do_PriorityTarget = oldPriorityTargetFn
    end
})

AI.RegisterZoneModule(icc)

local marrowGar = MosDefBossModule:new({
    name = "Marrowgar",
    creatureId = {36612},
    onStart = function(self)
        TargetUnit("lord")
        FocusUnit("target")
        -- AI.Config.startHealOverrideThreshold = 95
        AI.Config.starFormationRadius = 12
        AI.Config.manaTideThreshold = 20
        AI.DISABLE_DRAIN = true
        AI.do_PriorityTarget = function(isAoE)
            if not AI.IsTank() then
                return AI.DoTargetChain("bone spike", "marrowgar")
            end
        end
        AI.PRE_DO_DPS = function()
            RunMacroText("/petattack [@bone spike]")
            if AI.IsDps() and AI.IsValidOffensiveUnit() and strcontains(UnitName("target"), "bone spike") and
                AI.GetDistanceToUnit("target") > 35 then
                local p = AI.PathFinding.FindSafeSpotInCircle("target", 35, self:GetObstacles(), 1)
                if p and not AI.HasMoveTo() then
                    AI.SetMoveTo(p.x, p.y)
                end
            end
        end
        if AI.IsHeroicRaidOrDungeon() and not AI.HasBuff("lesser flask of resistance") and not AI.IsTank() then
            AI.UseContainerItem("lesser flask of resistance")
        end
        if AI.IsHealer() and AI.GetDistanceTo(self.healerP.x, self.healerP.y) > 3 and
            AI.ShouldMoveTo(self.healerP.x, self.healerP.y, self.healerP.z) then
            AI.SetMoveTo(self.healerP.x, self.healerP.y)
        elseif AI.IsDpsPosition(1) and AI.GetDistanceTo(self.dps1P.x, self.dps1P.y) > 3 and
            AI.ShouldMoveTo(self.dps1P.x, self.dps1P.y, self.dps1P.z) then
            AI.SetMoveTo(self.dps1P.x, self.dps1P.y)
        elseif AI.IsDpsPosition(2) and AI.GetDistanceTo(self.dps2P.x, self.dps2P.y) > 3 and
            AI.ShouldMoveTo(self.dps2P.x, self.dps2P.y, self.dps2P.z) then
            AI.SetMoveTo(self.dps2P.x, self.dps2P.y)
        elseif AI.IsDpsPosition(3) and AI.GetDistanceTo(self.dps3P.x, self.dps3P.y) > 3 and
            AI.ShouldMoveTo(self.dps3P.x, self.dps3P.y, self.dps3P.z) then
            AI.SetMoveTo(self.dps3P.x, self.dps3P.y)
        end
        AI.Config.useHealingWaveOnToons = true
    end,
    onStop = function(self)
        AI.Config.useHealingWaveOnToons = false
    end,
    onUpdate = function(self)
        if not AI.IsTank() and not AI.HasMoveTo() and (AI.IsDps() or not AI.IsCasting()) then
            local obstacles = self:GetObstacles()
            local playerP = AI.PathFinding.Vector3.new(AI.GetPosition())
            if not self:IsSpotSafeFromColdFlame(playerP) then
                -- AI.PathFinding.MoveToSafeLocationWithinPolygon(self.polygon, obstacles, 0.5)
                local delay = AI.HasBuff("bone storm", "focus") and AI.GetDistanceToUnit("focus") < 2 and 0.5 or 0
                AI.RegisterOneShotAction(function(self)
                    local p = AI.PathFinding.FindSafeSpotInCircle(self.tankP, self.tankR, obstacles, 1)
                    if p and AI.GetDistanceTo(p.x, p.y) > 3 then
                        AI.SetMoveTo(p.x, p.y)
                    end
                end, delay, "DODGE_COLD_FLAME")

            else
                if not AI.HasBuff("bone storm", "focus") and not strcontains(UnitName("target"), "bone spike") and
                    not AI.HasMoveTo() and not AI.IsCasting() then
                    if AI.IsHealer() and AI.GetDistanceTo(self.healerP.x, self.healerP.y) > 3 and
                        self:IsSpotSafeFromColdFlame(self.healerP) and AI.ShouldMoveTo(self.healerP) then
                        AI.SetMoveTo(self.healerP.x, self.healerP.y)
                    elseif AI.IsDpsPosition(1) and AI.GetDistanceTo(self.dps1P.x, self.dps1P.y) > 3 and
                        self:IsSpotSafeFromColdFlame(self.dps1P) and AI.ShouldMoveTo(self.dps1P) then
                        AI.SetMoveTo(self.dps1P.x, self.dps1P.y)
                    elseif AI.IsDpsPosition(2) and AI.GetDistanceTo(self.dps2P.x, self.dps2P.y) > 3 and
                        self:IsSpotSafeFromColdFlame(self.dps2P) and AI.ShouldMoveTo(self.dps2P) then
                        AI.SetMoveTo(self.dps2P.x, self.dps2P.y)
                    elseif AI.IsDpsPosition(3) and AI.GetDistanceTo(self.dps3P.x, self.dps3P.y) > 3 and
                        self:IsSpotSafeFromColdFlame(self.dps3P) and AI.ShouldMoveTo(self.dps3P) then
                        AI.SetMoveTo(self.dps3P.x, self.dps3P.y)
                    end
                end
            end
        end

    end,
    stormTime = 0,
    healerP = AI.PathFinding.Vector3.new(-345.96343994141, 2197.8630371094, 42.544063568115),
    dps1P = AI.PathFinding.Vector3.new(-366.29782104492, 2199.7543945313, 41.614604949951),
    dps2P = AI.PathFinding.Vector3.new(-364.75579833984, 2225.65234375, 41.758007049561),
    dps3P = AI.PathFinding.Vector3.new(-349.06317138672, 2229.1171875, 42.534591674805),
    centerP = AI.PathFinding.Vector3.new(-388.21759033203, 2212.9926757813, 41.993892669678),
    tankP = AI.PathFinding.Vector3.new(-362.99185180664, 2210.7692871094, 42.216464996338),
    tP = AI.PathFinding.Vector3.new(-340.50619506836, 2214.0368652344, 42.563850402832),
    tankR = 20,
    polygon = {AI.PathFinding.Vector3.new(-345.96343994141, 2197.8630371094, 42.544063568115),
               AI.PathFinding.Vector3.new(-366.29782104492, 2199.7543945313, 41.614604949951),
               AI.PathFinding.Vector3.new(-364.75579833984, 2225.65234375, 41.758007049561),
               AI.PathFinding.Vector3.new(-349.06317138672, 2229.1171875, 42.534591674805)}
})

function marrowGar:CHAT_MSG_RAID_BOSS_EMOTE(s, t)
    if strcontains(s, "storm") then
        self.stormTime = GetTime()
        if AI.IsDps() then
            AI.DISABLE_CDS = true
        end
        AI.RegisterPendingAction(function(self)
            if not strcontains(UnitName("target"), "bone spike") and not AI.IsCasting() then
                if AI.IsHealer() and AI.GetDistanceTo(self.healerP.x, self.healerP.y) > 3 and
                    self:IsSpotSafeFromColdFlame(self.healerP) and AI.ShouldMoveTo(self.healerP) then
                    AI.SetMoveTo(self.healerP.x, self.healerP.y)
                elseif AI.IsDpsPosition(1) and AI.GetDistanceTo(self.dps1P.x, self.dps1P.y) > 3 and
                    self:IsSpotSafeFromColdFlame(self.dps1P) and AI.ShouldMoveTo(self.dps1P) then
                    AI.SetMoveTo(self.dps1P.x, self.dps1P.y)
                elseif AI.IsDpsPosition(2) and AI.GetDistanceTo(self.dps2P.x, self.dps2P.y) > 3 and
                    self:IsSpotSafeFromColdFlame(self.dps2P) and AI.ShouldMoveTo(self.dps2P) then
                    AI.SetMoveTo(self.dps2P.x, self.dps2P.y)
                elseif AI.IsDpsPosition(3) and AI.GetDistanceTo(self.dps3P.x, self.dps3P.y) > 3 and
                    self:IsSpotSafeFromColdFlame(self.dps3P) and AI.ShouldMoveTo(self.dps3P) then
                    AI.SetMoveTo(self.dps3P.x, self.dps3P.y)
                end
                return true
            end
        end)
    end
end

function marrowGar:SPELL_AURA_APPLIED(args)
    if strcontains(args.spellName, "bone storm") and not AI.IsTank() then
        if AI.IsMage() then
            AI.MustCastSpell("frost ward")
        end
    end
end

function marrowGar:SPELL_AURA_REMOVED(args)
    if strcontains(args.spellName, "bone storm") and not AI.IsTank() then
        self.stormTime = 0
    end
    AI.DISABLE_CDS = false
end

function marrowGar:GetObstacles()
    local coldFlame = AI.FindNearbyDynamicObjects("coldflame")
    for i, o in ipairs(coldFlame) do
        o.radius = normalizeObstacleRadius(6)
    end
    local allies = AI.GetAlliesAsObstacles(3)
    for i, o in ipairs(allies) do
        table.insert(coldFlame, o)
    end
    -- if not AI.HasBuff("bone storm", "focus") then
    local marrowGar = AI.GetObjectInfo("focus")
    marrowGar.radius = 5
    table.insert(coldFlame, marrowGar)
    -- end
    return coldFlame
end

function marrowGar:IsSpotSafeFromColdFlame(p)
    local obstacles = self:GetObstacles()
    for i, o in ipairs(obstacles) do
        if AI.CalcDistance(p.x, p.y, o.x, o.y) <= o.radius then
            return false
        end
    end
    return true
end

function marrowGar:SMSG_SPELL_CAST_GO(spellId, spellName, casterGuid, targetGuid, src, dest)
    if (strcontains(spellName, "bone spike") or strcontains(spellName, "impaled")) and AI.IsDps() then
        AI.StopCasting()
        AI.DoTargetChain("bone spike", "marrowgar")
    end
end

AI.RegisterBossModule(marrowGar)

local ladyDeath = MosDefBossModule:new({
    name = "Lady Deathwhisper",
    creatureId = {36855},
    onStart = function(self)
        TargetUnit("lady deathwhisper")
        FocusUnit("target")
        if AI.IsTank() then
            AI.ALLOW_AUTO_REFACE = false
        end
        -- AI.Config.startHealOverrideThreshold = 95
        AI.Config.starFormationRadius = 15
        if AI.IsHeroicRaidOrDungeon() and not AI.HasBuff("lesser flask of resistance") and not AI.IsTank() then
            AI.UseContainerItem("lesser flask of resistance")
        end
        -- if AI.IsHealer() then
        --     AI.AUTO_CLEANSE = false
        -- end
        -- AI.PRE_DO_DPS = function()
        --     if AI.IsDps() and AI.IsValidOffensiveUnit() and AI.GetDistanceToUnit("target") > 35 then
        --         local p = AI.PathFinding.FindSafeSpotInCircle("target", 35, {})
        --         if p and not AI.HasMoveTo() then
        --             AI.SetMoveTo(p.x, p.y)
        --         end
        --     end
        -- end
        AI.do_PriorityTarget = nil
        AI.PRE_DO_DPS = nil
        if AI.IsHealer() and AI.GetDistanceTo(self.healerP.x, self.healerP.y) > 3 and
            self:IsSpotSafeFromDeathAndDecay(self.healerP) and not AI.IsCasting() and AI.ShouldMoveTo(self.healerP) then
            AI.SetMoveTo(self.healerP.x, self.healerP.y)
        elseif AI.IsDpsPosition(1) and AI.GetDistanceTo(self.dps1P.x, self.dps1P.y) > 3 and
            self:IsSpotSafeFromDeathAndDecay(self.dps1P) and not AI.IsCasting() and AI.ShouldMoveTo(self.dps1P) then
            AI.SetMoveTo(self.dps1P.x, self.dps1P.y)
        elseif AI.IsDpsPosition(2) and AI.GetDistanceTo(self.dps2P.x, self.dps2P.y) > 3 and
            self:IsSpotSafeFromDeathAndDecay(self.dps2P) and not AI.IsCasting() and AI.ShouldMoveTo(self.dps2P) then
            AI.SetMoveTo(self.dps2P.x, self.dps2P.y)
        elseif AI.IsDpsPosition(3) and AI.GetDistanceTo(self.dps3P.x, self.dps3P.y) > 3 and
            self:IsSpotSafeFromDeathAndDecay(self.dps3P) and not AI.IsCasting() and AI.ShouldMoveTo(self.dps3P) then
            AI.SetMoveTo(self.dps3P.x, self.dps3P.y)
        end
        AI.AUTO_CLEANSE = false
        -- AI.Config.curseToUse = "curse of the elements"
    end,
    onStop = function(self)
        AI.ALLOW_AUTO_REFACE = true
    end,
    onUpdate = function(self)
        if not self.darnavan then
            local darnavan = AI.FindNearbyUnitsByName("darnavan")
            if #darnavan > 0 then
                self.darnavan = darnavan[1].guid
            end
        end
        if AI.IsDps() and self.dominateTarget and UnitName("player") ~= self.dominateTarget and not AI.IsCasting() and
            GetTime() > self.lastCCTime + 10 then
            local info = AI.GetObjectInfo(self.dominateTarget)
            if info and not AI.IsUnitCC(info) then
                if AI.IsMage() and AI.CastSpell("polymorph", self.dominateTarget) then
                    print('polymorphing dominated target: ' .. self.dominateTarget)
                    self.lastCCTime = GetTime()
                    return true
                end
                -- if AI.IsWarlock() then
                --     AI.RegisterOneShotAction(function(self)
                --         local info = AI.GetObjectInfo(self.dominateTarget)
                --         if AI.IsCasting() then
                --             AI.StopCasting()
                --         end
                --         if info and not AI.IsUnitCC(info) and AI.CastSpell("fear", self.dominateTarget) then
                --             print('fearing dominated target: ' .. self.dominateTarget)
                --             return true
                --         end
                --     end, 2, "CC_DOMINATED")
                -- end
            end
        end
        if self.touchedTarget and (AI.IsPriest() or AI.IsHealer()) then
            local spell = "dispel magic"
            if AI.CastSpell(spell, self.touchedTarget) then
                print('cleansing touched target: ' .. self.touchedTarget)
                return true
            end
        end

        if self.cursedTarget and (AI.IsMage() or AI.IsHealer()) then
            local spell = AI.IsHealer() and "cleanse spirit" or "remove curse"
            if AI.CastSpell(spell, self.cursedTarget) then
                print('cleansing cursed target: ' .. self.cursedTarget)
                return true
            end
        end

        if not AI.IsTank() and AI.HasDebuff("death and decay") and not AI.HasMoveTo() and
            (not AI.IsHealer() or not AI.IsCasting()) then
            local dnd = self:GetDND()
            local allies = AI.GetAlliesAsObstacles(5)
            for i, o in ipairs(allies) do
                table.insert(dnd, o)
            end
            local p = AI.PathFinding.FindSafeSpotWithinRadiusCorridor(self.tankP, 15, 25, dnd, 1)
            if p then
                AI.SetMoveTo(p.x, p.y)
            end
        end

        if AI.IsHealer() and AI.GetDistanceTo(self.healerP.x, self.healerP.y) > 3 and
            self:IsSpotSafeFromDeathAndDecay(self.healerP) and not AI.IsCasting() and AI.ShouldMoveTo(self.healerP) then
            AI.SetMoveTo(self.healerP.x, self.healerP.y)
        elseif AI.IsDpsPosition(1) and AI.GetDistanceTo(self.dps1P.x, self.dps1P.y) > 3 and
            self:IsSpotSafeFromDeathAndDecay(self.dps1P) and not AI.IsCasting() and AI.ShouldMoveTo(self.dps1P) then
            AI.SetMoveTo(self.dps1P.x, self.dps1P.y)
        elseif AI.IsDpsPosition(2) and AI.GetDistanceTo(self.dps2P.x, self.dps2P.y) > 3 and
            self:IsSpotSafeFromDeathAndDecay(self.dps2P) and not AI.IsCasting() and AI.ShouldMoveTo(self.dps2P) then
            AI.SetMoveTo(self.dps2P.x, self.dps2P.y)
        elseif AI.IsDpsPosition(3) and AI.GetDistanceTo(self.dps3P.x, self.dps3P.y) > 3 and
            self:IsSpotSafeFromDeathAndDecay(self.dps3P) and not AI.IsCasting() and AI.ShouldMoveTo(self.dps3P) then
            AI.SetMoveTo(self.dps3P.x, self.dps3P.y)
        end

        if AI.IsTank() and strcontains(UnitName("target"), "deformed") and AI.GetDistanceToUnit("target") <= 5.5 and
            AI.CastSpell("hammer of justice", "target") then
            return true
        end

        if AI.IsWarlock() and self.darnavan ~= nil then
            local darnavanInfo = AI.GetObjectInfoByGUID(self.darnavan)
            if darnavanInfo and darnavanInfo.distance <= 20 and not darnavanInfo.isDead and
                not AI.IsUnitCC(darnavanInfo) and not AI.IsCasting() and AI.CastSpell("fear", self.darnavan) then
                print('fearing darnavan')
                return true
            end
        end
    end,
    dominateTarget = nil,
    touchedTarget = nil,
    cursedTarget = nil,
    dps1P = AI.PathFinding.Vector3.new(-635.64892578125, 2225.4775390625, 51.869136810303),
    dps2P = AI.PathFinding.Vector3.new(-657.91094970703, 2228.3107910156, 51.839881896973),
    healerP = AI.PathFinding.Vector3.new(-661.28668212891, 2205.447265625, 51.841480255127),
    dps3P = AI.PathFinding.Vector3.new(-640.84240722656, 2195.3986816406, 51.878345489502),
    tankP = AI.PathFinding.Vector3.new(-637.54956054688, 2212.9353027344, 51.55154800415),
    lastCCTime = 0,
    darnavan = nil
})

function ladyDeath:SMSG_SPELL_CAST_GO(spellId, spellName, casterGuid, targetGuid, src, dest)
    if not AI.IsTank() and strcontains(spellName, "death and decay") and AI.GetDistanceTo(dest.x, dest.y) < 8 then
        local dnd = self:GetDND()
        local allies = AI.GetAlliesAsObstacles(5)
        for i, o in ipairs(allies) do
            table.insert(dnd, o)
        end
        local p = AI.PathFinding.FindSafeSpotWithinRadiusCorridor(self.tankP, 15, 25, dnd)
        if p then
            AI.SetMoveTo(p.x, p.y)
        end
    end
end

function ladyDeath:SPELL_AURA_APPLIED(args)
    if strcontains(args.spellName, "dominate mind") then
        self.dominateTarget = args.target
    end
    if strcontains(args.spellName, "touch of insignificance") then
        self.touchedTarget = args.target
    end
    if strcontains(args.spellName, "curse of torpor") then
        self.cursedTarget = args.target
    end
end

function ladyDeath:SPELL_CAST_START(args)
    if args.spellName == "Frostbolt" and not AI.IsHealer() and strcontains(args.caster, "deathwhisper") then
        AI.DoStaggeredInterrupt()
    end
end

function ladyDeath:SPELL_AURA_REMOVED(args)
    if strcontains(args.spellName, "dominate mind") then
        self.dominateTarget = nil
    end
    if strcontains(args.spellName, "touch of insignificance") then
        self.touchedTarget = nil
    end
    if strcontains(args.spellName, "curse of torpor") then
        self.cursedTarget = nil
    end
end

function ladyDeath:GetDND()
    local dnd = AI.FindNearbyDynamicObjects(72109, "death and decay", 71001)
    for i, o in ipairs(dnd) do
        o.radius = o.radius * 2
    end
    return dnd
end

function ladyDeath:IsSpotSafeFromDeathAndDecay(p)
    local dnd = self:GetDND()
    for i, o in ipairs(dnd) do
        if AI.CalcDistance(p.x, p.y, o.x, o.y) <= o.radius then
            return false
        end
    end
    return true
end

AI.RegisterBossModule(ladyDeath)

local rottingGiant = MosDefBossModule:new({
    name = "Rotting Giant",
    creatureId = {38490},
    onStart = function(self)
        AI.Config.starFormationRadius = 12
    end,
    onStop = function(self)
    end,
    onUpdate = function(self)
    end
})

AI.RegisterBossModule(rottingGiant)

local gunship = MosDefBossModule:new({
    name = "Gunship Battle",
    subzone = "Rampart of Skulls",
    creatureId = {36939, 37215},
    onStart = function(self)
        if AI.IsTank() then
            AI.ALLOW_AUTO_REFACE = false
        end
        AI.Config.starFormationRadius = 15
        if AI.IsHeroicRaidOrDungeon() and not AI.HasBuff("flask of the frost wyrm") and not AI.IsTank() then
            AI.UseContainerItem("flask of the frost wyrm")
        end
        AI.do_PriorityTarget = function()
            if AI.IsDps() and not AI.IsPossessing() and self.channelingSorcerer and UnitGUID("target") ~=
                self.channelingSorcerer then
                local sorcerer = AI.GetObjectInfoByGUID(self.channelingSorcerer)
                if sorcerer and not sorcerer.isDead and sorcerer.distance <= 35 then
                    sorcerer:Target()
                    return true
                end
                if not sorcerer or sorcerer.isDead then
                    self.channelingSorcerer = nil
                end
            end
            if AI.IsDps() and AI.IsPossessing() then
                return AI.DoTargetChain("skybreaker sergeant", "skybreaker mortar soldier", "skybreaker rifleman",
                    "skybreaker sorcerer")
            end
        end
        AI.PRE_DO_DPS = function(isAoE)
            if self:IsGunnerCrew() and AI.IsPossessing() then
                return true
            end
            if AI.IsDps() and self.channelingSorcerer and UnitGUID("target") == self.channelingSorcerer then
                AI.UseInventorySlot(10)
                AI.UseInventorySlot(13)
                AI.UseInventorySlot(14)
            end
        end

        if AI.IsTank() then
            AI.RegisterOneShotAction(function(self)
                local guns = AI.FindNearbyUnitsByName("gunship cannon")
                if #guns == 2 and guns[1].distance <= 50 then
                    guns[1]:Target()
                    SetRaidTarget("target", 1)
                    guns[2]:Target()
                    SetRaidTarget("target", 2)
                    AI.SendAddonMessage("go-to-cannon", self.gunner1, guns[1].guid)
                    AI.SendAddonMessage("go-to-cannon", self.gunner2, guns[2].guid)
                end
            end, 1)

        end
    end,
    onStop = function(self)
        AI.ALLOW_AUTO_REFACE = true
    end,
    onUpdate = function(self)
        local tick = GetTime()
        if self:IsGunnerCrew() then
            if AI.IsPossessing() then
                local angle = ternary(strcontains(UnitName("player"), self.gunner1), self.gunner1Angle,
                    self.gunner2Angle)
                AI.do_PriorityTarget()
                VehicleAimRequestNormAngle(angle)
                -- AI.SetFacingUnit("target")
                if AI.IsValidOffensiveUnit() and
                    ((UnitPower("playerpet") >= 90 and AI.CastVehicleSpellOnDestination("incinerating blast", "target")) or
                        AI.CastVehicleSpellOnDestination("cannon blast", "target")) then
                    return true
                end
                return true
            end
            if not AI.IsPossessing() then
                local cannon = AI.GetObjectInfoByGUID(self.cannonToUse)
                if cannon then
                    if AI.GetDistanceToUnit(cannon) > 5 and GetFollowTarget() ~= cannon.guid then
                        SetFollowTarget(cannon.guid)
                    elseif AI.GetDistanceToUnit(cannon) <= 4 then
                        AI.ResetMoveTo()
                        if AI.IsMoving() then
                            AI.StopMoving()
                        end
                        cannon:InteractWith()
                    end
                    self.lastMoveTime = tick
                end
            end
        end

        if AI.IsTank() and self.cannonsFrozen then
            local portal = AI.FindNearbyUnitsByName("aliance ship teleport")
            if #portal > 0 and portal[1].distance <= 5 then
                portal[1]:InteractWith()
                AI.RegisterOneShotAction(function(self)
                    AI.SendAddonMessage("take-attack-portal")
                    local sorcerers = AI.FindNearbyUnitsByName("skybreaker sorcerer")
                    for i, o in ipairs(sorcerers) do
                        if not o.isDead and o.channelingSpellId == 69705 then
                            o:Target()
                            self.channelingSorcerer = o.guid
                            AI.SendAddonMessage("set-channeler-target", o.guid)
                            SetRaidTarget("target", 8) -- Set a raid marker for the channeling sorcerer
                        end
                    end
                end, 1, "BOARD_GUNSHIP")
            end
        end

        if not AI.IsTank() and not AI.IsPossessing() and not AI.HasMoveTo() and
            not self:IsSafeFromArtillery(AI.PathFinding.Vector3.new(AI.GetPosition())) then
            local artillery = AI.FindNearbyDynamicObjects("artillery")
            local p = AI.PathFinding.FindSafeSpotInCircle(AI.GetPrimaryTank(), 25, artillery, 5)
            if p then
                print('dodging incoming artillery')
                AI.SetMoveTo(p.x, p.y)
            end
        end

        -- clean up inflight artillery
        for i = #self.inflightArtillery, 1, -1 do
            local artillery = self.inflightArtillery[i]
            if tick > artillery.impactTime then
                table.remove(self.inflightArtillery, i)
            end
        end
    end,
    gunner1 = "Mosdefswp",
    gunner2 = "Mosdeffmage",
    cannonToUse = nil,
    gunner1Angle = 0.35966,
    gunner2Angle = 0.42184,
    -- desiredAimAngle = 0.39564,
    channelingSorcerer = nil,
    lastDodgeTime = 0,
    lastMoveTime = 0,
    cannonsFrozen = false,
    artillerySpeed = 16.5,
    inflightArtillery = {}
})

function gunship:ON_ADDON_MESSAGE(from, cmd, args)
    if cmd == "go-to-cannon" and self:IsGunnerCrew() then
        -- print("gunship:ON_ADDON_MESSAGE", cmd, args)
        local gunner, gun = splitstr2(args, ",")
        if strcontains(UnitName("player"), gunner) then
            local gunInfo = AI.GetObjectInfoByGUID(gun)
            if gunInfo and gunInfo.distance <= 50 then
                self.cannonToUse = gun
            end
        end
    end
    if cmd == "set-channeler-target" then
        -- print("gunship:ON_ADDON_MESSAGE", cmd, args)
        local sorcerer = AI.GetObjectInfoByGUID(args)
        if sorcerer and not sorcerer.isDead then
            self.channelingSorcerer = sorcerer.guid
        end
    end

    if cmd == "take-attack-portal" and not AI.IsTank() then
        -- print("gunship:ON_ADDON_MESSAGE", cmd, args)
        local portal = AI.FindNearbyUnitsByName("aliance ship teleport")
        if #portal > 0 then
            if portal[1].distance <= 5 then
                portal[1]:InteractWith()
            else
                local p = AI.PathFinding.FindSafeSpotInCircle(portal[1], 4)
                AI.SetMoveTo(p.x, p.y, p.z, 0, function()
                    portal[1]:InteractWith()
                end)
                print("moving to alliance ship teleport")
            end
        else
            print('no alliance ship teleport found')
        end
    end

    if cmd == "return-to-ship" and not AI.IsTank() then
        -- print("gunship:ON_ADDON_MESSAGE", cmd, args)

        local portal = AI.FindNearbyUnitsByName("horde ship teleport")
        if #portal > 0 then
            if portal[1].distance <= 5 then
                portal[1]:InteractWith()
                if self:IsGunnerCrew() then
                    AI.RegisterOneShotAction(function(self)
                        local guns = AI.FindNearbyUnitsByName("gunship cannon")
                        if #guns == 2 then
                            for i, gun in ipairs(guns) do
                                if gun.raidTargetIndex == 1 and strcontains(UnitName("player"), self.gunner1) then
                                    self.cannonToUse = gun.guid
                                elseif gun.raidTargetIndex == 2 and strcontains(UnitName("player"), self.gunner2) then
                                    self.cannonToUse = gun.guid
                                end
                            end
                        end
                    end, 0.5)
                end
            else
                local p = AI.PathFinding.FindSafeSpotInCircle(portal[1], 4)
                AI.SetMoveTo(p.x, p.y, p.z, 0, function(self)
                    portal[1]:InteractWith()
                    if self:IsGunnerCrew() then
                        AI.RegisterOneShotAction(function(self)
                            local guns = AI.FindNearbyUnitsByName("gunship cannon")
                            if #guns == 2 then
                                for i, gun in ipairs(guns) do
                                    if gun.raidTargetIndex == 1 and strcontains(UnitName("player"), self.gunner1) then
                                        self.cannonToUse = gun.guid
                                    elseif gun.raidTargetIndex == 2 and strcontains(UnitName("player"), self.gunner2) then
                                        self.cannonToUse = gun.guid
                                    end
                                end
                            end
                        end, 0.5)
                    end
                end)
            end
        else
            print('no horde ship teleport found')
        end
    end
end

function gunship:SMSG_SPELL_CAST_GO(spellId, spellName, casterGuid, targetGuid, src, dest)
    if spellId == 69679 then
        -- print("gunship:SMSG_SPELL_CAST_GO", spellId, spellName, casterGuid, targetGuid, table2str(src), table2str(dest))
        local caster = AI.GetObjectInfoByGUID(casterGuid)
        local casterx, castery = NormalizeCoordinates(caster.x, caster.y, caster.z)
        local distToTarget = AI.CalcDistance(dest.x, dest.y, casterx, castery)
        local time = distToTarget / self.artillerySpeed
        table.insert(self.inflightArtillery, {
            impactTime = GetTime() + time,
            casterGuid = casterGuid,
            dest = dest
        })
        -- print("inc artillery from ", casterx, castery, " to ", dest.x, dest.y, " will hit in ", time, " seconds")
    end
end

function gunship:IsSafeFromArtillery(p)
    local tick = GetTime()
    local nx, ny, nz = NormalizeCoordinates(p.x, p.y, p.z)
    for i, artillery in ipairs(self.inflightArtillery) do
        if AI.CalcDistance(nx, ny, artillery.dest.x, artillery.dest.y) <= 7 and artillery.impactTime - tick <= 2 then
            return false
        end
    end
    return true
end

function gunship:CHAT_MSG_MONSTER_YELL(s, t)
    if strcontains(s, "hull damage") and self:IsGunnerCrew() then
        if UnitPower("playerpet") >= 5 then
            AI.RegisterPendingAction(function(self)
                return AI.UsePossessionSpell("incinerating blast")
            end)
        end
    end
end

function gunship:IsGunnerCrew()
    local plrName = UnitName("player")
    return strcontains(plrName, self.gunner1) or strcontains(plrName, self.gunner2)
end

function gunship:UNIT_DIED(unit)
    if strcontains(unit, "skybreaker sorcerer") then
        self.cannonsFrozen = false
        -- print("Skybreaker Sorcerer dead, cannons unfrozen")
        if AI.IsTank() then
            AI.SendAddonMessage('return-to-ship')
        end
    end
    -- if strcontains(unit, "skybreaker sergeant") then
    --     if AI.IsTank() then
    --     end
    -- end
end

function gunship:SPELL_CAST_START(args)
    if strcontains(args.spellName, "below zero") or args.spellId == 69705 and self:IsGunnerCrew() then
        self.cannonsFrozen = true
        -- print("skybreaker Sorcerer casting below zero, exiting")
        if self:IsGunnerCrew() and AI.IsPossessing() then
            VehicleExit()
        end
        if self.cannonToUse then
            self.cannonToUse = nil
        end
    end
end

function gunship:GetDangerousRiflemen()
    local riflemen = AI.FindNearbyUnitsByName("skybreaker rifleman")
    for i, rifleman in ipairs(riflemen) do
        if not rifleman.isDead and (rifleman:HasAura("veteran") or rifleman:HasAura("elite")) then
            return rifleman
        end
    end
    return nil
end

AI.RegisterBossModule(gunship)

local deathbringer = MosDefBossModule:new({
    name = "Deathbringer Saurfang",
    creatureId = {37813},
    onStart = function(self)
        TargetUnit("deathbringer saurfang")
        FocusUnit("target")
        AI.Config.starFormationRadius = 15
        if AI.IsHeroicRaidOrDungeon() and not AI.HasBuff("flask of the frost wyrm") and not AI.IsTank() then
            AI.UseContainerItem("flask of the frost wyrm")
        end
        AI.do_PriorityTarget = function()
            if AI.GetUnitHealthPct("focus") > 7 and UnitPower("focus") <= 70 then
                return AI.DoTargetChain("blood beast")
            end
        end
        AI.PRE_DO_DPS = nil
        -- AI.Config.curseToUse = "curse of the elements"

        AI.Config.judgementToUse = "judgement of light"
    end,
    onStop = function(self)
    end,
    onUpdate = function(self)
        -- AI.DISABLE_DEEP_FREEZE = not strcontains(UnitName("target"), "blood beast")
        if AI.IsTank() and strcontains(UnitName("target"), "blood beast") and not AI.IsUnitCC("target") and
            AI.CastSpell("hammer of justice", "target") then
            return true
        end
        if AI.IsWarlock() and strcontains(UnitName("target"), "blood beast") and
            AI.HasDebuff("hammer of justice", "target") then
            local duration = AI.GetDebuffDuration("hammer of justice", "target")
            AI.RegisterPendingAction(function()
                if strcontains(UnitName("target"), "blood beast") then
                    return AI.CastAOESpell("shadowfury", "target")
                end
                return true
            end, duration, "STUN_CHAIN")
        end
    end
})

function deathbringer:SPELL_AURA_APPLIED(args)
    if strcontains(args.spellName, "rune of blood") then
        if AI.IsHealer() or AI.IsPaladin() then
            AI.RegisterPendingAction(function(self)
                if AI.HasDebuff("rune of blood", args.target) then
                    local spell = AI.IsHealer() and "cleanse spirit" or "cleanse"
                    return AI.CleanseFriendly(spell, args.target)
                end
                return true
            end)
        end
    end

    if strcontains(args.spellName, "boiling blood") and AI.HasDebuff("mark of the fallen champion", args.target) then
        if AI.IsMage() and UnitName("player") == args.target and AI.CanCastSpell("ice block", nil, true) then
            AI.MustCastSpell("ice block", nil)
            AI.RegisterOneShotAction(function()
                CancelUnitBuff("player", "ice block")
            end, 1)
        end
    end
end

AI.RegisterBossModule(deathbringer)

local precious = MosDefBossModule:new({
    name = "Precious/Stinky",
    creatureId = {37217, 37025},
    onStart = function(self)
    end,
    onUpdate = function(self)
        if AI.IsHealer() and GetTime() < self.lastDecimateTime + 5 then
            local healTar, missingHp, secondTar, secondTarHp = AI.GetMostDamagedFriendly("chain heal")
            if healTar and AI.CastSpell("chain heal", healTar) then
                return true
            end
        end
    end,
    lastDecimateTime = 0
})

function precious:SPELL_CAST_START(args)
    if strcontains(args.spellName, "decimate") and AI.IsHealer() then
        print("decimate incoming")
        self.lastDecimateTime = GetTime() + 3
        AI.RegisterPendingAction(function(self)
            return AI.CastSpell("chain heal", AI.GetPrimaryTank())
        end, 2, "PRE_CAST_CHAIN_HEAL")
    end
end

AI.RegisterBossModule(precious)

local rotface = MosDefBossModule:new({
    name = "Rotface",
    creatureId = {36627},
    onStart = function(self)
        AI.AUTO_CLEANSE = false
        TargetUnit("rotface")
        FocusUnit("target")
        AI.Config.starFormationRadius = 11
        -- if AI.IsHeroicRaidOrDungeon() and not AI.HasBuff("flask of the frost wyrm") and not AI.IsTank() then
        --     AI.UseContainerItem("flask of the frost wyrm")
        -- end        
        if AI.IsHeroicRaidOrDungeon() and not AI.HasBuff("lesser flask of resistance") and not AI.IsTank() then
            AI.UseContainerItem("lesser flask of resistance")
        end
        if not AI.IsTank() then
            AI.RegisterOneShotAction(function(self)
                local hx, hy = AI.GetPosition(AI.GetPrimaryHealer())
                local theta = AI.CalcFacing(self.centerP.x, self.centerP.y, hx, hy)
                local r = 11
                if AI.IsHealer() then
                    AI.SetMoveTo(hx + r * math.cos(theta), hy + r * math.sin(theta))
                end
                if AI.IsDpsPosition(1) then
                    theta = theta + rad90 * 1
                    AI.SetMoveTo(hx + r * math.cos(theta), hy + r * math.sin(theta))
                end
                if AI.IsDpsPosition(2) then
                    theta = theta + rad90 * 2
                    AI.SetMoveTo(hx + r * math.cos(theta), hy + r * math.sin(theta))
                end
                if AI.IsDpsPosition(3) then
                    theta = theta + rad90 * 3
                    AI.SetMoveTo(hx + r * math.cos(theta), hy + r * math.sin(theta))
                end
            end, 5)
        end
    end,
    onStop = function(self)
    end,
    onUpdate = function(self)
        if (AI.IsHealer() or AI.IsPaladin()) and self.infectedPlr then
            local infectedPlr = AI.GetObjectInfo(self.infectedPlr)
            local littleOoze = AI.FindNearbyUnitsByName("little ooze")
            local bigOoze = AI.FindNearbyUnitsByName("big ooze")
            if #littleOoze > 0 then
                local spell = AI.IsHealer() and "cleanse spirit" or "cleanse"
                if AI.CastSpell(spell, infectedPlr) then
                    print('little oozes r close -cleansing mutated infection from: ' .. self.infectedPlr)
                    return true
                end
            end
            if #bigOoze > 0 and AI.CalcDistance(bigOoze[1].x, bigOoze[1].y, infectedPlr.x, infectedPlr.y) <= 3 then
                local spell = AI.IsHealer() and "cleanse spirit" or "cleanse"
                if AI.CastSpell(spell, self.infectedPlr) then
                    print('close to Big-Ooze cleansing mutated infection from: ' .. self.infectedPlr)
                    return true
                end
            end
        end
        if AI.IsTank() then
            local bigOoze = AI.FindNearbyUnitsByName("big ooze")
            if #bigOoze > 0 then
                if UnitGUID("focus") ~= bigOoze[1].guid then
                    bigOoze[1]:Focus()
                end
                if not AI.IsTanking("player", "focus") and AI.CastSpell("Hand of Reckoning", "focus") then
                    -- print('taunting big ooze')
                    return true
                end
            end

        end
    end,
    centerP = AI.PathFinding.Vector3.new(4445.8701171875, 3137.3100585938, 360.38540649414),
    infectedPlr = nil
})

function rotface:SPELL_AURA_APPLIED(args)
    if strcontains(args.spellName, "mutated infection") then
        self.infectedPlr = args.target
    end
end
function rotface:SPELL_AURA_REMOVED(args)
    if strcontains(args.spellName, "mutated infection") then
        self.infectedPlr = nil
    end
end

AI.RegisterBossModule(rotface)

local festergut = MosDefBossModule:new({
    name = "Festergut",
    creatureId = {36626},
    onStart = function(self)
        TargetUnit("festergut")
        FocusUnit("target")
        AI.Config.starFormationRadius = 12
        if AI.IsHeroicRaidOrDungeon() and not AI.HasBuff("flask of the frost wyrm") and not AI.IsTank() then
            AI.UseContainerItem("flask of the frost wyrm")
        end
        -- if AI.IsHeroicRaidOrDungeon() and not AI.HasBuff("lesser flask of resistance") and not AI.IsTank() then
        --     AI.UseContainerItem("lesser flask of resistance")
        -- end
        -- if AI.IsTank() then
        --     AI.RegisterOneShotAction(function(self)
        --         AI.MustCastSpell("hand of salvation", AI.GetPrimaryHealer())
        --     end, 1)
        -- end
    end,
    onStop = function(self)
    end,
    onUpdate = function(self)
        if self.gasSporeTarget then
            local duration = AI.GetDebuffDuration("gas spore", self.gasSporeTarget)
            if AI.IsDps() and duration <= 4 and AI.GetDebuffCount("inoculated") < 2 and not AI.HasMoveTo() then
                local tarToMoveTo =
                    AI.GetDebuffCount("inoculated", AI.GetPrimaryHealer()) >= 2 and self.gasSporeTarget or
                        AI.GetPrimaryHealer()
                local p = AI.PathFinding.FindSafeSpotInCircle(tarToMoveTo, 3)
                if GetTime() <= self.gooImpactTime then
                    self.gooImpactTarget.radius = 7
                    AI.PathFinding.MoveSafelyTo(p, {self.gooImpactTarget})
                else
                    AI.SetMoveTo(p.x, p.y)
                end
            end
        end
        if not AI.IsTank() and GetTime() <= self.gooImpactTime then
            local obstacles = AI.GetAlliesAsObstacles(7)
            self.gooImpactTarget.radius = 7
            table.insert(obstacles, self.gooImpactTarget)
            if (not self.gasSporeTarget or GetTime() + AI.GetDebuffDuration("gas spore", self.gasSporeTarget) >=
                self.gooImpactTime) and AI.GetDistanceTo(self.gooImpactTarget.x, self.gooImpactTarget.y) <=
                self.gooImpactTarget.radius or not AI.IsCurrentPathSafeFromObstacles({self.gooImpactTarget}) then
                local p = AI.PathFinding.FindSafeSpotWithinRadiusCorridor(self.centerP, 1, 20, obstacles, 2)
                if p and (not AI.HasMoveTo() or AI.ShouldMoveTo(p)) then
                    -- print('dodging malleable goo')
                    AI.SetMoveTo(p.x, p.y)
                end
            end
        end
    end,
    centerP = AI.PathFinding.Vector3.new(4268.5571289063, 3137.4516601563, 360.38549804688),
    gasSporeTarget = nil,
    gooImpactTime = 0,
    gooImpactTarget = nil
})

function festergut:SPELL_AURA_APPLIED(args)
    if strcontains(args.spellName, "gas spore") then
        self.gasSporeTarget = args.target
    end
end
function festergut:SPELL_AURA_REMOVED(args)
    if strcontains(args.spellName, "gas spore") then
        self.gasSporeTarget = nil
        if AI.IsDps() then
            AI.RegisterPendingAction(function(self)
                local hX, hY = AI.GetPosition(AI.GetPrimaryHealer())
                local theta = AI.CalcFacing(self.centerP.x, self.centerP.y, hX, hY)
                local r = 13
                local x, y
                if AI.IsDpsPosition(1) then
                    theta = theta + rad90 * 1
                    x = self.centerP.x + r * math.cos(theta)
                    y = self.centerP.y + r * math.sin(theta)
                end
                if AI.IsDpsPosition(2) then
                    theta = theta + rad90 * 2
                    x = self.centerP.x + r * math.cos(theta)
                    y = self.centerP.y + r * math.sin(theta)

                end
                if AI.IsDpsPosition(3) then
                    theta = theta + rad90 * 3
                    x = self.centerP.x + r * math.cos(theta)
                    y = self.centerP.y + r * math.sin(theta)
                end
                if GetTime() > self.gooImpactTime or
                    AI.CalcDistance(self.gooImpactTarget.x, self.gooImpactTarget.y, x, y) > 7 then
                    AI.SetMoveTo(x, y)
                    return true
                end
            end)
        end
    end
end

function festergut:SMSG_SPELL_CAST_GO(spellId, spellName, casterGUID, targetGUID, src, dest)
    if spellId == 72296 then
        local caster = AI.GetObjectInfoByGUID(casterGUID)
        local dist = AI.CalcDistance(dest.x, dest.y, caster.x, caster.y)
        local speed = 12
        local impactTime = dist / speed
        self.gooImpactTime = GetTime() + impactTime
        self.gooImpactTarget = dest
    end
end

AI.RegisterBossModule(festergut)

local frostWingHalls = MosdefZoneModule:new({
    zoneName = "Frostwing Halls",
    zoneId = 605,
    subzone = "The Frostwing Halls",
    onEnter = function(self)
        if AI.IsTank() then
            local sister = AI.FindNearbyUnitsByName("Sister Svalna")
            if #sister > 0 and not sister[1].isDead and sister[1].distance <= 200 then
                -- print("Sister Svalna found, loading module")
                AI.SendAddonMessage("load-boss-module", sister[1].objectEntry)
            end
        end
    end,
    onLeave = function(self)
    end
})

AI.RegisterZoneModule(frostWingHalls)

local sisterSvalna = MosDefBossModule:new({
    name = "Sister Svalna",
    creatureId = {37126},
    -- subzone = "The Frostwing Halls",
    onStart = function(self)
    end,
    onStop = function(self)
    end,
    onUpdate = function(self)
        if AI.IsValidOffensiveUnit() and AI.HasBuff("aether shield", "target") and AI.HasContainerItem("infernal spear") and
            GetTime() > self.lastUseTime + 2 then
            if AI.UseContainerItem("infernal spear") then
                self.lastUseTime = GetTime()
                print('casting infernal spear on sista svalna')
                return true
            end
        end
    end,
    lastUseTime = 0
})

function sisterSvalna:SPELL_AURA_APPLIED(args)
    if strcontains(args.spellName, "impaling spear") then
        self.impaledTarget = args.target
        if AI.IsTank() then
            local dps = {"Mosdefswp", "Mosdeffmage", "Mosdeflocka"}
            for i = #dps, 1, -1 do
                if AI.HasDebuff("impaling spear", dps[i]) then
                    table.remove(dps, i)
                end
            end
            local rand = math.random(1, #dps)
            local selected = dps[rand]
            AI.SendAddonMessage("free-impaled-target", selected)
            -- print(selected .. " is selected to free impaled target: " .. self.impaledTarget)
        end
    end
    if strcontains(args.spellName, "aether shield") then
        print("shield on svalna")
        TargetUnit(args.target)
        if AI.HasContainerItem("infernal spear") then
            print("I have spear, will use it")
            AI.RegisterPendingAction(function(self)
                if AI.UseContainerItem("infernal spear") then
                    print('casting infernal spear on aether shield target: ' .. args.target)
                    return true
                end
            end)
        end
    end
end

function sisterSvalna:SPELL_AURA_REMOVED(args)
    if strcontains(args.spellName, "impaling spear") then
        self.impaledTarget = nil
    end
end

function sisterSvalna:ON_ADDON_MESSAGE(from, cmd, args)
    -- print("sisterSvalna:ON_ADDON_MESSAGE", cmd, args)
    if cmd == "free-impaled-target" and AI.IsDps() then
        local who = args
        if strcontains(UnitName("player"), who) and self.impaledTarget then
            AI.RegisterPendingAction(function(self)
                local spear = AI.FindNearbyUnitsByName("impaling spear")
                if #spear > 0 then
                    -- print('freeing impaled target: ' .. self.impaledTarget)
                    spear[1]:InteractWith()
                    return true
                end
            end, 1, "FREE_IMPALED_TARGET")
        end
    end
end

AI.RegisterBossModule(sisterSvalna)

local sindragosa = MosDefBossModule:new({
    name = "Sindragosa",
    creatureId = {36853},
    onStart = function(self)
        TargetUnit("sindragosa")
        FocusUnit("target")

        AI.Config.judgementToUse = "judgement of light"

        if AI.IsHeroicRaidOrDungeon() and not AI.HasBuff("lesser flask of resistance") and not AI.IsTank() then
            AI.UseContainerItem("lesser flask of resistance")
        end

        -- AI.DISABLE_PET_AA = true

        AI.PRE_DO_DPS = function(isAoE)
            local maxCount = not self.p2 and 7 or 3
            if AI.IsDps() and AI.GetDebuffCount("instability") >= maxCount then
                return true
            end
            if AI.IsDps() and AI.IsValidOffensiveUnit() and strcontains(UnitName("target"), "ice tomb") then
                if AI.IsPriest() then
                    AI.DoCastSpellChain("target", "mind blast", "mind flay")
                    return true
                end
                if AI.IsWarlock() then
                    AI.DoCastSpellChain("target", "chaos bolt", "immolate", "conflagrate", "incinerate")
                    return true
                end
            end
            if AI.IsTank() and self.p2 and AI.GetDebuffCount("chilled to the bone") >= 3 then
                if IsPlayerAA() then
                    AttackTarget()
                end
                return true
            end
        end
        AI.DISABLE_DRAIN = true

        if AI.IsHealer() then
            AI.doPost_Update = function()
                if AI.GetDistanceTo(self.p2DodgeSpot.x, self.p2DodgeSpot.y) <= 2 and AI.CanCast() and self.tombedPlayer then
                    local healTar, missingHp, secondTar = AI.GetMostDamagedFriendly("chain heal")
                    local finalTar = UnitName(healTar) ~= UnitName(AI.GetPrimaryTank()) and healTar or secondTar
                    AI.CastSpell("chain heal", finalTar)
                end
            end
        end

        AI.do_PriorityTarget = function()
            return strcontains(UnitName("target"), "ice tomb")
        end
    end,
    onStop = function(self)
    end,
    onUpdate = function(self)
        if self.p2 then
            if #AI.FindNearbyUnitsByName("ice tomb") > 0 then
                RunMacroText("/petattack [@ice tomb]")
            else
                RunMacroText("/petattack [target=target]")
            end
            if AI.GetUnitHealthPct("focus") < 5 and not self.tombedPlayer and
                (AI.IsTank() or (AI.GetDistanceTo(self.p2BattleSpot.x, self.p2BattleSpot.y) <= 2 and not AI.IsHealer())) then
                if AI.IsValidOffensiveUnit("focus") and AI.HasContainerItem("pulsing life crystal") and
                    not AI.HasBuff("soul preservation", "focus") and AI.UseContainerItem("pulsing life crystal") then
                    print("using pulsing life crystal on focus")
                end
            end
        end
        if not self.p2 and AI.HasBuffOrDebuff("frost beacon") and not AI.HasMoveTo() then
            if self.myBeaconSpot == "1" and AI.GetDistanceTo(self.frostBeaconSpot1.x, self.frostBeaconSpot1.y) >= 1 then
                AI.SetMoveTo(self.frostBeaconSpot1.x, self.frostBeaconSpot1.y)
            elseif self.myBeaconSpot == "2" and AI.GetDistanceTo(self.frostBeaconSpot2.x, self.frostBeaconSpot2.y) >= 1 then
                AI.SetMoveTo(self.frostBeaconSpot2.x, self.frostBeaconSpot2.y)
            end
        end
    end,
    p2 = false,
    bombsLeft = 4,
    frostBeaconSpot1 = AI.PathFinding.Vector3.new(4360.185546875, 2490.3149414063, 203.38278198242),
    frostBeaconSpot2 = AI.PathFinding.Vector3.new(4360.5068359375, 2478.8703613281, 203.38368225098),
    airphaseStairs = AI.PathFinding.Vector3.new(4348.1020507813, 2484.1149902344, 205.68493652344),
    p2TombSpot = AI.PathFinding.Vector3.new(4372.0361328125, 2471.6411132813, 203.38279724121),
    p2DodgeSpot = AI.PathFinding.Vector3.new(4366.5654296875, 2468.8442382813, 203.38331604004),
    p2BattleSpot = AI.PathFinding.Vector3.new(4368.4213867188, 2484.0700683594, 203.38238525391),
    p2UnchainedMagicSpot = AI.PathFinding.Vector3.new(4366.7416992188, 2506.2348632813, 203.38284301758),
    beaconCount = 0,
    myBeaconSpot = nil,
    tombedPlayer = nil
})

function sindragosa:CHAT_MSG_MONSTER_YELL(s, t)
    if strcontains(s, "incursion") then
        SetMinDistToStartFollow(0.5)
        -- print('air phase incoming')
        self.bombsLeft = 4
        self.beaconCount = 0
        AI.SetMoveTo(self.airphaseStairs.x, self.airphaseStairs.y)
        self.myBeaconSpot = nil
        AI.toggleAutoDps(false)
    end
    if strcontains(s, "limitless") then
        print('phase 2 incoming')
        self.p2 = true
        if not AI.IsTank() then
            AI.SetMoveTo(self.p2BattleSpot.x, self.p2BattleSpot.y)
        end
        AI.DISABLE_PET_AA = true
    end
end
function sindragosa:SMSG_SPELL_CAST_GO(spellId, spellName, casterGuid, targetGuid, src, dest)
    if casterGuid == UnitGUID("focus") then
        -- print('sindragosa:SMSG_SPELL_CAST_GO', spellId, spellName, casterGuid, targetGuid, src, dest)
    end
    if spellId == 70117 or strcontains(spellName, "icy grip") then -- icy grip, right before blistering cold
        AI.RegisterOneShotAction(function(self)
            local dragon = AI.GetObjectInfo("focus")
            dragon.radius = normalizeObstacleRadius(25)
            local p = AI.PathFinding.FindSafeSpotInCircle(dragon, 35, {dragon}, 1)
            AI.SetMoveTo(p.x, p.y)
            print('dodging blistering cold')
        end, 0.1, "DODGE_BLISTERING_COLD")
    end
    if spellId == 70123 or strcontains(spellName, "blistering cold") and not AI.IsTank() then
        -- AI.ClearObjectAvoidance()
    end
    if spellId == 69845 or spellId == 69846 then
        print("bombs left: " .. self.bombsLeft)
        self.bombsLeft = self.bombsLeft - 1
    end
    -- if (spellId == 70157 or strcontains(spellName, "ice tomb")) then
    --     local target = AI.GetObjectInfoByGUID(targetGuid)
    --     self.tombedPlayer = target
    --     if target then
    --         print("ice tomb applied on: " .. target.name)
    --     end        
    -- end
end

function sindragosa:SPELL_AURA_APPLIED(args)
    if strcontains(args.spellName, "frost beacon") and not self.p2 then
        self.beaconCount = self.beaconCount + 1
        if self.beaconCount == 2 and AI.IsTank() then
            local markedAllies = {}
            local allies = AI.GetRaidOrPartyMemberUnits()
            for i, o in ipairs(allies) do
                if AI.HasBuffOrDebuff("frost beacon", o) then
                    -- print("frost beacon applied on: " .. o)
                    local name = UnitName(o)
                    table.insert(markedAllies, name)
                end
            end
            AI.SendAddonMessage("brace-for-tomb", markedAllies[1], 1)
            AI.SendAddonMessage("brace-for-tomb", markedAllies[2], 2)
        end
        -- print("frost beacon applied on: " .. args.target)
    end
    if strcontains(args.spellName, "frost beacon") and self.p2 then
        -- print("frost beacon applied on: " .. args.target)
        if UnitName("player") == args.target then
            AI.StopCasting()
            AI.SetMoveTo(self.p2TombSpot.x, self.p2TombSpot.y)
            print("moving to p2 ice tomb spot")
        end
        if AI.IsPriest() or AI.IsHealer() then
            AI.RegisterPendingAction(function(self)
                if AI.IsPriest() then
                    if not AI.HasDebuff("weaked soul", args.target) and
                        AI.CanCastSpell("power word: shield", args.target, true) then
                        if AI.IsCasting() then
                            AI.StopCasting()
                        end
                        return AI.CastSpell("power word: shield", args.target)
                    end
                end
                if AI.IsHealer() and AI.CanCastSpell("riptide", args.target, true) then
                    if AI.IsCasting() then
                        AI.StopCasting()
                    end
                    return AI.CastSpell("riptide", args.target)
                end
            end, 5, "PROTECT_TOMBED_PLAYER")
        end
    end
    if strcontains(args.spellName, "ice tomb") and self.p2 then
        print("ice tomb applied to: " .. args.target)
        self.tombedPlayer = args.target
        if not AI.IsTank() and UnitName("player") ~= args.target then
            if AI.IsWarlock() then
                AI.FindNearbyUnitsByName("ice tomb")[1]:Focus()
                AI.MustCastSpell("curse of agony", "focus")
            end
            AI.RegisterPendingAction(function(self)
                local count = AI.GetDebuffCount("mystic buffet")
                local duration = AI.GetDebuffDuration("mystic buffet")
                if (not AI.IsHealer() or count >= 5) and duration <= 4 and self.tombedPlayer then
                    print("moving to p2 mystic buffet dodge spot")
                    AI.SetMoveTo(self.p2DodgeSpot.x, self.p2DodgeSpot.y)
                    AI.DoTargetChain("ice tomb", "sindragosa")
                    return true
                end
            end, 0.1, "MOVE_TO_P2_BATTLE_SPOT")
        end
    end
end

function sindragosa:SPELL_AURA_REMOVED(args)
    if strcontains(args.spellName, "ice tomb") and self.p2 then
        self.tombedPlayer = nil
        print("ice tomb removed from: " .. args.target)
        if UnitName("player") == args.target then
            AI.SetMoveTo(self.p2BattleSpot.x, self.p2BattleSpot.y)
        end
    end

    if strcontains(args.spellName, "mystic buffet") and args.target == UnitName("player") then
        if AI.IsDps() and self.tombedPlayer then
            print("mystic buffet expired from me, targetting tomb ")
            AI.DoTargetChain("ice tomb", "sindragosa")
        end
        if not AI.IsTank() and AI.GetDistanceTo(self.p2BattleSpot.x, self.p2BattleSpot.y) > 1 then
            AI.RegisterPendingAction(function(self)
                if not self.tombedPlayer and (not AI.IsHealer() or AI.GetUnitHealthPct(AI.GetPrimaryTank()) > 70) then
                    print("moving back to battlespot due to ice tomb removal")
                    AI.SetMoveTo(self.p2BattleSpot.x, self.p2BattleSpot.y)
                    return true
                end
            end, 0.1, "MOVE_TO_P2_BATTLE_SPOT")
        end
    end
end

function sindragosa:ON_ADDON_MESSAGE(from, cmd, args)
    if cmd == "brace-for-tomb" then
        -- print("sindragosa:ON_ADDON_MESSAGE", cmd, args)
        local beaconedPlr, spot = splitstr2(args, ",")
        if strcontains(UnitName("player"), beaconedPlr) then
            self.myBeaconSpot = spot
            if spot == "1" then
                AI.SetMoveTo(self.frostBeaconSpot1.x, self.frostBeaconSpot1.y)
            elseif spot == "2" then
                AI.SetMoveTo(self.frostBeaconSpot2.x, self.frostBeaconSpot2.y)
            end
        end
    end
end

AI.RegisterBossModule(sindragosa)

-- blood council

local bloodCouncil = MosDefBossModule:new({
    name = "Blood Prince Council",
    creatureId = {37972, 37970, 37973},
    onStart = function(self)
        AI.do_PriorityTarget = function()
            if AI.IsValidOffensiveUnit() and AI.HasBuff("invocation of blood", "target") then
                return true
            elseif self.invocationTarget then
                local target = AI.GetObjectInfoByGUID(self.invocationTarget)
                if target then
                    target:Target()
                    return true
                end
            end
        end

        AI.AUTO_CLEANSE = false
        AI.PRE_DO_DPS = function(isAoE)
            if AI.IsDps() and AI.IsValidOffensiveUnit() and strcontains(UnitName("target"), "dark nucleus") then
                return true
            end
            -- if GetTime() > self.shockTime + 5 and AI.IsDps() and AI.IsValidOffensiveUnit() and
            --     AI.GetDistanceToUnit("target") > 35 and not AI.HasMoveTo() then
            --     local p = AI.PathFinding.FindSafeSpotInCircle(AI.GetPrimaryTank(), 30, self:GetObstacles(), 1)
            --     if p then
            --         AI.PathFinding.MoveSafelyTo(p, self:GetObstacles())
            --         -- AI.SetMoveTo(p.x, p.y)
            --         print("moving in-range of tank")
            --     end
            -- end
        end
        if AI.IsHeroicRaidOrDungeon() and not AI.HasBuff("lesser flask of resistance") and not AI.IsTank() then
            AI.UseContainerItem("lesser flask of resistance")
        end
    end,
    onStop = function(self)
    end,
    onUpdate = function(self)
        if (AI.IsWarlock() or AI.IsMage()) and self.kineticTarget then
            local kTarget = AI.GetObjectInfoByGUID(self.kineticTarget)
            if kTarget and not kTarget.isDead and UnitGUID("focus") ~= kTarget.guid then
                kTarget:Focus()
            end
            AI.DISABLE_PET_AA = true
            if UnitExists("focus") and AI.IsValidOffensiveUnit("focus") then
                RunMacroText("/petattack [target=focus]")
            elseif AI.IsValidOffensiveUnit() then
                RunMacroText("/petattack [target=target]")
            else
                PetFollow()
            end
        end

        if AI.IsHealer() then
            local obstacles = self:GetObstacles()
            local p = AI.PathFinding.FindSafeSpotInCircle(AI.GetPrimaryTank(), 40, obstacles, 5)
            if p and AI.GetDistanceTo(p.x, p.y) > 1 and not AI.HasMoveTo() then
                print("moving closer to tank")
                -- AI.PathFinding.MoveSafelyTo(p, self:GetObstacles())
                AI.SetMoveTo(p.x, p.y)
                AI.SendAddonMessage("move-to", p.x, p.y, p.z)
                -- return true
            end
        end

        -- close to healer and we have sparks
        if AI.IsPriest() and AI.GetDistanceToUnit(AI.GetPrimaryHealer()) <= 15 and not AI.HasMoveTo() and
            (AI.HasDebuff("glittering sparks") or AI.HasDebuff("glittering sparks", AI.GetPrimaryHealer()) and
                AI.CastAOESpell("mass dispel", "player")) then
            print("mass cleansing sparks")
            return true
        end

        if AI.IsPaladin() and AI.HasDebuff("glittering sparks") and AI.CleanseSelf("cleanse", "magic") then
            -- print("cleansing self")
            return true
        end

        -- if AI.IsDps() and AI.GetDistanceToUnit(AI.GetPrimaryHealer()) > 30 and not AI.HasMoveTo() then
        --     local p = AI.PathFinding.FindSafeSpotInCircle(AI.GetPrimaryHealer(), 25, self:GetObstacles(), 1)
        --     if p then
        --         AI.SetMoveTo(p.x, p.y)
        --         print("moving inrange of primary healer")
        --         return true
        --     end
        -- end
        if AI.IsTank() then
            local nucleus = AI.FindNearbyUnitsByName("dark nucleus")
            for i, o in ipairs(nucleus) do
                if not o.isDead and not o:IsChanneling() and AI.CanCastSpell("avenger's shield", "target", true) then
                    o:Focus()
                    if AI.CastSpell("avenger's shield", "focus") then
                        return true
                    end
                    return false
                end
            end
        end
    end,
    centerP = AI.PathFinding.Vector3.new(4643.1630859375, 2769.1127929688, 361.17626953125),
    r = 40,
    invocationTarget = nil,
    fightArea = AI.PathFinding.createCircularPolygon(AI.PathFinding.Vector3.new(4643.1630859375, 2769.1127929688,
        361.17626953125), 40),
    shockTime = 0,
    kineticTarget = nil
})

function bloodCouncil:SMSG_SPELL_CAST_START(spellId, spellName, casterGuid, targetGuid, src, dest)
    if strcontains(spellName, "shock vortex") then
        -- print("shock v ", spellId, casterGuid, targetGuid, table2str(src), table2str(dest))
    end
    if (spellId == 73038) and AI.IsDps() then
        self.shockTime = GetTime()
        print("shock vortex incoming, fanning out")
        local allies = AI.GetRaidOrPartyMemberUnits()
        local obstacles = self:GetObstacles()
        for i, o in ipairs(allies) do
            if UnitGUID(o) ~= UnitGUID("player") then
                table.insert(obstacles, AI.GetObjectInfo(o))
            end
        end
        local poly = AI.PathFinding.createCircularPolygon(AI.GetPrimaryHealer(), self.r)
        AI.SetObjectAvoidance({
            guids = obstacles,
            radius = normalizeObstacleRadius(12),
            polygon = poly
        })
    end
end

function bloodCouncil:SMSG_SPELL_CAST_GO(spellId, spellName, casterGuid, targetGuid, src, dest)
    if (spellId == 73038) and AI.IsDps() then
        self.shockTime = GetTime()
        AI.ClearObjectAvoidance()
        if AI.GetDistanceToUnit(AI.GetPrimaryHealer()) > 3 and not AI.HasMoveTo() then
            AI.RegisterOneShotAction(function(self)
                local p = AI.PathFinding.Vector3.new(AI.GetPosition(AI.GetPrimaryHealer()))
                AI.PathFinding.MoveSafelyTo(p, self:GetObstacles(), 3)
                print("moving to healer spot after empowered shock vortex")
            end, 1, "TO_HEALER")
        end
    end
    if (spellId == 72037) and AI.IsHealer() then
        print("shock vortex summoned")
        AI.RegisterOneShotAction(function(self)
            local p = AI.PathFinding.FindSafeSpotInCircle(AI.GetPrimaryTank(), 40, self:GetObstacles(), 3)
            if p then
                if AI.GetDistanceTo(p.x, p.y) > 1 then
                    AI.SetMoveTo(p.x, p.y)
                end
                print("dodging shock vortex")
                AI.SendAddonMessage("dodge-shock-vortex", p.x, p.y, p.z)
            end
            -- AI.SendAddonMessage("move-to", p.x, p.y, p.z)           
        end, 0.5, "DODGE_SHOCK_VORTEX")
    end
end

function bloodCouncil:SPELL_DAMAGE(args)
    if args.spellId == 72801 then
        AI.ResetMoveTo()
    end
end

function bloodCouncil:CHAT_MSG_MONSTER_YELL(s, t)
    if strcontains(s, "runneth over") and AI.IsTank() then
        print("kinetic bomb spawned")
        AI.RegisterOneShotAction(function(self)
            local bomb = AI.FindNearbyUnitsByName(38454)
            if #bomb > 0 and self.kineticTarget ~= bomb[1].guid then
                self.kineticTarget = bomb[1].guid
                bomb[1]:Focus()
                SetRaidTarget("focus", 1)
                AI.SendAddonMessage("set-kinetic-target", self.kineticTarget)
            end
        end, 2, "SET_KINETIC_TARGET")
    end
end

function bloodCouncil:CHAT_MSG_RAID_BOSS_EMOTE(s, t)
    local match = "jumps to ([^%s]+)"
    local target = strmatch(s, match)
    if target then
        -- print("invocation of blood switched to: " .. target)
        TargetUnit(target)
        self.invocationTarget = UnitGUID("target")
    end

end

function bloodCouncil:SPELL_AURA_APPLIED(args)
    if strcontains(args.spellName, "invocation of blood") then
        TargetUnit(args.target)
        self.invocationTarget = UnitGUID("target")
        -- print("invocation of blood applied to : " .. args.target)
    end
end

function bloodCouncil:ON_ADDON_MESSAGE(from, cmd, args)
    if cmd == "move-to" and AI.IsDps() and GetTime() > self.shockTime + 5 then
        local x, y, z = splitstr3(args, ",")
        if AI.GetDistanceTo(x, y) > 3 and not AI.HasMoveTo() then
            print('dps moving to healers safe spot')
            AI.PathFinding.MoveSafelyTo(AI.PathFinding.Vector3.new(x, y, z), self:GetObstacles())
        end
    end
    if cmd == "set-kinetic-target" and self.kineticTarget ~= args then
        -- print("setting kinetic target to: " .. args)
        self.kineticTarget = args
    end
    if cmd == "dodge-shock-vortex" and AI.IsDps() then
        local x, y, z = splitstr3(args, ",")
        print("dodging shock vortex")
        AI.SetMoveTo(x, y)
        -- AI.PathFinding.MoveSafelyTo(AI.PathFinding.Vector3.new(x, y, z), self:GetObstacles())
    end
end

function bloodCouncil:GetObstacles()
    local shockVortex = AI.FindNearbyUnitsByName(38422, "shock vortex")
    for i, vortex in ipairs(shockVortex) do
        vortex.radius = normalizeObstacleRadius(12)
    end
    return shockVortex
end

AI.RegisterBossModule(bloodCouncil)

local bloodQueen = MosDefBossModule:new({
    name = "Blood Queen Lana'thel",
    creatureId = {37955},
    onStart = function(self)

        if AI.IsHeroicRaidOrDungeon() and not AI.HasBuff("lesser flask of resistance") and not AI.IsTank() then
            AI.UseContainerItem("lesser flask of resistance")
        end
        if AI.IsDps() then
            AI.SetMoveTo(self.centerP.x, self.centerP.y)
        end
        if AI.IsHealer() then
            AI.SetMoveTo(self.healerP.x, self.healerP.y)
        end
        AI.PRE_DO_DPS = function(isAoE)
            return AI.HasDebuff("frenzied bloodthirst")
        end
    end,
    onStop = function(self)
    end,
    onUpdate = function(self)
        if AI.IsPriest() and AI.CastSpell("fear ward", "player") then
            return true
        end
        if (AI.HasDebuff("frenzied bloodthirst") or AI.HasDebuff(70877)) and not AI.HasMoveTo() then
            local allies = AI.GetRaidOrPartyMemberUnits()
            local victim = nil
            -- remove healer and tank by default
            table_removeif(allies, function(o)
                local name = UnitName(o)
                return strcontains(name, AI.GetPrimaryTank()) or strcontains(name, AI.GetPrimaryHealer()) and
                           strcontains(name, UnitName("player"))
            end)
            for i, o in ipairs(allies) do
                if not AI.HasBuff("essence of the blood queen", o) and not AI.HasDebuff("uncontrollable frenzy", o) then
                    victim = o
                    break
                end
            end
            if not victim then
                victim =
                    not AI.HasBuff("essence of the blood queen", AI.GetPrimaryHealer()) and AI.GetPrimaryHealer() or
                        AI.GetPrimaryTank()
                if AI.HasBuff("essence of the blood queen", victim) then
                    victim = nil
                end
            end
            if victim then
                FocusUnit(victim)
                AI.SetFacingUnit("focus")
                if AI.GetDistanceToUnit("focus") > 5 then
                    local p = AI.PathFinding.FindSafeSpotInCircle("focus", 4.5)
                    AI.SetMoveTo(p.x, p.y, p.z, 0, function()
                        AI.RegisterPendingAction(function(self)
                            return AI.CastSpell("vampiric bite", "focus") or
                                       AI.CastVehicleSpellOnTarget("vampiric bite", "focus")
                            -- print('casting vampiric bite on ' .. UnitName("focus"))
                            -- try to cast vampiric bite on focus
                            -- if we are in vehicle, use vehicle spell                       
                        end, 0, "VAMPIRIC_BITE")
                    end)
                else
                    if (AI.CastSpell("vampiric bite", "focus") or AI.CastVehicleSpellOnTarget("vampiric bite", "focus")) then
                        local name = UnitName("focus")
                        AI.SayRaid("I bit " .. name)
                        return true
                    end
                end
            else
                print('no vampiric bite victim to choose, MC incoming')
            end

        end
    end,
    healerP = AI.PathFinding.Vector3.new(4609.4409179688, 2769.33203125, 400.13809204102),
    centerP = AI.PathFinding.Vector3.new(4595.9111328125, 2769.4855957031, 400.13726806641),
    flameKiteWp1 = {AI.PathFinding.Vector3.new(4614.0141601563, 2789.9033203125, 400.13821411133),
                    AI.PathFinding.Vector3.new(4601.3940429688, 2797.3210449219, 400.13665771484),
                    AI.PathFinding.Vector3.new(4586.1357421875, 2796.5583496094, 400.13702392578),
                    AI.PathFinding.Vector3.new(4588.408203125, 2790.8203125, 400.13562011719),
                    AI.PathFinding.Vector3.new(4597.654296875, 2789.1013183594, 400.13671875)},

    flameKiteWp2 = {AI.PathFinding.Vector3.new(4580.189453125, 2792.396484375, 400.13793945313),
                    AI.PathFinding.Vector3.new(4571.3754882813, 2773.2924804688, 400.13824462891),
                    AI.PathFinding.Vector3.new(4576.5073242188, 2748.380859375, 400.13809204102),
                    AI.PathFinding.Vector3.new(4584.2192382813, 2752.8449707031, 400.13809204102),
                    AI.PathFinding.Vector3.new(4585.8740234375, 2760.6655273438, 400.13711547852)},

    flameKiteWp3 = {AI.PathFinding.Vector3.new(4609.0229492188, 2745.013671875, 400.13714599609),
                    AI.PathFinding.Vector3.new(4586.5673828125, 2742.0473632813, 400.13714599609),
                    AI.PathFinding.Vector3.new(4587.8442382813, 2750.728515625, 400.13714599609),
                    AI.PathFinding.Vector3.new(4600.1879882813, 2750.86328125, 400.13714599609),
                    AI.PathFinding.Vector3.new(4600.0249023438, 2750.5217285156, 400.13711547852),
                    AI.PathFinding.Vector3.new(4594.3720703125, 2755.861328125, 400.13711547852)},
    nextKiteIdx = 1
})

function bloodQueen:SMSG_SPELL_CAST_GO(spellId, spellName, casterGuid, targetGuid, src, dest)
    if spellId == 71264 then
        local target = AI.GetObjectInfoByGUID(targetGuid)
        local name = target and target.name or targetGuid
        -- print('bloodqueen casting swarming shadows on ' .. name)
        if AI.IsPriest() and not AI.HasDebuff("weakened soul", name) then
            AI.MustCastSpell("power word: shield", name)
        end

        if target and strcontains(UnitName("player"), name) then
            if self.nextKiteIdx == 1 then
                AI.SetMoveToPath(self.flameKiteWp1)
            elseif self.nextKiteIdx == 2 then
                AI.SetMoveToPath(self.flameKiteWp2)
            elseif self.nextKiteIdx == 3 then
                AI.SetMoveToPath(self.flameKiteWp3)
            end
            local nextIdx = self.nextKiteIdx + 1
            if nextIdx > 3 then
                nextIdx = 1
            end
            AI.SendAddonMessage("set-kite-idx", nextIdx)
        end
    end

    if strcontains(spellName, "incite terror") and AI.IsPriest() then
        print("incite terror applied, will try to mass dispel")
        AI.RegisterPendingAction(function(self)
            if not AI.HasDebuff("incite terror", AI.GetPrimaryHealer()) then
                return true
            end
            if not AI.HasDebuff("incite terror") and AI.CastAOESpell("mass dispel", AI.GetPrimaryHealer()) then
                return true
            end
        end, 0.1, "CLEANSE_INCITE_TERROR")
    end

    -- if spellId == 70877 then
    --     local caster = AI.GetObjectInfoByGUID(casterGuid)
    --     local name = caster and caster.name or casterGuid
    --     print("frenzied bloodthirst on " .. name)
    -- end
end

function bloodQueen:SPELL_AURA_APPLIED(args)
end

function bloodQueen:SPELL_AURA_REMOVED(args)
    if args.spellId == 71265 and UnitName("player") == args.target and AI.IsDps() then
        print("swarming shadows expired, moving back to dps position")
        AI.SetMoveTo(self.centerP.x, self.centerP.y)
    end
    if strcontains(args.spellName, "incite terror") and not AI.IsTank() and args.target == UnitName("player") then
        print("incite terror removed, moving back")
        if AI.IsDps() then
            AI.SetMoveTo(self.centerP.x, self.centerP.y)
        end
        if AI.IsHealer() then
            AI.SetMoveTo(self.healerP.x, self.healerP.y)
        end
    end
end

function bloodQueen:ON_ADDON_MESSAGE(from, cmd, args)
    if cmd == "set-kite-idx" then
        -- print("set-kite-idx received : " .. from .. " idx: " .. args)
        self.nextKiteIdx = tonumber(args) or 1
    end
end

AI.RegisterBossModule(bloodQueen)
