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
        AI.do_PriorityTarget = function(isAoE)
            if not AI.IsTank() then
                return AI.DoTargetChain("bone spike", "marrowgar")
            end
        end
        AI.PRE_DO_DPS = function()
            RunMacroText("/petattack [@bone spike]")
            if AI.IsDps() and AI.IsValidOffensiveUnit() and strcontains(UnitName("target"), "bone spike") and
                AI.GetDistanceToUnit("target") > 35 then
                local p = AI.PathFinding.FindSafeSpotInCircle("target", 35, self:GetObstacles(), 2)
                if p and not AI.HasMoveTo() then
                    AI.SetMoveTo(p.x, p.y)
                end
            end
        end
        if AI.IsHeroicRaidOrDungeon() and not AI.HasBuff("lesser flask of resistance") and not AI.IsTank() then
            AI.UseContainerItem("lesser flask of resistance")
        end
        if AI.IsHealer() and AI.GetDistanceTo(self.healerP.x, self.healerP.y) > 1 and
            AI.ShouldMoveTo(self.healerP.x, self.healerP.y, self.healerP.z) then
            AI.SetMoveTo(self.healerP.x, self.healerP.y)
        elseif AI.IsDpsPosition(1) and AI.GetDistanceTo(self.dps1P.x, self.dps1P.y) > 1 and
            AI.ShouldMoveTo(self.dps1P.x, self.dps1P.y, self.dps1P.z) then
            AI.SetMoveTo(self.dps1P.x, self.dps1P.y)
        elseif AI.IsDpsPosition(2) and AI.GetDistanceTo(self.dps2P.x, self.dps2P.y) > 1 and
            AI.ShouldMoveTo(self.dps2P.x, self.dps2P.y, self.dps2P.z) then
            AI.SetMoveTo(self.dps2P.x, self.dps2P.y)
        elseif AI.IsDpsPosition(3) and AI.GetDistanceTo(self.dps3P.x, self.dps3P.y) > 1 and
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
            local flame = AI.FindNearbyDynamicObjects("coldflame")
            if #flame > 0 and flame[1].distance <= normalizeObstacleRadius(5) and
                (not AI.IsHealer() or not AI.IsCasting()) then
                local obstacles = self:GetObstacles()
                local p = AI.PathFinding.FindSafeSpotInCircle(self.tankP, self.tankR, obstacles)
                if p then
                    AI.SetMoveTo(p.x, p.y)
                end
            end
        end

        if not AI.HasBuff("bone storm", "focus") and not AI.HasMoveTo() then
            if AI.IsHealer() and AI.GetDistanceTo(self.healerP.x, self.healerP.y) > 1 and
                self:IsSpotSafeFromColdFlame(self.healerP) and AI.ShouldMoveTo(self.healerP) then
                AI.SetMoveTo(self.healerP.x, self.healerP.y)
            elseif AI.IsDpsPosition(1) and AI.GetDistanceTo(self.dps1P.x, self.dps1P.y) > 1 and
                self:IsSpotSafeFromColdFlame(self.dps1P) and AI.ShouldMoveTo(self.dps1P) then
                AI.SetMoveTo(self.dps1P.x, self.dps1P.y)
            elseif AI.IsDpsPosition(2) and AI.GetDistanceTo(self.dps2P.x, self.dps2P.y) > 1 and
                self:IsSpotSafeFromColdFlame(self.dps2P) and AI.ShouldMoveTo(self.dps2P) then
                AI.SetMoveTo(self.dps2P.x, self.dps2P.y)
            elseif AI.IsDpsPosition(3) and AI.GetDistanceTo(self.dps3P.x, self.dps3P.y) > 1 and
                self:IsSpotSafeFromColdFlame(self.dps3P) and AI.ShouldMoveTo(self.dps3P) then
                AI.SetMoveTo(self.dps3P.x, self.dps3P.y)
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
    polygon = AI.PathFinding.createCircularPolygon(AI.PathFinding.Vector3.new(-388.21759033203, 2212.9926757813,
        41.993892669678), 35)
})

function marrowGar:CHAT_MSG_RAID_BOSS_EMOTE(s, t)
    if strcontains(s, "storm") then
        self.stormTime = GetTime()
        if AI.IsDps() then
            AI.DISABLE_CDS = true
        end
        AI.RegisterPendingAction(function(self)
            if not strcontains(UnitName("target"), "bone spike") then
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
        o.radius = normalizeObstacleRadius(5)
    end
    local allies = AI.GetAlliesAsObstacles(5)
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
        if AI.CalcDistance(p.x, p.y, o.x, o.y) < o.radius then
            return false
        end
    end
    return true
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
        if AI.IsHealer() and AI.GetDistanceTo(self.healerP.x, self.healerP.y) > 1 and
            self:IsSpotSafeFromDeathAndDecay(self.healerP) and not AI.IsCasting() and AI.ShouldMoveTo(self.healerP) then
            AI.SetMoveTo(self.healerP.x, self.healerP.y)
        elseif AI.IsDpsPosition(1) and AI.GetDistanceTo(self.dps1P.x, self.dps1P.y) > 1 and
            self:IsSpotSafeFromDeathAndDecay(self.dps1P) and not AI.IsCasting() and AI.ShouldMoveTo(self.dps1P) then
            AI.SetMoveTo(self.dps1P.x, self.dps1P.y)
        elseif AI.IsDpsPosition(2) and AI.GetDistanceTo(self.dps2P.x, self.dps2P.y) > 1 and
            self:IsSpotSafeFromDeathAndDecay(self.dps2P) and not AI.IsCasting() and AI.ShouldMoveTo(self.dps2P) then
            AI.SetMoveTo(self.dps2P.x, self.dps2P.y)
        elseif AI.IsDpsPosition(3) and AI.GetDistanceTo(self.dps3P.x, self.dps3P.y) > 1 and
            self:IsSpotSafeFromDeathAndDecay(self.dps3P) and not AI.IsCasting() and AI.ShouldMoveTo(self.dps3P) then
            AI.SetMoveTo(self.dps3P.x, self.dps3P.y)
        end
    end,
    onStop = function(self)
        AI.ALLOW_AUTO_REFACE = true
    end,
    onUpdate = function(self)
        if AI.IsDps() and self.dominateTarget and UnitName("player") ~= self.dominateTarget and not AI.IsCasting() then
            local info = AI.GetObjectInfo(self.dominateTarget)
            if info and not AI.IsUnitCC(info) then
                if AI.IsMage() and AI.CastSpell("polymorph", self.dominateTarget) then
                    print('polymorphing dominated target: ' .. self.dominateTarget)
                    return true
                end
                if AI.IsWarlock() then
                    AI.RegisterOneShotAction(function(self)
                        local info = AI.GetObjectInfo(self.dominateTarget)
                        if AI.IsCasting() then
                            AI.StopCasting()
                        end
                        if info and not AI.IsUnitCC(info) and AI.CastSpell("fear", self.dominateTarget) then
                            print('fearing dominated target: ' .. self.dominateTarget)
                            return true
                        end
                    end, 2, "CC_DOMINATED")
                end
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

        if AI.IsHealer() and AI.GetDistanceTo(self.healerP.x, self.healerP.y) > 1 and
            self:IsSpotSafeFromDeathAndDecay(self.healerP) and not AI.IsCasting() and AI.ShouldMoveTo(self.healerP) then
            AI.SetMoveTo(self.healerP.x, self.healerP.y)
        elseif AI.IsDpsPosition(1) and AI.GetDistanceTo(self.dps1P.x, self.dps1P.y) > 1 and
            self:IsSpotSafeFromDeathAndDecay(self.dps1P) and not AI.IsCasting() and AI.ShouldMoveTo(self.dps1P) then
            AI.SetMoveTo(self.dps1P.x, self.dps1P.y)
        elseif AI.IsDpsPosition(2) and AI.GetDistanceTo(self.dps2P.x, self.dps2P.y) > 1 and
            self:IsSpotSafeFromDeathAndDecay(self.dps2P) and not AI.IsCasting() and AI.ShouldMoveTo(self.dps2P) then
            AI.SetMoveTo(self.dps2P.x, self.dps2P.y)
        elseif AI.IsDpsPosition(3) and AI.GetDistanceTo(self.dps3P.x, self.dps3P.y) > 1 and
            self:IsSpotSafeFromDeathAndDecay(self.dps3P) and not AI.IsCasting() and AI.ShouldMoveTo(self.dps3P) then
            AI.SetMoveTo(self.dps3P.x, self.dps3P.y)
        end
    end,
    dominateTarget = nil,
    touchedTarget = nil,
    cursedTarget = nil,
    dps1P = AI.PathFinding.Vector3.new(-644.13055419922, 2228.1281738281, 51.875164031982),
    dps2P = AI.PathFinding.Vector3.new(-659.5908203125, 2222.1137695313, 51.84814453125),
    healerP = AI.PathFinding.Vector3.new(-661.28668212891, 2205.447265625, 51.841480255127),
    dps3P = AI.PathFinding.Vector3.new(-649.80755615234, 2192.4226074219, 51.872287750244),
    tankP = AI.PathFinding.Vector3.new(-637.54956054688, 2212.9353027344, 51.55154800415)
})

function ladyDeath:SMSG_SPELL_CAST_GO(spellId, spellName, casterGuid, targetGuid, src, dest)
    if not AI.IsTank() and strcontains(spellName, "death and decay") and AI.GetDistanceTo(dest.x, dest.y) < 3 then
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
        o.radius = normalizeObstacleRadius(o.radius)
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
                if #guns == 2 then
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
            if not AI.IsPossessing() and tick - self.lastMoveTime > 0.3 then
                local cannon = AI.GetObjectInfoByGUID(self.cannonToUse)
                if cannon then
                    if AI.GetDistanceToUnit(cannon) > 5 then
                        AI.SetMoveTo(cannon.x, cannon.y)
                    else
                        AI.ResetMoveTo()
                        if AI.IsMoving() then
                            AI.StopMoving()
                        end
                        -- TODO:
                        -- local dangerousRiflemen = self:GetDangerousRiflemen()
                        -- if dangerousRiflemen then
                        --     dangerousRiflemen:Target()
                        -- end
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

        if not AI.IsTank() and not AI.IsPossessing() and not AI.HasMoveTo() and tick - self.lastDodgeTime > 2 then
            local artillery = AI.FindNearbyDynamicObjects("artillery")
            if #artillery > 0 and artillery[1].distance <= 8 then
                for i, a in ipairs(artillery) do
                    a.radius = 5
                end
                local p = AI.PathFinding.FindSafeSpotInCircle(AI.GetPrimaryTank(), 25, artillery, 3)
                if p then
                    -- print('dodging incoming artillery')
                    AI.SetMoveTo(p.x, p.y)
                end
            end
            self.lastDodgeTime = tick
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
    cannonsFrozen = false
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
                AI.SetMoveTo(portal[1].x, portal[1].y, portal[1].z, 0, function()
                    portal[1]:InteractWith()
                end)
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
                AI.SetMoveTo(portal[1].x, portal[1].y, portal[1].z, 0, function(self)
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

function gunship:CHAT_MSG_MONSTER_YELL(s, t)
    if strcontains(s, "hull") and self:IsGunnerCrew() then
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
            if AI.GetUnitHealthPct("target") > 7 then
                return AI.DoTargetChain("blood beast")
            end
        end
        AI.PRE_DO_DPS = nil
    end,
    onStop = function(self)
    end,
    onUpdate = function(self)
        -- AI.DISABLE_DEEP_FREEZE = not strcontains(UnitName("target"), "blood beast")
        if AI.IsTank() and strcontains(UnitName("target"), "blood beast") and not AI.IsUnitCC("target") and
            AI.CastSpell("hammer of justice", "target") then
            return true
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
            local littleOoze = AI.FindNearbyUnitsByName("little ooze")
            local bigOoze = AI.FindNearbyUnitsByName("big ooze")
            if #littleOoze > 0 then
                local spell = AI.IsHealer() and "cleanse spirit" or "cleanse"
                if AI.CastSpell(spell, self.infectedPlr) then
                    print('little oozes r close -cleansing mutated infection from: ' .. self.infectedPlr)
                    return true
                end
            end
            if #bigOoze > 0 and AI.CalcDistance(bigOoze[1].x, bigOoze[1].y, self.infectedPlr.x, self.infectedPlr.y) <= 3 then
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
        if AI.IsTank() then
            AI.RegisterOneShotAction(function(self)
                AI.MustCastSpell("hand of salvation", AI.GetPrimaryHealer())
            end, 1)
        end
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
                local p = AI.PathFinding.FindSafeSpotInCircle(tarToMoveTo, 5)
                if GetTime() <= self.gooImpactTime then
                    self.gooImpactTarget.radius = 7
                    AI.PathFinding.MoveSafelyTo(p, {self.gooImpactTarget})
                else
                    AI.SetMoveTo(p.x, p.y)
                end
            end
        end
        if not AI.IsTank() and GetTime() <= self.gooImpactTime then
            local obstacles = AI.GetAlliesAsObstacles(normalizeObstacleRadius(7))
            self.gooImpactTarget.radius = normalizeObstacleRadius(7)
            table.insert(obstacles, self.gooImpactTarget)
            if (not self.gasSporeTarget or GetTime() + AI.GetDebuffDuration("gas spore", self.gasSporeTarget) >=
                self.gooImpactTime) and AI.GetDistanceTo(self.gooImpactTarget.x, self.gooImpactTarget.y) <= 7 or
                not AI.IsCurrentPathSafeFromObstacles(obstacles) then
                local p = AI.PathFinding.FindSafeSpotWithinRadiusCorridor(self.centerP, 10, 15, obstacles, 1)
                if p then
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
                print("Sister Svalna found, loading module")
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
        if AI.IsValidOffensiveUnit() and AI.HasBuff("aether shield") and AI.HasContainerItem("infernal spear") and
            GetTime() > self.lastUseTime + 2 then
            if AI.UseContainerItem("infernal spear") then
                self.lastUseTime = GetTime()
                print('casting infernal spear on impaled target: ' .. self.impaledTarget)
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
    print("sisterSvalna:ON_ADDON_MESSAGE", cmd, args)
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

        AI.Config.judgmentToUse = "judgement of light"

        if AI.IsHeroicRaidOrDungeon() and not AI.HasBuff("lesser flask of resistance") and not AI.IsTank() then
            AI.UseContainerItem("lesser flask of resistance")
        end

        -- AI.DISABLE_PET_AA = true

        AI.PRE_DO_DPS = function(isAoE)
            local maxCount = not self.p2 and 7 or 4
            local count = AI.GetDebuffCount("mystic buffet")
            if count >= 5 or AI.HasDebuff("frost beacon") then
                maxCount = 2
            end
            if AI.IsDps() and AI.GetDebuffCount("instability") >= maxCount then
                return true
            end
            if AI.IsDps() and AI.IsValidOffensiveUnit() and strcontains(UnitName("target"), "ice tomb") then
                if AI.IsPriest() then
                    AI.DoCastSpellChain("target", "mind blast", "shadow word: death", "mind flay")
                    return true
                end
                if AI.IsWarlock() then
                    AI.DoCastSpellChain("target", "immolate", "conflagrate", "incinerate")
                    return true
                end
            end
        end
        AI.DISABLE_DRAIN = true
    end,
    onStop = function(self)
    end,
    onUpdate = function(self)
        -- if AI.IsMage() then
        --     if AI.FindNearbyUnitsByName("ice tomb") then
        --         RunMacroText("/petattack [@ice tomb]")
        --     else
        --         RunMacroText("/petattack [@target]")
        --     end
        -- end
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
    end
    if strcontains(s, "limitless") then
        print('phase 2 incoming')
        self.p2 = true
        if not AI.IsTank() then
            AI.SetMoveTo(self.p2BattleSpot.x, self.p2BattleSpot.y)
        end
    end
end
function sindragosa:SMSG_SPELL_CAST_GO(spellId, spellName, casterGuid, targetGuid, src, dest)
    if casterGuid == UnitGUID("focus") then
        -- print('sindragosa:SMSG_SPELL_CAST_GO', spellId, spellName, casterGuid, targetGuid, src, dest)
    end
    if spellId == 70117 or strcontains(spellName, "icy grip") then -- icy grip, right before blistering cold
        local dragon = AI.GetObjectInfo("focus")
        dragon.radius = normalizeObstacleRadius(25)
        local p = AI.PathFinding.FindSafeSpotInCircle(dragon, 35, {dragon}, 1)
        AI.SetMoveTo(p.x, p.y)
        print('dodging blistering cold')
    end
    if spellId == 70123 or strcontains(spellName, "blistering cold") and not AI.IsTank() then
        -- AI.ClearObjectAvoidance()
    end
    if spellId == 69845 or spellId == 69846 then
        self.bombsLeft = self.bombsLeft - 1
        print("bombs left: " .. self.bombsLeft)
    end
    if (spellId == 70157 or strcontains(spellName, "ice tomb")) then
        local target = AI.GetObjectInfoByGUID(targetGuid)
        self.tombedPlayer = target
        print("ice tomb applied on: " .. targetGuid)
    end
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
    if strcontains(args.spellName, "frost beacon") and self.p2 and UnitName("player") == args.target then
        -- print("frost beacon applied on: " .. args.target)
        AI.SetMoveTo(self.p2TombSpot.x, self.p2TombSpot.y)
        print("moving to ice tomb dodge spot")
    end
    if strcontains(args.spellName, "ice tomb") then
        print("ice tomb applied on: " .. args.target)
        self.tombedPlayer = args.target
    end
end

function sindragosa:SPELL_AURA_APPLIED_DOSE(args)
    if self.p2 and not AI.IsTank() and strcontains(args.spellName, "mystic buffet") and UnitName("player") ==
        args.target then
        local count = AI.GetDebuffCount("mystic buffet")
        -- print("mystic buffet applied on: " .. args.target .. " count: " .. count)

        if count >= 5 and self.tombedPlayer and not AI.HasMoveTo() then
            AI.SetMoveTo(self.p2DodgeSpot.x, self.p2DodgeSpot.y)
            print("moving to mystic buffet dodge spot")
        end
    end
end

function sindragosa:SPELL_AURA_REMOVED(args)
    if strcontains(args.spellName, "ice tomb") and self.p2 then
        self.tombedPlayer = nil
        if UnitName("player") == args.target then
            -- print("frost beacon removed from: " .. args.target)
            AI.SetMoveTo(self.p2BattleSpot.x, self.p2BattleSpot.y)
        end
    end
    if strcontains(args.spellName, "mystic buffet") and self.p2 and not AI.IsTank() and UnitName("player") ==
        args.target and AI.GetDistanceTo(self.p2BattleSpot) > 1 and
        (not AI.IsHealer() or AI.GetUnitHealthPct(AI.GetPrimaryTank()) > 50) then

        -- print("mystic buffet removed from: " .. args.target)
        AI.SetMoveTo(self.p2BattleSpot.x, self.p2BattleSpot.y)
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

