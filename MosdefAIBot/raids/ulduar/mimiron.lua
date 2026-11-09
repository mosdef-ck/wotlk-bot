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
        AI.Config.startHealOverrideThreshold = 90
        if not AI.HasBuff("lesser flask of resistance") and not AI.IsTank() then
            AI.UseContainerItem("lesser flask of resistance")
        end
        AI.judgementToUse = nil

        -- if not AI.IsTank() then
        --     AI.SetFlySpeed(10)
        --     AI.LevitateFor(1)
        -- else
        --     AI.SetRunSpeed(10)
        -- end
    end,
    onStop = function(self)
        AI.ALLOW_AUTO_REFACE = true
        AI.do_PriorityTarget = oldPriorityTargetFn
        AI.Config.startHealOverrideThreshold = 100
        AI.ResetHacks()
    end,
    onUpdate = function(self)
        -- if not AI.IsTank() then
        --     if not AI.GetObjectInfo("player"):IsFlying() then
        --         AI.LevitateFor(1)                
        --     end
        --     if AI.GetFlySpeed() < 10 then
        --         AI.SetFlySpeed(10)
        --     end
        -- else
        --     if AI.GetRunSpeed() < 10 then
        --         AI.SetRunSpeed(10)
        --     end
        -- end
        if AI.IsDps() then
            local healer = AI.GetPrimaryHealer()
            if healer and not UnitIsDeadOrGhost(healer) and AI.GetDistanceToUnit(healer) > 2 then
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

        -- if AI.IsMage() and not AI.HasMyBuff("fire ward") and AI.CastSpell("fire ward") then
        --     return true
        -- end        
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
            local p = AI.PathFinding.FindSafeSpotOnBoundary("target", 20)            
            AI.SetMoveTo(p.x, p.y, p.z, 0.5, function()
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
                local angleBehind = normalizeAngle(target.facing + math.pi)
                local r = 3
                local x, y = r * math.cos(angleBehind), r * math.sin(angleBehind)
                local nX, nY = target.x + x, target.y + y
                AI.SetMoveTo(nX, nY)
            end
        end
    end
end

function mimiron:SMSG_SPELL_CAST_GO2(args)
    if args.spellId == 64064 then
        print("Rocket Strike is coming!")
    end
end

AI.RegisterBossModule(mimiron)
