local oldPriorityTargetFn = nil

local malygos = MosDefBossModule:new({
    name = "Malygos",
    creatureId = {28859},
    surgeTarget = nil,
    onStart = function(self)
        AI.DISABLE_DRAIN = true
        TargetUnit("Malygos")
        FocusUnit("target")
        if AI.IsTank() then
            AI.ALLOW_AUTO_REFACE = false
        end
        AI.do_PriorityTarget = function()
            if not AI.IsTank() then
                if AI.DoTargetChain("power spark", "Scion", "Nexus Lord") then
                    if strcontains(UnitName("target"), "power spark") then
                        local tx, ty = AI.GetPosition("target")
                        return AI.CalcDistance(self.centerP.x, self.centerP.y, tx, ty) <= self.r and AI.GetDistanceToUnit("target") <= 35
                    end
                    return AI.GetDistanceToUnit("target") <= 35
                end
            end
            return false
        end
    end,
    onStop = function(self)
        AI.DISABLE_DRAIN = false
        AI.ALLOW_AUTO_REFACE = true
    end,
    onUpdate = function(self)
        local class = AI.GetClass():lower()

        if AI.IsPossessing() then
            -- if AI.HasDebuff("surge of power", "playerpet") and GetComboPoints("playerpet", "target") > 1 and
            --     self:CanCast("flame shield") and AI.UsePossessionSpell("flame shield") then
            --     AI.SayRaid("flame shielding")
            --     return true
            -- end

            if AI.IsHealer() then
                if self:CanCast("life burst") then
                    for i, unit in ipairs(AI.GetRaidOrPartyPetMemberUnits()) do
                        if GetComboPoints("playerpet", unit) > 4 and AI.CastVehicleSpellOnTarget("life burst", unit) then
                            return true
                        end
                    end
                end

                local healTarget = AI.GetMostDamagedFriendlyPet()
                if healTarget then
                    -- if GetComboPoints("playerpet", healTarget) > 4 and self:CanCast("life burst") and
                    --     AI.UsePossessionSpell("Life Burst") then
                    --     return true
                    -- end
                    if self:CanCast("Revivify") then
                        if AI.GetBuffCount("revivify", healTarget) < 5 and
                            AI.CastVehicleSpellOnTarget("Revivify", healTarget) then
                            return true
                        end
                    end
                else
                    if GetComboPoints("playerpet", "playerpet") > 4 and self:CanCast("life burst") and
                        AI.CastVehicleSpellOnTarget("Life Burst", "playerpet") then
                        return true
                    end
                    if AI.GetBuffCount("revivify", "playerpet") and self:CanCast("Revivify") and
                        AI.CastVehicleSpellOnTarget("Revivify", "playerpet") then
                        return true
                    end
                end
            else
                AI.DoTargetChain("malygos")

                if not AI.IsValidOffensiveUnit("target") then
                    return true
                end

                if self:CanCast("Engulf in Flames") and GetComboPoints("playerpet", "target") > 4 and
                    AI.CastVehicleSpellOnTarget("Engulf in Flames", "target") then
                    return true
                end
                if self:CanCast("Flame Spike") and GetComboPoints("playerpet", "target") < 5 then
                    AI.CastVehicleSpellOnTarget("Flame Spike", "target")
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
    end,
    centerP = AI.PathFinding.Vector3.new(776.10754394531, 1323.0025634766, 267.19049072266),
    r = 30
})

function malygos:SPELL_AURA_APPLIED(args)
    if strcontains(args.spellName:lower(), "vortex") and strcontains(args.target, UnitName("player")) then
        AI.RegisterPendingAction(function()
            if AI.IsPriest() and not AI.HasDebuff("weakened soul", AI.Config.healer) and
                AI.CastSpell("power word: shield", AI.Config.healer) then
                return true
            end
            if AI.IsWarlock() and AI.CastSpell("demonic circle: teleport") then
                return true
            end
            if AI.IsMage() and AI.CastSpell("blink") then
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
