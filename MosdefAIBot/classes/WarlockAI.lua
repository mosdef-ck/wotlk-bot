local isAIEnabled = false
local primaryTank = nil
local primaryHealer = nil
local manaPctThreshold = 10
local startLifeTapManaThreshold = 50
local endLifeTapManaThreshold = 85

local isLifeTapping = false
local panicPct = 10
local drainSoulHp = 5
local createStoneSpell = nil
local stoneName = nil
local sbImpactTime = 0
local lastSeedTime = 0

local corruptionProcTier = 0

local SoCFn = coroutine.create(function()
    while true do
        if UnitName("focus") == nil or not AI.IsValidOffensiveUnit("focus") or not AI.CanHitTarget("focus") then
            FocusUnit("target")
        end
        if AI.CastSpell("seed of corruption", "focus") then
            TargetNearestEnemy()
            FocusUnit("target")
            coroutine.yield(true)
        end
        coroutine.yield(false)
    end
end)

local function applyWeaponEnchant()
    if AI.IsInCombat() or not AI.IsInDungeonOrRaid() then
        return false
    end

    local hasMainHandEnchant = GetWeaponEnchantInfo()
    if not hasMainHandEnchant then
        if not AI.HasContainerItem(stoneName) and AI.CastSpell(createStoneSpell) then
            return true
        end
        if AI.UseContainerItem(stoneName) then
            PickupInventoryItem(16) -- mainhand slot
            ReplaceEnchant()
            return true
        end
    end
    return false
end

local function manageThreat()
    if AI.IsInCombat() and AI.GetTargetStrength() > 3 and AI.IsValidOffensiveUnit("target") and
        not AI.DISABLE_THREAT_MANAGEMENT then
        local threat = AI.GetThreatPct("target")
        local tank = AI.GetPrimaryTank()
        if threat > 90 and (AI.CastSpell("demonic siphon", tank) or AI.CastSpell("soulshatter")) then
            -- AI.Print("Exceeded 90% of threat on " .. GetUnitName("target"))
            -- if primaryTank then
            --     AI.SayWhisper("Exceeded 90% of threat on " .. GetUnitName("target"), primaryTank)
            -- end
            return true
        end
    end
    return false
end

local function doLifeTap()
    local pct = AI.GetUnitPowerPct("player")
    local healthpct = AI.GetUnitHealthPct("player")
    if AI.USE_MANA_REGEN and healthpct > 30 then
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
            if AI.IsInCombat() then
                if AI.UseInventorySlot(6) or AI.UseContainerItem("saronite bomb") then
                    CastCursorAOESpell(AI.GetPosition("target"))
                end
            end
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

local function manageHealthstone()
    if AI.IsInDungeonOrRaid() and not AI.IsInCombat() and not AI.HasContainerItem("Fel Healthstone") and
        AI.CastSpell("ritual of souls") then
        return true
    end

    useHealthStone()
end

local function getProcTier()
    if AI.HasBuff("bloodlust") or AI.HasBuff("eradication") or AI.HasBuff("hyperspeed acceleration") then
        return 1
    end
    if AI.HasBuff("bloodlust") and (AI.HasBuff("eradication") or AI.HasBuff("hyperspeed acceleration")) then
        return 2
    end
    if AI.HasBuff("bloodlust") and AI.HasBuff("eradication") and AI.HasBuff("hyperspeed acceleration") then
        return 3
    end
    return 0
end

local function shouldDrainSoul()
    local _, _, count = AI.FindContainerItem("soul shard")
    return count == nil or count < 100 and not AI.DISABLE_DRAIN
end

local function doAutoDpsDestro()
    if not AI.AUTO_DPS then
        return
    end

    if not isAIEnabled or IsMounted() or UnitUsingVehicle("player") or not AI.CanCast() or UnitIsDeadOrGhost("player") or
        AI.HasBuff("drink") then
        return
    end

    useHealthStone()

    if not AI.do_PriorityTarget() then
        AssistUnit(primaryTank)
    end

    if not AI.IsValidOffensiveUnit("target") then
        return
    end

    if shouldDrainSoul() and AI.GetTargetStrength() < 3 and AI.GetUnitHealthPct("target") <= 10 and
        AI.CastSpell("drain soul", "target") then
        return
    end

    if AI.AUTO_AOE then
        if not AI.HasMyDebuff("seed of corruption", "target") and AI.CastSpell("seed of corruption", "target") then
            return
        end
    end

    if not AI.DISABLE_WARLOCK_CURSE and AI.GetTargetStrength() >= 3 and not AI.HasMyDebuff(AI.Config.curseToUse, "target") and
        AI.CastSpell(AI.Config.curseToUse, "target") then
        return
    end

    if GetTime() > sbImpactTime and AI.GetTargetStrength() > 3 and AI.GetDebuffDuration("shadow mastery", "target") <= 3 and
        AI.CastSpell("shadow bolt", "target") then
        sbImpactTime = GetTime() + 3 + 2 -- wait 3 sec before we try to cast again, prevents dbl casting of SB since it has a travel time
        return
    end

    if not AI.HasMyBuff("backdraft", "player") and not AI.HasDebuff("immolate", "target") and
        AI.CastSpell("immolate", "target") then
        return
    end
    if AI.HasDebuff("immolate", "target") and not AI.HasMyBuff("backdraft", "player") and
        AI.CastSpell("Conflagrate", "target") then
        return
    end
    if AI.CastSpell("chaos bolt", "target") then
        return
    end
    AI.CastSpell("Incinerate", "target")
end

local function doAutoDpsAffliction()
    if not AI.AUTO_DPS then
        return
    end

    if not isAIEnabled or IsMounted() or UnitUsingVehicle("player") or UnitIsDeadOrGhost("player") or
        AI.HasBuff("drink") then
        return
    end

    useHealthStone()

    if not AI.do_PriorityTarget() then
        AssistUnit(primaryTank)
    end

    if not AI.IsValidOffensiveUnit("target") then
        return
    end

    if UnitChannelInfo("player") == "Drain Soul" and AI.GetMyDebuffDuration("haunt", "target") <= 4 then
        AI.StopCasting()
    end

    if not AI.CanCast() then
        return
    end

    if not AI.DISABLE_WARLOCK_CURSE and AI.GetTargetStrength() >= 3 and not AI.HasMyDebuff(AI.Config.curseToUse, "target") and
        AI.CastSpell(AI.Config.curseToUse, "target") then
        return
    end

    if shouldDrainSoul() and AI.GetTargetStrength() < 3 and AI.GetUnitHealthPct("target") <= 10 and
        AI.CastSpell("drain soul", "target") then
        return
    end

    if AI.AUTO_AOE then
        -- if not AI.HasMyDebuff("seed of corruption", "target") and AI.CastSpell("seed of corruption", "target") then
        --     return
        -- end
        if coroutine.resume(SoCFn) then
            return
        end
    else
        if AI.GetTargetStrength() >= 3 and AI.HasMyDebuff("shadow mastery", "target") and
            AI.GetDebuffCount("shadow embrace", "target") >= 3 and AI.HasMyDebuff("haunt", "target") then

            if not AI.HasMyDebuff("corruption", "target") and AI.CastSpell("corruption", "target") then
                return
            end

            if AI.GetTargetStrength() > 3 then
                local procTier = getProcTier()
                if procTier > 0 and procTier > corruptionProcTier and AI.CastSpell("corruption", "target") then
                    corruptionProcTier = procTier
                    -- AI.SayRaid("corruption under procTier " .. procTier)
                    return
                end
            end
        end

        if AI.GetTargetStrength() >= 3 and AI.GetMyDebuffDuration("haunt", "target") <= 4 and
            AI.CastSpell("haunt", "target") then
            return
        end

        if AI.GetTargetStrength() >= 2 and AI.GetMyDebuffDuration("unstable affliction", "target") <= 3 and
            AI.CastSpell("unstable affliction", "target") then
            return
        end

        if AI.GetTargetStrength() >= 3 and AI.GetUnitHealthPct("target") <= 25 and
            AI.GetDebuffCount("shadow embrace", "target") >= 3 and AI.GetMyDebuffDuration("haunt", "target") > 6 and
            AI.CastSpell("drain soul", "target") then
            return
        end
    end

    AI.CastSpell("shadow bolt", "target")
end

local function doBuffs()
    if not AI.IsInCombat() and AI.IsInDungeonOrRaid() and not AI.HasBuff("fel armor") and AI.CastSpell("fel armor") then
            return true        
    end
    return false
end

local function doUpdate_Warlock()

    if not isAIEnabled or IsMounted() or UnitUsingVehicle("player") or not AI.CanCast() or UnitIsDeadOrGhost("player") or
        AI.HasBuff("drink") then
        return
    end

    if applyWeaponEnchant() then
        return
    end

    if doBuffs() then
        return
    end

    if manageThreat() then
        return
    end

    if not AI.DISABLE_CDS and AI.IsInCombat() and AI.GetTargetStrength() >= 3 and AI.GetUnitHealthPct("target") <= 95 then

        if AI.HasBuff("dying curse") or AI.HasBuff("bloodlust") then
            AI.CastSpell("blood fury")
            AI.UseInventorySlot(10)
            AI.UseInventorySlot(13)
            AI.UseInventorySlot(14)
        end
        if AI.HasBuff("bloodlust") and AI.HasContainerItem(AI.Config.dpsPotion) then
            AI.UseContainerItem(AI.Config.dpsPotion)
        end

    end

    if manageHealthstone() then
        return
    end

    if doLifeTap() then
        return
    end

    if AI.GetTargetStrength() > 3 and not AI.HasMyDebuff("corruption", "target") then
        -- if swp somehow expires, we want to reset the flags to we can re-apply given favorable conditions
        corruptionProcTier = 0
    end

    -- keep pet passive unless we're in combat
    if not AI.IsInCombat() and IsPetAttackActive() then
        PetFollow()
        PetPassiveMode()
    end
end

local function doDpsDestro(isAoE)
    if IsMounted() or UnitUsingVehicle("player") or not AI.CanCast() or UnitIsDeadOrGhost("player") or
        AI.HasBuff("drink") then
        return
    end

    PetAttack()

    if shouldDrainSoul() and AI.GetTargetStrength() < 3 and AI.GetUnitHealthPct("target") <= 10 and
        AI.CastSpell("drain soul", "target") then
        return
    end

    if not AI.DISABLE_WARLOCK_CURSE and AI.GetTargetStrength() >= 3 and not AI.HasMyDebuff(AI.Config.curseToUse, "target") and
        AI.CastSpell(AI.Config.curseToUse, "target") then
        return
    end

    -- if AI.GetTargetStrength() > 3 and not AI.HasDebuff("curse of doom", "target") and
    --     AI.CastSpell("curse of doom", "target") then
    --     return
    -- end

    if isAoE then
        if AI.GetDistanceToUnit("target") <= 7 and AI.CastSpell("shadowflame") then
            if AI.UseInventorySlot(6) or AI.UseContainerItem("saronite bomb") then
                CastCursorAOESpell(AI.GetPosition("target"))
            end
            return
        end

        if AI.CastSpell("seed of corruption", "target") then
            return
        end
        -- if coroutine.resume(SoCFn) then
        --     return
        -- end
    end
    local sbTravelTime = math.floor(AI.GetDistanceToUnit("target") / 20.0);
    if GetTime() > sbImpactTime and AI.GetTargetStrength() >= 3 and AI.GetDebuffDuration("shadow mastery", "target") <= sbTravelTime and
        AI.CastSpell("shadow bolt", "target") then
        sbImpactTime = GetTime() + sbTravelTime + 3; --SB speed is 20
        return
    end

    if not AI.HasMyBuff("backdraft", "player") and not AI.HasDebuff("immolate", "target") and
        AI.CastSpell("immolate", "target") then
        return
    end
    if AI.HasDebuff("immolate", "target") and not AI.HasMyBuff("backdraft", "player") and
        AI.CastSpell("Conflagrate", "target") then
            if AI.UseInventorySlot(6) or AI.UseContainerItem("saronite bomb") then
                CastCursorAOESpell(AI.GetPosition("target"))
            end
        return
    end
    if AI.CastSpell("chaos bolt", "target") then
        return
    end
    AI.CastSpell("Incinerate", "target")
end

local function doDpsAffliction(isAoE)
    if IsMounted() or UnitUsingVehicle("player") or UnitIsDeadOrGhost("player") or AI.HasBuff("drink") or AI.IsMoving() or
        AI.AUTO_DPS then
        return
    end

    PetAttack()

    if AI.GetTargetStrength() >= 2 and UnitChannelInfo("player") == "Drain Soul" and
        AI.GetMyDebuffDuration("haunt", "target") <= 3 then
        AI.StopCasting()
    end

    if not AI.CanCast() then
        return
    end

    if shouldDrainSoul() and AI.GetTargetStrength() < 3 and AI.GetUnitHealthPct("target") <= 10 and
        AI.CastSpell("drain soul", "target") then
        return
    end

    if not AI.DISABLE_WARLOCK_CURSE and AI.GetTargetStrength() >= 3 and not AI.HasMyDebuff(AI.Config.curseToUse, "target") and
        AI.CastSpell(AI.Config.curseToUse, "target") then
        return
    end

    if isAoE then
        if AI.CastSpell("seed of corruption", "target") then
            return
        end
        -- if coroutine.resume(SoCFn) then
        --     return
        -- end
    end

    local hauntImpactTime = math.floor(AI.GetDistanceToUnit("target") / 20.0)

    if AI.GetTargetStrength() >= 2 and AI.HasMyDebuff("shadow mastery", "target") and
        AI.GetDebuffCount("shadow embrace", "target") >= 3 and AI.HasMyDebuff("haunt", "target") then
        if not AI.HasMyDebuff("corruption", "target") and AI.CastSpell("corruption", "target") then
            if AI.UseInventorySlot(6) or AI.UseContainerItem("saronite bomb") then
                CastCursorAOESpell(AI.GetPosition("target"))
            end
            return
        end

        if AI.GetTargetStrength() > 3 then
            local procTier = getProcTier()
            if procTier > 0 and procTier > corruptionProcTier and AI.CastSpell("corruption", "target") then
                corruptionProcTier = procTier
                if AI.UseInventorySlot(6) or AI.UseContainerItem("saronite bomb") then
                    CastCursorAOESpell(AI.GetPosition("target"))
                end
                -- AI.SayRaid("corruption under procTier " .. procTier)
                return
            end
        end
    end

    if AI.GetTargetStrength() >= 2 and AI.GetMyDebuffDuration("haunt", "target") <= hauntImpactTime and
        AI.CastSpell("haunt", "target") then
        return
    end

    if AI.GetTargetStrength() >= 2 and AI.GetMyDebuffDuration("unstable affliction", "target") <= 3 and
        AI.CastSpell("unstable affliction", "target") then
        return
    end

    if AI.GetTargetStrength() >= 3 and AI.GetUnitHealthPct("target") <= 25 and
        AI.GetDebuffCount("shadow embrace", "target") >= 3 and AI.GetMyDebuffDuration("haunt", "target") > 5 and
        AI.CastSpell("drain soul", "target") then
        return
    end

    AI.CastSpell("shadow bolt", "target")
end

function AI.doOnCombatStart_Warlock()
    corruptionProcTier = 0
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

        if spec == "Destruction" then
            AI.DO_DPS = doDpsDestro
            AI.doAutoDps = doAutoDpsDestro
            createStoneSpell = "Create Firestone"
            stoneName = "Grand Firestone"
        else
            AI.DISABLE_CDS = true
            AI.DO_DPS = doDpsAffliction
            AI.doAutoDps = doAutoDpsAffliction
            createStoneSpell = "Create Spellstone"
            stoneName = "Grand Spellstone"
        end

        --
        if AI.Config then
            AI.Print("auto-configuration applied")
            primaryTank = AI.Config.tank
            primaryHealer = AI.Config.healer
            panicPct = AI.Config.panicHpPct
            AI.Config.curseToUse = AI.Config.curseToUse or "curse of the elements"
            AI.Print({
                primaryTank = primaryTank,
                panicPct = panicPct
            })
        end
    else

        AI.Print(spec .. " warlock spec is not supported")
    end
end
