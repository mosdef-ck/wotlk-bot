local oldPriorityTargetFn = nil

local malygos = MosDefBossModule:new({
    name = "Malygos",
    creatureId = {28859},
    surgeTarget = nil,
    onStart = function(self)
        oldPriorityTargetFn = AI.do_PriorityTarget
        AI.DISABLE_DRAIN = true
        if AI.IsTank() then
            AI.ALLOW_AUTO_REFACE = false
        end
        AI.do_PriorityTarget = function()
            if not AI.IsTank() then
                ClearTarget()
                TargetUnit("Power Spark")
                if AI.IsValidOffensiveUnit("target") and AI.CanHitTarget() then
                    return true
                end
            else
                ClearTarget()
                TargetUnit("malygos")
                return AI.IsValidOffensiveUnit("target")
            end
            ClearTarget()
            TargetUnit("scion")
            if AI.IsValidOffensiveUnit("target") and AI.CanHitTarget() then
                return true
            end
            ClearTarget()
            TargetUnit("Nexus Lord")
            if AI.IsValidOffensiveUnit("target") and AI.CanHitTarget() then
                return true
            end
            return false
        end
    end,
    onStop = function(self)
        AI.DISABLE_DRAIN = false
        AI.ALLOW_AUTO_REFACE = true
        if oldPriorityTargetFn ~= nil then
            AI.do_PriorityTarget = oldPriorityTargetFn
        end
    end,
    onUpdate = function(self)
        local class = AI.GetClass():lower()

        if not AI.IsPossessing() then
            if AI.IsValidOffensiveUnit("target") and UnitName("target"):lower() == "power spark" then
                if class == "priest" and AI.CastSpell("mind flay", "target") then
                    return true
                end
                if class == "mage" and AI.CastSpell("arcane missiles", "target") then
                    return true
                end
            end
        else
            -- if AI.HasDebuff("surge of power", "playerpet") and GetComboPoints("playerpet", "target") > 1 and
            --     self:CanCast("flame shield") and AI.UsePossessionSpell("flame shield") then
            --     AI.SayRaid("flame shielding")
            --     return true
            -- end

            if AI.IsHealer() then
                if UnitName("focus") ~= "Malygos" then
                    TargetUnit("malygos")
                    FocusUnit("target")
                end

                if self:CanCast("life burst") then
                    for i, unit in ipairs(AI.GetRaidOrPartyPetMemberUnits()) do
                        if GetComboPoints("playerpet", unit) > 4 then
                            TargetUnit(unit)
                            AI.UsePossessionSpell("Life Burst")
                            return true
                        end
                    end
                end

                local healTarget = AI.GetMostDamagedFriendlyPet()
                if healTarget then
                    TargetUnit(healTarget)

                    -- if GetComboPoints("playerpet", healTarget) > 4 and self:CanCast("life burst") and
                    --     AI.UsePossessionSpell("Life Burst") then
                    --     return true
                    -- end
                    if self:CanCast("Revivify") then
                        if AI.GetBuffCount("revivify", healTarget) < 5 and AI.UsePossessionSpell("Revivify", healTarget) then
                            return true
                        end
                    end
                else
                    TargetUnit("playerpet")
                    if GetComboPoints("playerpet", "playerpet") > 4 and self:CanCast("life burst") and
                        AI.UsePossessionSpell("Life Burst") then
                        return true
                    end
                    if AI.GetBuffCount("revivify", "playerpet") and self:CanCast("Revivify") and
                        AI.UsePossessionSpell("Revivify", "playerpet") then
                        return true
                    end
                end
            else
                if UnitName("target") ~= "Malygos" then
                    TargetUnit("Malygos")
                end

                if not AI.IsValidOffensiveUnit("target") then
                    return true
                end

                -- if GetComboPoints("playerpet", "target") == 0 and AI.GetBuffDuration("revivify", "playerpet") < 3 and
                --     self:CanCast("Revivify") then
                --     TargetUnit("playerpet")
                --     AI.UsePossessionSpell("revivify", "playerpet")
                --     return true
                -- end

                if UnitName("target") ~= "Malygos" then
                    TargetUnit("Malygos")
                end

                if self:CanCast("Engulf in Flames") and GetComboPoints("playerpet", "target") > 4 and
                    AI.UsePossessionSpell("Engulf in Flames", "target") then
                    return true
                end
                if self:CanCast("Flame Spike") and GetComboPoints("playerpet", "target") < 5 then
                    AI.UsePossessionSpell("Flame Spike", "target")
                end
            end
            return true
        end
        return false
    end,
    CanCast = function(self, spell)
        local energy = UnitMana("playerpet")
        if (spell:lower() == "flame spike" or spell:lower() == "revivify") and energy > 10 then
            return true
        end
        if (spell:lower() == "engulf in flames" or spell:lower() == "life burst") and energy > 50 then
            return true
        end
        if (spell:lower() == "flame shield") and energy > 25 then
            return true
        end
        if spell:lower() == "blazing speed" then
            return true
        end
        return false
    end
})

function malygos:SPELL_AURA_APPLIED(args)
    if args.spellName:lower() == "vortex" and args.target == UnitName("player") then
        AI.RegisterPendingAction(function()
            local class = AI.GetClass():lower()
            if class == "priest" and not AI.HasDebuff("weakened soul", AI.Config.healer) and
                AI.CastSpell("power word: shield", AI.Config.healer) then
                return true
            end
            if class == "warlock" and AI.CastSpell("demonic circle: teleport") then
                return true
            end
            if class == "mage" and AI.CastSpell("blink") then
                return true
            end
        end, 2)
    end
    if args.spellName:lower() == "surge of power" and args.target == UnitName("playerpet") then
        self.surgeTarget = UnitName("player")
    end
end

function malygos:SPELL_AURA_REMOVED(args)
    if args.spellName:lower() == "surge of power" then
        self.surgeTarget = nil
    end
end

function malygos:SPELL_DAMAGE(args)
    if args.spellName:lower() == "static field" and
        (args.target == UnitName("playerpet") or args.target == UnitName("player")) then
        AI.UsePossessionSpell("blazing speed")
    end
end

AI.RegisterBossModule(malygos)
