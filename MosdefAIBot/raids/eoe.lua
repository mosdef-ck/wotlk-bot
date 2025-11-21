local oldPriorityTargetFn = nil

local malygos = MosDefBossModule:new({
    name = "Malygos",
    creatureId = {28859},
    surgeTarget = nil,
    lastEngulfTime = 0,
    healTarget = nil,
    onStart = function(self)
        AI.DISABLE_DRAIN = true
        AI.FocusUnit("Malygos")
        if AI.IsTank() then
            AI.ALLOW_AUTO_REFACE = false
        end
        AI.do_PriorityTarget = function()
            if not AI.IsTank() and not AI.IsPossessing() then
                if AI.DoTargetChain("power spark", "Scion", "Nexus Lord") then
                    if strcontains(UnitName("target"), "power spark") then
                        local tx, ty = AI.GetPosition("target")
                        return AI.GetDistanceToUnit("target") <= 35
                    end
                    return AI.GetDistanceToUnit("target") <= 35
                end
            elseif AI.IsPossessing() then
                AI.DoTargetChain("malygos")
            end
            return false
        end

        AI.PRE_DO_DPS = function(isAoe)
            if AI.IsDps() and AI.IsValidOffensiveUnit() and strcontains(UnitName("target"), "power spark") then
                if AI.IsPriest() then
                    AI.DoCastSpellChain("target", "mind blast", "shadow word: death", "mind flay")
                    return true
                end
                if AI.IsWarlock() then
                    AI.CastSpell("searing pain", "target")
                    return true
                end
            end
            if AI.IsPossessing() then
                return true
            end
            return false
        end
        if AI.IsWarlock() and not AI.HasBuff("demonic circle: summon") then
            AI.MustCastSpell("demonic circle: summon")
        end
        AI.Config.judgementToUse = nil
    end,
    onStop = function(self)
        AI.DISABLE_DRAIN = false
        AI.ALLOW_AUTO_REFACE = true
    end,
    onUpdate = function(self)
        if AI.IsPossessing() then
            if AI.IsHealer() then
                -- being surged 
                if AI.HasDebuff("surge of power", "playerpet") and AI.GetUnitHealthPct("playerpet") <= 30 and
                    not AI.HasBuff("flame shield", "playerpet") then
                    TargetUnit(self.healTarget or "playerpet")
                    if GetComboPoints("playerpet", "target") > 0 and
                        AI.CastVehicleSpellOnTarget("flame shield", "target") then
                        print("casting flame shield to survive surge")
                        -- self.healTarget = nil
                    end
                end

                if not self.healTarget or not UnitExists(self.healTarget) then
                    self.healTarget = AI.GetMostDamagedFriendlyPet()
                    print("new heal target:", self.healTarget)
                end

                if self.healTarget then
                    local healTarget, amount = AI.GetMostDamagedFriendlyPet()
                    if self:CanCast("life burst") and AI.GetUnitHealthPct(healTarget) <= 90 and
                        GetComboPoints("playerpet", self.healTarget) > 4 then
                        TargetUnit(self.healTarget)
                        if AI.CastVehicleSpellOnTarget("life burst", "target") then
                            -- self.healTarget = nil
                            return true
                        end
                    end
                    if self:CanCast("revivify") then
                        TargetUnit(self.healTarget)
                        if (GetComboPoints("playerpet", self.healTarget) < 5 and
                            AI.CastVehicleSpellOnTarget("revivify", self.healTarget)) then
                            return true
                        end
                    end
                end
            else
                AI.DoTargetChain("malygos")
                if not AI.IsValidOffensiveUnit("target") then
                    return true
                end

                if AI.HasDebuff("surge of power", "playerpet") and GetComboPoints("playerpet", "target") > 1 and
                    not AI.HasBuff("flame shield", "playerpet") and AI.GetUnitHealthPct("playerpet") <= 30 and
                    AI.CastVehicleSpellOnTarget("flame shield", "target") then
                    return true
                end

                if self:CanCast("Engulf in Flames") and -- UnitPower("playerpet") > 70 and
                GetComboPoints("playerpet", "target") > 4 and AI.CastVehicleSpellOnTarget("engulf in flames", "target") then
                    return true
                end
                if self:CanCast("Flame Spike") and GetComboPoints("playerpet", "target") < 5 and
                    AI.CastVehicleSpellOnTarget("Flame Spike", "target") then
                    return true
                end
            end
            return true
        end
        return false
    end,
    CanCast = function(self, spell)
        local energy = UnitPower("playerpet")
        if (strcontains(spell, "flame spike") or strcontains("revivify")) and energy > 10 then
            return true
        end
        if (strcontains(spell, "engulf in flames") or strcontains("life burst")) and energy > 50 then
            return true
        end
        if (strcontains(spell, "flame shield")) then
            return true
        end
        if strcontains(spell, "blazing speed") then
            return true
        end
        return false
    end,
    centerP = AI.PathFinding.Vector3.new(776.10754394531, 1323.0025634766, 267.19049072266),
    r = 30
})

function malygos:SPELL_AURA_APPLIED(args)
    if strcontains(args.spellName:lower(), "vortex") then
        if AI.IsPriest() or AI.IsWarlock() or AI.IsMage() then
            AI.RegisterPendingAction(function()
                if AI.IsPriest() and AI.CastSpell("power word: shield", AI.GetPrimaryHealer()) then
                    return true
                end
                if AI.IsWarlock() and AI.CastSpell("demonic circle: teleport") then
                    return true
                end
                if AI.IsMage() and AI.CastSpell("blink") then
                    return true
                end
            end, 2, "REACT_TO_VORTEX")
        end
    end
end

function malygos:SPELL_AURA_REMOVED(args)
    if args.spellName:lower() == "surge of power" then
        self.surgeTarget = nil
    end
end

function malygos:SMSG_SPELL_CAST_GO2(args)
    if args.spellId == 57430 then
        print("static field inc")
        AI.RegisterPendingAction(function()
            return AI.HasBuff("blazing speed", "playerpet") or AI.UsePossessionSpell("blazing speed")
        end, 0)
    end
    if args.spellId == 57143 or args.spellId == 57108 and args.casterGUID == UnitGUID("playerpet") and AI.IsHealer() then
        print("life burst or flame shield away")
        self.healTarget = nil
    end
end

function malygos:CHAT_MSG_RAID_BOSS_EMOTE(s, t)
    -- print("CHAT_MSG_RAID_BOSS_EMOTE", s, t)
    -- if strcontains(s, "fixes") then
    --     -- print("surge on me")
    --     local target = (AI.IsHealer() and self.healTarget) and self.healTarget or "target"
    --     if GetComboPoints("playerpet", target) > 0 and AI.GetUnitHealthPct("playerpet") <= 50 then
    --         AI.RegisterPendingAction(function()
    --             return AI.CastVehicleSpellOnTarget("flame shield", target)
    --         end, 0)
    --     end
    -- end
end

AI.RegisterBossModule(malygos)
