local isAIEnabled = false
local primaryTank = nil
local primaryManaPot = "runic mana potion"
local panicHpPct = 20
local manaPctThreshold = 30

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

local function doOnUpdate_Shaman()

	if not isAIEnabled or IsMounted() or not AI.CanCast() then return end

	-- maintain water shield
	if not AI.HasBuff("water shield", "player") and AI.CastSpell("water shield") then return end
	
	--keep earthliving weapon up
	if ApplyWeaponEnchants("Earthliving weapon") then return end
	
	if AI.GetUnitPowerPct("player") <= manaPctThreshold then
		if primaryManaPot and AI.CastSpell(primaryManaPot) then return end
		if AI.CastSpell("mana tide totem") then return end
	end
	
	-- keep earth shield on the tank
	if primaryTank then
		local missingHealth = AI.GetMissingHealth(primaryTank)
		local tankHpPct = AI.GetUnitHealthPct(primaryTank)
		if tankHpPct <= panicHpPct then
			AI.Print(primaryTank .. " is in danger. Using Nature's Swiftness/Tidal Force")
			--tank is in danger use insta-cast CDS
			AI.CastSpell("Nature's Swiftness")
			AI.CastSpell("Tidal Force")
		
		end
		if not AI.HasBuff("earth shield", primaryTank) and AI.CastSpell("earth shield", primaryTank) then return end
		if missingHealth >= AI.GetSpellEffect("riptide") and not AI.HasBuff("riptide", primaryTank) and AI.CastSpell("riptide", primaryTank) then return end
		if AI.HasBuff("tidal waves", "player") then
			if missingHealth >= AI.GetSpellEffect("healing wave")and AI.CastSpell("healing wave", primaryTank) then return end
			if missingHealth >= AI.GetSpellEffect("lesser healing wave") and AI.CastSpell("lesser healing wave", primaryTank) then return end
		end
	end
	
	if AI.CleanseRaid("Cleanse Spirit", "Curse", "Poison", "Disease") then return end
	
	--otherwise heal the raid
	local healTar, missingHp = AI.GetMostDamagedFriendly("chain heal")
	if healTar and missingHp > AI.GetSpellEffect("chain heal") and AI.CastSpell("chain heal", healTar) then return end
end

function AI.doOnLoad_Shaman()
	local class = AI.GetClass("player")
	
	if class ~= "SHAMAN" then
		AI.Print(class.. " class is not supported")
		return
	end
    local spec = AI.GetMySpecName() or "" 
    if spec == "Restoration" then
        AI.Print("detected shaman spec "..spec)
		isAIEnabled = true
		-- set the callback to be detected by AIBotBase and automatically invoked
		AI.doOnUpdate_Shaman = doOnUpdate_Shaman

		--
		if HealBot then
			primaryTank = HealBot.tank
			primaryManaPot = HealBot.manaPotion or primaryManaPot
			panicHpPct = HealBot.panicHpPct or panicHpPct
			manaPctThreshold = HealBot.manaPctThreshold or manaPctThreshold
			MB.Print("auto-configuration applied")
			MB.Print({ 
				primaryTank = primaryTank, 
				manaPot = primaryManaPot,
				panicHpPct = panicHpPct,
				manaPctThreshold = manaPctThreshold
			})
		end

    else
        AI.Print(spec.. " is not a supported spec")
	end
end

function AI.doOnChatCmd_Shaman(arg)
	--print("onChatCommand "..arg)
	local m, rest = MaloWUtils_StringStartsWith(string.lower(arg), "settank")
	if m then	
		if UnitExists(rest) then
			primaryTank = rest
			AI.Print("setting the tank to "..rest)
			return true
		else
			AI.Print("tried setting the tank to an invalid unit "..rest)
		end
	end
	return false
end