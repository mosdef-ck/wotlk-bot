local yoggFightAreaPolygon = {{
    x = 1977.8753662109,
    y = -52.049556732178,
    z = 324.96905517578
}, {
    x = 1975.8239746094,
    y = -79.036811828613,
    z = 329.15621948242
}, {
    x = 1996.3413085938,
    y = -91.403045654297,
    z = 330.19497680664
}, {
    x = 2019.0654296875,
    y = -68.501243591309,
    z = 328.92037963867
}, {
    x = 2030.5631103516,
    y = -54.842628479004,
    z = 329.00997924805
}, {
    x = 2053.3598632813,
    y = -44.36323928833,
    z = 331.51644897461
}, {
    x = 2059.2114257813,
    y = -15.882532119751,
    z = 332.3782043457
}, {
    x = 2024.7449951172,
    y = 12.82525062561,
    z = 329.33810424805
}, {
    x = 2009.4055175781,
    y = 32.77600479126,
    z = 331.00936889648
}, {
    x = 1990.0318603516,
    y = 24.874994277954,
    z = 329.34487915039
}, {
    x = 1982.5721435547,
    y = 1.5592385530472,
    z = 325.41296386719
}, {
    x = 2004.9440917969,
    y = -20.725526809692,
    z = 325.52200317383
}, {
    x = 1995.4056396484,
    y = -41.379180908203,
    z = 324.88952636719
}}

local oldPriorityTargetFn

local yoggSaron = MosDefBossModule:new({
    name = "Yogg-Saron",
    creatureId = {33288, 33134, 33136},
    onStart = function(self)
        local mod = self
        if not AI.IsTank() then
            AI.RegisterOneShotAction(function(self)
                local cx, cy, cz = AI.GetPosition()
                local path = CalculatePathToDetour(GetCurrentMapID(), AI.PathFinding.Vector3.new(cx, cy, cz),
                    AI.PathFinding.Vector3.new(self.dpsstartx, self.dpsstarty, self.dpsstartz))
                if path and type(path) == "table" then
                    print("moving to starting point")
                    AI.SetMoveToPath(path)
                else
                    print("moving directly to starting point")
                    AI.SetMoveTo(self.dpsstartx, self.dpsstarty)
                end
            end)
        end

        AI.Config.manaTideThreshold = 20

        oldPriorityTargetFn = AI.do_PriorityTarget

        AI.do_PriorityTarget = function()
            if AI.IsValidOffensiveUnit() and
                (AI.HasBuff("shadowy barrier", "target") or
                    (not mod:isDescentTeam() and strcontains("brain", UnitName("target")))) then
                        ClearTarget()
                return false
            end

            if mod.phase == 2 then
                if AI.IsTank() then
                    if AI.DoTargetChain("constrictor", "guardian", "corruptor", "tentacle") then
                        return true
                    end
                else
                    if mod:isDescentTeam() then
                        if AI.HasMoveTo() then
                            return true
                        end
                        if mod.illusionShattered and mod.usedDescentPortal then
                            TargetUnit("brain")
                            return true

                        end
                        if mod.usedDescentPortal then
                            -- TargetNearestEnemy()
                            return true
                        end
                    end
                    AssistUnit(AI.GetPrimaryTank())
                    return AI.IsValidOffensiveUnit()
                end
            end

            if mod.phase == 3 then
                if UnitName("focus") ~= "Yogg-Saron" then
                    TargetUnit("yogg")
                    FocusUnit("target")
                end

                if not AI.IsTank() then
                    -- AssistUnit(AI.GetPrimaryTank())
                    if AI.DoTargetChain("tentacle") then
                        return true
                    end
                    if not AI.IsChanneling("focus") or (AI.GetDebuffCount("sanity") > 15 and AI.GetUnitHealthPct() > 50) then
                        TargetUnit("focus")
                        return true
                    else
                        AssistUnit(AI.GetPrimaryTank())
                    end
                end
            end
            return false
        end

        AI.PRE_DO_DPS = function(isAoE)
            local tick = GetTime()

            if AI.HasBuff("flash freeze") -- or AI.HasDebuff("squeeze") 
            or AI.HasDebuff("malady of the mind") then
                return true
            end

            if self.phase == 3 then
                if strcontains(UnitName("target"), "yogg") and AI.GetDebuffCount("sanity") <= 15 and
                    (AI.IsChanneling("target") or math.abs(tick - self.nextLunaticGazeTime) <= 0.5) then
                    return true
                end
            end

            if self.phase == 2 and AI.IsValidOffensiveUnit() and not AI.HasBuff("shadowy barrier", "target") and
                not AI.IsTank() and AI.GetDistanceToUnit("target") >= 35 and
                (not self.portalToUse and not self.usedDescentPortal) then
                local x, y, z = AI.GetPosition("target")
                local dist = ternary(AI.IsHealer(), 25, 30)
                if (not AI.IsHealer() or not AI.IsCasting()) and tick > self.lastPathTargetSetTime + 5 then
                    if AI.HasObjectAvoidance() then
                        AI.SetObjectAvoidanceTarget(UnitGUID("target"), dist)
                        self.lastPathTargetSetTime = tick
                    elseif not AI.HasMoveTo() or not AI.IsCurrentPathSafeFromObstacles(self:GetCurrentObstacles()) then
                        self:MoveSafelyToSpotWithin(dist, x, y, z, nil, "to range dps the target")
                        self.lastPathTargetSetTime = tick
                    end
                end
            end

            -- Paladin tank moves in-range to melee attack target
            if AI.IsTank() and AI.AUTO_DPS and AI.IsValidOffensiveUnit() and strcontains(UnitName("target"), "tentacle") and
                AI.GetDistanceToUnit("target") > 5 and tick > self.lastPathTargetSetTime + 5 then
                if AI.HasObjectAvoidance() then
                    AI.SetObjectAvoidanceTarget(UnitGUID("target"), 4.5)
                    self.lastPathTargetSetTime = tick
                elseif not AI.HasMoveTo() or not AI.IsCurrentPathSafeFromObstacles(self:GetCurrentObstacles()) then
                    local x, y, z = AI.GetPosition("target")
                    self:MoveSafelyToSpotWithin(4.5, x, y, z, nil, "to melee attack the target");
                    self.lastPathTargetSetTime = tick
                end
            end

            if self.usedDescentPortal and not self.illusionShattered then
                if AI.IsWarlock() and AI.DoCastSpellChain("target", "corruption") then
                    return true
                end
            end

            if AI.IsValidOffensiveUnit() and strcontains(UnitName("target"), "constrictor") then
                if AI.IsPriest() and AI.DoCastSpellChain("target", "mind blast", "shadow word: death", "mind flay") then
                    return true
                end
                if AI.IsWarlock() and AI.DoCastSpellChain("target", "corruption", "shadow bolt") then
                    return true
                end
                if AI.IsMage() and AI.DoCastSpellChain("target", "fire blast", "scorch") then
                    return true
                end

                if AI.IsShaman() and AI.DoCastSpellChain("target", "lightning bolt") then
                    return true
                end
            end

            return false
        end

        if AI.IsHeroicRaidOrDungeon() and not AI.HasBuff("lesser flask of resistance") and not AI.IsTank() then
            AI.UseContainerItem("lesser flask of resistance")
        end
    end,
    onEnd = function(self)
        AI.do_PriorityTarget = oldPriorityTargetFn
    end,
    onUpdate = function(self)
        local tick = GetTime()
        if AI.HasBuff("flash freeze") or AI.HasDebuff("squeeze") or AI.HasDebuff("malady of the mind") then
            return true
        end

        if (AI.IsMage() and AI.CleanseRaid("Remove Curse", "Curse")) or
            (AI.IsPriest() and AI.CleanseRaid("Dispel Magic", "Magic")) or
            (AI.IsShaman() and AI.CleanseRaid("Cleanse Spirit", "Curse")) then
            return true
        end

        if AI.IsWarlock() and
            ((not self.illusionShattered and AI.GetUnitHealthPct() < 30) or AI.HasDebuff("sara's blessing")) and
            AI.CastSpell("shadow ward") then
            return true
        end

        -- have priest keep healer free of black plague
        if AI.IsPriest() and self.phase == 2 then
            local healer = AI.GetPrimaryHealer()
            if not AI.HasMyBuff("abolish disease", healer) and AI.HasDebuff("black plague", healer) and
                AI.CastSpell("abolish disease", healer) then
                return true
            end
        end

        if AI.IsShaman() then
            local totems = AI.FindNearbyUnitsByName("grounding totem")
            if not AI.HasMoveTo() and (#totems == 0 or totems[1].distance > 30) and AI.CastSpell("grounding totem") then
                return true
            end
            totems = AI.FindNearbyUnitsByName("cleansing totem")
            if self.phase == 2 and not AI.HasMoveTo() and (#totems == 0 or totems[1].distance > 30) and
                AI.CastSpell("cleansing totem") then
                return true
            end
        end

        -- have paladin self cleanse in p2
        if AI.IsPaladin() and self.phase >= 2 then
            if AI.GetUnitPowerPct() > 20 and AI.CleanseSelf("Cleanse", "Disease", "Magic", "Poison") then
                return true
            end
        end

        if self.phase == 2 then
            local deathorbs = AI.FindNearbyUnitsByName("death orb")
            if #deathorbs == 0 and AI.HasObjectAvoidance() and not self.maladyTarget and not self.usedDescentPortal then
                print("death orbs gone, clearing object avoidance")
                AI.ClearObjectAvoidance()
            end

            if self:isDescentTeam() then
                if self.portalToUse and not self:doesPortalExist(self.portalToUse) then
                    self.portalToUse = nil
                    print("portal to use no longer around")
                    if not AI.HasObjectAvoidance() and AI.HasMoveTo() then
                        AI.ResetMoveTo()
                    elseif AI.HasObjectAvoidance() then
                        AI.ClearObjectAvoidanceTarget()
                    end
                end
                if self.portalToUse then
                    if AI.GetDistanceTo(self.portalToUse.x, self.portalToUse.y) <= 5 and tick > self.squeezeExpireTime +
                        1 then
                        print("at target portal location")
                        AI.ClearObjectAvoidance()
                        AI.ResetMoveTo()
                        self.portalToUse:InteractWith()
                        self.portalToUse = nil
                        if not self.usedDescentPortal then
                            print("taking brain portal")
                            self.usedDescentPortal = (not self.usedDescentPortal)
                            if AI.IsWarlock() then
                                AI.USE_MANA_REGEN = false
                            end
                            if strcontains(UnitName("player"), AI.GetDpsPositionName(self.descentDpsPos2)) then -- face away from skulls upon teleporting
                                AI.RegisterOneShotAction(function(self)
                                    -- local doors = AI.FindNearbyGameObjects(194635, 194636, 194637)
                                    -- for i, o in ipairs(doors) do
                                    --     if o.state ~= 0 then
                                    --         o:SetGoState(0)
                                    --     end
                                    -- end
                                    AI.SetFacing(GetPlayerFacing() + math.pi)
                                    if self.illusionShattered then
                                        print(
                                            "took brain portal after shattered illusion. Moving to brain attack vector")
                                        -- TargetUnit("brain")
                                        local escapePortal = AI.FindNearbyGameObjects("flee to the surface")
                                        if #escapePortal > 0 then
                                            local path = CalculatePathToDetour(GetCurrentMapID(),
                                                AI.PathFinding.Vector3.new(AI.GetPosition()), AI.PathFinding.Vector3
                                                    .new(escapePortal[1].x, escapePortal[1].y, escapePortal[1].z))
                                            if type(path) == "table" and #path > 0 then
                                                print("moving to engage brain of yogg")
                                                AI.SetMoveToPath(path)
                                                AI.UseInventorySlot(8)
                                            else
                                                print("failed to generate path to brain of yogg")
                                            end
                                        else
                                            print("no escape portal found, something is wrong!")
                                        end
                                    end
                                end, 1)
                            end
                        else
                            print("taking escape portal")
                            AI.RegisterOneShotAction(function(self)
                                self.illusionShattered = false
                                self.lastPathTargetSetTime = 0
                                self.usedDescentPortal = (not self.usedDescentPortal)
                            end, 1)
                        end
                        AI.toggleAutoDps(false)
                    elseif self.usedDescentPortal and not AI.HasMoveTo() then
                        print("moving to escape portal")
                        local path = CalculatePathToDetour(GetCurrentMapID(),
                            AI.PathFinding.Vector3.new(AI.GetPosition()), AI.PathFinding.Vector3
                                .new(self.portalToUse.x, self.portalToUse.y, self.portalToUse.z))
                        if path and type(path) == "table" then
                            AI.SetMoveToPath(path)
                        end
                    elseif not self.usedDescentPortal then
                        -- if we have object avoidance, let the portal as the target goal
                        if AI.HasObjectAvoidance() then
                            AI.SetObjectAvoidanceTarget(self.portalToUse.guid, 0)
                            self.lastPathTargetSetTime = tick
                        elseif tick > self.lastPathGenerateTime then
                            self:MoveSafelyToSpot(self.portalToUse.x, self.portalToUse.y, self.portalToUse.z, nil,
                                "Get to Brain Portal")
                            self.lastPathGenerateTime = tick + 0.5
                            self.lastPathTargetSetTime = tick
                        end
                    end
                end
            end

            if self.brainLinkCaster ~= nil and self.brainLinkVictim and UnitName("player") == self.brainLinkCaster and
                not self.portalToUse and not self.usedDescentPortal and not AI.IsHealer() and (not self.portalsOpen or
                (UnitName(self.brainLinkVictim) ~= AI.GetDpsPositionName(self.descentDpsPos2) and UnitName(self.brainLinkVictim) ~=
                    AI.GetDpsPositionName(self.descentDpsPos1))) and not self.squeezeTarget then
                if AI.HasObjectAvoidance() and AI.GetObjectAvoidanceTarget() ~= UnitGUID(self.brainLinkVictim) and
                    AI.GetDistanceToUnit(self.brainLinkVictim) > 20 then
                    AI.SetObjectAvoidanceTarget(UnitGUID(self.brainLinkVictim), 20)
                    self.lastPathTargetSetTime = tick
                else
                    if AI.GetDistanceToUnit(self.brainLinkVictim) > 20 and
                        (not AI.HasMoveTo() or tick > self.lastPathGenerateTime) then
                        local tx, ty, tz = AI.GetPosition(self.brainLinkVictim)
                        self:MoveSafelyToSpotWithin(20, tx, ty, tz, nil, " moving in-range of brain-link victim")
                        self.lastPathGenerateTime = tick + 0.5
                        self.lastPathTargetSetTime = tick
                    end
                end
            end
            if self.brainLinkVictim ~= nil and self.brainLinkCaster ~= nil and UnitName("player") ==
                self.brainLinkVictim and not self.portalToUse and not self.usedDescentPortal and not AI.IsHealer() and
                (not self.portalsOpen or
                    (UnitName(self.brainLinkCaster) ~= AI.GetDpsPositionName(self.descentDpsPos2) and UnitName(self.brainLinkCaster) ~=
                        AI.GetDpsPositionName(self.descentDpsPos1))) and not self.squeezeTarget then
                if AI.HasObjectAvoidance() and AI.GetObjectAvoidanceTarget() ~= UnitGUID(self.brainLinkCaster) and
                    AI.GetDistanceToUnit(self.brainLinkCaster) > 20 then
                    AI.SetObjectAvoidanceTarget(UnitGUID(self.brainLinkCaster), 20)
                    self.lastPathTargetSetTime = tick
                else
                    if AI.GetDistanceToUnit(self.brainLinkCaster) > 20 and
                        (not AI.HasMoveTo() or tick > self.lastPathGenerateTime) then
                        local tx, ty, tz = AI.GetPosition(self.brainLinkCaster)
                        self:MoveSafelyToSpotWithin(20, tx, ty, tz, nil, " moving in-range of brain-link caster")
                        self.lastPathGenerateTime = tick + 0.5
                        self.lastPathTargetSetTime = tick
                    end
                end
            end
        elseif self.phase == 3 then
            --- Escaping yogg's brain after phase 3 starts
            if self.usedDescentPortal and self.portalToUse then
                if AI.GetDistanceTo(self.portalToUse.x, self.portalToUse.y) <= 5 then
                    print("taking escape portal due to phase 3")
                    AI.ResetMoveTo()
                    self.portalToUse:InteractWith()
                    self.portalToUse = nil
                    self.usedDescentPortal = false
                    self.illusionShattered = false
                    AI.RegisterOneShotAction(function(self)
                        AI.SetMoveTo(self.p3x, self.p3y, self.p3z)
                    end, 0.5)
                else
                    print("moving to escape portal due to phase 3")
                    local path = CalculatePathToDetour(GetCurrentMapID(), AI.PathFinding.Vector3.new(AI.GetPosition(),
                        AI.PathFinding.Vector3.new(self.portalToUse.x, self.portalToUse.y, self.portalToUse.z)))
                    if path and type(path) == "table" then
                        AI.SetMoveToPath(path)
                    end
                end
            end

            if UnitName("focus") ~= "Yogg-Saron" then
                TargetUnit("yogg")
                FocusUnit("target")
            end

            if ((math.abs(tick - self.nextLunaticGazeTime) <= 0.5) or AI.IsChanneling("focus")) and
                (AI.GetDebuffCount("sanity") <= 20 or AI.GetUnitHealthPct() < 50) and not AI.IsTank() then
                local facing = AI.GetFacingForPosition(AI.GetPosition("focus")) + math.pi
                AI.SetFacing(facing)
            end
        end
        return false
    end,
    phase = 1,
    descentDpsPos1 = 2,
    descentDpsPos2 = 1,
    portalToUse = nil,
    illusionShattered = false,
    usedDescentPortal = false,
    portalsOpen = false,
    lastPathGenerateTime = 0,
    lastPathTargetSetTime = 0,
    squeezeExpireTime = 0,
    centerx = 1980.1986083984,
    centery = -26.137254714966,
    centerz = 324.88958740234,
    dpsstartx = 2010.7935791016,
    dpsstarty = -32.513927459717,
    dpsstartz = 325.5881652832,
    p3x = 2006.3864746094,
    p3y = -23.113317489624,
    p3z = 325.66485595703,
    p3tankx = 2029.5695800781,
    p3tanky = -44.710132598877,
    p3tankz = 328.283203125,
    yoggRadius = 27.0,
    maladyTarget = nil,
    brainLinkCaster = nil,
    brainLinkVictim = nil,
    nextLunaticGazeTime = 0
})

function yoggSaron:isDescentTeam()
    local dps1 = AI.GetDpsPositionName(self.descentDpsPos1)
    local dps2 = AI.GetDpsPositionName(self.descentDpsPos2)
    return strcontains(UnitName("player"), dps1) or strcontains(UnitName("player"), dps2)
end

function yoggSaron:doesPortalExist(portal)
    local portals = AI.FindNearbyObjectsOfTypeAndName(AI.ObjectTypeFlag.UnitsAndGameObjects, "descend into madness",
        "flee to the surface")
    for i, o in ipairs(portals) do
        if portal.guid == o.guid then
            return true
        end
    end
    return false
end

function yoggSaron:GetCurrentObstacles()
    local obstacles = AI.FindNearbyUnitsByName("death orb")
    for i, o in ipairs(obstacles) do
        o.radius = 10
    end
    if self.maladyTarget ~= UnitName("player") and not self.squeezeTarget then
        local maladyOb = AI.GetObjectInfo(self.maladyTarget)
        if maladyOb then
            maladyOb.radius = 15
            table.insert(obstacles, maladyOb)
        end
    end
    return obstacles
end

function yoggSaron:MoveToSanityWell(force)
    if AI.GetDebuffCount("sanity") <= 50 or force then
        local well = AI.FindUnitYWithinXOf("thorim", "sanity well", 50)
        if #well > 0 and AI.GetDistanceTo(well[1].x, well[1].y) > 4 then
            self:MoveSafelyToSpot(well[1].x, well[1].y, well[1].z, "moving to sanity well")
            return true
        end
    end
    return false
end

function yoggSaron:MoveSafelyToSpotWithin(r, tx, ty, tz, force, reason)
    local x, y = AI.GetPosition()
    local facing = AI.CalcFacing(tx, ty, x, y)
    if AI.CalcDistance(x, y, tx, ty) > r then
        local nx, ny = tx + r * math.cos(facing), ty + r * math.sin(facing)
        return self:MoveSafelyToSpot(nx, ny, tz, force, reason)
    else
        AI.StopMoving()
    end
    return true
end

function yoggSaron:MoveSafelyToSpot(tx, ty, tz, force, reason)
    local endp = AI.PathFinding.Vector3.new(tx, ty, tz)

    local obstacles = self:GetCurrentObstacles()

    ---yogg sitting at the center, avoid him too
    -- table.insert(obstacles, {
    --     x = self.centerx,
    --     y = self.centery,
    --     z = self.centerz,
    --     radius = 22
    -- })
    print('trying to move due to :' .. reason or "N/A")

    return AI.PathFinding.MoveSafelyTo(endp, obstacles)
end

function yoggSaron:SPELL_CAST_START(args)
    if strcontains(args.spellName, "dark volley") then
        print("dark volley/drain life casting")
        if not AI.IsTank() then
            local guardians = AI.FindNearbyUnitsByName("guardian")
            for i, o in ipairs(guardians) do
                if not o.isDead and (o.castingSpellId or o.channelingSpellId) then
                    o:Focus()
                    AI.DoStaggeredInterrupt()
                    return
                end
            end
        end
    end
end

function yoggSaron:CHAT_MSG_MONSTER_YELL(text, monster)
    if strcontains(text, "lucid dream") then
        AI.AUTO_AOE = false
        self.phase = 2
        print("phase 2")
        if AI.IsHealer() then
            AI.toggleAutoDps(true)
        end
        AI.Config.startHealOverrideThreshold = 90
    end

    if strcontains(text, "true face of death") then
        self.phase = 3
        AI.toggleAutoDps(false)
        print("phase 3")
        self.nextLunaticGazeTime = GetTime() + 7
        if self.usedDescentPortal and self.illusionShattered then
            local escapePortal = AI.FindNearbyGameObjects("flee to the surface")
            if #escapePortal > 0 then
                self.portalToUse = escapePortal[1]
            end
        end
        if not self.usedDescentPortal then
            if AI.IsDps() then
                AI.SetMoveTo(self.p3x, self.p3y, self.p3z)
            else
                AI.SetMoveTo(self.p3tankx, self.p3tanky, self.p3tankz);
            end
        end
    end

    if strcontains(text, "tremble") then
        AI.RegisterOneShotAction(function(self)
            if not self.portalToUse and not self.usedDescentPortal then
                print("death rays inbound")
                local obstacles = self:GetCurrentObstacles()
                if #obstacles > 0 then
                    AI.SetObjectAvoidance({
                        guids = obstacles,
                        safeDistance = 5,
                        polygon = yoggFightAreaPolygon
                    })
                end
            end
        end, 2)
    end
end

function yoggSaron:CHAT_MSG_RAID_BOSS_EMOTE(s, t)
    if strcontains(s, "illusion shatters") then
        print("illusion shattered")        
        AI.USE_MANA_REGEN = true
        self.illusionShattered = true
        if self.usedDescentPortal then
            TargetUnit("brain of")
            local escapePortal = AI.FindNearbyGameObjects("flee to the surface")
            if #escapePortal > 0 and escapePortal[2].distance > 5 then
                local path = CalculatePathToDetour(GetCurrentMapID(), AI.PathFinding.Vector3.new(AI.GetPosition()),
                    AI.PathFinding.Vector3.new(escapePortal[2].x, escapePortal[2].y, escapePortal[2].z))
                if type(path) == "table" and #path > 0 then
                    print("moving to engage brain of yogg wpsize:" .. #path)
                    AI.SetMoveToPath(path, 0.3, function(self)
                        
                        AI.SetFacingUnit("target")
                        AI.toggleAutoDps(true)
                    end)
                    AI.UseInventorySlot(8)
                else
                    print("failed to generate path to brain of yogg")
                end
            else
                print("no escape portal found, something is wrong!")
            end
        end
    end

    if strcontains(s, "portals open into") then
        self.portalsOpen = true
        self.usedDescentPortal = false
        self.illusionShattered = false
        local mod = self
        AI.RegisterOneShotAction(function(self)
            print("portals closed")
            mod.portalsOpen = false
        end, 25, "PORTALS_CLOSED")

        if AI.IsPriest() then
            AI.RegisterPendingAction(function()
                return AI.HasMyBuff("abolish disease", AI.GetDpsPositionName(self.descentDpsPos1)) or
                           AI.CastSpell("abolish disease", AI.GetDpsPositionName(self.descentDpsPos1))
            end, nil, "CLEANSE_DESCENDER_1")
            AI.RegisterPendingAction(function()
                return AI.HasMyBuff("abolish disease", AI.GetDpsPositionName(self.descentDpsPos2)) or
                           AI.CastSpell("abolish disease", AI.GetDpsPositionName(self.descentDpsPos2))
            end, nil, "CLEANSE_DESCENDER_2")

            AI.RegisterPendingAction(function(self)
                local healer = AI.GetPrimaryHealer()
                AI.CastSpell("power word: shield", healer)
                return self.illusionShattered
            end, nil, "BUBBLE_HEALER")
        end

        if self:isDescentTeam() then
            AI.RegisterOneShotAction(function(self)
                local portals = AI.FindNearbyUnitsByName("descend into madness")
                if #portals == 2 then
                    if AI.IsWarlock() then
                        AI.MustCastSpell("shadow ward")
                    end
                    if strcontains(UnitName("player"), AI.GetDpsPositionName(self.descentDpsPos1)) then
                        local portal = portals[1]
                        self.portalToUse = portal
                        AI.ResetMoveTo()
                        AI.SayRaid("descentDps1 portal set heading to it")
                        if AI.HasObjectAvoidance() then
                            AI.SetObjectAvoidanceTarget(self.portalToUse.guid, 0)
                            self.lastPathTargetSetTime = GetTime()
                        else
                            self:MoveSafelyToSpot(self.portalToUse.x, self.portalToUse.y, self.portalToUse.z, nil,
                                "Get to Brain Portal")
                        end
                    end
                    if strcontains(UnitName("player"), AI.GetDpsPositionName(self.descentDpsPos2)) then
                        AI.RegisterOneShotAction(function(self)
                            local portals = AI.FindNearbyUnitsByName("descend into madness")
                            -- if AI.IsMage() then
                            --     AI.MustCastSpell("mana shield")
                            -- end
                            if #portals > 0 then
                                if #portals == 2 then
                                    local dx, dy = AI.GetPosition(AI.GetDpsPositionName(self.descentDpsPos1))
                                    local dist = 0
                                    for i, o in ipairs(portals) do
                                        if AI.CalcDistance(dx, dy, o.x, o.y) > dist then
                                            dist = AI.CalcDistance(dx, dy, o.x, o.y)
                                            self.portalToUse = o
                                        end
                                    end
                                else
                                    self.portalToUse = portals[1]
                                end
                                AI.ResetMoveTo()
                                AI.SayRaid("descentDps2 portal set heading to it")
                                if AI.HasObjectAvoidance() then
                                    AI.SetObjectAvoidanceTarget(self.portalToUse.guid, 0)
                                    self.lastPathTargetSetTime = GetTime()
                                end
                            else
                                AI.SayRaid("descendDps2 rdy to take portal but no portal found")
                            end
                        end, 10)
                    end
                end

                --- Move to escape portals when it's time(3s before induce madness finishes)
                AI.RegisterOneShotAction(function(self)
                    if self.phase == 2 and self.usedDescentPortal then
                        print("brain will finish casting Induce Madness in 2s")
                        local escapePortal = AI.FindNearbyGameObjects("flee to the surface")
                        if #escapePortal > 0 then
                            self.portalToUse = escapePortal[1]
                        end
                    end
                end, 55, "MOVE_TO_ESCAPE_PORTALS")
            end, 1)
        end
        if not self:isDescentTeam() then
            AI.toggleAutoDps(true)
        end
    end

    if strcontains(s, "opens his mouth wide") then
        self.nextLunaticGazeTime = self.nextLunaticGazeTime + 1
        if AI.IsHealer() and AI.FindContainerItem("Unbound Fragments of Val'anyr") then
            AI.RegisterPendingAction(function(self)
                if not AI.IsValidOffensiveUnit() or not UnitName("target"):lower() == "yogg-saron" then
                    TargetUnit("yogg-saron")
                end
                print("throwing valanyr into maw")
                return AI.UseContainerItem("Unbound Fragments of Val'anyr")
            end)
        end
    end
end

function yoggSaron:SPELL_AURA_APPLIED(args)
    if args.spellName == "Squeeze" then
        self.squeezeTarget = args.target
        if not self.portalToUse and not self.usedDescentPortal then
            if AI.IsPaladin() and strcontains(UnitName(args.target), AI.GetPrimaryHealer()) and
                AI.GetUnitHealthPct(args.target) <= 50 then
                print("healer has been squeeze, will try bubble")
                AI.MustCastSpell("hand of protection", args.target)
            end
            if AI.IsPriest() and not AI.HasDebuff("weakened soul", args.target) then
                AI.MustCastSpell("power word: shield", args.target)
            end
            TargetUnit("constrictor")
            local x, y, z = AI.GetPosition("target")
            local dist = ternary(AI.IsPaladin(), 4.5, 30)
            if AI.HasObjectAvoidance() then
                AI.SetObjectAvoidanceTarget(UnitGUID("target"), dist)
                self.lastPathTargetSetTime = GetTime()
            else
                self:MoveSafelyToSpotWithin(dist, x, y, z, nil, 'attack constrictor tentacle')
            end
        end
    end

    if strcontains(args.spellName, "malady of the mind") and args.target ~= UnitName("player") then
        if not self.portalToUse and not self.usedDescentPortal then
            self.maladyTarget = args.target
            -- if not AI.IsHealer() then
            print(args.target .. " has been afflicted by malady of the mind, avoiding")
            local obstacles = self:GetCurrentObstacles()
            AI.SetObjectAvoidance({
                guids = obstacles,
                polygon = yoggFightAreaPolygon,
                safeDistance = 5
            })
            -- end
        end
    end

    if strcontains(args.spellName, "brain link") then
        -- print("brain link applied on "..args.target)
        self.brainLinkCaster = args.target
        local allies = AI.GetRaidOrPartyMemberUnits()
        for i, a in ipairs(allies) do
            if UnitGUID(a) ~= UnitGUID(args.target) then
                local info = AI.GetObjectInfo(a)
                if info:HasAura("brain link") then
                    print(args.target .. " is brain linked to " .. UnitName(a))
                    self.brainLinkVictim = UnitName(a)
                    break
                end
            end
        end
    end
end

function yoggSaron:SPELL_AURA_REMOVED(args)
    if args.spellName == "Squeeze" then
        if args.target == UnitName("player") then
            self.squeezeExpireTime = GetTime()
        end
        self.squeezeTarget = nil
    end

    if args.spellName:lower() == "brain link" then
        self.brainLinkCaster = nil
        self.brainLinkVictim = nil
        -- AI.ClearObjectAvoidanceTarget()
    end

    if args.spellName:lower() == "malady of the mind" then
        self.maladyTarget = nil
        if not self.portalToUse and not self.usedDescentPortal then
            local obstacles = self:GetCurrentObstacles()
            if #obstacles == 0 and AI.HasObjectAvoidance() then
                AI.ClearObjectAvoidance()
            elseif not AI.HasObjectAvoidance() then
                AI.SetObjectAvoidance({
                    guids = obstacles,
                    polygon = yoggFightAreaPolygon,
                    safeDistance = 5
                })
            end
            if args.target == UnitName("player") then
                local healer = AI.GetPrimaryHealer()
                local closestAlly, dist = AI.GetClosestAlly(function(ally)
                    return UnitName(ally) ~= AI.GetDpsPositionName(self.descentDpsPos1) and UnitName(ally) ~= AI.GetDpsPositionName(self.descentDpsPos2)
                end)
                local targetToMoveTo = healer
                if AI.IsHealer() then
                    targetToMoveTo = closestAlly
                end
                local x, y, z = AI.GetPosition(targetToMoveTo)
                if AI.HasObjectAvoidance() then
                    AI.SetObjectAvoidanceTarget(UnitGUID(targetToMoveTo), 15)
                    self.lastPathTargetSetTime = GetTime()
                else
                    AI.RegisterPendingAction(function(self)
                        return self:MoveSafelyToSpotWithin(15, x, y, z, nil, "moving closer to ally")
                    end)
                end
            end
        end
    end
end

function yoggSaron:SPELL_CAST_SUCCESS(args)
    local time = GetTime()
    if args.spellName:lower() == "lunatic gaze" and not self.usedDescentPortal then
        if UnitName("focus") ~= "Yogg-Saron" then
            TargetUnit("yogg")
            FocusUnit("target")
        end
        if AI.GetDebuffCount("sanity") <= 20 or AI.GetUnitHealthPct() < 50 then
            local facing = AI.GetFacingForPosition(AI.GetPosition("focus")) + math.pi
            AI.SetFacing(facing)
        end
        self.nextLunaticGazeTime = time + 12
        -- print("lunatic gaze now:"..time.." Next  Cast:"..self.nextLunaticGazeTime)
    end
end

function yoggSaron:SPELL_DAMAGE(args)
    if args.spellName == "Brain Link" then
        self.brainLinkCaster = args.caster
        if args.caster ~= args.target then
            self.brainLinkVictim = args.target
        end
        -- print("brainlink caster:" .. args.caster .. " target:" .. args.target)
    end

    if args.spellName == "Erupt" then
        -- print("constrictor erupted on " .. args.target)
        if not self.portalToUse and not self.usedDescentPortal then
            TargetUnit("constrictor")
            local x, y, z = AI.GetPosition("target")
            local dist = ternary(AI.IsPaladin(), 4.5, 35)
            if AI.HasObjectAvoidance() then
                -- ensure we go after and try to address the target
                AI.SetObjectAvoidance({
                    guids = self:GetCurrentObstacles(),
                    polygon = yoggFightAreaPolygon,
                    safeDistance = 5
                })
                AI.SetObjectAvoidanceTarget(UnitGUID("target"), dist)
                self.lastPathTargetSetTime = GetTime()
            else
                self:MoveSafelyToSpotWithin(dist, x, y, z, nil, 'attack constrictor tentacle')
            end
        end
    end
end

AI.RegisterBossModule(yoggSaron)
