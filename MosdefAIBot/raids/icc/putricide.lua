local putricide = MosDefBossModule:new({
    name = "Professor Putricide",
    creatureId = {36678},
    onStart = function(self)
        TargetUnit("professor putricide")
        FocusUnit("target")
        AI.AUTO_CLEANSE = false
        AI.Config.judgementToUse = "judgement of light"
        if AI.IsHeroicRaidOrDungeon() and not AI.HasBuff("flask of the frost wyrm") and not AI.IsTank() then
            AI.UseContainerItem("flask of the frost wyrm")
        end
        -- if AI.IsHeroicRaidOrDungeon() and not AI.HasBuff("lesser flask of resistance") and not AI.IsTank() then
        --     AI.UseContainerItem("lesser flask of resistance")
        -- end
        AI.do_PriorityTarget = function()
            if not AI.IsTank() then
                return AI.DoTargetChain("gas cloud", "volatile ooze")
            end
        end
        AI.PRE_DO_DPS = function(isAoE)
            if self:IsAbomination() then
                AI.DoTargetChain("volatile ooze", "gas cloud")
                local puddles = self:GetSlimePuddles()
                local isAttackingOoze = strcontains(UnitName("target"), "ooze") or
                                            strcontains(UnitName("target"), "cloud")
                if isAttackingOoze then
                    if GetFollowTarget() ~= UnitGUID("target") then
                        SetFollowTarget(UnitGUID("target"))
                    end

                    if strcontains(UnitName("target"), "cloud") and not AI.HasDebuff("regurgitated ooze", "target") and
                        UnitPower("playerpet") >= 45 and AI.CastVehicleSpellOnTarget("regurgitated ooze", "target") then
                        print("casting regurgitated ooze on target: " .. UnitName("target"))
                        return true
                    end
                    AI.CastVehicleSpellOnTarget("mutated slash", "playerpet")
                    AI.UsePossessionSpell("mutated slash")
                elseif #puddles == 0 then
                    TargetUnit("professor putricide")
                    if GetFollowTarget() ~= UnitGUID("target") then
                        SetFollowTarget(UnitGUID("target"))
                    end
                    AI.CastVehicleSpellOnTarget("mutated slash", "playerpet")
                    AI.UsePossessionSpell("mutated slash")
                end
                return true
            end
        end

        if strcontains(UnitName("player"), self.mutateDps) then
            local table = AI.FindNearbyGameObjects(201584, "drink me!")
            if #table > 0 then
                -- print('to grab potion')
                local drinkMe = table[1]
                local p = AI.PathFinding.FindSafeSpotInCircle(drinkMe, 2)
                AI.UseInventorySlot(8)
                AI.SetMoveTo(p.x, p.y, p.z, 2, function()
                    drinkMe:InteractWith()
                end)
            end
        end
    end,
    onStop = function(self)
    end,
    onUpdate = function(self)
        if self:IsAbomination() and not strcontains(UnitName("target"), "ooze") and
            not strcontains(UnitName("target"), "cloud") and not AI.HasMoveTo() then
            local puddles = self:GetSlimePuddles()
            if #puddles > 0 then
                local puddle = puddles[1]
                if GetFollowTarget() ~= puddle.guid then
                    SetFollowTarget(puddle.guid)
                end
                if AI.CastVehicleSpellOnTarget("eat ooze", "playerpet") then
                    if AI.IsValidOffensiveUnit() and AI.GetDistanceToUnit("target") <= 5.5 then
                        AI.CastVehicleSpellOnTarget("mutated slash", "playerpet")
                        AI.UsePossessionSpell("mutated slash")
                    end
                    -- print("eating ooze puddle")
                    return true
                end
            end
        end
        if not AI.IsTank() and not self:IsAbomination() then
            -- local obstacles = self:GetObstacles()
            -- if #obstacles > 0 then
            --     AI.PathFinding.MoveToSafeLocationWithinPolygon(self.battlePoly, obstacles, 3)
            -- end
        end        
    end,
    centerP = AI.PathFinding.Vector3.new(4355.7622070313, 3231.7758789063, 389.400390625),
    battlePoly = AI.PathFinding.createCircularPolygon(AI.PathFinding.Vector3.new(4355.7622070313, 3231.7758789063, 389.400390625), 30),
    mutateDps = "Mosdeffmage",
    p3 = false,
    p3Start = AI.PathFinding.Vector3.new(4332.5493164063, 3237.5791015625, 389.39944458008)
})

function putricide:IsAbomination()
    return AI.IsDps() and AI.IsPossessing()
end

function putricide:GetSlimePuddles()
    local puddles = AI.FindNearbyUnitsByName(37690, "growing ooze puddle")
    table_removeif(puddles, function(p)
        return not p:HasAura("grow") or not p:HasAura("grow stacker")
    end)
    for i, p in ipairs(puddles) do
        p.radius = 3 * p.objectScale
    end
    table.sort(puddles, function(a, b)
        return a:GetDistanceToUnit(AI.GetPrimaryHealer()) < b:GetDistanceToUnit(AI.GetPrimaryHealer())
    end)
    return puddles
end

function putricide:GetObstacles()
    -- 37690 - growing ooze puddle
    -- 38159 - choking gas bomb
    local obstacles = AI.FindNearbyUnitsByName(37690, 38159, "volatile ooze", "gas cloud")
    table_removeif(obstacles, function(o)
        return o.isDead
    end)
    for i, o in ipairs(obstacles) do
        if strcontains(o.name, "choking gas bomb") then
            o.radius = 3
        elseif strcontains(o.name, "volatile ooze") or strcontains(o.name, "gas cloud") then
            o.radius = 10
        else
            o.radius = 3 * o.objectScale
        end
    end
    local boss = AI.GetObjectInfo("focus")
    boss.radius = 3
    table.insert(obstacles, boss)
    return obstacles
end

function putricide:SPELL_DAMAGE(args)
    if strcontains(args.spellName, "slime puddle") and args.target == UnitName("player") and AI.IsHealer() then
        if AI.HasDebuff("volatile ooze adhesive") then
            return
        end
        print("moving to avoid ooze puddle")
        local obstacles = self:GetObstacles()
        local p = AI.PathFinding.FindSafeSpotInCircle(self.centerP, 30, obstacles, 2)
        AI.SetMoveTo(p.x, p.y)
        AI.SendAddonMessage("dodge-to", p.x, p.y, p.z)
    end
end

function putricide:SMSG_SPELL_CAST_START(spellId, spellName, casterGUID, targetGUID, src, dest)
    if strcontains(spellName, "volatile ooze adhesive") then
        local target = AI.GetObjectInfoByGUID(targetGUID)
        if AI.IsHealer() then
            AI.MustCastSpell("riptide", target.name)
        end
        if AI.IsPriest() then
            AI.MustCastSpell("power word: shield", target.name)
        end
    end
end

function putricide:SMSG_SPELL_CAST_GO(spellId, spellName, casterGUID, targetGUID, src, dest)
    local caster = AI.GetObjectInfoByGUID(casterGUID)
    if caster and (strcontains(caster.name, "professor") or strcontains(caster.name, "gas")) then
        -- print("spell cast go: " .. spellId, spellName, caster.name, targetGUID, table2str(src), table2str(dest))
    end
    if (spellId == 72295 or strcontains(spellName, "malleable goo")) and AI.IsHealer() then
        -- print("malleable goo cast " .. spellName, targetGUID, table2str(src), table2str(dest))
        local caster = AI.GetObjectInfoByGUID(casterGUID)
        local px, py = AI.GetPosition("player")
        if AI.DoesLineIntersect(caster.x, caster.y, dest.x, dest.y, px, py, 7) then
            print("moving to avoid malleable goo")
            local obstacles = self:GetObstacles()
            local obj = {
                x = dest.x,
                y = dest.y,
                z = dest.z,
                radius = 7
            }
            table.insert(obstacles, obj)
            local p = AI.PathFinding.FindSafeSpotInCircle(self.centerP, 30, obstacles, 2)
            AI.SetMoveTo(p.x, p.y)
            AI.SendAddonMessage("dodge-to", p.x, p.y, p.z)
        end
    end
    if ((spellId == 70341 and dest.x > 0 and AI.GetDistanceTo(dest.x, dest.y) <= 5) or
        (strcontains(spellName, "bomb summon"))) and AI.IsHealer() then
        if AI.HasDebuff("volatile ooze adhesive") then
            return
        end
        print("slime puddle inc" .. spellId, spellName, casterGUID, targetGUID, table2str(src), table2str(dest))
        local obstacles = self:GetObstacles()
        table.insert(obstacles, {
            x = dest.x,
            y = dest.y,
            z = dest.z,
            radius = 3
        })
        local p = AI.PathFinding.FindSafeSpotInCircle(self.centerP, 30, obstacles, 2)
        AI.SetMoveTo(p.x, p.y)
        AI.SendAddonMessage("dodge-to", p.x, p.y, p.z)
    end

    if strcontains(spellName, "guzzle") then
        -- print("p3 coming")
        self.p3 = true
    end
end

function putricide:SPELL_AURA_APPLIED(args)
    if strcontains(args.spellName, "mutated transformation") and args.target == UnitName("player") then
        print("mutated transformation applied to: " .. args.target)
        local x, y = AI.GetPosition("focus")
        AI.SetMoveTo(x, y)
    end
    -- if strcontains(args.spellName, "volatile ooze adhesive") and AI.IsPriest() then
    --     AI.MustCastSpell("power word: shield", args.target)
    -- end
end

function putricide:UNIT_DIED(unit)
    if not self.p3 and AI.GetUnitHealthPct("focus") <= 35 then
        AI.RegisterPendingAction(function(self)
            if #AI.FindNearbyUnitsByName("volatile ooze", "gas cloud") == 0 then
                print("all oozes killed, moving to p3")
                self.p3 = true
                if AI.IsHealer() then
                    print("removing abomination")
                    local mutatedDpsName = UnitName(self.mutateDps)
                    AI.RegisterPendingAction(function(self)
                        return AI.CleanseFriendly("cleanse spirit", mutatedDpsName .. '-pet', "disease")
                    end, 0, "CLEANSE_ABOMINATION")
                end
                return true
            end
        end, 0, "TRIGGER_P3_DPS_RACE")
    end
end

function putricide:ON_ADDON_MESSAGE(from, cmd, args)
    if cmd == "dodge-to" and AI.IsDps() and not self:IsAbomination() then
        local x, y, z = splitstr3(args, ",")
        AI.SetMoveTo(x, y, z)
    end
end

AI.RegisterBossModule(putricide)
