local isAIEnabled = false
local primaryTank = nil
local primaryManaPot = "runic mana potion"
local panicPct = 20
local manaPotThreshold = 20
local innervateThreshold = 50

local function useHealthStone()
    if AI.IsInCombat() and AI.GetUnitHealthPct() <= panicPct and not AI.HasDebuff('Necrotic Aura') and
        AI.UseContainerItem("Fel Healthstone") then
    end
end

local function doHealTarget(healTar, missingHp)
    if healTar ~= nil then
        if missingHp >= AI.GetSpellEffect("swiftmend") and
            (AI.HasMyBuff("rejuvenation", healTar) or AI.HasMyBuff("regrowth", healTar)) and
            AI.CastSpell("swiftmend", healTar) then
            return true
        end
        if missingHp >= AI.GetSpellEffect("nourish") and
            (AI.HasMyBuff("rejuvenation", healTar) or AI.HasMyBuff("regrowth", healTar)) and not AI.IsMoving() and
            AI.CastSpell("nourish", healTar) then
            return
        end
        -- if missingHp >= AI.GetSpellEffect("lifebloom") and AI.HasMyBuff("Clearcasting") and
        --     AI.GetMyBuffCount("lifebloom", healTar) < 3 and AI.CastSpell("lifebloom", healTar) then
        --     return
        -- end
        if missingHp >= AI.GetSpellEffect("rejuvenation") and not AI.HasMyBuff("rejuvenation", healTar) and
            AI.CastSpell("rejuvenation", healTar) then
            return true
        end
        -- if missingHp >= AI.GetSpellEffect("regrowth") and not AI.HasMyBuff("regrowth", healTar) and not AI.IsMoving() and
        --     AI.CastSpell("regrowth", healTar) then
        --     return true
        -- end
    end
    return false
end

local function doOnUpdate_RestorationDruid()

    if not isAIEnabled or IsMounted() or UnitUsingVehicle("player") or UnitIsDeadOrGhost("player") or
        AI.HasBuff("drink") or not AI.CanCast() then
        return
    end

    useHealthStone()

    if AI.IsInDungeonOrRaid() then
        local nStance = GetShapeshiftForm()
        if nStance ~= 5 then
            CastShapeshiftForm(5)
            return
        end
    end

    -- otherwise heal the raid
    local healTar, missingHp, secondTar, secondTarHp = AI.GetMostDamagedFriendly("regrowth")

    if AI.IsUnitValidFriendlyTarget(primaryTank, "regrowth") then
        local missingHealth = AI.GetMissingHealth(primaryTank)
        local tankHpPct = AI.GetUnitHealthPct(primaryTank)
        -- before we heal the tank, if we have a more crucial target to heal instead, let's heal them before we heal the tank(provided the tank is healthy enough)
        if healTar and healTar:lower() ~= primaryTank:lower() then
            local healTarPct = AI.GetUnitHealthPct(healTar)
            if healTarPct <= panicPct and tankHpPct >= 50 then
                -- if (AI.HasMyBuff("regrowth", healTar) or AI.HasMyBuff("rejuvenation", healTar)) and
                --     (AI.CastSpell("swiftmend", healTar) or AI.CastSpell("nourish", healTar)) then
                --     return
                -- end
                if (not AI.HasMyBuff("regrowth", healTar) and AI.CastSpell("regrowth", healTar)) or
                    (not AI.HasMyBuff("rejuvenation", healTar) and AI.CastSpell("rejuvenation", healTar)) then
                    return
                end
            end
        end

        if tankHpPct <= panicPct and AI.IsInCombat() then
            -- AI.Print(primaryTank .. " is in danger. Using Nature's Swiftness/Tidal Force")
            -- tank is in danger use insta-cast CDS
            AI.CastSpell("Nature's Swiftness")
            if AI.CastSpell("healing touch", primaryTank) or (AI.HasMyBuff("regrowth", primarTank) and AI.CastSpell("swiftmend", primaryTank) ) then
                return
            end
        end

        if missingHealth >= AI.GetSpellEffect("wild growth") and not AI.HasMyBuff("wild growth", primaryTank) and
            AI.CastSpell("wild growth", primaryTank) then
            return
        end

        if missingHealth >= (AI.GetSpellEffect("healing touch") * 1.5 ) and AI.CastSpell("healing touch", primaryTank) then
            return
        end

        if missingHealth >= AI.GetSpellEffect("nourish") and AI.HasMyBuff("regrowth", primaryTank) and
            AI.CastSpell("nourish", primaryTank) then
            return
        end

        if missingHealth >= AI.GetSpellEffect("lifebloom") and ( AI.HasMyBuff("Clearcasting") and
            AI.GetMyBuffCount("lifebloom", primaryTank) < 3 ) and AI.CastSpell("lifebloom", primaryTank) then
            return
        end
        
        -- if AI.IsInCombat() and AI.IsHeroicRaidOrDungeon() and AI.GetTargetStrength() > 3 then
        --     if missingHealth >= AI.GetSpellEffect("lifebloom") and AI.GetMyBuffCount("lifebloom", primaryTank) < 3 and AI.CastSpell("lifebloom", primaryTank) then 
        --         return
        --     end
        --     if AI.GetMyBuffCount("lifebloom", primaryTank) == 3 and AI.GetMyBuffDuration("lifebloom") < 2 and AI.CastSpell("lifebloom", primaryTank) then 
        --         return
        --     end
        -- end

        if missingHealth >= AI.GetSpellEffect("rejuvenation") and not AI.HasMyBuff("rejuvenation", primaryTank) and
            AI.CastSpell("rejuvenation", primaryTank) then
            return
        end

        if missingHealth >= AI.GetSpellEffect("regrowth") and not AI.HasMyBuff("regrowth", primaryTank) and
            AI.CastSpell("regrowth", primaryTank) then
            return
        end
    end

    if AI.IsInCombat() and AI.GetTargetStrength() > 3 and AI.GetUnitHealthPct("target") < 95 then
        AI.UseInventorySlot(13)
        AI.UseInventorySlot(14)
    end

    if doHealTarget(healTar, missingHp) then
        return
    end

    if secondTar ~= nil and secondTarHp >= AI.GetSpellEffect("wild growth") and
        (not AI.HasMyBuff("wild growth", healTar) or not AI.HasMyBuff("wild growth", secondTar)) and
        AI.CastSpell("wild growth", secondTar) then
        return
    end

    -- mana pot and innervate
    if AI.IsInCombat() and AI.GetUnitPowerPct("player") <= innervateThreshold and AI.CastSpell("innervate", "player") then
        return
    end
    if AI.IsInCombat() and AI.GetUnitPowerPct("player") <= manaPotThreshold and AI.HasContainerItem(primaryManaPot) and
        AI.UseContainerItem(primaryManaPot) then
        return
    end

    if AI.AUTO_CLEANSE and
        (AI.CleanseRaid("Cleanse", "Poison", "Disease", "Magic") or AI.CleanseRaid("Remove Curse", "Curse")) then
        return
    end
end

function AI.doOnLoad_Druid()
    local class = AI.GetClass("player")

    if class ~= "DRUID" then
        return
    end
    local spec = AI.GetMySpecName() or ""
    if spec == "Restoration" then
        AI.Print("detected druid spec " .. spec)
        isAIEnabled = true
        if spec == "Restoration" then
            AI.doOnUpdate_Druid = doOnUpdate_RestorationDruid
        end

        --
        if AI.Config then
            primaryTank = AI.Config.tank
            -- primaryManaPot = AI.Config.manaPotion or primaryManaPot
            panicPct = AI.Config.panicHpPct or panicPct
            manaPotThreshold = AI.Config.manaPctThreshold or manaPotThreshold
            AI.Print("auto-configuration applied")
            AI.Print({
                primaryTank = primaryTank,
                manaPot = primaryManaPot,
                panicPct = panicPct,
                manaPctThreshold = manaPotThreshold
            })
        end

    else
        AI.Print(spec .. " shaman spec is not supported")
    end
end
