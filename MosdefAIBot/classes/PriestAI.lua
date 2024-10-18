local isAIEnabled = false
local doAutoDps = false
local primaryTank = nil
local panicPct = 20

local function upkeepShadowForm()
    if GetShapeshiftForm() ~= 1 and AI.CastSpell("Shadowform") then
        return true
    end

    if not AI.HasBuff("inner fire") and AI.CastSpell("inner fire") then
        return true
    end

    if not AI.IsInCombat() and not AI.HasBuff("vampiric embrace") and AI.CastSpell("vampiric embrace") then
        return true
    end
    return false
end

local function doPowerWordShield()
    if AI.IsInCombat() then
        local criticalTarget, missingHp = AI.GetMostDamagedFriendly("power word: shield")
        if criticalTarget and AI.GetUnitHealthPct(criticalTarget) <= panicPct and
            not AI.HasDebuff("weakened soul", criticalTarget) then
            if AI.IsCasting() then
                SpellStopCasting()
            end
            if AI.CastSpell("power word: shield", criticalTarget) then
                AI.Print("pw:shielded " .. UnitName(criticalTarget))
                if primaryTank then
                    AI.SayWhisper("pw:shielded " .. UnitName(criticalTarget), primaryTank)
                end
                return true
            end
        end
    end
    return false
end

local function useHealthStone()
    if AI.IsInCombat() and AI.GetUnitHealthPct() <= panicPct and not AI.HasDebuff('Necrotic Aura') and
        AI.UseContainerItem("Fel Healthstone") then
        AI.Print("I am critical, using fel healthstone")
        if primaryTank and UnitName("player") ~= primaryTank then
            AI.SayWhisper("I am critical, using fel healthstone", primaryTank)
        end
    end
end

local function doAutoDps()
    if not AI.AUTO_DPS then
        return
    end

    if not isAIEnabled or IsMounted() or UnitUsingVehicle("player") or not AI.CanCast() or UnitIsDeadOrGhost("player") or
        AI.HasBuff("drink") or AI.IsMoving() then
        return
    end

    if not AI.do_PriorityTarget() then
        AssistUnit(primaryTank)
    end
    if not AI.IsValidOffensiveUnit("target") then
        return
    end

    useHealthStone()

    if AI.GetTargetStrength() >= 2 and AI.GetUnitPowerPct("player") <= 40 and AI.CastSpell("shadowfiend", "target") then
        return
    end

    if AI.GetTargetStrength() > 3 and AI.GetUnitPowerPct("player") < 20 and AI.CastSpell("Hymn of Hope") then
        return
    end

    if AI.GetTargetStrength() > 2 and AI.GetUnitPowerPct("player") < 20 and AI.CastSpell("Dispersion") then
        return
    end

    -- AI.CastSpell("inner focus")

    if AI.CastSpell("mind blast", "target") then
        return
    end
    -- if AI.CastSpell("shadow word: death", "target") then
    --     return
    -- end

    if not AI.AUTO_AOE then        
        if AI.GetTargetStrength() >= 2 and AI.GetDebuffDuration("Vampiric Touch", "target") <= 1 and
            AI.CastSpell("Vampiric Touch", "target") then
            return
        end
        if AI.GetTargetStrength() >= 3 and AI.GetDebuffDuration("devouring plague", "target") <= 1 and
            AI.CastSpell("devouring plague", "target") then
            return
        end

        if AI.GetTargetStrength() >= 2 and
            (not AI.HasDebuff("Shadow Word: Pain", "target") or AI.GetBuffDuration("potion of wild magic") >= 12 or AI.GetBuffDuration("now is the time!") >= 8) and
            AI.CastSpell("Shadow Word: Pain", "target") then
            return
        end
        if AI.CastSpell("mind flay", "target") then
            return
        end
    elseif AI.CastSpell("mind sear", "target") then
        return
    end
end

local function autoPurge()
    if AI.IsInCombat() and AI.HasPurgeableBuff("target") and AI.CastSpell("dispel magic", "target") then
        return true
    end
    return false
end

local function manageThreat()
    if AI.IsInCombat() and AI.GetTargetStrength() > 3 and AI.IsValidOffensiveUnit("target") then
        local threat = AI.GetThreatPct("target")
        if AI.GetUnitHealthPct("target") < 95 and threat > 90 and AI.CastSpell("fade") then
            -- AI.Print("Exceeded 90% of threat on " .. GetUnitName("target"))
            -- if primaryTank then
            --     AI.SayWhisper("Exceeded 90% of threat on " .. GetUnitName("target"), primaryTank)
            -- end
            return true
        end
    end
    return false
end

local function doOnUpdate_ShadowPriest()
    if not isAIEnabled or IsMounted() or UnitUsingVehicle("player") or UnitIsDeadOrGhost("player") or
        AI.HasBuff("drink") or AI.IsMoving() then
        return
    end

    if doPowerWordShield() then
        return
    end

    if not AI.CanCast() then
        return
    end

    if upkeepShadowForm() then
        return
    end

    if manageThreat() then
        return
    end

    if AI.AUTO_PURGE and autoPurge() then
        return
    end

    if not AI.DISABLE_CDS and AI.IsInCombat() and AI.GetTargetStrength() >= 3 and AI.GetUnitHealthPct("target") < 95 then
        if AI.HasBuff("bloodlust") and AI.HasContainerItem(AI.Config.dpsPotion) then
            if AI.UseContainerItem(AI.Config.dpsPotion) then
                return
            end
        end
        AI.UseInventorySlot(10)
        AI.UseInventorySlot(13)
        AI.UseInventorySlot(14)
    end

    useHealthStone()
end

local function doDps(isAoE)

    if IsMounted() or UnitUsingVehicle("player") or not AI.CanCast() or UnitIsDeadOrGhost("player") or
        AI.HasBuff("drink") or AI.IsMoving() or AI.AUTO_DPS then
        return
    end

    if not AI.IsValidOffensiveUnit("target") then
        return
    end

    if AI.GetTargetStrength() >= 2 and AI.GetUnitPowerPct("player") <= 50 and AI.CastSpell("shadowfiend", "target") then
        return
    end

    if AI.GetTargetStrength() > 2 and AI.GetUnitPowerPct("player") < 20 and AI.CastSpell("Dispersion") then
        return
    end

    if AI.GetTargetStrength() > 3 and AI.GetUnitPowerPct("player") < 10 and AI.CastSpell("Hymn of Hope") then
        return
    end

    -- if AI.GetTargetStrength() >= 2 then
    --     AI.CastSpell("inner focus")
    -- end

    if AI.CastSpell("Mind Blast") then
        return
    end
    if AI.CastSpell("Shadow Word: Death", "target") then
        return
    end

    if isAoE and AI.CastSpell("mind sear", "target") then
        return
    else
        if AI.GetTargetStrength() >= 2 and AI.GetDebuffDuration("Vampiric Touch", "target") <= 1 and
            AI.CastSpell("Vampiric Touch", "target") then
            return
        end

        if AI.GetTargetStrength() >= 3 and AI.GetDebuffDuration("devouring plague", "target") <= 1 and
            AI.CastSpell("devouring plague", "target") then
            return
        end

        if AI.GetTargetStrength() >= 2 and
            (not AI.HasDebuff("Shadow Word: Pain", "target") or AI.GetBuffDuration("potion of wild magic") >= 12) and
            AI.CastSpell("Shadow Word: Pain", "target") then
            return
        end
        if AI.CastSpell("mind flay", "target") then
            return
        end
    end
end

function AI.doOnLoad_ShadowPriest()
    local class = AI.GetClass("player")

    if class ~= "PRIEST" then
        return
    end
    local spec = AI.GetMySpecName() or ""
    if spec == "Shadow" then
        AI.Print("detected priest spec " .. spec)
        isAIEnabled = true
        -- set the callback to be detected by AIBotBase and automatically invoked
        AI.doOnUpdate_ShadowPriest = doOnUpdate_ShadowPriest
        AI.doAutoDps = doAutoDps
        AI.DO_DPS = doDps

        --
        if AI.Config then
            AI.Print("auto-configuration applied")
            primaryTank = AI.Config.tank
            -- panicPct = AI.Config.panicHpPct
            AI.Print({
                primaryTank = primaryTank,
                panicPct = panicPct
            })
        end

    else
        AI.Print(spec .. "  priest spec is not supported")
    end
end
