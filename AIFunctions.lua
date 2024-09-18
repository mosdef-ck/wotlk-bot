AI = AI or {}

local function getGCDSpell(playerClass)
    if playerClass == "DEATHKNIGHT" then
		return "Death Coil"
	elseif playerClass == "DRUID" then
		return "Healing Touch"
	elseif playerClass == "HUNTER" then
		return "Serpent Sting"
	elseif playerClass == "MAGE" then
		return "Blink"
	elseif playerClass == "PALADIN" then
		return "Seal of Righteousness"
	elseif playerClass == "PRIEST" then
		return "Lesser Heal"
	elseif playerClass == "ROGUE" then
		return "Sinister Strike"
	elseif playerClass == "SHAMAN" then
		return "Healing Wave"
	elseif playerClass == "WARLOCK" then
		return "Demon Skin"
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
	MaloWUtils_Print("|cffffff33"..AI.CHAT_PREFIX .. "|r: " .. tostring(msg))
end

function AI.GetClass(unit)
    local _, class = UnitClass(unit)
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

function AI.IsCasting()
    return UnitCastingInfo("player") ~= nil or UnitChannelInfo("player") ~= nil
end

function AI.IsChanneling()
    return UnitChannelInfo("player") ~= nil
end

function AI.IsOnGCD()
	if GetSpellCooldown(getGCDSpell(AI.GetClass("player"))) ~= 0 then
		return true
	end
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
    return AI.CanCast() and AI.IsUsableSpell(spell, unit) and GetSpellCooldown(spell) == 0
end

function AI.CastSpell(spell, target)
    if AI.CanCastSpell(spell, target) then
        CastSpellByName(spell, target)
        return true
    end
    return false
end


function AI.GetDebuffDuration(spell, unit)
    local name, rank, icon, count, debuffType, duration, expirationTime, unitCaster, isStealable, shouldConsolidate, spellId = UnitAura(unit, spell, nil, "PLAYER|HARMFUL")
    if name == nil then
        return 0
    end
    return expirationTime - GetTime()
end

function AI.GetBuffDuration(spell, unit)
    local name, rank, icon, count, debuffType, duration, expirationTime, unitCaster, isStealable, shouldConsolidate, spellId = UnitAura(unit, spell, nil, "PLAYER|HELPFUL")
    if name == nil then
        return 0
    end
    return expirationTime - GetTime()
end

function AI.GetTargetStrength()
    local members = AI.GetNumPartyOrRaidMembers()
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
    return (UnitHealth(unit) * 100) / UnitHealthMax(unit)
end

function AI.GetUnitPowerPct(unit)
    return (UnitPower(unit) * 100) / UnitPowerMax(unit)
end

-- Returns the name of your spec
function AI.GetMySpecName()
	local name, _, points = GetTalentTabInfo(1)
	for i = 2, 3 do
		local n, _, p = GetTalentTabInfo(i)
		if p > points then
			points = p
			name = n
		end
	end
	return name
end