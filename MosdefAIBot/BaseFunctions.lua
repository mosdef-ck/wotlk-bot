AI = AI or {}

local function getGCDSpell(playerClass)
    if playerClass == "DEATHKNIGHT" then
        return "Death Coil"
    elseif playerClass == "DRUID" then
        return "life bloom"
    elseif playerClass == "HUNTER" then
        return "Serpent Sting"
    elseif playerClass == "MAGE" then
        return "frost armor"
    elseif playerClass == "PALADIN" then
        return "Seal of Righteousness"
    elseif playerClass == "PRIEST" then
        return "lesser heal"
    elseif playerClass == "ROGUE" then
        return "Sinister Strike"
    elseif playerClass == "SHAMAN" then
        return "healing wave"
    elseif playerClass == "WARLOCK" then
        return "demon skin"
    elseif playerClass == "WARRIOR" then
        return "Hamstring"
    else
        AI.Print("Error, playerClass " .. tostring(playerClass) .. " not supported")
    end
end

function AI.Print(msg)
    if type(msg) == "table" then
        msg = MaloWUtils_ConvertTableToString(msg)
    end
    MaloWUtils_Print("|cffffff33" .. AI.CHAT_PREFIX .. "|r: " .. tostring(msg))
end

function AI.GetClass(unit)
    local _, class = UnitClass(unit or "player")
    return class
end

function AI.GetNumPartyOrRaidMembers()
    if UnitInRaid("player") then
        return GetNumRaidMembers()
    else
        return GetNumPartyMembers()
    end
    return 1
end

-- Prints message in raid-chat
function AI.SayRaid(message)
    SendChatMessage(message, "RAID")
end

-- Player speaks the message in /s
function AI.Say(message)
    SendChatMessage(message, "SAY", "Common")
end

function AI.SayWhisper(msg, player)
    SendChatMessage(msg, "WHISPER", nil, player)
end

function AI.SendAddonMessage(cmd, params)
    SendAddonMessage(AI.CHAT_PREFIX, cmd .. "|" .. tostring(params or ""), "RAID")
end

function AI.IsCasting(unit)
    return UnitCastingInfo(unit or "player") ~= nil or UnitChannelInfo(unit or "player") ~= nil
end

function AI.IsChanneling(unit)
    return UnitChannelInfo(unit or "player") ~= nil
end

function AI.IsOnGCD()
    -- return GetSpellCooldown(getGCDSpell(AI.GetClass("player"))) ~= 0
    return false
end

function AI.CanCast()
    return not AI.IsCasting() and not AI.IsOnGCD()
end

function AI.IsInCombat()
    return UnitAffectingCombat("player") ~= nil
end

function AI.IsSpellInRange(spell, unit)
    return IsSpellInRange(spell, unit) == 1
end

function AI.IsValidOffensiveUnit(unit, requireCombat)
    if not UnitExists(unit) then
        return false
    end
    if UnitIsDeadOrGhost(unit) then
        return false
    end
    if UnitCanAttack("player", unit) == nil then
        return false
    end
    if requireCombat then
        if not UnitAffectingCombat(unit) then
            return false
        end
    end
    return true
end

function AI.IsUnitValidFriendlyTarget(unit, spell)
    if UnitIsDeadOrGhost(unit) then
        return false
    end
    if UnitCanAttack("player", unit) == 1 then
        return false
    end
    if spell ~= nil and not AI.IsSpellInRange(spell, unit) then
        return false
    end
    if UnitBuff(unit, "Spirit of Redemption") then
        return false
    end
    return true
end

-- Unit is optional, if provided it will check that the spell can be cast on the unit (that it's a valid target and is in range)
function AI.IsUsableSpell(spell, unit)
    local usable, nomana = IsUsableSpell(spell)
    if usable == nil then
        return false
    end
    if unit == nil then
        return true
    end
    if UnitCanAttack("player", unit) == 1 then
        return AI.IsValidOffensiveUnit(unit) and AI.IsSpellInRange(spell, unit)
    else
        return AI.IsUnitValidFriendlyTarget(unit, spell)
    end
end

function AI.CanCastSpell(spell, unit)
    local name, r, i, manaCost = GetSpellInfo(spell)
    if name == nil then
        return false
    end
    return AI.CanCast() and AI.IsUsableSpell(spell, unit) and GetSpellCooldown(spell) == 0 and UnitPower("player") >=
               manaCost
end

function AI.CastSpell(spell, target)
    if AI.CanCastSpell(spell, target) then
        CastSpellByName(spell, target)
        return true
    end
    return false
end

function AI.GetDebuffDuration(spell, unit)
    local name, rank, icon, count, debuffType, duration, expirationTime, unitCaster, isStealable, shouldConsolidate,
        spellId = UnitAura(unit or "player", spell, nil, "HARMFUL")
    if name == nil then
        return 0
    end
    return expirationTime - GetTime()
end

function AI.GetMyDebuffDuration(spell, unit)
    local name, rank, icon, count, debuffType, duration, expirationTime, unitCaster, isStealable, shouldConsolidate,
        spellId = UnitAura(unit or "player", spell, nil, "PLAYER|HARMFUL")
    if name == nil then
        return 0
    end
    return expirationTime - GetTime()
end

function AI.GetDebuffCount(spell, unit)
    local name, rank, icon, count, debuffType, duration, expirationTime, unitCaster, isStealable, shouldConsolidate,
        spellId = UnitAura(unit or "player", spell, nil, "HARMFUL")
    if name then
        return count or 0
    end
    return 0
end

function AI.GetMyDebuffCount(spell, unit)
    local name, rank, icon, count, debuffType, duration, expirationTime, unitCaster, isStealable, shouldConsolidate,
        spellId = UnitAura(unit or "player", spell, nil, "PLAYER|HARMFUL")
    if name then
        return count or 0
    end
    return 0
end

function AI.HasDebuff(spell, unit)
    return AI.GetDebuffDuration(spell, unit or "player") > 0
end

function AI.HasMyDebuff(spell, unit)
    return AI.GetMyDebuffDuration(spell, unit or "player") > 0
end

function AI.GetBuffDuration(spell, unit)
    local name, rank, icon, count, debuffType, duration, expirationTime, unitCaster, isStealable, shouldConsolidate,
        spellId = UnitAura(unit or "player", spell, nil, "HELPFUL")
    if name == nil then
        return 0
    end
    if expirationTime == 0 then -- infinite buffs
        return 9999
    end
    return expirationTime - GetTime()
end

function AI.GetMyBuffDuration(spell, unit)
    local name, rank, icon, count, debuffType, duration, expirationTime, unitCaster, isStealable, shouldConsolidate,
        spellId = UnitAura(unit or "player", spell, nil, "PLAYER|HELPFUL")
    if name == nil then
        return 0
    end
    if expirationTime == 0 then -- infinite buffs
        return 9999
    end
    return expirationTime - GetTime()
end

function AI.GetBuffCount(spell, unit)
    local name, rank, icon, count, debuffType, duration, expirationTime, unitCaster, isStealable, shouldConsolidate,
        spellId = UnitAura(unit or "player", spell, nil, "HELPFUL")
    if name then
        return count or 0
    end
    return 0
end

function AI.GetMyBuffCount(spell, unit)
    local name, rank, icon, count, debuffType, duration, expirationTime, unitCaster, isStealable, shouldConsolidate,
        spellId = UnitAura(unit or "player", spell, nil, "PLAYER|HELPFUL")
    if name then
        return count or 0
    end
    return 0
end

function AI.HasBuff(spell, unit)
    return AI.GetBuffDuration(spell, unit or "player") > 0
end

function AI.HasMyBuff(spell, unit)
    return AI.GetMyBuffDuration(spell, unit) > 0
end

function AI.GetTargetStrength()
    local members = AI.GetNumPartyOrRaidMembers()
    -- 4 for bosses
    if UnitHealthMax("target") > 400000 then
        return 4
    end

    if UnitHealthMax("target") > UnitHealthMax("player") * members * 2 then
        return 3
    end
    if UnitHealthMax("target") > UnitHealthMax("player") * members then
        return 2
    end
    if UnitHealthMax("target") > UnitHealthMax("player") then
        return 1
    end
    return 0
end

function AI.GetUnitHealthPct(unit)
    return (UnitHealth(unit or "player") * 100) / UnitHealthMax(unit or "player")
end

function AI.GetUnitPowerPct(unit)
    return (UnitPower(unit or "player") * 100) / UnitPowerMax(unit or "player")
end

-- Returns the name of your spec
function AI.GetMySpecName()
    local tabCount = GetNumTalentTabs()
    local name = nil
    local points = 0
    for i = 1, tabCount do
        local n, _, p = GetTalentTabInfo(i)
        if p > points then
            points = p
            name = n
        end
    end
    return name
end

function AI.GetMissingHealth(unit)
    return UnitHealthMax(unit) - UnitHealth(unit)
end

-- Returns the unit that has specified raidIndex
function AI.GetUnitFromPartyOrRaidIndex(index)
    if index ~= 0 then
        if UnitInRaid("player") then
            return "raid" .. index
        else
            return "party" .. index
        end
    end
    return "player"
end

function AI.GetMostDamagedFriendly(spell)
    local healCandidates = {}
    local members = AI.GetNumPartyOrRaidMembers()
    for i = 1, members do
        local unit = AI.GetUnitFromPartyOrRaidIndex(i)
        local missingHealth = AI.GetMissingHealth(unit)
        if missingHealth > 0 and AI.IsUnitValidFriendlyTarget(unit, spell) then
            table.insert(healCandidates, {
                unit = unit,
                missingHealth = missingHealth
            })
        end
    end
    table.sort(healCandidates, function(a, b)
        return a.missingHealth > b.missingHealth
    end)

    local mostHurt, mostHurtMissingHp, secondMostHurt, secondMostHurtHp = nil, nil, nil, nil
    local tsize = table.getn(healCandidates)
    if tsize > 0 then
        mostHurt = healCandidates[1].unit
        mostHurtMissingHp = healCandidates[1].missingHealth
    end
    if tsize > 1 then
        secondMostHurt = healCandidates[2].unit
        secondMostHurtHp = healCandidates[1].missingHealth
    end
    return mostHurt, mostHurtMissingHp, secondMostHurt, secondMostHurtHp
end

--
local function UnitHasDebuffOfType(unit, debuffType1, debuffType2, debuffType3)
    for i = 1, 40 do
        local name, _, _, _, type = UnitDebuff(unit, i)
        if name then
            if debuffType1 ~= nil and debuffType1 == type then
                return true
            end
            if debuffType2 ~= nil and debuffType2 == type then
                return true
            end
            if debuffType3 ~= nil and debuffType3 == type then
                return true
            end
        end
    end
    return false
end

function AI.CleanseRaid(spell, debuffType1, debuffType2, debuffType3)
    for i = 1, AI.GetNumPartyOrRaidMembers() do
        local unit = AI.GetUnitFromPartyOrRaidIndex(i)
        if UnitHasDebuffOfType(unit, debuffType1, debuffType2, debuffType3) and
            AI.IsUnitValidFriendlyTarget(unit, spell) then
            return AI.CastSpell(spell, unit)
        end
    end
    return false
end

local function FindContainerItem(itemName)
    for bag = 0, 4 do
        for slot = 1, GetContainerNumSlots(bag) do
            local item = GetContainerItemLink(bag, slot)
            if item and string.lower(item):find(itemName:lower()) then
                return bag, slot
            end
        end
    end
    return nil
end

function AI.HasContainerItem(itemName)
    local bag, slot = FindContainerItem(itemName)
    return bag ~= nil and slot ~= nil
end

function AI.UseContainerItem(itemName)
    local bag, slot = FindContainerItem(itemName)
    if bag ~= nil then
        local s, d, cd = GetContainerItemCooldown(bag, slot)
        if s and s == 0 then
            UseContainerItem(bag, slot, true)
            return true
        end
    end
    return false
end

function AI.IsDrinking()
    return UnitBuffer("player", "drink") ~= nil
end

function AI.CanDrink(item)
    if UnitAffectingCombat("player") or UnitIsDeadOrGhost("player") then
        return false
    end
    if AI.IsDrinking() then
        return false
    end

    if AI.GetUnitPowerPct("player") > 50 then
        return false
    end

    if FindContainerItem(item) == nil then
        return false
    end

    return true
end

function AI.UseInventorySlot(slotNum)
    local s, d, enable = GetInventoryItemCooldown("player", slotNum)
    if s ~= nil and s == 0 and enable == 1 then
        UseInventoryItem(slotNum)
        return true
    end
    return false
end

function AI.IsParachuting()
    return AI.HasBuff("parachute", "player")
end

function AI.IsInVehicle(unit)
    return UnitUsingVehicle(unit or "player")
end

function AI.StopMoving()
    MoveForwardStart()
    MoveBackwardStart()
    MoveForwardStop()
    MoveBackwardStop()
    StrafeLeftStop()
    StrafeRightStop()
    TurnLeftStop()
    TurnRightStop()
end

function AI.CanInterrupt()
    if not AI.CanCast() or UnitIsDeadOrGhost("player") or not AI.IsValidOffensiveUnit("target") then
        return false
    end
    local spell, _, _, _, _, endTime, _, _, notInterruptible = UnitCastingInfo("target")
    if spell == nil then
        spell, _, _, _, _, _, _, notInterruptible = UnitChannelInfo("target")
    end
    if spell == nil or notInterruptible then
        return false
    end
    return true
end

function AI.GetThreatPct(unit)
    local _, _, threatPercentage = UnitDetailedThreatSituation("player", unit)
    if threatPercentage == nil then
        threatPercentage = 0
    end
    return threatPercentage
end

function AI.HasStealableBuff(unit)
    if not AI.IsValidOffensiveUnit(unit) then
        return false
    end
    for i = 1, 40 do
        local name, _, _, _, debuffType, _, _, _, isStealable, shouldConsolidate, spellId = UnitBuff(unit, i)
        if name and isStealable then
            return true
        end
    end
    return false
end

function AI.HasPurgeableBuff(unit)
    if not AI.IsValidOffensiveUnit(unit) then
        return false
    end
    for i = 1, 40 do
        local name, _, _, _, debuffType, _, _, _, _, shouldConsolidate, spellId = UnitBuff(unit, i)
        if name and debuffType and debuffType:lower() == "magic" then
            return true
        end
    end
    return false
end

function AI.IsTanking(unit, creatureUnit)
    if creatureUnit == nil then
        creatureUnit = unit .. "target"
    end
    local isTanking, tankingStatus = UnitDetailedThreatSituation(unit, creatureUnit)
    return isTanking == 1, tankingStatus
end

function AI.IsHealer()
    local spec = AI.GetMySpecName() or ""
    return spec:lower() == "restoration"
end

function AI.IsTank()
    local spec = AI.GetMySpecName() or ""
    return spec:lower() == "protection"
end

function AI.IsPossessing()
    for i = 1, 12 do
        local slot = 120 + i
        if HasAction(slot) then
            return true
        end
    end
    return false
end

function AI.FindPossessionSpellSlot(spellName)
    if not AI.IsPossessing() then
        return nil
    end
    for i = 1, 12 do
        local slot = 120 + i
        local _, _, _, spellId = GetActionInfo(slot)
        if spellId ~= nil then
            local name = GetSpellInfo(spellId)
            if name and name:lower() == spellName:lower() then
                return slot
            end
        end
    end
    return nil
end

function AI.HasPossessionSpellCooldown(spellName)
    local slot = AI.FindPossessionSpellSlot(spellName)
    if slot ~= nil then
        return GetActionCooldown(slot) == 0
    end
    return nil
end

function AI.UsePossessionSpell(spellName, unit)
    local hasCd = AI.HasPossessionSpellCooldown(spellName)
    if hasCd ~= nil and hasCd == true then
        UseAction(AI.FindPossessionSpellSlot(spellName), unit or "target")
        return true
    end
    return false
end

function AI.GetPosition(unit)
    local x, y = GetPlayerMapPosition(unit or "player")
    if x == 0 and y == 0 then
        SetMapToCurrentZone()
        x, y = GetPlayerMapPosition(unit or "player")
    end
    return x, y
end

function AI.CalcDistance(x1, y1, x2, y2)
    local dX, dY = x1 - x2, y1 - y2
    local distance = math.sqrt(dX * dX + dY * dY)
    return distance
end

function AI.GetDistanceTo(x, y)
    local mX, mY = AI.GetPosition()
    return AI.CalcDistance(mX, mY, x, y)
end

function AI.IsMoving()
    return GetUnitSpeed("player") ~= 0
end

function AI.GetUnitCreatureId(unit)
    local guid = UnitGUID(unit)
    return (guid and tonumber(guid:sub(9, 12), 16)) or 0
end

function AI.StopCasting()
    SpellStopCasting()
    AI.StopMoving()
end
