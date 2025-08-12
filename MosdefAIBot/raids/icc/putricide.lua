local putricide = MosDefBossModule:new({
    name = "Professor Putricide",
    creatureId = {36678},
    onStart = function(self)
        TargetUnit("professor putricide")
        FocusUnit("target")
        -- if AI.IsHeroicRaidOrDungeon() and not AI.HasBuff("flask of the frost wyrm") and not AI.IsTank() then
        --     AI.UseContainerItem("flask of the frost wyrm")
        -- end
        -- if AI.IsHeroicRaidOrDungeon() and not AI.HasBuff("lesser flask of resistance") and not AI.IsTank() then
        --     AI.UseContainerItem("11lesser flask of resistance")
        -- end
        AI.do_PriorityTarget = function()
            if AI.IsDps() then
                return AI.DoTargetChain("volatile ooze", "gas cloud")
            end
        end
        AI.PRE_DO_DPS = function(isAoE)
            if self:IsAbomination() then
                if strcontains(UnitName("target"), "ooze") or strcontains(UnitName("target"), "cloud") then
                    if not AI.HasDebuff("regurgitated ooze", "target") and UnitPower("playerpet") >= 45 and
                        AI.UsePossessionSpell("regurgitated ooze") then
                        print("casting regurgitated ooze on target: " .. UnitName("target"))
                        return true
                    end
                end
                AI.UsePossessionSpell("mutated slash")
                if not IsPlayerAA() then
                    AI.GetObjectInfo("target"):InteractWith()
                end
                return true
            end
        end

        if strcontains(UnitName("player"), self.mutateDps) then
            local table = AI.FindNearbyGameObjects(201584, "drink me!")
            if #table > 0 then
                print('to grab potion')
                local drinkMe = table[1]
                AI.SetMoveTo(drinkMe.x, drinkMe.y, drinkMe.z, 4, function()
                    drinkMe:InteractWith()
                end)
            end
        end
    end,
    onStop = function(self)
    end,
    onUpdate = function(self)
        if self:IsAbomination() and not strcontains(UnitName("target"), "ooze") and
            not strcontains(UnitName("target"), "cloud") then
            local puddles = AI.FindNearbyUnitsByName("growing ooze puddle")
            if #puddles > 0 then
                local puddle = puddles[1]
                if not puddle.isDead then
                    if AI.GetDistanceTo(puddle) > 5 then
                        print("moving to puddle")
                        AI.SetMoveTo(puddle.x, puddle.y)
                    else
                        if AI.UsePossessionSpell("eat ooze") then
                            print("eating ooze puddle")
                            return true
                        end
                    end
                end
            end
        end
    end,
    centerP = AI.PathFinding.Vector3.new(4356.6743164063, 3211.2973632813, 389.39831542969),
    battlePoly = AI.PathFinding.createCircularPolygon(AI.PathFinding.Vector3.new(4356.6743164063, 3211.2973632813,
        389.39831542969), 45, 32),
    mutateDps = "Mosdefswp"
})

function putricide:IsAbomination()
    return AI.IsDps() and AI.IsPossessing()
end

function putricide:GetObstacles()
    local obstacles = AI.FindNearbyDynamicObjects("growing ooze puddle", "choking gas bomb")
    for i, o in ipairs(obstacles) do
        if o.name == "choking gas bomb" then
            o.radius = 3
        else
            o.radius = 5
        end
    end
    return obstacles
end

function putricide:SMSG_SPELL_CAST_GO(spellId, spellName, casterGUID, targetGUID, src, dest)
    if (spellId == 72295 or strcontains(spellName, "malleable goo")) and not self:IsAbomination() and not AI.IsTank() then
        local caster = AI.GetObjectInfoByGUID(casterGUID)
        local px, py = AI.GetPosition("player")
        if AI.DoesLineIntersect(caster.x, caster.y, dest.x, dest.y, px, py, 5) then
            print("moving to avoid malleable goo")
            local obstacles = self:GetObstacles()
            local obj = {
                x = dest.x,
                y = dest.y,
                z = dest.z,
                radius = 5
            }
            table.insert(obstacles, obj)
            AI.PathFinding.MoveToSafeLocationWithinPolygon(self.battlePoly, obstacles, 1)
        end
    end
    if (strcontains(spellName, "choking gas bomb") or strcontains(spellName, "slime puddle") ) and not AI.IsTank() then
        print("moving to avoid choking gas bomb")
        AI.PathFinding.MoveToSafeLocationWithinPolygon(self.battlePoly, obstacles, 1)
    end
end

AI.RegisterBossModule(putricide)
