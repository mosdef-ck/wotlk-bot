local isAIEnabled = false
local doAutoDps = false
local primaryTank = nil
local primaryHealer = nil

local panicPct = 20
local primaryManaPot = "runic mana potion"

local procTierForSwp = 0
local lastVampiricTouch = 0

local function upkeepShadowForm()

    if AI.IsInDungeonOrRaid() and not AI.IsInVehicle() then
        if GetShapeshiftForm() ~= 1 and AI.CastSpell("Shadowform") then
            return true
        end

        if not AI.HasBuff("inner fire") and AI.CastSpell("inner fire") then
            return true
        end

        if not AI.IsInCombat() and not AI.HasBuff("vampiric embrace") and AI.CastSpell("vampiric embrace") then
            return true
        end

        if not AI.IsInCombat() and not AI.HasBuff("prayer of shadow protection") and
            AI.CastSpell("prayer of shadow protection", nil) then
            return true
        end
    end
    return false
end

local function doPowerWordShield()
    if AI.IsInCombat() then
        local criticalTarget, missingHp = AI.GetMostDamagedFriendly("power word: shield")
        if criticalTarget and AI.GetDistanceToUnit(criticalTarget) <= 35 and
            AI.IsUnitValidFriendlyTarget(criticalTarget) and AI.GetUnitHealthPct(criticalTarget) <= panicPct and
            not AI.HasDebuff("weakened soul", criticalTarget) then
            if AI.IsCasting() then
                AI.StopCasting()
            end
            if AI.CastSpell("power word: shield", criticalTarget) then
                -- AI.Print("pw:shielded " .. UnitName(criticalTarget))
                -- if primaryTank then
                --     AI.SayWhisper("pw:shielded " .. UnitName(criticalTarget), primaryTank)
                -- end
                return true
            end
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

local function getProcTier()
    if AI.HasBuff("bloodlust") or AI.HasBuff("flame of the heavens") or AI.HasBuff("dying curse") then
        return 1
    end
    if AI.HasBuff("bloodlust") and (AI.HasBuff("flame of the heavens") and AI.HasBuff("dying curse")) then
        return 2
    end
    return 0
end

local function autoPurge()
    if AI.IsInCombat() and AI.HasPurgeableBuff("target") and AI.CastSpell("dispel magic", "target") then
        return true
    end
    return false
end

local function manageThreat()
    if AI.IsInCombat() and AI.GetTargetStrength() > 3 and AI.IsValidOffensiveUnit("target") and
        not AI.DISABLE_THREAT_MANAGEMENT then
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
    if not isAIEnabled or IsMounted() or UnitIsDeadOrGhost("player") or AI.HasBuff("drink") or AI.IsMoving() then
        return
    end

    if not AI.CanCast() then
        return
    end

    if upkeepShadowForm() then
        return
    end

    if doPowerWordShield() then
        return
    end

    if AI.AUTO_CLEANSE and AI.CleanseRaid("Dispel Magic", "Magic") then
        return
    end

    if AI.AUTO_PURGE and autoPurge() then
        return
    end

    if manageThreat() then
        return
    end

    if AI.IsInCombat() and AI.USE_MANA_REGEN then
        if AI.GetTargetStrength() > 3 and AI.GetUnitPowerPct("player") <= 50 and AI.HasContainerItem(primaryManaPot) and
            AI.UseContainerItem(primaryManaPot) then
            return
        end

        local hasBloodLust = AI.HasBuff("bloodlust")

        if (AI.IsHeroicRaidOrDungeon() or AI.GetTargetStrength() > 3) and AI.GetUnitPowerPct("player") <= 5 and
            AI.CastSpell("Hymn of Hope") then
            return
        end
        if (AI.IsHeroicRaidOrDungeon() or AI.GetTargetStrength() >= 2) and
            (AI.GetUnitPowerPct("player") <= 20 or hasBloodLust) and AI.CastSpell("shadowfiend", "target") then
            return
        end
        if (AI.IsHeroicRaidOrDungeon() or AI.GetTargetStrength() > 2) and AI.GetUnitPowerPct("player") <
            (hasBloodLust and 10 or 30) and not AI.DISABLE_PRIEST_DISPERSION and AI.CastSpell("Dispersion") then
            return
        end
    end

    if not AI.DISABLE_CDS and AI.IsInCombat() and (AI.GetTargetStrength() >= 3 or AI.IsHeroicRaidOrDungeon()) then

        if AI.HasBuff("flame of the heavens") or AI.HasBuff("dying curse") or AI.HasBuff("bloodlust") then
            AI.UseInventorySlot(10)
        end
        if AI.HasBuff("bloodlust") then
            AI.CastSpell("berserking")
            AI.UseContainerItem(AI.GetAvailableDpsPotion())
            AI.UseInventorySlot(13)
            AI.UseInventorySlot(14)
        end

    end

    if AI.GetTargetStrength() > 3 and not AI.HasMyDebuff("Shadow Word: Pain", "target") then
        -- if swp somehow expires, we want to reset the flags to we can re-apply given favorable conditions
        procTierForSwp = 0
    end

    useHealthStone()
end

local function doAutoDps()
    if not AI.AUTO_DPS then
        return
    end

    if not isAIEnabled or IsMounted() or not AI.CanCast() or UnitIsDeadOrGhost("player") or AI.HasBuff("drink") or
        AI.IsMoving() then
        return
    end

    if type(AI.do_PriorityTarget) ~= "function" or not AI.do_PriorityTarget() then
        AssistUnit(AI.GetPrimaryTank())
    end

    if not AI.IsValidOffensiveUnit("target") then
        return
    end

    if not AI.DISABLE_PET_AA then
        PetAttack()
    end

    if not AI.AUTO_AOE then
        if AI.GetTargetStrength() >= 1 and GetTime() > lastVampiricTouch + 1.3 and AI.GetUnitCreatureId("target") ~=
            16243 and AI.DoCastSpellChain("target", "vampiric touch") then
            lastVampiricTouch = GetTime()
            return
        end

        if AI.DoCastSpellChain("target", "devouring plague") then
            -- if AI.UseInventorySlot(6) or AI.UseContainerItem("saronite bomb") then
            --     CastCursorAOESpell(AI.GetPosition("target"))
            -- end
            return
        end

        -- if AI.CanCastSpell("shadow word: death", "target", true) then
        --     RunMacro("mindblast-swd")
        -- end

        if AI.Config.useMindBlast and AI.DoCastSpellChain("target", "mind blast") then
            return
        end

        if UnitHealth("target") > 50000 and AI.GetMyBuffCount("shadow weaving") == 5 then
            if AI.DoCastSpellChain("target", "Shadow Word: Pain") then
                return
            end
            if AI.GetTargetStrength() > 3 then
                local procTier = getProcTier()
                if procTier > 0 and procTier > procTierForSwp and AI.CastSpell("Shadow Word: Pain", "target") then
                    procTierForSwp = procTier
                    -- if AI.UseInventorySlot(6) or AI.UseContainerItem("saronite bomb") then
                    --     CastCursorAOESpell(AI.GetPosition("target"))
                    -- end
                    -- AI.SayRaid("SWP under procTier " .. procTier)
                    return
                end
            end
        end

        AI.CastSpell("mind flay", "target")
    else
        if AI.DoCastSpellChain("target", "mind blast", "mind sear") then
            return
        end
    end
end

local function doDps(isAoE)

    if IsMounted() or not AI.CanCast() or UnitIsDeadOrGhost("player") or AI.HasBuff("drink") or AI.IsMoving() or
        AI.AUTO_DPS then
        return
    end

    if not AI.IsValidOffensiveUnit("target") then
        return
    end

    if not AI.DISABLE_PET_AA then
        PetAttack()
    end

    if isAoE then
        if AI.DoCastSpellChain("target", "mind blast", "mind sear") then
            return
        end
    else
        if AI.GetTargetStrength() >= 1 and GetTime() > lastVampiricTouch + 1.3 and AI.GetUnitCreatureId("target") ~=
            16243 and AI.DoCastSpellChain("target", "vampiric touch") then
            lastVampiricTouch = GetTime()
            return
        end

        if AI.DoCastSpellChain("target", "devouring plague") then
            -- if AI.UseInventorySlot(6) or AI.UseContainerItem("saronite bomb") then
            --     CastCursorAOESpell(AI.GetPosition("target"))
            -- end
            return
        end

        -- if AI.CanCastSpell("shadow word: death", "target", true) then
        --     RunMacro("mindblast-swd")
        -- end

        if AI.Config.useMindBlast and AI.DoCastSpellChain("target", "mind blast") then
            return
        end

        if UnitHealth("target") > 50000 and AI.GetMyBuffCount("shadow weaving") == 5 then
            if AI.DoCastSpellChain("target", "Shadow Word: Pain") then
                return
            end
            if AI.GetTargetStrength() > 3 then
                local procTier = getProcTier()
                if procTier > 0 and procTier > procTierForSwp and AI.CastSpell("Shadow Word: Pain", "target") then
                    procTierForSwp = procTier
                    -- if AI.UseInventorySlot(6) or AI.UseContainerItem("saronite bomb") then
                    --     CastCursorAOESpell(AI.GetPosition("target"))
                    -- end
                    -- AI.SayRaid("SWP under procTier " .. procTier)
                    return
                end
            end
        end

        AI.CastSpell("mind flay", "target")
    end
end

function AI.doOnCombatStart_ShadowPriest()
    procTierForSwp = 0
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
            primaryHealer = AI.Config.healer
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
