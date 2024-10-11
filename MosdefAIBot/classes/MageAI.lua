local isAIEnabled = false
local primaryTank = nil
local panicPct = 20

local function doSpellSteal()
    if AI.IsInCombat() and AI.HasStealableBuff("target") and AI.GetTargetStrength() > 3 and AI.CastSpell("spellsteal") then
        AI.Print("I've stolen a buff from " .. UnitName("target"))
        return true
    end
    return false
end

local function doManaSapphire()
    if not AI.IsInCombat() and not AI.HasContainerItem("mana sapphire") and AI.CastSpell("Conjure Mana Gem") then
        return true
    end
    if AI.IsInCombat() and AI.GetUnitPowerPct("player") <= 50 then
        AI.UseContainerItem("mana sapphire")
    end
    return false
end

local function doManaShield()
    if AI.IsInCombat() and AI.GetUnitHealthPct() <= 10 and not AI.HasBuff("mana shield") and AI.CastSpell("mana shield") then
        return true
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
        AI.HasBuff("drink") then
        return
    end

    if not AI.do_PriorityTarget() then
        AssistUnit(primaryTank)
    end

    if doManaSapphire() then
        return
    end

    if doManaShield() then
        return
    end

    if doSpellSteal() then
        return
    end

    useHealthStone()

    if not AI.IsValidOffensiveUnit("target") then
        return
    end

    if AI.GetUnitPowerPct("player") <= 10 and AI.CastSpell("Evocation") then
        return
    end

    if AI.GetTargetStrength() <= 1 and AI.CastSpell("arcane missiles", "target") then
        return
    end

    if AI.GetDebuffCount("arcane blast") > 3 and AI.CastSpell("arcane missiles", "target") then
        return
    end

    AI.CastSpell("arcane blast", "target")
end

local function doOnUpdate_MageAI()
    if not isAIEnabled or IsMounted() or UnitUsingVehicle("player") or not AI.CanCast() or UnitIsDeadOrGhost("player") or
        AI.HasBuff("drink") then
        return
    end

    if not AI.IsInCombat() and not AI.HasMyBuff("molten armor") and AI.CastSpell("molten armor") then return end

    if doSpellSteal() then
        return
    end

    if doManaSapphire() then
        return
    end

    if doManaShield() then
        return
    end

    if AI.IsInCombat() and AI.GetUnitPowerPct("player") <= 10 and AI.CastSpell("Evocation") then
        return
    end

    if not AI.DISABLE_CDS and AI.IsInCombat() and AI.GetTargetStrength() >= 3 and AI.GetUnitHealthPct("target") < 95 then
        AI.UseInventorySlot(10)
        AI.UseInventorySlot(13)
        AI.UseInventorySlot(14)
        if AI.CastSpell("mirror image") then
            return
        end
        if AI.HasBuff("Bloodlust") then
            if AI.HasContainerItem(AI.Config.dpsPotion) and AI.UseContainerItem(AI.Config.dpsPotion) then
                return
            end
            AI.CastSpell("presence of mind")
            AI.CastSpell("arcane power")
            AI.CastSpell("Icy Veins")

        end
    end
    useHealthStone()
end

local function doDpsArcane(isAoE)

    if IsMounted() or UnitUsingVehicle("player") or not AI.CanCast() or UnitIsDeadOrGhost("player") or
        AI.HasBuff("drink") then
        return
    end

    if not AI.IsValidOffensiveUnit("target") then
        return
    end

    if isAoE then
        if CheckInteractDistance("target", 3) and AI.CastSpell("arcane explosion") then
            return
        end
    end

    if AI.GetTargetStrength() <= 1 and AI.GetDebuffCount("arcane blast") > 1 and AI.HasBuff("missile barrage") and
        AI.CastSpell("arcane missiles", "target") then
        return
    end

    if AI.GetDebuffCount("arcane blast") > 3 and AI.CastSpell("arcane missiles", "target") then
        return
    end

    AI.CastSpell("arcane blast", "target")
end

local function doDpsFireMage()
    if IsMounted() or UnitUsingVehicle("player") or not AI.CanCast() or UnitIsDeadOrGhost("player") or
        AI.HasBuff("drink") then
        return
    end

    if not AI.IsValidOffensiveUnit("target") then
        return
    end

    if AI.GetUnitPowerPct("player") <= 20 and AI.CastSpell("Evocation") then
        return
    end

    if AI.GetTargetStrength() >= 3 and not AI.HasDebuff("living bomb", "target") and
        AI.CastSpell("living bomb", "target") then
        return
    end

    if AI.GetTargetStrength() >= 3 then
        AI.CastSpell("combustion")
    end

    if AI.HasBuff("hot streak", "player") and AI.CastSpell("pyroblast") then
        return
    end

    AI.CastSpell("frostfire bolt")
end

function AI.doOnLoad_Mage()
    local class = AI.GetClass("player")

    if class ~= "MAGE" then
        return
    end
    local spec = AI.GetMySpecName() or ""
    if spec == "Arcane" or spec == "Fire" or spec == "Frost" then
        AI.Print("detected mage spec " .. spec)
        isAIEnabled = true
        -- set the callback to be detected by AIBotBase and automatically invoked
        AI.doOnUpdate_MageAI = doOnUpdate_MageAI
        AI.doAutoDps = doAutoDps
        if spec == "Arcane" then
            AI.DO_DPS = doDpsArcane
        else
            AI.DO_DPS = doDpsFireMage
        end

        --
        if AI.Config then
            AI.Print("auto-configuration applied")
            primaryTank = AI.Config.tank
            panicPct = AI.Config.panicHpPct
            AI.Print({
                primaryTank = primaryTank,
                panicPct = panicPct
            })
        end
    else
        AI.Print(spec .. " mage spec is not supported")
    end
end
