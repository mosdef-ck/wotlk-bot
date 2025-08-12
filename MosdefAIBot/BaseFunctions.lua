AI = AI or {}

local lastCastTime = 0
local function getGCDSpell(playerClass)
    if playerClass == "DEATHKNIGHT" then
        return "Death Coil"
    elseif playerClass == "DRUID" then
        return "lifebloom"
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

local function getInSpellRangeHarm(class)
    local lClass = class:lower()
    if lClass == "shaman" then
        return "lightning bolt"
    elseif lClass == "priest" then
        return "mind flay"
    elseif lClass == "warlock" then
        return "shadow bolt"
    elseif lClass == "mage" then
        return "arcane blast"
    elseif lClass == "paladin" then
        return "Hand of Reckoning"
    elseif lClass == "druid" then
        return "Wrath"
    end
    return nil
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
        return GetNumRaidMembers()+1
    else
        return GetNumPartyMembers()+1
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

function AI.SendAddonMessage(cmd, ...)
    local argsStr = ""
    local acount = select('#', ...)
    for i = 1, acount, 1 do
        if i < acount then
            argsStr = argsStr .. tostring(select(i, ...)) .. ','
        else
            argsStr = argsStr .. tostring(select(i, ...))
        end
    end
    local command = cmd .. "|" .. argsStr
    -- print(command)
    SendAddonMessage(AI.CHAT_PREFIX, cmd .. "|" .. argsStr, "RAID")
end

function AI.IsCasting(unit)
    return UnitCastingInfo(unit or "player") ~= nil or UnitChannelInfo(unit or "player") ~= nil
end

function AI.IsChanneling(unit)
    return UnitChannelInfo(unit or "player") ~= nil
end

function AI.IsOnGCD()
    -- local minValue = 0.05;
    -- local maxValue = 0.3;
    -- local _, _, lag = GetNetStats()
    -- local curPing = tonumber((lag) / 1000) + .025;

    -- if curPing < minValue then
    --     curPing = minValue;
    -- elseif curPing > maxValue then
    --     curPing = maxValue;
    -- end

    -- return GetSpellCooldown(getGCDSpell(AI.GetClass("player"))) - curPing > 0
    -- return GetTime() - lastCastTime < 0.3
    return false
end

function AI.CanCast()
    return not AI.IsCasting() and not AI.IsOnGCD()
end

function AI.IsInCombat()
    return UnitAffectingCombat("player") ~= nil
end

function AI.IsSpellInRange(spell, unit)
    -- return IsSpellInRange(spell, unit) == 1
    return true
end

function AI.CanHitTarget(unit)
    return IsSpellInRange(getInSpellRangeHarm(AI.GetClass()), unit or "target") == 1
end

function AI.IsValidOffensiveUnit(nunit, requireCombat)
    local unit = nunit or "target"
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
    if unit == nil or not UnitExists(unit) then
        return false
    end
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

function AI.CanCastSpell(spell, unit, ignoreCurrentCasting)
    local name, r, i, manaCost, _, _, castTime = GetSpellInfo(spell)
    if name == nil then
        return false
    end
    return (ignoreCurrentCasting or AI.CanCast()) and AI.IsUsableSpell(spell, unit) and GetSpellCooldown(spell) == 0 and
               UnitPower("player") >= manaCost and (castTime == 0 or not AI.IsMoving())
end

function AI.CastSpell(spell, target)
    if AI.CanCastSpell(spell, target) then
        CastSpellByName(spell, target)
        return true
        -- local spellId = GetPlayerSpellIdByName(spell)
        -- if not spellId then
        --     spellId = GetPlayetPetSpellIdByName(spell)
        -- end
        -- if spellId then
        --     -- print("CastSpellOnTarget :" ..tostring(AI.CanCastSpell(spell, target)))
        --     CastSpellOnTarget(UnitGUID(target or "player"), spellId)
        --     lastCastTime = GetTime()
        --     return true
        -- end
    end
    return false
end

function AI.CastAOESpell(spell, target)
    if AI.CanCastSpell(spell, nil) then
        CastSpellByName(spell, nil)
        if CastCursorAOESpell(AI.GetPosition(target or "player")) then
            lastCastTime = GetTime()
            return true
        end
    end
    return false
end

function AI.GetDebuffDuration(spell, unit)
    local name, rank, icon, count, debuffType, duration, expirationTime, unitCaster, isStealable, shouldConsolidate,
        spellId = UnitAura(unit or "player", spell, nil, "HARMFUL")
    if name == nil then
        local info = AI.GetObjectInfo(unit or "player")
        if info then
            return info:GetAuraDuration(spell)
        end
        return 0
    end
    if expirationTime == 0 then -- infinite buffs
        return 9999
    end
    return expirationTime - GetTime()
end

function AI.GetMyDebuffDuration(spell, unit)
    local name, rank, icon, count, debuffType, duration, expirationTime, unitCaster, isStealable, shouldConsolidate,
        spellId = UnitAura(unit or "player", spell, nil, "PLAYER|HARMFUL")
    if name == nil then
        local info = AI.GetObjectInfo(unit or "player")
        if info then
            return info:GetMyAuraDuration(spell)
        end
        return 0
    end
    if expirationTime == 0 then -- infinite buffs
        return 9999
    end
    return expirationTime - GetTime()
end

function AI.GetDebuffCount(spell, unit)
    local name, rank, icon, count, debuffType, duration, expirationTime, unitCaster, isStealable, shouldConsolidate,
        spellId = UnitAura(unit or "player", spell, nil, "HARMFUL")
    if type(spell) == "string" and name then
        return count or 0
    end
    local info = AI.GetObjectInfo(unit or "player")
    if info then
        return info:GetAuraCount(spell) or 0
    end
    return 0
end

function AI.GetMyDebuffCount(spell, unit)
    local name, rank, icon, count, debuffType, duration, expirationTime, unitCaster, isStealable, shouldConsolidate,
        spellId = UnitAura(unit or "player", spell, nil, "PLAYER|HARMFUL")
    if type(spell) == "string" and name then
        return count or 0
    end
    local info = AI.GetObjectInfo(unit or "player")
    if info then
        return info:GetMyAuraCount(spell) or 0
    end
    return 0
end

function AI.HasDebuff(spell, unit)
    return AI.GetDebuffDuration(spell, unit or "player") > 0
end

function AI.HasMyDebuff(spell, unit)
    return AI.GetMyDebuffDuration(spell, unit or "target") > 0
end

function AI.GetBuffDuration(spell, unit)
    local name, rank, icon, count, debuffType, duration, expirationTime, unitCaster, isStealable, shouldConsolidate,
        spellId = UnitAura(unit or "player", spell, nil, "HELPFUL")
    if name == nil then
        local info = AI.GetObjectInfo(unit or "player")
        if info then
            return info:GetAuraDuration(spell)
        end
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
        local info = AI.GetObjectInfo(unit or "player")
        if info then
            return info:GetMyAuraDuration(spell)
        end
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
    if type(spell) == "string" and name then
        return count or 0
    end
    local info = AI.GetObjectInfo(unit or "player")
    if info then
        return info:GetAuraCount(spell) or 0
    end
    return 0
end

function AI.GetMyBuffCount(spell, unit)
    local name, rank, icon, count, debuffType, duration, expirationTime, unitCaster, isStealable, shouldConsolidate,
        spellId = UnitAura(unit or "player", spell, nil, "PLAYER|HELPFUL")
    if type(spell) == "string" and name then
        return count or 0
    end
    local info = AI.GetObjectInfo(unit or "player")
    if info then
        return info:GetMyAuraCount(spell) or 0
    end
    return 0
end

function AI.HasBuff(spell, unit)
    return AI.GetBuffDuration(spell, unit or "player") > 0
end

function AI.HasMyBuff(spell, unit)
    return AI.GetMyBuffDuration(spell, unit) > 0
end

function AI.HasBuffOrDebuff(spell, unit)
    local nunit = unit or "player"
    return AI.HasBuff(spell, nunit) or AI.HasDebuff(spell, nunit)
end

function AI.GetTargetStrength()
    local members = AI.GetNumPartyOrRaidMembers()
    -- 4 for bosses
    if UnitHealthMax("target") >= 700000 then
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

function AI.GetRaidOrPartyMemberUnits()
    local members = {}
    local memberCount = AI.GetNumPartyOrRaidMembers()
    for i = 1, memberCount do
        local unit = AI.GetUnitFromPartyOrRaidIndex(i)
        table.insert(members, unit)
    end
    return members
end

function AI.GetRaidOrPartyPetMemberUnits()
    local members = {}
    local memberCount = AI.GetNumPartyOrRaidMembers()
    for i = 1, memberCount do
        local unit = AI.GetUnitFromPartyOrRaidIndex(i)
        local unitPet = unit .. "-pet"
        table.insert(members, unitPet)
    end
    return members
end

function AI.GetMostDamagedFriendlyPet()
    local healCandidates = {}
    local members = AI.GetNumPartyOrRaidMembers()
    for i = 1, members do
        local unit = AI.GetUnitFromPartyOrRaidIndex(i)
        local unitPet = unit .. "-pet"
        if UnitExists(unitPet) then
            local missingHealth = AI.GetMissingHealth(unitPet)
            if missingHealth >= 0 then
                table.insert(healCandidates, {
                    unit = unitPet,
                    missingHealth = missingHealth
                })
            end
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
local function UnitHasDebuffOfType(unit, ...)
    for i = 1, 40 do
        local name, _, _, _, type = UnitDebuff(unit, i)
        if name then
            local count = select("#", ...)
            for j = 1, count, 1 do
                if (type or ""):lower() == select(j, ...):lower() then
                    return true
                end
            end
        end
    end
    return false
end

AI.UnitHasDebuffOfType = UnitHasDebuffOfType

function AI.CleanseSelf(spell, ...)
    if UnitHasDebuffOfType("player", ...) then
        return AI.CastSpell(spell, "player")
    end
    return false
end

function AI.CleanseRaid(spell, ...)
    for i = 1, AI.GetNumPartyOrRaidMembers() do
        local unit = AI.GetUnitFromPartyOrRaidIndex(i)
        if UnitHasDebuffOfType(unit, ...) and AI.IsUnitValidFriendlyTarget(unit, spell) then
            return AI.CastSpell(spell, unit)
        end
    end
    return false
end

function AI.CleanseFriendly(spell, unit, ...)
    if AI.IsUnitValidFriendlyTarget(unit) then
        if UnitHasDebuffOfType(unit, ...) then
            return AI.CastSpell(spell, unit)
        end
    end
    return false
end

function AI.FindContainerItem(itemName)
    if not itemName or itemName == "" then
        return nil
    end
    for bag = 0, 4 do
        for slot = 1, GetContainerNumSlots(bag) do
            local item = GetContainerItemLink(bag, slot)
            local _, itemCount = GetContainerItemInfo(bag, slot)
            if item and string.lower(item):find(itemName:lower()) then
                return bag, slot, itemCount
            end
        end
    end
    return nil
end

function AI.HasContainerItem(itemName)
    if not itemName or itemName == "" then
        return false
    end
    local bag, slot = AI.FindContainerItem(itemName)
    return bag ~= nil and slot ~= nil
end

function AI.UseContainerItem(itemName)
    if not itemName then
        return false
    end
    local bag, slot = AI.FindContainerItem(itemName)
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
    if not AI.CanCast() then
        return false
    end
    local s, d, enable = GetInventoryItemCooldown("player", slotNum)
    if enable == 0 then -- not activable, just return true
        return true
    end
    if s == 0 and enable == 1 then
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
    StopMoving()
end

function AI.CanInterrupt(target)
    if UnitIsDeadOrGhost("player") or not AI.IsValidOffensiveUnit(target or "target") then
        return false
    end
    local spell, _, _, _, _, endTime, _, _, notInterruptible = UnitCastingInfo(target or "target")
    if spell == nil then
        spell, _, _, _, _, _, _, notInterruptible = UnitChannelInfo(target or "target")
    end
    if spell == nil then
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

function AI.IsDps()
    local spec = AI.GetMySpecName() or ""
    return spec:lower() ~= "protection" and spec:lower() ~= "restoration" and spec:lower() ~= "holy"
end

function AI.IsPossessing()
    if not HasPetUI() and not HasPetSpells() then
        for i = 1, 12 do
            local slot = 120 + i
            if HasAction(slot) then
                return true
            end
        end
    end
    return false
end

function AI.IsInVehicle(unit)
    return UnitInVehicle(unit or "player")
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

function AI.FindPossessionSpellId(spellName)
    if not AI.IsPossessing() then
        return nil
    end
    for i = 1, 12 do
        local slot = 120 + i
        local _, _, _, spellId = GetActionInfo(slot)
        if spellId ~= nil then
            local name = GetSpellInfo(spellId)
            if name and name:lower() == spellName:lower() then
                return spellId
            end
        end
    end
    return nil
end

function AI.HasPossessionSpellCooldown(spellName)
    local slot = AI.FindPossessionSpellSlot(spellName)
    if slot ~= nil then
        return GetActionCooldown(slot) > 0
    end
    return nil
end

function AI.UsePossessionSpell(spellName, unit)
    local hasCd = AI.HasPossessionSpellCooldown(spellName)
    if hasCd ~= nil and hasCd == false then
        UseAction(AI.FindPossessionSpellSlot(spellName), unit)
        return true
    end
    return false
end

function AI.CastVehicleSpellOnDestination(spellName, dest)
    if not AI.HasPossessionSpellCooldown(spellName) then
        local casterGuid = UnitExists("playerpet") and UnitGUID("playerpet") or UnitGUID("player")
        local spellId = AI.FindPossessionSpellId(spellName)
        if spellId then
            local targetDest;
            if type(dest) == "table" and dest.x and dest.y and dest.z then
                targetDest = dest
            elseif type(dest) == "string" then
                targetDest = AI.PathFinding.Vector3.new(AI.GetPosition(dest))
            else
                targetDest = AI.PathFinding.Vector3.new(AI.GetPosition("target"))
            end
            CastVehicleSpellOnDestination(casterGuid, spellId, targetDest)
            return true
        end
    end
    return false
end

function AI.CastVehicleSpellOnTarget(spellName, target)
    if not AI.IsCasting("playerpet") and not AI.HasPossessionSpellCooldown(spellName) then
        local casterGuid = UnitExists("playerpet") and UnitGUID("playerpet") or UnitGUID("player")
        local spellId = AI.FindPossessionSpellId(spellName)
        if spellId then
            local targetGuid;
            if type(target) == "table" and target.guid then
                targetGuid = target.guid
            else
                targetGuid = UnitGUID(target or "target")
            end
            CastVehicleSpellOnTarget(casterGuid, spellId, targetGuid)
            return true
        end
    end
    return false
end

function AI.GetPosition(unit)
    local nUnit = UnitExists(unit) and unit or "player"
    local x, y, z = GetObjectCoords(nUnit)
    return x, y, z
end

function AI.CalcDistance(x1, y1, x2, y2)
    if not x1 or not y1 or not x2 or not y2 then
        return 0
    end
    local dX, dY = x1 - x2, y1 - y2
    local distance = math.sqrt(dX * dX + dY * dY)
    return distance
end

function AI.DoesLineIntersect(x1, y1, x2, y2, x_c, y_c, radius)
    -- Handle vertical line case
    if x2 - x1 == 0 then
        -- Calculate distance from circle center to line
        local distance = math.abs(x_c - x1)
        return distance <= radius
    end

    -- Calculate slope and intercept of the line
    local slope = (y2 - y1) / (x2 - x1)
    local intercept = y1 - slope * x1

    -- Substitute line equation into circle equation
    local A = 1 + slope * slope
    local B = 2 * slope * (intercept - y_c) - 2 * x_c
    local C = x_c * x_c + (intercept - y_c) * (intercept - y_c) - radius * radius

    -- Calculate discriminant
    local discriminant = B * B - 4 * A * C

    -- Check for intersection
    if discriminant < 0 then
        return false -- No intersection
    elseif discriminant == 0 then
        -- Tangent to circle
        return true
    else
        -- Calculate intersection points (x1, x2)
        x1 = (-B + math.sqrt(discriminant)) / (2 * A)
        x2 = (-B - math.sqrt(discriminant)) / (2 * A)

        -- Check if intersection points are within the line segment
        if (math.min(x1, x2) <= x1 and x1 <= math.max(x1, x2)) or (math.min(x1, x2) <= x2 and x2 <= math.max(x1, x2)) then
            return true
        else
            return false
        end
    end
end

function AI.CalcFacing(x1, y1, x2, y2)
    if not x1 or not y1 or not x2 or not y2 then
        return nil
    end
    local dX, dY = x2 - x1, y2 - y1
    local f = math.atan2(dY, dX)
    local pi2 = math.pi * 2.0
    if f < 0.0 then
        f = f + pi2
    else
        if f > pi2 then
            f = f - pi2
        end
    end
    return f
end

function AI.GetDistanceTo(x, y)
    local mX, mY = AI.GetPosition()
    return AI.CalcDistance(mX, mY, x, y)
end

function AI.GetDistance3DTo(x, y, z)
    local mX, mY, mZ = AI.GetPosition()
    if not x or not y or not z then
        return 0
    end
    local dX, dY, dZ = x - mX, y - mY, z - mZ
    return math.sqrt(dX * dX + dY * dY + dZ * dZ)
end

function AI.GetDistanceToUnit(unit)
    local nUnit = unit or "target"
    local uX, uY
    if type(unit) == "table" and type(unit.x) == "number" and type(unit.y) == "number" then
        uX, uY = unit.x, unit.y
    else
        uX, uY = AI.GetPosition(nUnit)
    end
    local mX, mY = AI.GetPosition()
    return AI.CalcDistance(mX, mY, uX, uY)
end

function AI.GetDistance3DToUnit(unit)
    local nUnit = unit or "target"
    local uX, uY, uZ
    if type(unit) == "table" and type(unit.guid) == "string" then
        uX, uY, uZ = unit.x, unit.y, unit.z
    else
        uX, uY, uZ = AI.GetPosition(nUnit)
    end
    local mX, mY, mZ = AI.GetPosition()
    local dx, dy, dz = uX - mX, uY - mY, uZ - mZ
    return math.sqrt(dx ^ 2 + dy ^ 2 + dz ^ 2)
end

function AI.GetFacingForPosition(x, y)
    local mX, mY = AI.GetPosition()
    if not x or not y or not mX or not mY then
        return 0
    end
    local dX, dY = x - mX, y - mY
    local f = math.atan2(dY, dX)
    f = normalizeAngle(f)
    return f
    -- return AI.GetFacingForPosition2(x,y)
end

function AI.GetFacingForPosition2(x, y)
    local mX, mY = AI.GetPosition()
    if not x or not y or not mX or not mY then
        return 0
    end
    local dX, dY = x - mX, y - mY
    if math.abs(dX) >= 0.00000023841858 then
        if math.abs(dY) >= 0.00000023841858 then
            return math.atan2(dY, dX)
        elseif x <= mX then
            return 0
        else
            return math.pi
        end
    elseif dY >= 0 then
        return math.pi / 2
    else
        return 1.5 * math.pi
    end
    return 0
end

function AI.GetFacingForUnit(unit)
    local nUnit = unit or "target"
    local nX, nY
    if type(unit.guid) == "string" then
        nX, nY = unit.x, unit.y
    else
        nX, nY = AI.GetPosition(nUnit)
    end
    return AI.GetFacingForPosition(nX, nY)
end

function AI.SetFacing(rads)
    if AI.IsInVehicle() then
        SetFacingInVehicle(rads)
    else
        SetFacing(rads)
    end
    SetView(4);
    SetView(4);
end

function AI.SetFacingCoords(x, y)
    if x and y then
        local facing = AI.GetFacingForPosition(x, y)
        AI.SetFacing(facing)
    end
end

function AI.SetFacingUnit(unit)
    if not AI.IsFacingTowards(AI.GetPosition(unit or "target")) then
        AI.SetFacingCoords(AI.GetPosition(unit or "target"))
    end
end

function AI.IsFacingTowards(x, y)
    local desiredFacing = AI.GetFacingForPosition(x, y)
    local facing = GetPlayerFacing()
    return math.abs(desiredFacing - facing) <= 0.1745329
end

function AI.IsPointWithinCone(x, y, x2, y2, theta, coneAngleRads)
    local half_cone_angle_radians = coneAngleRads / 2

    -- Vector from (x2, y2) to (x, y)
    local v_x = x - x2
    local v_y = y - y2

    -- Central axis vector
    local a_x = math.cos(theta)
    local a_y = math.sin(theta)

    -- Dot product
    local dot_product = v_x * a_x + v_y * a_y

    -- Magnitudes
    local magnitude_v = math.sqrt(v_x ^ 2 + v_y ^ 2)
    local magnitude_a = 1 -- Always 1 for a unit vector

    -- Angle calculation
    if magnitude_v == 0 then
        return true
    end

    local cos_angle = dot_product / (magnitude_v * magnitude_a)
    local angle_radians = math.acos(cos_angle)

    -- Check if within half the cone angle
    return math.abs(angle_radians) <= half_cone_angle_radians
end

function AI.IsMoving()
    return GetUnitSpeed("player") ~= 0
end

function AI.GetSpeed(unit)
    return GetUnitSpeed(unit or "player")
end

function AI.GetUnitCreatureId(unit)
    local guid = UnitGUID(unit or "target")
    return (guid and tonumber(guid:sub(9, 12), 16)) or 0
end

function AI.StopCasting()
    -- SpellStopCasting()
    -- CancelChannelingSpell()    
    -- AI.StopMoving()
    StopFollowing()
end

function AI.IsInDungeonOrRaid()
    local _, instanceType = GetInstanceInfo()
    return instanceType == "party" or instanceType == "raid"
end

function AI.GetMapDifficulty()
    local _, instanceType, difficulty, _, _, playerDifficulty, isDynamicInstance = GetInstanceInfo()
    if instanceType == "raid" then -- "new" instance (ICC)
        if difficulty == 1 then -- 10 men
            return playerDifficulty == 0 and "normal10" or playerDifficulty == 1 and "heroic10" or "unknown"
        elseif difficulty == 2 then -- 25 men
            return playerDifficulty == 0 and "normal25" or playerDifficulty == 1 and "heroic25" or "unknown"
        elseif difficulty == 3 or difficulty == 4 then
            return playerDifficulty == 0 and "heroic10" or playerDifficulty == 1 and "heroic25" or "unknown"
        end
    elseif instanceType == "party" then -- support for "old" instances
        local instanceDiff = GetInstanceDifficulty()
        if instanceDiff == 1 then
            return "normal5"
        elseif instanceDiff == 2 then
            return "heroic5"
        end
    end
end

function AI.IsHeroicRaidOrDungeon()
    local diff = AI.GetMapDifficulty()
    return diff ~= nil and (MaloWUtils_StrContains(diff, "heroic") or MaloWUtils_StrContains(diff, "25"))
end

function AI.IsPriest()
    local class = AI.GetClass():lower()
    return class == "priest"
end

function AI.IsShaman()
    local class = AI.GetClass():lower()
    return class == "shaman"
end

function AI.IsMage()
    local class = AI.GetClass():lower()
    return class == "mage"
end

function AI.IsWarlock()
    local class = AI.GetClass():lower()
    return class == "warlock"
end

function AI.IsDruid()
    local class = AI.GetClass():lower()
    return class == "druid"
end

function AI.IsPaladin()
    local class = AI.GetClass():lower()
    return class == "paladin"
end

function AI.GetPrimaryTank()
    if type(AI.Config.tank) == "string" then
        return AI.Config.tank
    elseif type(AI.Config.tank) == "table" then
        for i, unit in ipairs(AI.Config.tank) do
            if UnitExists(unit) and UnitIsPlayer(unit) then
                return unit
            end
        end
    end
    return nil
end

function AI.GetPrimaryHealer()

    if type(AI.Config.healers) == "string" then
        return AI.Config.healers
    elseif type(AI.Config.healers) == "table" then
        for i, unit in ipairs(AI.Config.healers) do
            if UnitExists(unit) and UnitIsPlayer(unit) then
                return unit
            end
        end
    end
    return nil
end

function AI.IsDpsPosition(...)
    local dpsUnits = {}
    for i = 1, select('#', ...), 1 do
        local index = select(i, ...)
        if index == 1 then
            for i, n in ipairs(AI.Config.dps1) do
                table.insert(dpsUnits, n)
            end
        elseif index == 2 then
            for i, n in ipairs(AI.Config.dps2) do
                table.insert(dpsUnits, n)
            end
        elseif index == 3 then
            for i, n in ipairs(AI.Config.dps3) do
                table.insert(dpsUnits, n)
            end
        end
    end
    for i, unit in ipairs(dpsUnits) do
        if UnitName("player"):lower() == unit:lower() then
            return true
        end
    end
    return false
end

local function adornObject(obj)
    local stunnedFlag, pacifiedFlag, confusedFlag, fleeingFlag, possessedFlag, notSelectableFlag = 0x00040000,
        0x00020000, 0x00400000, 0x00800000, 0x01000000, 0x02000000
    if obj ~= nil and type(obj.unitFlags) == "number" then
        obj.isStunned = bit.band(obj.unitFlags, stunnedFlag) ~= 0
        obj.stunned = obj.isStunned
        obj.isPacified = bit.band(obj.unitFlags, pacifiedFlag) ~= 0
        obj.pacified = obj.isPacified
        obj.isConfused = bit.band(obj.unitFlags, confusedFlag) ~= 0
        obj.confused = obj.isConfused
        obj.isFleeing = bit.band(obj.unitFlags, fleeingFlag) ~= 0
        obj.fleeing = obj.isFleeing
        obj.isPossessed = bit.band(obj.unitFlags, possessedFlag) ~= 0
        obj.possessed = obj.isPossessed
        obj.isSelectable = bit.band(obj.unitFlags, notSelectableFlag) == 0
        obj.selectable = obj.isSelectable
    end
    if obj ~= nil and type(obj.health) == "number" then
        obj.isDead = obj.health == 0
        obj.dead = obj.isDead
    end

    if obj.objectType == AI.ObjectType.Unit or obj.objectType == AI.ObjectType.Player then
        obj.HasAura = function(self, spell)
            local auras = self:auras()
            for i, a in ipairs(auras) do
                -- print("aura " .. table2str(a))
                if type(spell) == "number" and a.spellId == spell then
                    return true
                end
                if type(spell) == "string" and strcontains(spell, a.name) then
                    return true
                end
            end
            return false
        end
        obj.GetAuraCount = function(self, spell)
            local auras = self:auras()
            for i, a in ipairs(auras) do
                if type(spell) == "number" and a.spellId == spell then
                    return a.stackCount or 1
                end
                if type(spell) == "string" and strcontains(spell, a.name) then
                    return a.stackCount or 1
                end
            end
            return 0
        end

        obj.GetMyAuraCount = function(self, spell)
            local auras = self:auras()
            local guid = UnitGUID("player")
            for i, a in ipairs(auras) do
                if type(spell) == "number" and a.spellId == spell and a.casterGUID == guid then
                    return a.stackCount or 1
                end
                if type(spell) == "string" and strcontains(spell, a.name) and a.casterGUID == guid then
                    return a.stackCount or 1
                end
            end
            return 0
        end

        obj.GetAuraDuration = function(self, spell)
            local time = GetTime()
            local auras = self:auras()
            for i, a in ipairs(auras) do
                local duration = a.expiration > 0 and a.expiration - time or 9999
                if type(spell) == "number" and a.spellId == spell then
                    return duration
                end
                if type(spell) == "string" and strcontains(spell, a.name) then
                    return duration
                end
            end
            return 0
        end

        obj.GetMyAuraDuration = function(self, spell)
            local time = GetTime()
            local auras = self:auras()
            local guid = UnitGUID("player")
            for i, a in ipairs(auras) do
                local duration = a.expiration > 0 and a.expiration - time or 9999
                if type(spell) == "number" and a.spellId == spell and a.casterGUID == guid then
                    return duration
                end
                if type(spell) == "string" and strcontains(spell, a.name) and a.casterGUID == guid then
                    return duration
                end
            end
            return 0
        end

        obj.IsCasting = function(self)
            return self.castingSpellId > 0 or self.castingSpellId > 0
        end
        obj.IsChanneling = function(self)
            return self.channelingSpellId and self.channelingSpellId > 0
        end
    end
    obj.GetDistanceTo = function(self, x, y)
        return AI.CalcDistance(self.x, self.y, x, y)
    end
    obj.GetDistanceToUnit = function(self, unit)
        local info = AI.GetObjectInfo(unit)
        if info then
            return AI.CalcDistance(self.x, self.y, info.x, info.y)
        end
        return nil
    end

    obj.distance = AI.GetDistanceTo(obj.x, obj.y)

    return obj
end

function AI.GetNearbyObjects(typeFilter, ...)
    local objs = GetNearbyObjects(typeFilter or nil, ...)
    for i, o in ipairs(objs) do
        adornObject(o)
    end
    table.sort(objs, function(a, b)
        return a.distance < b.distance
    end)
    return objs
end

function AI.FindNearbyObjectsOfTypeAndName(typeFilter, ...)
    local objs = AI.GetNearbyObjects(typeFilter, ...)
    return objs
end

function AI.FindNearbyUnitsByName(...)
    local objs = AI.GetNearbyObjects(AI.ObjectTypeFlag.Units, ...)
    return objs
end

function AI.FindNearbyDynamicObjects(...)
    return AI.FindNearbyObjectsOfTypeAndName(AI.ObjectTypeFlag.DynamicObject, ...)
end
function AI.FindNearbyGameObjects(...)
    return AI.FindNearbyObjectsOfTypeAndName(AI.ObjectTypeFlag.Gameobject, ...)
end

function AI.FindUnitsWithinXOf(unit, r)
    local unitName = UnitName(unit or "player") or unit
    if type(unitName) ~= "string" then
        return {}
    end
    local unitInQuestion = AI.FindNearbyUnitsByName(unitName)
    local result = {}
    if #unitInQuestion > 0 then
        local nearbyObjs = AI.GetNearbyObjects(AI.ObjectTypeFlag.Units)
        for i, o in ipairs(nearbyObjs) do
            if o.guid ~= unitInQuestion[1].guid and AI.CalcDistance(o.x, o.y, unitInQuestion[1].x, unitInQuestion[1].y) <=
                r then
                table.insert(result, o)
            end
        end
    end
    return result
end

function AI.FindUnitYWithinXOf(haystack, needle, r)
    local unitInQuestion
    if type(haystack) == "string" then
        local unitName = UnitName(haystack or "player") or haystack
        if type(unitName) ~= "string" then
            return {}
        end
        unitInQuestion = AI.FindNearbyUnitsByName(unitName)
    else
        unitInQuestion = haystack
    end
    local result = {}
    if #unitInQuestion > 0 then
        local nearbyObjs = AI.FindNearbyUnitsByName(needle)
        for i, o in ipairs(nearbyObjs) do
            if o.guid ~= unitInQuestion[1].guid and strcontains(o.name:lower(), needle:lower()) and
                AI.CalcDistance(o.x, o.y, unitInQuestion[1].x, unitInQuestion[1].y) <= r then
                table.insert(result, o)
            end
        end
    end

    return result
end

function AI.GetObjectInfo(unit)
    local info = GetObjectInfo(unit)
    if info ~= nil then
        adornObject(info)
    end
    return info
end

function AI.GetObjectInfoByGUID(guid)
    if type(guid) == "string" then
        local info = GetObjectInfoFromGUID(guid)
        if info then
            adornObject(info)
            return info
        end
    end
    return nil
end

function AI.IsPlayerInControl()
    local playerInfo = AI.GetObjectInfo("player")
    -- If we have on control of our character, return elemental master
    if playerInfo.isStunned or playerInfo.isConfused or playerInfo.isPossessed or playerInfo.isFleeing then
        return false
    end
    return true
end

function AI.IsUnitCC(unit)
    local info
    if type(unit) == "table" and type(unit.guid) == "string" then
        info = unit
    else
        local info = AI.GetObjectInfo(unit or "target")
    end
    if info ~= nil then
        return info.isStunned or info.isPacified or info.isFleeing or info.isConfused
    end
    return false
end

function AI.DoTargetChain(...)
    local count = select('#', ...)
    if count > 0 then
        for i = 1, count, 1 do
            local name = select(i, ...)
            -- print("DoTargetChain " .. name)
            if AI.IsValidOffensiveUnit() and strcontains(UnitName("target"), name) then
                return true
            end
            local targets = AI.FindNearbyUnitsByName(name)
            if #targets > 0 then
                for i, o in ipairs(targets) do
                    if not o.isDead then
                        o:Target()
                        -- print("Targeted " .. o.name)
                        if UnitExists("target") and strcontains(UnitName("target"), name) then
                            return true
                        end
                    end
                end
            end
        end
    end
    return false
end

function AI.DoCastSpellChain(unit, ...)
    local count = select('#', ...)
    if count > 0 then
        for i = 1, count, 1 do
            local spell = select(i, ...)
            if not AI.HasMyDebuff(spell, unit) or AI.GetDebuffDuration(spell, unit) < 2 then
                local success = AI.CastSpell(spell, unit)
                if success then
                    return true
                end
            end
        end
    end
    return false
end

function AI.HasTotemOut(idx)
    local _, active = GetTotemInfo(idx)
    return active ~= "" and active ~= nil
end

function AI.GetInterruptSpell()
    local spec = AI.GetMySpecName() or ""

    local spell = nil
    if AI.IsMage() then
        spell = "counterspell"
    elseif AI.IsPriest() then
        if AI.CanCastSpell("silence", "target", true) or AI.CanCastSpell("silence", "focus", true) then
            spell = "silence"
        else
            spell = "shadow shear"
        end
    elseif AI.IsShaman() then
        spell = "wind shear"
    elseif AI.IsPaladin() then
        spell = "Hammmer of Justice"
    elseif AI.IsWarlock() then
        if AI.CanCastSpell("death coil", "target", true) or AI.CanCastSpell("death coil", "focus", true) then
            spell = "death coil"
        else
            spell = spec == "Destruction" and "shadowfury" or "spell lock"
        end
    end
    return spell
end

function AI.DoInterrupt()
    local interrupt = AI.GetInterruptSpell()
    local target = ternary(AI.IsValidOffensiveUnit("focus"), "focus", "target")
    if interrupt and AI.CanInterrupt(target) then
        if AI.CanCastSpell(interrupt, target, true) then
            -- print("stopping casting to interrupt")
            AI.StopCasting()
        else
            if not AI.UseInventorySlot(6) then
                AI.UseContainerItem("saronite bomb")
            end
        end
        AI.SetFacingUnit(target)
        if strcontains(interrupt, "shadowfury") then
            AI.CastSpell(interrupt, nil)
        end
        if CastCursorAOESpell(AI.GetPosition(target)) or AI.CastSpell(interrupt, target) then
            print("interrupted " .. (UnitName(target) or "unk"))
            return true
        end
    end
    return false
end

function AI.DoStaggeredInterrupt()
    local delay = 0
    if AI.IsShaman() then
        delay = 0.2
    elseif AI.IsMage() then
        delay = 0.3
    elseif AI.IsWarlock() then
        delay = 0.5
    end
    local interrupt = AI.GetInterruptSpell()
    -- print("staggered interrupt "..(interrupt or ""))
    if interrupt then
        AI.RegisterPendingAction(function()
            return AI.DoInterrupt()
        end, delay, "INTERRUPT_TARGET")
    end
end

function AI.GetClosestAlly(filter)
    local allies = AI.GetRaidOrPartyMemberUnits()
    local spots = {}
    local closestAlly = nil
    local distToAlly = 200
    for i, ally in ipairs(allies) do
        if UnitGUID(ally) ~= UnitGUID("player") and (not filter or filter(ally)) then
            local dist = AI.GetDistanceToUnit(ally)
            if dist <= distToAlly then
                distToAlly = dist
                closestAlly = ally
            end
        end
    end
    return closestAlly, distToAlly
end

function AI.GetAlliesAsObstacles(r)
    local allies = AI.GetRaidOrPartyMemberUnits()
    local obstacles = {}
    for i, ally in ipairs(allies) do
        if UnitGUID(ally) ~= UnitGUID("player") then
            local x, y, z = AI.GetPosition(ally)
            table.insert(obstacles, {
                x = x,
                y = y,
                z = z,
                guid = UnitGUID(ally),
                radius = r or 5
            })
        end
    end
    return obstacles
end

function AI.GetAvailableDpsPotion()
    local pots = {AI.Config.dpsPotion, AI.Config.dpsPotion2}
    for i, p in ipairs(pots) do
        if AI.HasContainerItem(p) then
            return p
        end
    end
    return nil
end

function AI.IsTargetABoss()
    return AI.IsValidOffensiveUnit("target") and UnitClassification("target") == "worldboss"
end
