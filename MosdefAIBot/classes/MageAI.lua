local isAIEnabled = false
local primaryTank = nil
local panicPct = 20

local function doSpellSteal()
    if AI.IsInCombat() and AI.HasStealableBuff("target") and AI.CastSpell("spellsteal") then
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
        if not AI.UseContainerItem("mana sapphire") then
            AI.UseContainerItem(AI.Config.manaPotion)
        end
    end
    return false
end

local function doManaShield()
    if AI.IsInCombat() and AI.GetUnitHealthPct() <= 20 and not AI.HasBuff("mana shield") and AI.CastSpell("mana shield") then
        return true
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

local function doAutoDpsArcane()
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

    -- if doManaShield() then
    --     return
    -- end

    if doSpellSteal() then
        return
    end

    useHealthStone()

    if not AI.IsValidOffensiveUnit("target") then
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

local function doAutoDpsFire()
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

    -- if doManaShield() then
    --     return
    -- end

    if doSpellSteal() then
        return
    end

    useHealthStone()

    if not AI.IsValidOffensiveUnit("target") then
        return
    end

    if AI.GetTargetStrength() >= 3 and not AI.HasDebuff("living bomb", "target") and
        AI.CastSpell("living bomb", "target") then
        return
    end

    if AI.HasBuff("hot streak", "player") and AI.CastSpell("pyroblast") then
        return
    end

    AI.CastSpell("frostfire bolt")

end

local function doOnUpdate_MageAI()
    if IsMounted() or UnitUsingVehicle("player") or not AI.CanCast() or UnitIsDeadOrGhost("player") or
        AI.HasBuff("drink") then
        return
    end

    if doSpellSteal() then
        return
    end

    if doManaSapphire() then
        return
    end

    if AI.AUTO_CLEANSE and AI.CleanseRaid("Remove Curse", "Curse") then
        return
    end

    -- if doManaShield() then
    --     return
    -- end

    if AI.IsInCombat() and AI.GetUnitPowerPct("player") <= 10 and AI.CastSpell("Evocation") then
        return
    end

    -- cast mirror image IF we're not lusting(slows dps)
    if AI.IsInCombat() and AI.GetTargetStrength() >= 3 and not AI.HasBuff("bloodlust") and AI.CastSpell("mirror image") then
        return
    end

    if not AI.DISABLE_CDS and AI.GetTargetStrength() >= 3 then
        -- if AI.HasBuff("Bloodlust") then
        --     if AI.HasContainerItem(AI.Config.dpsPotion) then
        --         AI.UseContainerItem(AI.Config.dpsPotion)
        --     end
        -- end
        if (AI.HasBuff("flame of the heavens") or AI.HasBuff("Bloodlust")) then
            AI.CastSpell("Icy Veins")
            AI.CastSpell("presence of mind")
            AI.CastSpell("arcane power")
            AI.CastSpell("combustion")
            AI.UseInventorySlot(10)
            AI.UseInventorySlot(13)
            AI.UseInventorySlot(14)
        end

    end

    useHealthStone()

    if AI.IsInDungeonOrRaid() and not AI.IsInCombat() then
        local spec = AI.GetMySpecName() or ""
        if not AI.HasMyBuff("molten armor") and AI.CastSpell("molten armor") then
            return
        end
        -- if spec == "Frost" and not AI.HasMyBuff("mage armor") and AI.CastSpell("mage armor") then return end

        if spec == "Arcane" then
            if AI.IsUnitValidFriendlyTarget(AI.Config.focusMagicTarget, "focus magic") and
                not AI.HasMyBuff("focus magic", AI.Config.focusMagicTarget) and not AI.HasBuff("teleport momentum") then
                AI.CastSpell("focus magic", AI.Config.focusMagicTarget)
            end
        end
    end

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
        if AI.GetDistanceToUnit("target") <= 5 and AI.CastSpell("arcane explosion") then
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

local function doDpsFireMage(isAoE)

    if IsMounted() or UnitUsingVehicle("player") or not AI.CanCast() or UnitIsDeadOrGhost("player") or
        AI.HasBuff("drink") then
        return
    end

    if not AI.IsValidOffensiveUnit("target") then
        return
    end

    if AI.GetTargetStrength() >= 3 and not AI.HasDebuff("living bomb", "target") and
        AI.CastSpell("living bomb", "target") then
        -- if AI.UseInventorySlot(6) or AI.UseContainerItem("saronite bomb") then
        --     CastCursorAOESpell(AI.GetPosition("target"))
        -- end
        return
    end

    if AI.HasBuff("hot streak", "player") and AI.CastSpell("pyroblast") then
        -- if AI.UseInventorySlot(6) or AI.UseContainerItem("saronite bomb") then
        --     CastCursorAOESpell(AI.GetPosition("target"))
        -- end
        return
    end

    if isAoE then
        if (AI.GetDistanceToUnit("target") <= 10 and AI.CastSpell("dragon's breath")) then
            -- if AI.UseInventorySlot(6) or AI.UseContainerItem("saronite bomb") then
            --     CastCursorAOESpell(AI.GetPosition("target"))
            -- end
            return
        end
        if (AI.CastSpell("flamestrike") and CastCursorAOESpell(AI.GetPosition("target"))) then
            return
        end
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

        if spec == "Arcane" then
            AI.DO_DPS = doDpsArcane
            AI.doAutoDps = doAutoDpsArcane
        else
            AI.DO_DPS = doDpsFireMage
            AI.doAutoDps = doAutoDpsFire
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
