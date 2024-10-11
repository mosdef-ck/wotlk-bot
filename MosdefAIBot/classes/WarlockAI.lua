local isAIEnabled = false
local primaryTank = nil
local manaPctThreshold = 30
local startLifeTapManaThreshold = 50
local endLifeTapManaThreshold = 70

local isLifeTapping = false
local panicPct = 20
local drainSoulHp = 5

local function applyWeaponEnchant()
    if AI.IsInCombat() then
        return false
    end

    local hasMainHandEnchant = GetWeaponEnchantInfo()
    if not hasMainHandEnchant then
        if not AI.HasContainerItem("Grand Spellstone") and AI.CastSpell("Create Spellstone") then
            return true
        end
        if AI.UseContainerItem("Grand Spellstone") then
            PickupInventoryItem(16) -- mainhand slot
            ReplaceEnchant()
            return true
        end
    end
    return false
end

local function manageThreat()
    if AI.IsInCombat() and AI.GetTargetStrength() > 3 and AI.IsValidOffensiveUnit("target") then
        local threat = AI.GetThreatPct("target")
        if AI.GetUnitHealthPct("target") < 95 and threat > 90 and AI.CastSpell("soulshatter") then
            AI.Print("Exceeded 90% of threat on " .. GetUnitName("target"))
            if primaryTank then
                AI.SayWhisper("Exceeded 90% of threat on " .. GetUnitName("target"), primaryTank)
            end
            return true
        end
    end
    return false
end

local function doLifeTap()
    local pct = AI.GetUnitPowerPct("player")
    local healthpct = AI.GetUnitHealthPct("player")
    if healthpct > 30 then
        if AI.IsInCombat() then
            if pct <= startLifeTapManaThreshold then
                isLifeTapping = true
            elseif pct >= endLifeTapManaThreshold then
                isLifeTapping = false
            end
        else
            if pct < 90 then
                isLifeTapping = true
            else
                isLifeTapping = false
            end
        end

        if isLifeTapping and AI.CastSpell("life tap") then
            return true
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
        AI.UseContainerItem("Fel Healthstone")
    end
end

local function manageHealthstone()
    if not AI.IsInCombat() and not AI.HasContainerItem("Fel Healthstone") and AI.CastSpell("ritual of souls") then
        return true
    end

    useHealthStone()
end

local function doAutoDps()
    if not AI.AUTO_DPS then
        return
    end

    if not isAIEnabled or IsMounted() or UnitUsingVehicle("player") or not AI.CanCast() or UnitIsDeadOrGhost("player") or
        AI.HasBuff("drink") or AI.IsMoving() then
        return
    end

    if doLifeTap() then
        return
    end

    if manageThreat() then
        return
    end

    if manageHealthstone() then
        return
    end

    useHealthStone()

    if not AI.do_PriorityTarget() then
        AssistUnit(primaryTank)
    end
    if not AI.IsValidOffensiveUnit("target") then
        return
    end

    if AI.GetUnitHealthPct("target") <= 2 and AI.CastSpell("drain soul", "target") then
        return
    end
    if AI.GetTargetStrength() >= 3 and not AI.HasDebuff("curse of the elements", "target") and
        AI.CastSpell("curse of the elements", "target") then
        return
    end

    if AI.HasBuff("backdraft") then
        if AI.CastSpell("chaos bolt", "target") then
            return
        end
        if not AI.HasDebuff("shadow mastery", "target") and AI.CastSpell("shadow bolt", "target") then
            return
        end
    end
    if not AI.HasDebuff("immolate", "target") and AI.CastSpell("immolate", "target") then
        return
    end
    if AI.HasDebuff("immolate", "target") and AI.CastSpell("Conflagrate", "target") then
        return
    end
    if AI.CastSpell("chaos bolt", "target") then
        return
    end
    AI.CastSpell("Incinerate", "target")
end

local function doBuffs()

    if not AI.IsInCombat() then
        if not AI.HasBuff("fel armor") and AI.CastSpell("fel armor") then
            return true
        end
    end
    return false
end

local function doUpdate_Warlock()

    if not isAIEnabled or IsMounted() or UnitUsingVehicle("player") or not AI.CanCast() or UnitIsDeadOrGhost("player") or
        AI.HasBuff("drink") or AI.IsMoving() then
        return
    end

    if applyWeaponEnchant() then
        return
    end

    if doBuffs() then
        return
    end

    if doLifeTap() then
        return
    end

    if manageThreat() then
        return
    end

    if manageHealthstone() then
        return
    end

    if not AI.DISABLE_CDS and AI.IsInCombat() and AI.GetTargetStrength() >= 3 and AI.GetUnitHealthPct("target") < 95 then
        AI.CastSpell("blood fury")
        AI.UseInventorySlot(10)
        AI.UseInventorySlot(13)
        AI.UseInventorySlot(14)
        if AI.HasBuff("bloodlust") and AI.HasContainerItem(AI.Config.dpsPotion) then
            AI.UseContainerItem(AI.Config.dpsPotion)
        end
    end

    -- keep pet passive unless we're in combat
    if not AI.IsInCombat() then
        PetFollow()
        PetPassiveMode()
    end
end

local function doDpsDestro(isAoE)

    if IsMounted() or UnitUsingVehicle("player") or not AI.CanCast() or UnitIsDeadOrGhost("player") or
        AI.HasBuff("drink") or AI.IsMoving() or AI.AUTO_DPS then
        return
    end

    PetAttack()

    if AI.GetTargetStrength() < 3 and AI.GetUnitHealthPct("target") <= 10 and AI.CastSpell("drain soul", "target") then
        return
    end

    if AI.GetTargetStrength() >= 3 and not AI.HasDebuff("curse of the elements", "target") and
        AI.CastSpell("curse of the elements", "target") then
        return
    end
    -- if AI.GetTargetStrength() >= 3 and not AI.HasDebuff("curse of doom", "target") and
    --     AI.CastSpell("curse of doom", "target") then
    --     return
    -- end

    if isAoE then
        if CheckInteractDistance("target", 3) and AI.CastSpell("shadowflame") then
            return
        end
        if not AI.HasDebuff("seed of corruption", "target") and AI.CastSpell("seed of corruption", "target") then
            return
        end
    else

        if AI.GetTargetStrength() >= 3 and AI.GetDebuffDuration("shadow mastery", "target") <= 3 and
            AI.CastSpell("shadow bolt", "target") then
            return
        end

        if not AI.HasDebuff("immolate", "target") and AI.CastSpell("immolate", "target") then
            return
        end
        if AI.HasDebuff("immolate", "target") and AI.CastSpell("Conflagrate", "target") then
            return
        end
        if AI.CastSpell("chaos bolt", "target") then
            return
        end
        AI.CastSpell("Incinerate", "target")
    end
end

local function doDpsAffliction(isAoE)
    if IsMounted() or UnitUsingVehicle("player") or UnitIsDeadOrGhost("player") or
        AI.HasBuff("drink") or AI.IsMoving() or AI.AUTO_DPS then
        return
    end

    PetAttack()

    -- if UnitChannelInfo("player") == "Drain Soul" and not AI.HasDebuff("haunt", "target") then
    --     AI.StopCasting()
    -- end

    if not AI.CanCast() then return end

    if AI.GetTargetStrength() < 3 and AI.GetUnitHealthPct("target") <= 10 and AI.CastSpell("drain soul", "target") then
        return
    end

    if AI.GetTargetStrength() >= 3 and not AI.HasMyDebuff("curse of the elements", "target") and
        AI.CastSpell("curse of the elements", "target") then
        return
    end

    if isAoE then
        if CheckInteractDistance("target", 3) and AI.CastSpell("shadowflame") then
            return
        end
        if not AI.HasMyDebuff("seed of corruption", "target") and AI.CastSpell("seed of corruption", "target") then
            return
        end
    end

    if AI.GetTargetStrength() >= 3 and AI.GetMyDebuffDuration("haunt", "target") <= 2 and AI.CastSpell("haunt", "target") then
        return
    end

    if AI.GetTargetStrength() >= 2 and AI.GetMyDebuffDuration("unstable affliction", "target") <= 2 and AI.CastSpell("unstable affliction", "target") then
        return
    end

    if ((AI.HasMyDebuff("shadow mastery", "target") and AI.GetDebuffCount("shadow embrace", "target") >= 3 and not AI.HasMyDebuff("corruption", "target")) or
        AI.GetBuffDuration("now is the time!") >= 8) and AI.CastSpell("corruption", "target") then
        return
    end

    if AI.GetTargetStrength() >= 3 and AI.GetUnitHealthPct("target") <= 25 and AI.HasMyDebuff("shadow mastery", "target") and AI.GetDebuffCount("shadow embrace", "target") >= 3 and AI.CastSpell("drain soul", "target") then
        return
    end    

    AI.CastSpell("shadow bolt", "target")

end

function AI.doOnLoad_Warlock()
    local class = AI.GetClass("player")

    if class ~= "WARLOCK" then
        return
    end
    local spec = AI.GetMySpecName() or ""
    if spec == "Destruction" or spec == "Affliction" then
        AI.Print("detected warlock spec " .. spec)
        isAIEnabled = true
        -- set the callback to be detected by AIBotBase and automatically invoked
        AI.doOnUpdate_Warlock = doUpdate_Warlock
        AI.doAutoDps = doAutoDps

        if spec == "Destruction" then
            AI.DO_DPS = doDpsDestro
        else
            AI.DO_DPS = doDpsAffliction
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

        AI.Print(spec .. " warlock spec is not supported")
    end
end
