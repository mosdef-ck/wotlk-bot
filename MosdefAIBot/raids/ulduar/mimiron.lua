-- mimiron
local oldPriorityTargetFn = nil
local mimiron = MosDefBossModule:new({
    name = "Mimiron",
    creatureId = {33350, 33432},
    onStart = function(self)
        if AI.IsTank() then
            AI.ALLOW_AUTO_REFACE = false
        end
        oldPriorityTargetFn = AI.do_PriorityTarget
        AI.do_PriorityTarget = function()
            -- return AI.DoTargetChain("assault bot", "aerial command unit")
        end
        AI.Config.startHealOverrideThreshold = 95
    end,
    onStop = function(self)
        AI.ALLOW_AUTO_REFACE = true
        AI.do_PriorityTarget = oldPriorityTargetFn
        AI.Config.startHealOverrideThreshold = 100
    end,
    onUpdate = function(self)
        if AI.IsDps() then
            local healer = AI.GetPrimaryHealer()
            if healer and AI.GetDistanceToUnit(healer) > 2 then
                -- print("too far from healer, moving towards")
                local x, y = AI.GetPosition(healer)
                if AI.IsCasting() then
                    AI.StopCasting()
                end
                FollowUnit(healer)
                -- AI.SetMoveToPosition(x, y)
            end
        end

        if AI.IsPriest() then
            if self.plasmaTarget ~= nil and not AI.HasDebuff("weakened soul", self.plasmaTarget) and
                AI.CastSpell("power word: shield", self.plasmaTarget) then
                return true
            end
            local criticalTarget, missingHp = AI.GetMostDamagedFriendly("power word: shield")
            if criticalTarget and AI.GetUnitHealthPct(criticalTarget) <= 10 and
                not AI.HasDebuff("weakened soul", criticalTarget) then
                if AI.IsCasting() then
                    AI.StopCasting()
                end
                if AI.CastSpell("power word: shield", criticalTarget) then
                    return true
                end
            end
        end

        if AI.IsHealer() and self.plasmaTarget then
            if AI.IsShaman() and AI.CastSpell("riptide", self.plasmaTarget) or
                AI.CastSpell("healing wave", self.plasmaTarget) then
                return true
            end
        end

        if AI.IsMage() and not AI.HasMyBuff("fire ward") and AI.CastSpell("fire ward") then
            return true
        end

        if AI.IsHealer() then
            local rocket = AI.FindNearbyUnitsByName("rocket strike")
            if #rocket > 0 and rocket[1].distance <= 3 and rocket[1]:HasAura("64064") and not AI.HasMoveTo() then
                print('evading rocket')
                local facing = AI.GetFacingForPosition(self.centerx, self.centery)
                local theta = facing - rad90
                local r = 7
                local pX, pY = AI.GetPosition("player")
                local nX, nY = pX + r * math.cos(theta), pY + r * math.sin(theta)
                AI.SetMoveTo(nX, nY)
            end
        end        
        return false
    end,
    plasmaTarget = nil,
    centerx = 2745.083984375,
    centery = 2569.5290527344
})

function mimiron:SPELL_AURA_APPLIED(args)
    if args.spellName == "Plasma Blast" then
        self.plasmaTarget = args.target
    end
end

function mimiron:SPELL_AURA_REMOVED(args)
    if args.spellName == "Plasma Blast" then
        self.plasmaTarget = nil
    end
end

function mimiron:SPELL_CAST_START(args)
    if (args.spellName == "Shock Blast" or args.spellId == 63631) and AI.IsTank() then
        if not AI.HasMoveTo() then
            print("avoiding shock blast")
            local facing = GetPlayerFacing() + math.pi
            local r = 20
            local x, y = r * math.cos(facing), math.sin(facing)
            local cX, cY, cZ = AI.GetPosition()
            local nX, nY = cX + x, cY + y
            AI.SetMoveTo(nX, nY, cZ, 0.5, function()
                AI.SetFacingUnit("target")
            end)
        end
    end

    if args.spellName == "plasma blast" then
        if AI.IsPriest() then
            AI.RegisterPendingAction(function()
                local tank = AI.GetPrimaryTank()
                if not AI.HasDebuff("weakened soul", tank) then
                    return AI.CastSpell("power word: shield", tank)
                end
                return false
            end, null, "SHIELD_TANK")
        end
    end
end

function mimiron:SPELL_CAST_SUCCESS(args)
    if args.spellId == 63414 or args.spellName == "spinning up" then
        if AI.IsTank() and AI.IsValidOffensiveUnit() then
            print("mimiron spinning up")
            local pi2 = math.pi * 2
            local target = GetObjectInfo("target")
            if target.facing ~= nil then
                local angleBehind = target.facing + math.pi
                angleBehind = normalizeAngle(angleBehind)
                local r = 2
                local x, y = r * math.cos(angleBehind), r * math.sin(angleBehind)
                local nX, nY = target.x + x, target.y + y
                AI.SetMoveTo(nX, nY)
            end
        end
    end
end

AI.RegisterBossModule(mimiron)
