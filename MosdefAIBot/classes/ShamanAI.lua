local isAIEnabled = false
local primaryTank = nil
local primaryManaPot = "runic mana potion"
local panicPct = 10
local manaPctThreshold = 10
local manaTideTreshold = 50

local function ApplyWeaponEnchants(mainHandSpell, offHandSpell)
    local hasMainHandEnchant, mainHandExpiration, _, hasOffHandEnchant, offHandExpiration = GetWeaponEnchantInfo()
    if not hasMainHandEnchant then
        if AI.CastSpell(mainHandSpell) then
            return true
        end
    end
    if offHandSpell == nil then
        return false
    end
    if not hasOffHandEnchant then
        if AI.CastSpell(offHandSpell) then
            return true
        end
    end
    return false
end

local function doHealTarget(target, missingHp, healSpell)
    if AI.IsUnitValidFriendlyTarget(target) then
        local missingPct = AI.GetUnitHealthPct(target)
        if missingPct <= panicPct and AI.IsInCombat() then
            AI.CastSpell("Nature's Swiftness")
            AI.CastSpell("Tidal Force")
        end
        if missingHp >= AI.GetSpellEffect(healSpell or "chain heal") and AI.CastSpell(healSpell or "chain heal", target) then
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
        -- 	AI.SayWhisper("I am critical, using fel healthstone", primaryTank)
        -- end	
    end
end

local function autoPurge()
    if AI.IsInCombat() and AI.HasPurgeableBuff("target") and AI.CastSpell("purge", "target") then
        return true
    end
    return false
end

local function doOnUpdate_RestorationShaman()

    if not isAIEnabled or IsMounted() or UnitUsingVehicle("player") or UnitIsDeadOrGhost("player") or
        AI.HasBuff("drink") or not AI.CanCast() then
        return
    end

    useHealthStone()

    -- otherwise heal the raid
    local healTar, missingHp, secondTar, secondTarHp = AI.GetMostDamagedFriendly("chain heal")

    if AI.IsUnitValidFriendlyTarget(primaryTank, "chain heal") then
        local missingHealth = AI.GetMissingHealth(primaryTank)
        local tankHpPct = AI.GetUnitHealthPct(primaryTank)
        -- before we heal the tank, if we have a more crucial target to heal instead, let's heal them before we heal the tank(provided the tank is healthy enough)
        if healTar and healTar:lower() ~= primaryTank:lower() then
            local healTarPct = AI.GetUnitHealthPct(healTar)
            if healTarPct <= panicPct and tankHpPct >= 50 and doHealTarget(healTar, missingHp, "chain heal") then
                -- if healTarPct <= panicPct and tankHpPct >= 50 and AI.CastSpell("lesser healing wave", healTar) then
                return
            end
        end

        if tankHpPct <= panicPct and AI.IsInCombat() then
            -- AI.Print(primaryTank .. " is in danger. Using Nature's Swiftness/Tidal Force")
            -- tank is in danger use insta-cast CDS
            AI.CastSpell("Nature's Swiftness")
            AI.CastSpell("Tidal Force")
        end

        if missingHealth >= AI.GetSpellEffect("riptide") and not AI.HasMyBuff("riptide", primaryTank) and
            AI.CastSpell("riptide", primaryTank) then
            return
        end
        if AI.HasBuff("tidal waves", "player") then
            if missingHealth >= AI.GetSpellEffect("healing wave") * 1.5 and AI.CastSpell("healing wave", primaryTank) then
                return
            end
            -- if missingHealth >= AI.GetSpellEffect("lesser healing wave") and
            --     AI.CastSpell("lesser healing wave", primaryTank) then
            --     return
            -- end
        end

        -- keep earth shield on the tank
        if not AI.HasBuff("earth shield", primaryTank) and AI.CastSpell("earth shield", primaryTank) then
            return
        end
    end

    -- activate bloodlust
    if not AI.DISABLE_CDS and AI.IsInCombat() and AI.GetTargetStrength() > 3 and AI.GetUnitHealthPct("target") <= 95 then
        AI.CastSpell("berserking")
        AI.UseInventorySlot(13)
        AI.UseInventorySlot(14)
    end

    -- heal raid
    -- if AI.IsUnitValidFriendlyTarget(secondTar) and secondTarHp >= AI.GetSpellEffect("chain heal") * 0.4 then
    --     if doHealTarget(healTar, missingHp, "chain heal") then
    --         return
    --     end
    -- else
    --     if doHealTarget(healTar, missingHp, "riptide") or doHealTarget(healTar, missingHp, "lesser healing wave") then
    --         return
    --     end
    -- end
    if doHealTarget(healTar, missingHp, "chain heal") then
        return
    end

    if AI.AUTO_PURGE and autoPurge() then
        return
    end

    -- mana pot and mana ride
    if AI.IsInCombat() and AI.GetUnitPowerPct("player") <= manaTideTreshold and AI.CastSpell("mana tide totem") then
        return
    end
    if AI.IsInCombat() and AI.GetUnitPowerPct("player") <= manaPctThreshold and AI.HasContainerItem(primaryManaPot) and
        AI.UseContainerItem(primaryManaPot) then
        return
    end

    if AI.AUTO_CLEANSE and AI.CleanseRaid("Cleanse Spirit", "Curse", "Poison", "Disease") then
        return
    end

    -- maintain water shield
    if not AI.HasBuff("water shield", "player") and AI.CastSpell("water shield") then
        return
    end

    -- keep earthliving weapon up
    if AI.IsInDungeonOrRaid() and ApplyWeaponEnchants("Earthliving weapon") then
        return
    end
end

local function doOnTargetStartCasting_Shaman()
    if AI.CanInterrupt() then
        AI.RegisterPendingAction(function()
            if AI.CanCast() and AI.CastSpell("wind shear") then
                return true
            end
            return false
        end, nil, "DO_INTERRUPT")
    end
end

local function doOnUpdate_ElementalShaman()
    if not isAIEnabled or IsMounted() or UnitUsingVehicle("player") or UnitIsDeadOrGhost("player") or
        AI.HasBuff("drink") or not AI.CanCast() or AI.IsMoving() then
        return
    end

    useHealthStone()

    if AI.AUTO_PURGE and autoPurge() then
        return
    end

    -- maintain water shield
    if not AI.HasBuff("water shield", "player") and AI.CastSpell("water shield") then
        return
    end

    if AI.HasBuff("bloodlust") and AI.HasContainerItem(AI.Config.dpsPotion) then
        AI.UseContainerItem(AI.Config.dpsPotion)
    end

    if not AI.DISABLE_CDS and AI.IsInCombat() and AI.GetTargetStrength() >= 3 and AI.GetUnitHealthPct("target") <= 95 then
        AI.CastSpell("berserking")
        AI.UseInventorySlot(10)
        AI.UseInventorySlot(13)
        AI.UseInventorySlot(14)
    end

    -- keep earthliving weapon up
    if AI.IsInDungeonOrRaid() and ApplyWeaponEnchants("flametongue weapon") then
        return
    end
end

local function doDpsElemental(isAoE)
    if IsMounted() or UnitUsingVehicle("player") or UnitIsDeadOrGhost("player") or AI.HasBuff("drink") or AI.IsMoving() or
        AI.AUTO_DPS then
        return
    end

    PetAttack()

    if not AI.CanCast() then
        return
    end

    if not AI.IsValidOffensiveUnit("target") then
        return
    end

    if AI.GetTargetStrength() >= 2 then
        AI.CastSpell("elemental mastery")
    end

    if isAoE then
        -- if CheckInteractDistance("target", 3) and AI.CastSpell("fire nova") then
        --     return
        -- end
        if AI.CastSpell("chain lightning") then
            return
        end
    end

    if not AI.HasMyDebuff("flame shock", "target") and AI.CastSpell("flame shock", "target") then
        return
    end
    if AI.HasMyDebuff("flame shock", "target") and AI.CastSpell("lava burst", "target") then
        return
    end

    if AI.GetUnitPowerPct("player") < 90 and AI.CastSpell("thunderstorm") then
        return
    end

    AI.CastSpell("lightning bolt", "target")
end

local function doAutoDpsElemental()

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

    if AI.GetTargetStrength() >= 2 then
        AI.CastSpell("elemental mastery")
    end

    if AI.AUTO_AOE and AI.CastSpell("chain lightning") then
        return
    end

    if not AI.HasMyDebuff("flame shock", "target") and AI.CastSpell("flame shock", "target") then
        return
    end
    if AI.HasMyDebuff("flame shock", "target") and AI.CastSpell("lava burst", "target") then
        return
    end

    if AI.GetUnitPowerPct("player") < 80 and AI.CastSpell("thunderstorm") then
        return
    end

    AI.CastSpell("lightning bolt", "target")
end

function AI.doOnLoad_Shaman()
    local class = AI.GetClass("player")

    if class ~= "SHAMAN" then
        return
    end
    local spec = AI.GetMySpecName() or ""
    if spec == "Restoration" or spec == "Elemental" then
        AI.Print("detected shaman spec " .. spec)
        isAIEnabled = true
        -- set the callback to be detected by AIBotBase and automatically invoked
        if spec == "Restoration" then
            AI.doOnUpdate_Shaman = doOnUpdate_RestorationShaman
        elseif spec == "Elemental" then
            AI.doOnUpdate_Shaman = doOnUpdate_ElementalShaman
            AI.DO_DPS = doDpsElemental
            AI.doAutoDps = doAutoDpsElemental
        end
        AI.doOnTargetStartCasting_Shaman = doOnTargetStartCasting_Shaman

        --
        if AI.Config then
            primaryTank = AI.Config.tank
            primaryManaPot = AI.Config.manaPotion or primaryManaPot
            panicPct = AI.Config.panicHpPct or panicPct
            manaPctThreshold = AI.Config.manaPctThreshold or manaPctThreshold
            AI.Print("auto-configuration applied")
            AI.Print({
                primaryTank = primaryTank,
                manaPot = primaryManaPot,
                panicPct = panicPct,
                manaPctThreshold = manaPctThreshold
            })
        end

    else
        AI.Print(spec .. " shaman spec is not supported")
    end
end

function AI.doOnChatCmd_Shaman(arg)
    -- print("onChatCommand "..arg)
    local m, rest = MaloWUtils_StringStartsWith(string.lower(arg), "settank")
    if m then
        if UnitExists(rest) then
            primaryTank = rest
            AI.Print("setting the tank to " .. rest)
            return true
        else
            AI.Print("tried setting the tank to an invalid unit " .. rest)
        end
    end
    return false
end
