local isAIEnabled = false
local primaryTank = nil
local panicPct = 20

local function autoTaunt()
    if AI.AUTO_TAUNT and AI.IsInCombat() and AI.IsValidOffensiveUnit() and not AI.IsTanking("player") then
        if AI.CastSpell("Hand of Reckoning", "target") then
            return true
        end
        if AI.CastSpell("righteous defense", "targettarget") then
            return true
        end
    end
    return false
end

local function useHealthStone()
    if AI.IsInCombat() and AI.GetUnitHealthPct() <= panicPct and not AI.HasDebuff('Necrotic Aura') and
        AI.UseContainerItem("Fel Healthstone") then
        -- AI.Print("I am critical, using fel healthstone")
        -- if primaryTank and UnitName("player") ~= primaryTank then
        --     AI.SayWhisper("I am critical, using fel healthstone", primaryTank)
        -- end
    end
end

local function doAutoDps()
    if not AI.AUTO_DPS then
        return
    end

    if not isAIEnabled or IsMounted() or UnitUsingVehicle("player") or not AI.CanCast() or UnitIsDeadOrGhost("player") or
        AI.HasBuff("drink") then
        return
    end

    if not AI.do_PriorityTarget() and not AI.IsValidOffensiveUnit("target") then
        TargetNearestEnemy()
    end
    if not AI.IsValidOffensiveUnit("target") then
        return
    end

    if autoTaunt() then
        return
    end

    useHealthStone()

    -- if AI.GetTargetStrength() > 3 and not AI.HasBuff("avenging wrath", "player") then
    --     AI.CastSpell("avenging wrath")
    -- end

    if AI.GetTargetStrength() >= 3 and not AI.HasBuff("holy shield", "player") and AI.CastSpell("holy shield") then
        return
    end
    if AI.CanCastSpell("hammer of wrath", "target") and AI.CastSpell("hammer of wrath", "target") then
        return
    end

    if AI.GetDistanceToUnit("target") <= 8 and AI.CastSpell("Consecration") then
        return
    end

    if AI.DoCastSpellChain("target", "Hammer of the Righteous", "Shield of Righteousness", "judgement of wisdom") then
        return
    end
    if AI.GetTargetStrength() >= 3 and not AI.HasBuff("divine plea") and AI.CastSpell("divine plea") then
        return
    end
    if AI.GetTargetStrength() > 3 and not AI.HasBuff("sacred shield", "player") and AI.CastSpell("sacred shield") then
        return
    end
end

local function doDps(isAoE)

    if IsMounted() or UnitUsingVehicle("player") or not AI.CanCast() or UnitIsDeadOrGhost("player") or
        AI.HasBuff("drink") or AI.AUTO_DPS then
        return
    end

    if not AI.IsValidOffensiveUnit("target") then
        return
    end

    if AI.GetTargetStrength() >= 3 and not AI.HasBuff("holy shield", "player") and AI.CastSpell("holy shield") then
        return
    end

    if AI.CanCastSpell("hammer of wrath", "target") and AI.CastSpell("hammer of wrath", "target") then
        return
    end

    if AI.GetDistanceToUnit("target") <= 8 and AI.CastSpell("Consecration") then
        return
    end

    if AI.DoCastSpellChain("target", "Hammer of the Righteous", "Shield of Righteousness", "judgement of wisdom") then
        return
    end

    -- if AI.GetTargetStrength() > 3 and not AI.HasBuff("avenging wrath", "player") then
    --     AI.CastSpell("avenging wrath")
    -- end

    if AI.GetTargetStrength() >= 3 and not AI.HasBuff("sacred shield", "player") and AI.CastSpell("sacred shield") then
        return
    end
    if AI.GetTargetStrength() >= 3 and not AI.HasBuff("divine plea", "player") and AI.CastSpell("divine plea") then
        return
    end
end

local function doOnUpdate_ProtPaladin()
    if not isAIEnabled or IsMounted() or UnitUsingVehicle("player") or not AI.CanCast() or UnitIsDeadOrGhost("player") or
        AI.HasBuff("drink") then
        return
    end

    if not AI.IsInCombat() and AI.IsInDungeonOrRaid() then
        if not AI.HasBuff("righteous fury") and AI.CastSpell("righteous fury") then
            return
        end
        if not AI.HasBuff("greater blessing of sanctuary") and AI.CastSpell('greater blessing of sanctuary', "player") then
            return
        end
    end

    -- if AI.IsInCombat() and AI.GetUnitHealthPct() <= panicPct then
    --     AI.UseInventorySlot(13)
    --     AI.UseInventorySlot(14)
    -- end
    if AI.IsInCombat() then
        local criticalTarget, missingHp = AI.GetMostDamagedFriendly("hand of sacrifice")
        if criticalTarget ~= nil and UnitName(criticalTarget) ~= UnitName("player") and
            AI.GetUnitHealthPct(criticalTarget) <= panicPct then
            AI.MustCastSpell("hand of sacrifice", criticalTarget)
            return
        end
    end

    useHealthStone()

    if autoTaunt() then
        return
    end
end

function AI.doOnLoad_ProtPaladin()
    local class = AI.GetClass("player")

    if class ~= "PALADIN" then
        return
    end
    local spec = AI.GetMySpecName() or ""
    if spec == "Protection" then
        AI.Print("detected paladin spec " .. spec)
        isAIEnabled = true
        -- set the callback to be detected by AIBotBase and automatically invoked
        AI.doOnUpdate_ProtPaladin = doOnUpdate_ProtPaladin
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
        AI.Print(spec .. "  paladin spec is not supported")
    end
end
