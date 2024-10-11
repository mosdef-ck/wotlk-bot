local isAIEnabled = false
local primaryTank = nil
local primaryManaPot = "runic mana potion"
local panicPct = 30
local manaPctThreshold = 10

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

local function doChainHeal(target, missingHp)
	if target and UnitExists(target) and not UnitIsDeadOrGhost(target) then
		local missingPct = AI.GetUnitHealthPct(target)
		if missingPct <= panicPct and AI.IsInCombat() then
			AI.CastSpell("Nature's Swiftness")
			AI.CastSpell("Tidal Force")
		end
		if missingHp > AI.GetSpellEffect("chain heal") and AI.CastSpell("chain heal", target) then return true end
	end
	return false
end

local function useHealthStone()
    if AI.IsInCombat() and AI.GetUnitHealthPct() <= panicPct and not AI.HasDebuff('Necrotic Aura') and AI.UseContainerItem("Fel Healthstone") then
		AI.Print("I am critical, using fel healthstone")
		if primaryTank and UnitName("player") ~= primaryTank then
			AI.SayWhisper("I am critical, using fel healthstone", primaryTank)
		end	
	end
end

local function autoPurge()
	if AI.IsInCombat() and AI.HasPurgeableBuff("target") and AI.CastSpell("purge", "target") then return true end
	return false
end

local function doOnUpdate_Shaman()

	if not isAIEnabled or IsMounted() or UnitUsingVehicle("player") or UnitIsDeadOrGhost("player") or AI.HasBuff("drink") or not AI.CanCast() or AI.IsMoving() then return end    			

    useHealthStone()

	if AI.AUTO_CLEANSE and AI.CleanseRaid("Cleanse Spirit", "Curse", "Poison", "Disease") then return end
	
	--otherwise heal the raid
	local healTar, missingHp = AI.GetMostDamagedFriendly("chain heal")
	
	if UnitExists(primaryTank) and not UnitIsDeadOrGhost(primaryTank) then
		local missingHealth = AI.GetMissingHealth(primaryTank)
		local tankHpPct = AI.GetUnitHealthPct(primaryTank)
		--before we heal the tank, if we have a more crucial target to heal instead, let's heal them before we heal the tank(provided the tank is healthy enough)
		if healTar and healTar:lower() ~= primaryTank:lower() then
			local healTarPct = AI.GetUnitHealthPct(healTar)
			if healTarPct <= panicPct and tankHpPct >= 50 and doChainHeal(healTar, missingHp) then return end
		end
		
		if tankHpPct <= panicPct and AI.IsInCombat() then
			--AI.Print(primaryTank .. " is in danger. Using Nature's Swiftness/Tidal Force")
			--tank is in danger use insta-cast CDS
			AI.CastSpell("Nature's Swiftness")
			AI.CastSpell("Tidal Force")		
		end
		
		-- keep earth shield on the tank
		if not AI.HasBuff("earth shield", primaryTank) and AI.CastSpell("earth shield", primaryTank) then return end
		
		--  disable auto healing if we're not in combat
		--if not AI.IsInCombat() then return end
		
		if missingHealth >= AI.GetSpellEffect("riptide") and not AI.HasBuff("riptide", primaryTank) and AI.CastSpell("riptide", primaryTank) then return end
		if AI.HasBuff("tidal waves", "player") then
			if missingHealth >= AI.GetSpellEffect("healing wave") and AI.CastSpell("healing wave", primaryTank) then return end		
			--if missingHealth >= AI.GetSpellEffect("lesser healing wave") and AI.CastSpell("lesser healing wave", primaryTank) then return end
		end
	end
	
	-- activate bloodlust
	if AI.IsInCombat() and AI.GetTargetStrength() > 3 and AI.GetUnitHealthPct("target") < 95 then
        --if AI.GetUnitHealthPct("target") <= 90 and not AI.HasDebuff("sated") then
       --     AI.CastSpell("bloodlust") 
        --end
		AI.CastSpell("berserking")
		AI.UseInventorySlot(13)
		AI.UseInventorySlot(14)
	end
	
	--heal raid
	if doChainHeal(healTar, missingHp) then return end
    
	if AI.AUTO_PURGE and autoPurge() then
		return
	end
    

    -- mana pot and mana ride
	if AI.IsInCombat() and AI.GetUnitPowerPct("player") <= manaPctThreshold then
		if AI.HasContainerItem(primaryManaPot) and AI.UseContainerItem(primaryManaPot) then return end
		if AI.CastSpell("mana tide totem") then return end
	end

    -- maintain water shield
	if not AI.HasBuff("water shield", "player") and AI.CastSpell("water shield") then return end

    --keep earthliving weapon up
	if ApplyWeaponEnchants("Earthliving weapon") then return end
end

local function doOnTargetStartCasting_Shaman()
	if AI.CanCast() and AI.CanInterrupt() and AI.CastSpell("wind shear") then
		--AI.Print("just interrupted ".. UnitName("target"))
		--if primaryTank then
		--	AI.SayWhisper("just interrupted ".. UnitName("target"), primaryTank)
		--end
	end
end

function AI.doOnLoad_Shaman()
	local class = AI.GetClass("player")
	
	if class ~= "SHAMAN" then
		return
	end
    local spec = AI.GetMySpecName() or "" 
    if spec == "Restoration" then
        AI.Print("detected shaman spec "..spec)
		isAIEnabled = true
		-- set the callback to be detected by AIBotBase and automatically invoked
		AI.doOnUpdate_Shaman = doOnUpdate_Shaman
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
        AI.Print(spec.. " shaman spec is not supported")
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