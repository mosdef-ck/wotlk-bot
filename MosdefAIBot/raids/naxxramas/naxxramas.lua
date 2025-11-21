local oldPriorityTargetFn = nil

-- noth
local noth = MosDefBossModule:new({
    name = "Noth the Plaguebringer",
    creatureId = {15954},
    onStart = function(self)
        AI.FocusUnit("noth the")
        AI.AUTO_TAUNT = false
        oldPriorityTargetFn = AI.do_PriorityTarget
        AI.do_PriorityTarget = function()
            -- return AI.DoTargetChain("plagued conqueror")
        end
        AI.PRE_DO_DPS = function(isAoe)
            -- if AI.IsDps() and AI.IsHeroicRaidOrDungeon() and AI.IsValidOffensiveUnit() and strcontains(UnitName("target", "noth")) then
            --     local threat = AI.GetThreatPct("target")
            --     return threat > 90        
            -- end
            if AI.IsDps() and GetTime() < self.lastBlinkTime + 5 then
                return true
            end
            return false
        end
        if AI.IsPriest() then
            CancelUnitBuff("player", "vampiric embrace")
            AI.CastSpell("power word: shield", AI.GetPrimaryTank())
        end
        if AI.IsTank() then
            AI.ALLOW_AUTO_REFACE = false
        end
    end,
    onStop = function(self)
        AI.AUTO_TAUNT = true
        if oldPriorityTargetFn ~= nil then
            AI.do_PriorityTarget = oldPriorityTargetFn
        end
        AI.ALLOW_AUTO_REFACE = true
        AI.PRE_DO_DPS = nil
    end,
    onUpdate = function(self)
        if AI.IsTank() and AI.IsValidOffensiveUnit("focus") and not AI.IsTanking("player") and
            (AI.DoCastSpellChain("focus", "Hand of Reckoning") or AI.CastSpell("righteous defense", "focustarget")) then
            return true
        end
    end,
    lastBlinkTime = 0
})

function noth:CHAT_MSG_RAID_BOSS_EMOTE(s, t)
    -- print("Noth has blinked")
    if strcontains(s, "blinks") then
        AI.FocusUnit("noth the")
        self.lastBlinkTime = GetTime()
        if AI.IsTank() then
            AI.MustCastSpell("avenger's shield", "focus")
        elseif AI.IsDps() then
            AI.StopCasting()
        end
    end
    if strcontains(s, "teleport") then
        AI.FocusUnit("noth the")
    end
end

AI.RegisterBossModule(noth)

-- anub
local anubRehkan = MosDefBossModule:new({
    name = "Anub'Rekhan",
    creatureId = {15956, 16573},
    onStart = function(self)
        if AI.IsTank() then
            AI.ALLOW_AUTO_REFACE = false
        end
        AI.FocusUnit("anub'rekhan")
        if AI.IsHeroicRaidOrDungeon() then
            AI.Config.judgementToUse = nil
        end
        if not AI.IsTank() then
            AI.RegisterPendingAction(function(self)
                local guards = AI.FindNearbyUnitsByName("crypt guard")
                local canMove = true
                for i, g in ipairs(guards) do
                    if not g.isDead then
                        canMove = false
                        break
                    end
                end
                if canMove then
                    AI.SetMoveTo(self.spotA.x, self.spotA.y)
                    return true
                end
            end, 0)
        end
    end,
    onStop = function(self)
        AI.ALLOW_AUTO_REFACE = true
    end,
    onUpdate = function(self)
        return false
    end,
    spotA = AI.PathFinding.Vector3.new(3295.2529296875, -3476.5881347656, 287.07577514648),
    spotB = AI.PathFinding.Vector3.new(3251.8349609375, -3476.0593261719, 287.07577514648),
    centerP = AI.PathFinding.Vector3.new(3273.3605957031, -3476.64453125, 287.07574462891)
})

function anubRehkan:SPELL_CAST_START(args)
    if strcontains(args.spellName:lower(), "locust swarm") then
        print("locust swarm coming")
        if not AI.IsTank() then
            AI.SetMoveTo(self.centerP.x, self.centerP.y)
            AI.RegisterPendingAction(function(self)
                AI.SetObjectAvoidance({
                    guids = {UnitGUID("focus")},
                    r = 35
                })
            end, 5)
        end
    end
end

function anubRehkan:SPELL_AURA_REMOVED(args)
    if strcontains(args.spellName, "locust swarm") and strcontains(args.target, "anub") and not AI.IsTank() then
        print("Locust Swarm removed")
        AI.ClearObjectAvoidance()
        AI.RegisterOneShotAction(function(self)
            local fx, fy = AI.GetPosition("focus")
            if AI.CalcDistance(fx, fy, self.spotA.x, self.spotA.y) < AI.CalcDistance(fx, fy, self.spotB.x, self.spotB.y) then
                AI.SetMoveTo(self.spotA.x, self.spotA.y)
            else
                AI.SetMoveTo(self.spotB.x, self.spotB.y)
            end
        end, 10)
    end
end
AI.RegisterBossModule(anubRehkan)

-- faerlina
local faerlina = MosDefBossModule:new({
    name = "Grand Window Faerlina",
    creatureId = {15953, 16506, 16505},
    onStart = function(self)
        AI.FocusUnit("grand widow")
        self.startP = AI.PathFinding.Vector3.new(AI.GetPosition())
        AI.do_PriorityTarget = function()
            return AI.DoTargetChain("naxxramas follower")
        end
        if AI.IsTank() then
            AI.ALLOW_AUTO_REFACE = false
        end
    end,
    onStop = function()
        AI.AUTO_CLEANSE = true
        AI.ALLOW_AUTO_REFACE = true
    end,
    onUpdate = function(self)
        if AI.IsHeroicRaidOrDungeon() and not AI.IsTank() then
            if AI.GetDistanceTo(self.startP.x, self.startP.y) > 3 and (not AI.IsHealer() or not AI.IsCasting()) then
                AI.SetMoveTo(self.startP.x, self.startP.y)
            end
        end
        return false
    end,
    startP = nil
})
AI.RegisterBossModule(faerlina)

---- Grobbulus
local grobbulusBossMod = MosDefBossModule:new({
    name = "Grobbulus",
    creatureId = {15931},
    startx = nil,
    starty = nil,
    startz = nil,
    onStart = function(self)
        AI.FocusUnit("grobbulus")
        if AI.IsHealer() then
            AI.AUTO_CLEANSE = false
        end
        AI.Config.judgementToUse = nil
        if AI.IsWarlock() and not AI.HasBuff("demonic circle: summon") then
            AI.MustCastSpell("demonic circle: summon")
        end
        self.startx, self.starty, self.startz = AI.GetPosition()
        -- AI.do_PriorityTarget = function()
        --     if AI.IsPriest() then
        --         TargetUnit("focus")
        --         return true
        --     end
        -- end
    end,
    onStop = function()
        if AI.IsHealer() then
            AI.AUTO_CLEANSE = true
        end
    end,
    onUpdate = function(self)
    end
})

function grobbulusBossMod:SPELL_AURA_APPLIED(args)
    if (args.spellName:lower() == "mutating injection" or args.spellId == 28169) then
        if strcontains(args.target, UnitName("player")) and AI.GetUnitHealthPct("focus") > 7 then
            local dist = AI.GetDistanceToUnit(AI.GetPrimaryTank())
            local distToStart = AI.CalcDistance(self.startx, self.starty, AI.GetPosition())
            -- if we get reinfected while closer to tank than start, move back to tank
            if dist < distToStart and not AI.IsHealer() then
                self:moveToTank()
                return
            end
            AI.RegisterPendingAction(function(self)
                local duration = AI.GetDebuffDuration("mutating injection")
                local speed = 7
                if duration > dist / speed and not AI.IsHealer() then
                    return false
                end
                if not AI.IsHealer() or (AI.GetUnitHealthPct(AI.GetPrimaryTank()) > 70 or duration < 2) then
                    self:moveToTank()
                    return true
                end
            end, 0)
        end
        if AI.IsPriest() and AI.GetPrimaryHealer() == args.target then
            AI.MustCastSpell("power word: shield", args.target)
        end
        if AI.IsHealer() then
            AI.MustCastSpell("riptide", args.target)
        end
    end
end

function grobbulusBossMod:ON_ADDON_MESSAGE(from, cmd, args)
    if cmd == "cleanse-me" and AI.IsTank() then
        print("cleansing " .. from)
        AI.RegisterPendingAction(function(self)
            if not AI.HasDebuff("mutating injection", from) then
                return true
            end
            if AI.GetDistanceToUnit(from) >= 22 or AI.GetUnitHealthPct("player") >= 70 then
                return AI.CastSpell("cleanse", from)
            end
        end)
    end
end

function grobbulusBossMod:SPELL_AURA_REMOVED(args)
    if strcontains(args.spellName, "mutating injection") and strcontains(args.target, UnitName("player")) then
        AI.RegisterPendingAction(function(self)
            if not AI.IsHealer() or AI.GetUnitHealthPct(AI.GetPrimaryTank()) > 50 then
                AI.SetMoveTo(self.startx, self.starty)
                return true
            end
        end, 0)
        if AI.IsWarlock() and AI.CanCastSpell("demonic circle: teleport", nil, true) then
            AI.MustCastSpell("demonic circle: teleport", nil)
        end
    end
end

function grobbulusBossMod:moveToTank()
    local x, y, z = AI.GetPosition(AI.GetPrimaryTank())
    AI.SetMoveTo(x, y, z, 0, function(self)
        AI.SendAddonMessage("cleanse-me")
    end)
end

AI.RegisterBossModule(grobbulusBossMod)

---- maexxna
local maexxna = MosDefBossModule:new({
    name = "Maexxna",
    creatureId = {15952},
    druidIsUp = false,
    priestIsUp = false,
    onStart = function(self)
        AI.DISABLE_DRAIN = true
        self.druidIsUp = false
        self.priestIsUp = false
        AI.FocusUnit("maexxna")
        AI.do_PriorityTarget = function()
            if not AI.IsTank() then
                return AI.DoTargetChain("web wrap", "spiderling")
            end
        end
        AI.Config.judgementToUse = nil

        AI.doPost_Update = function()
            if AI.GetUnitHealthPct(AI.GetPrimaryTank()) <= 50 then
                return
            end
            if not self.druidIsUp then
                local druid = AI.FindNearbyUnitsByName("naturalistic druid")
                if #druid > 0 and not druid[1].isDead then
                    druid[1]:Target()
                    local spell = AI.HasBuff("tidal waves") and "healing wave" or "chain heal"
                    AI.CastSpell(spell, "target")
                    return
                end
            end
            if not self.priestIsUp then
                local spell = AI.HasBuff("tidal waves") and "healing wave" or "chain heal"
                local spellEffect = AI.GetSpellEffect(spell)
                local priest = AI.FindNearbyUnitsByName("faithful priest")
                if #priest > 0 and not priest[1].isDead then
                    local healedAmount = priest[1].health + spellEffect
                    if healedAmount < priest[1].maxHealth or AI.GetUnitHealthPct("focus") <= 30 then
                        priest[1]:Target()
                        AI.CastSpell(spell, "target")
                        return
                    end
                end
            end
        end
    end,
    onStop = function(self)
        self.druidIsUp = false
        self.priestIsUp = false
        AI.DISABLE_DRAIN = false
    end,
    onUpdate = function(self)
        if AI.IsPaladin() and AI.CleanseSelf("cleanse", "Poison", "Disease") then
            return true
        end
        if AI.IsHeroicRaidOrDungeon() then
            -- print("onUpdate heroic druidUp " .. tostring(self.druidIsUp) .. " priestUp " ..tostring(self.priestIsUp))
            if not self.druidIsUp then
                local druid = AI.FindNearbyUnitsByName("naturalistic druid")
                if #druid > 0 and druid[1].health >= druid[1].maxHealth then
                    self.druidIsUp = true
                    print("druid fully healed")
                end
            end
            if not self.priestIsUp then
                local priest = AI.FindNearbyUnitsByName("faithful priest")
                if #priest > 0 and priest[1].health >= priest[1].maxHealth then
                    print("priest fully healed")
                    self.priestIsUp = true
                end
            end
        end
    end
})

function maexxna:SPELL_AURA_REMOVED(args)
    -- if args.spellName:lower() == "web spray" and (AI.IsPriest() or AI.IsShaman()) then
    --     AI.RegisterPendingAction(function()
    --         AI.StopCasting()
    --         if AI.IsPriest() then
    --             return AI.CastSpell("power word: shield", AI.GetPrimaryTank())
    --         elseif AI.IsShaman() and AI.IsDps() then
    --             return AI.CastSpell("lesser healing wave", AI.GetPrimaryTank())
    --         end
    --         return true
    --     end)
    -- end
end

function maexxna:CHAT_MSG_RAID_BOSS_EMOTE(s, t)
    -- print("CHAT_MSG_RAID_BOSS_EMOTE: ", s, t)
    if strcontains(s, "appear") then
        -- print("spiders launched, web wrap in 5")
        if AI.IsPriest() then
            AI.RegisterPendingAction(function()
                AI.StopCasting()
                return AI.CastSpell("power word: shield", AI.GetPrimaryTank())
            end, 8, "PWD_TANK")
        end
    end
end

AI.RegisterBossModule(maexxna)

-- instructor razuvious
local razuvious = MosDefBossModule:new({
    name = "instructor razuvious",
    creatureId = {16061, 16803},
    onStart = function(self)
        AI.AUTO_TAUNT = false
        AI.FocusUnit("instructor razuvious")
        if not AI.IsHeroicRaidOrDungeon() and AI.IsTank() then
            local crystals = AI.FindNearbyUnitsByName(29912, "obedience crystal")
            -- print("crystal count: " .. #crystals)
            AI.RegisterOneShotAction(function()
                AI.SendAddonMessage('select-crystal', 1, crystals[1].guid)
            end, 0.2, "SELECT_CRYSTAL_1")
            AI.RegisterOneShotAction(function()
                AI.SendAddonMessage('select-crystal', 3, crystals[2].guid)
            end, 1, "SELECT_CRYSTAL_2")
        end
        AI.doPost_Update = function()
            local pet, missingHealth = AI.GetMostDamagedFriendlyPet()
            if AI.IsValidOffensiveUnit("focus") and AI.GetUnitPowerPct() > 50 and pet and missingHealth >=
                AI.GetSpellEffect("chain heal") then
                AI.CastSpell("chain heal", pet)
            end
        end
        AI.do_PriorityTarget = function()
            if not AI.IsTank() and AI.IsHeroicRaidOrDungeon() then
                return AI.DoTargetChain("instructor razuvious")
            end
        end
        AI.Config.judgementToUse = nil
    end,
    onStop = function(self)
        AI.AUTO_TAUNT = true
        -- SetCVar("autoInteract", 0)
        AI.doPost_Update = nil
    end,
    onUpdate = function(self)
        if not AI.IsHeroicRaidOrDungeon() then
            if AI.IsPossessing() and AI.IsValidOffensiveUnit("focus") then
                if self.petGUID == nil then
                    self.petGUID = UnitGUID("playerpet")
                end
                if GetFollowTarget() ~= UnitGUID("focus") then
                    SetFollowTarget(UnitGUID("focus"))
                end
                if not IsPlayerAA() then
                    TargetUnit("focus")
                    AI.GetObjectInfo("focus"):InteractWith()
                end
                -- auto-attack if not already
                if AI.IsTanking("playerpet", "focus") and not AI.HasPossessionSpellCooldown("bone barrier") and
                    AI.CastVehicleSpellOnTarget("bone barrier", "playerpet") then
                    return true
                end
                if not AI.HasDebuff("taunt", "focus") and not AI.HasPossessionSpellCooldown("bone barrier") then
                    if AI.GetBuffDuration("bone barrier", "focustarget") <= 0 and
                        AI.CastVehicleSpellOnTarget("taunt", "focus") then
                        return true
                    end
                end

                if AI.CastVehicleSpellOnTarget("blood strike", "focus") then
                    return true
                end
            elseif not AI.IsPossessing() and self.selectedCrystal ~= nil and not AI.HasCTM() and
                AI.IsValidOffensiveUnit("focus") then
                if self.petGUID ~= nil then
                    local pet = AI.GetObjectInfoByGUID(self.petGUID)
                    if not pet or pet.isDead then
                        return
                    end
                end
                local crystal = AI.GetObjectInfoByGUID(self.selectedCrystal)
                if crystal then
                    crystal:InteractWith()
                    -- print("Interacting with crystal: " .. self.selectedCrystal)
                end
            end
        else
            if AI.IsTank() then
                local mobs = AI.FindNearbyUnitsByName(16803)
                for i, o in ipairs(mobs) do
                    if not o.isDead and o.targetGUID ~= UnitGUID("player") then
                        local unit = AI.GetObjectInfoByGUID(o.targetGUID)
                        if unit and not unit.isDead and unit.objectType == 4 then
                            -- print("understudy targetting " .. unit.name)
                            o:Target()
                            if AI.CastSpell("righteous defense", "targettarget") then
                                AI.DoTargetChain("instructor razuvious")
                            end
                            return true
                        end
                    end
                end

                if UnitName("focus") ~= "Death Knight Understudy" or not AI.IsValidOffensiveUnit("focus") then
                    AI.FocusUnit("Death Knight Understudy")
                end
                if AI.IsValidOffensiveUnit("focus") and strcontains(UnitName("focus"), "Death Knight Understudy") and
                    AI.CastSpell("Hand of Reckoning", "focus") then
                    return true
                end

            end
        end
        return false
    end,
    selectedCrystal = nil,
    petGUID = nil
})

function razuvious:ON_ADDON_MESSAGE(from, cmd, params)
    print("ON_ADDON_MESSAGE: ", from, cmd, params)
    if cmd == "select-crystal" then
        local position, crystalGuid = splitstr2(params)
        if AI.IsDpsPosition(tonumber(position)) then
            print('set selected crystal ' .. crystalGuid)
            self.selectedCrystal = crystalGuid
        end
    end
end

AI.RegisterBossModule(razuvious)

-- Gluth
local gluth = MosDefBossModule:new({
    name = "Gluth",
    creatureId = {15932},
    kiteP = AI.PathFinding.Vector3.new(3256.8796386719, -3182.6652832031, 297.80291748047),
    dpsP = AI.PathFinding.Vector3.new(3291.9213867188, -3127.4636230469, 297.55905151367),
    healerP = AI.PathFinding.Vector3.new(3323.5234375, -3099.8308105469, 297.75787353516),
    tankP = AI.PathFinding.Vector3.new(3341.0397949219, -3105.1442871094, 297.77069091797),
    kiterPosition = 0,
    kiter = nil,
    decimateTime = 0,
    kiteDebuff = 200623,
    onStart = function(self)
        AI.FocusUnit("gluth")
        -- print("moving to battle formations")
        if AI.IsTank() then
            AI.SetMoveToPosition(self.tankP.x, self.tankP.y)
            AI.RegisterOneShotAction(function(self)
                AI.MustCastSpell("hand of salvation", AI.GetPrimaryHealer())
            end, 5)
        elseif AI.IsHealer() then
            AI.SetMoveToPosition(self.healerP.x, self.healerP.y)
        elseif AI.IsDps() and not AI.IsDpsPosition(self.kiterPosition) then
            AI.SetMoveToPosition(self.dpsP.x, self.dpsP.y, self.dpsP.z, 0, function(self)
                AI.toggleAutoDps(true)
            end)
        elseif AI.IsDpsPosition(self.kiterPosition) then
            if not AI.IsHeroicRaidOrDungeon() then
                AI.SetMoveToPosition(self.kiteP.x, self.kiteP.y)
            else
                AI.SetMoveToPosition(self.dpsP.x, self.dpsP.y, self.dpsP.z, 0, function(self)
                    AI.toggleAutoDps(true)
                end)
            end
            AI.SendAddonMessage("i-am-kiter")
        end
        if AI.IsPriest() then
            CancelUnitBuff("player", "vampiric embrace")
            AI.CastSpell("power word: shield", AI.GetPrimaryTank())
        end
        AI.do_PriorityTarget = function()
            if AI.IsTank() then
                TargetUnit("focus")
                return true
            elseif not AI.IsDpsPosition(self.kiterPosition) then
                if GetTime() <= self.decimateTime + 10 then
                    AssistUnit(self.kiter)
                    if not AI.IsValidOffensiveUnit() or
                        (UnitGUID("target") ~= UnitGUID("focus") and AI.GetUnitHealthPct("target") > 10) then
                        TargetUnit("focus")
                        return true
                    end
                else
                    AssistUnit(AI.GetPrimaryTank())
                end
            end
            return true
        end

        AI.AUTO_TAUNT = false
        -- if AI.IsTank() then
        --     AI.ALLOW_AUTO_REFACE = false
        -- end

        AI.PRE_DO_DPS = function(isAoe)
            if AI.IsDpsPosition(self.kiterPosition) then
                local spell = "ice lance"
                if not isAoe then
                    AI.CastSpell(spell, "target")
                    return true
                end
            end
            return false
        end
    end,
    onStop = function(self)
    end,
    onUpdate = function(self)
        if AI.IsTank() and AI.HasBuff("enrage", "focus") and AI.CastSpell("Hand of Reckoning", "focus") then
            return true
        end
        if AI.IsDps() and AI.HasDebuff(self.kiteDebuff, "player") and self.kiter ~= UnitName("player") then
            self.kiter = UnitName("player")
            AI.SendAddonMessage("i-am-kiter")
        end

    end
})

function gluth:SMSG_SPELL_CAST_GO2(args)
    if strcontains(args.spellName, "decimate") then
        print("decimated")
        self.decimateTime = GetTime()
    end

    if (args.spellId == self.kiteDebuff or strcontains(args.spellName, "smartest person in naxxramas")) then
        print("Kiter debuff applied to " .. args.target)
        if args.targetGUID == UnitGUID("player") or args.casterGUID == UnitGUID("player") then
            self.kiter = UnitName("player")
            AI.SendAddonMessage("i-am-kiter")
        end
    end
end

function gluth:SPELL_AURA_APPLIED(args)
    if args.spellId == self.kiteDebuff and args.targetGUID == UnitGUID("player") then
        self.kiter = args.caster
        AI.SendAddonMessage("i-am-kiter")
    end
end

function gluth:SPELL_AURA_REMOVED(args)
    if args.spellId == self.kiteDebuff then
        self.kiter = nil
        if args.targetGUID == UnitGUID("player") then
            AI.SetMoveTo(self.dpsP.x, self.dpsP.y, self.dpsP.z, 0, function(self)
                AI.toggleAutoDps(true)
            end)
        end
    end
end

function gluth:ON_ADDON_MESSAGE(from, cmd, params)
    if cmd == "i-am-kiter" then
        print("Kiter is " .. from)
        self.kiter = from
    end
end

AI.RegisterBossModule(gluth)

-- heigan the unclean
local heigan = MosDefBossModule:new({
    name = "Heigan The Unclean",
    creatureId = {15936},
    onStart = function(self)
        if not AI.IsTank() then
            AI.SetMoveTo(self.startP.x, self.startP.y)
        end
        if AI.IsTank() then
            AI.ALLOW_AUTO_REFACE = false
        end
    end,
    onStop = function()
        AI.ALLOW_AUTO_REFACE = true
    end,
    onUpdate = function()
        return false
    end,
    startP = AI.PathFinding.Vector3.new(2804.5974121094, -3707.037109375, 276.65213012695),
    danceStartP = AI.PathFinding.Vector3.new(2795.7810058594, -3680.0031738281, 273.66815185547)
})

function heigan:CHAT_MSG_RAID_BOSS_EMOTE(s, y)
    -- print("CHAT_MSG_RAID_BOSS_EMOTE" .. arg2 .. "says " .. arg1)
    if strcontains(s, "teleports") then
        AI.DISABLE_CDS = true
        if not AI.IsTank() then
            AI.SetMoveTo(self.danceStartP.x, self.danceStartP.y)
        end
    elseif strcontains(s, "rushes to attack") then
        AI.DISABLE_CDS = false
        if not AI.IsTank() then
            AI.SetMoveTo(self.startP.x, self.startP.y)
        end
    end
end

AI.RegisterBossModule(heigan)

-- loatheb
local loatheb = MosDefBossModule:new({
    name = "Loatheb",
    creatureId = {16011},
    onStart = function()
        if AI.IsTank() then
            AI.ALLOW_AUTO_REFACE = false
        end
        -- AI.Config.startHealOverrideThreshold = 90
        oldPriorityTargetFn = AI.do_PriorityTarget
        AI.do_PriorityTarget = function()
            if not AI.IsTank() then
                return AI.DoTargetChain("plagued mushroom-men")
            end
        end
        AI.PRE_DO_DPS = function(isAoe)
            if AI.IsDps() and AI.IsValidOffensiveUnit() and strcontains(UnitName("target"), "spore") then
                if AI.IsPriest() and AI.DoCastSpellChain("target", "mind flay") then
                    return true
                end
                if AI.IsWarlock() and AI.DoCastSpellChain("target", "searing pain") then
                    return true
                end
                if AI.IsMage() and AI.DoCastSpellChain("target", "ice lance") then
                    return true
                end
            end
            return false
        end
        AI.Config.judgementToUse = nil
    end,
    onStop = function()
        AI.ALLOW_AUTO_REFACE = true
    end,
    onUpdate = function()
        if AI.IsTank() then
            if AI.GetUnitHealthPct("player") < 50 then
                AI.UseInventorySlot(13)
                AI.UseInventorySlot(14)
            end
        end
        if AI.IsHealer() then
            local neuroticDuration = AI.GetDebuffDuration("Necrotic Aura")
            if AI.IsShaman() then
                if neuroticDuration > 7 and AI.DoCastSpellChain("target", "lightning bolt") then
                    return true
                end
                local alphaTar, _, betaTar, _ = AI.GetMostDamagedFriendly("chain heal")
                if alphaTar then
                    if neuroticDuration <= 4 and AI.CastSpell("riptide", AI.GetPrimaryTank()) then
                        return true
                    end
                    if neuroticDuration <= 2 and neuroticDuration > 0 and AI.CastSpell("chain heal", alphaTar) then
                        return true
                    end
                    local tankPct = AI.GetUnitHealthPct(AI.GetPrimaryTank())
                    if neuroticDuration == 0 and AI.CastSpell("healing wave", AI.GetPrimaryTank()) then
                        return true
                    end                    
                end
            end
        end

        if AI.IsPriest() and AI.HasDebuff("Necrotic Aura") then
            if not AI.HasDebuff("weakened soul", AI.GetPrimaryTank()) and
                AI.CastSpell("power word: shield", AI.GetPrimaryTank()) then
                return true
            end
        end

        local protectiveMushrooms = AI.FindNearbyUnitsByName("protective mushroom")
        local mushroomMen = AI.FindNearbyUnitsByName("plagued mushroom-men")
        if not AI.IsTank() and #protectiveMushrooms > 0 and protectiveMushrooms[1].distance > 3 and not AI.HasMoveTo() then
            print("moving to mushroom")
            AI.SetMoveTo(protectiveMushrooms[1].x, protectiveMushrooms[1].y)
        end

        return AI.IsHealer() and AI.HasDebuff("Necrotic Aura")
    end
})

function loatheb:SPELL_AURA_REMOVED(args)
    if strcontains(args.spellName, "Necrotic Aura") then
        if AI.IsHealer() and UnitCastingInfo("player") ~= "Healing Wave" then
            AI.StopCasting()
            AI.CastSpell("healing wave", AI.GetPrimaryTank())
        end
    end
end

function loatheb:SMSG_SPELL_CAST_START2(args)
    if strcontains(args.spellName, "acid explosion") then
        print("acid explosion coming")
    end
end

AI.RegisterBossModule(loatheb)

-- four horsemen
local fourHorsemen = MosDefBossModule:new({
    name = "Baron Rivendare",
    creatureId = {16065, 16064, 30549, 16063},
    onStart = function(self)
        AI.DISABLE_THREAT_MANAGEMENT = true
        if AI.IsTank() then
            AI.SetMoveTo(self.tankP.x, self.tankP.y)
        elseif AI.IsHealer() then
            AI.ALLOW_AUTO_REFACE = false
            AI.SetMoveTo(self.healerP.x, self.healerP.y)
        else
            if AI.IsDpsPosition(1) then
                AI.SetMoveTo(self.dps1P.x, self.dps1P.y)
            elseif AI.IsDpsPosition(2) then
                AI.SetMoveTo(self.dps2P.x, self.dps2P.y)
            elseif AI.IsDpsPosition(3) then
                AI.SetMoveTo(self.dps3P.x, self.dps3P.y)
            end
        end
        AI.do_PriorityTarget = function()
            if AI.IsTank() then
                TargetUnit("Baron Rivendare")
                if not AI.IsValidOffensiveUnit("target") or self.baronDead then
                    TargetUnit("Thane")
                end
            elseif AI.IsDps() then
                local distToCaster = AI.GetDistanceTo(self.dpsStartAreaP.x, self.dpsStartAreaP.y)
                local distToTank = AI.GetDistanceTo(self.tankP.x, self.tankP.y)
                if distToCaster < distToTank then
                    TargetUnit("Lady Blaumeux")
                    if not AI.IsValidOffensiveUnit("target") or self.ladyDead then
                        TargetUnit("Sir Zeliek")
                    end
                else
                    TargetUnit("Baron")
                    if not AI.IsValidOffensiveUnit("target") or self.baronDead then
                        TargetUnit("Thane")
                    end
                end
            end
            return AI.IsValidOffensiveUnit("target")
        end

        AI.Config.manaTideThreshold = 30
        AI.Config.useHealingWaveOnToons = true
    end,
    onStop = function(self)
    end,
    onUpdate = function(self)
        if AI.IsTank() and AI.GetUnitHealthPct() <= 40 then
            AI.UseInventorySlot(13)
            AI.UseInventorySlot(14)
            if AI.GetUnitHealthPct() <= 20 then
                if not AI.HasBuff("hand of salvanation") and not AI.HasBuff("divine protection") and
                    (AI.CastSpell("hand of salvation", "player") or AI.CastSpell("divine protection", "player")) then
                    return true
                end
            end
        end
        if AI.IsDps() and AI.GetDebuffDuration(28835) <= 8 and not AI.HasMoveTo() and self.baronDead and
            not self.sirDead then
            local distToCaster = AI.GetDistanceTo(self.dpsStartAreaP.x, self.dpsStartAreaP.y)
            local distToTank = AI.GetDistanceTo(self.tankP.x, self.tankP.y)
            if distToTank < distToCaster then
                AI.SetMoveToPosition(self.dpsStartAreaP.x, self.dpsStartAreaP.y)
            end
        end
        if AI.IsDps() and AI.GetDebuffCount(28835) >= 4 and AI.GetDebuffDuration(28835) <= 15 and not AI.HasMoveTo() then
            if AI.GetDistanceTo(self.healerP.x, self.healerP.y) > 3 then
                print("reached dangerous stacks of mark of zek")
                AI.SetMoveToPosition(self.healerP.x, self.healerP.y)
            end
        end
    end,
    tankP = AI.PathFinding.Vector3.new(2585.7082519531, -2963.5400390625, 241.32925415039),
    healerP = AI.PathFinding.Vector3.new(2578.7680664063, -2976.0261230469, 241.34608459473),
    dps1P = AI.PathFinding.Vector3.new(2556.0395507813, -3017.0544433594, 241.36608886719),
    dps2P = AI.PathFinding.Vector3.new(2554.1862792969, -3004.6896972656, 241.36131286621),
    dps3P = AI.PathFinding.Vector3.new(2543.9018554688, -2995.2373046875, 241.32885742188),
    dpsStartAreaP = AI.PathFinding.Vector3.new(2547.4650878906, -2999.5471191406, 241.33703613281),
    baronDead = false,
    ladyDead = false,
    thaneDead = false,
    sirDead = false,
    battlePolygon = {AI.PathFinding.Vector3.new(2554.4599609375, -3018.6262207031, 241.3699798584),
                     AI.PathFinding.Vector3.new(2566.1865234375, -3014.91796875, 241.40231323242),
                     AI.PathFinding.Vector3.new(2533.2106933594, -2987.8090820313, 241.29895019531),
                     AI.PathFinding.Vector3.new(2526.7797851563, -2994.578125, 241.30102539063)}
})

function fourHorsemen:UNIT_DIED(unit)
    local deadUnitName = unit:lower()
    -- print("Unit DIED ", deadUnitName)
    if strcontains(deadUnitName, "lady") then
        self.ladyDead = true
        if AI.IsDps() then
            -- if not AI.IsShaman() then
            --     AI.SetMoveToPosition(self.healerStartX, self.healerStartY)
            -- else
            --     AI.SetMoveToPosition(self.ms1X, self.ms1Y)
            --     self.nextDpsSpot = 2
            -- end
            AI.SetMoveTo(self.healerP.x, self.healerP.y)
        end
    elseif strcontains(deadUnitName, "baron") then
        self.baronDead = true
        if AI.IsDps() then
            if AI.IsDpsPosition(1) then
                AI.SetMoveTo(self.dps1P.x, self.dps1P.y)
            elseif AI.IsDpsPosition(2) then
                AI.SetMoveTo(self.dps2P.x, self.dps2P.y)
            elseif AI.IsDpsPosition(3) then
                AI.SetMoveTo(self.dps3P.x, self.dps3P.y)
            end
        end
    elseif strcontains(deadUnitName, "sir") then
        self.sirDead = true
        if AI.IsDps() then
            AI.SetMoveTo(self.healerP.x, self.healerP.y)
        end
    end
end

-- function fourHorsemen:SMSG_SPELL_CAST_GO2(args)
--     if (strcontains(args.spellName, "void zone") or args.spellId == 57463) and AI.IsDps() then
--         print("void zone cast " .. table2str(args))
--         AI.RegisterOneShotAction(function(self)
--             local voidZones = AI.FindNearbyUnitsByName(16697, "void zone")
--             local allies = AI.GetAlliesAsObstacles(3)
--             local baronThane = AI.FindNearbyUnitsByName("baron", "thane")
--             for _, zone in ipairs(voidZones) do
--                 zone.radius = 3
--             end
--             for _, b in ipairs(baronThane) do
--                 b.radius = 45
--             end
--             for i, a in ipairs(allies) do
--                 table.insert(voidZones, a)
--             end
--             for i, b in ipairs(baronThane) do
--                 table.insert(voidZones, b)
--             end
--             print("dodging void zone")
--             AI.PathFinding.MoveToSafeLocationWithinPolygon(self.battlePolygon, voidZones, 0.5)
--         end, 0.5)
--     end
-- end

function fourHorsemen:SPELL_DAMAGE(args)
    if strcontains(args.spellName, "consumption") and strcontains(args.target, UnitName("player")) and AI.IsDps() then
        AI.RegisterOneShotAction(function(self)
            local voidZones = AI.FindNearbyUnitsByName(16697, "void zone")
            local allies = AI.GetAlliesAsObstacles(3)
            local baronThane = AI.FindNearbyUnitsByName("baron", "thane")
            for _, zone in ipairs(voidZones) do
                zone.radius = 3
            end
            for _, b in ipairs(baronThane) do
                b.radius = 45
            end
            for i, a in ipairs(allies) do
                table.insert(voidZones, a)
            end
            for i, b in ipairs(baronThane) do
                table.insert(voidZones, b)
            end
            print("dodging void zone")
            AI.PathFinding.MoveToSafeLocationWithinPolygon(self.battlePolygon, voidZones, 1)
        end, 0, "DODGE")
    end
end

-- function fourHorsemen:SPELL_AURA_REMOVED(args)
--     if args.target:lower() ~= UnitName("player"):lower() then
--         return
--     end
--     -- print("i'm no longer afflicted with " .. args.spellName)
--     if args.spellId == 28835 and not self.sirDead and not AI.HasMoveToPosition() then
--         if not AI.IsHealer() and not AI.IsTank() then
--             -- AI.SayRaid("recovered from marks of Zeliek, moving back to dps him")
--             AI.SetMoveToPosition(self.dpsSharedSpotX, self.dpsSharedSpotY)
--         end
--     end
-- end

function fourHorsemen:SPELL_AURA_APPLIED_DOSE(args)
    local amount = args.arg2
    if args.target:lower() ~= UnitName("player"):lower() then
        return
    end
    if args.spellId == 28832 or args.spellId == 28833 or args.spellId == 28834 or args.spellId == 28835 then
        -- print("i'm afflicted with " .. amount .. " doses of " .. args.spellName)
    end
    if args.spellId == 28835 and amount >= 4 and AI.GetBuffDuration(28835) <= 15 and not AI.HasMoveTo() and AI.IsDps() then
        -- AI.SayRaid("Too much stacks of Mark of Zeliek, moving away for a moment")

    end
end

AI.RegisterBossModule(fourHorsemen)

-- THADDIUS
local thaddius = MosDefBossModule:new({
    name = "Thaddius",
    creatureId = {15928},
    onStart = function(self)
    end,
    onStop = function(self)
    end,
    onUpdate = function(self)
        if not AI.IsTank() then
            local plr = AI.GetObjectInfo("player")
            if plr:HasAura("positive charge") and AI.GetDistanceTo(self.positiveP.x, self.positiveP.y) > 3 and
                not AI.HasMoveTo() then
                AI.SetMoveToPosition(self.positiveP.x, self.positiveP.y)
            elseif plr:HasAura("negative charge") and AI.GetDistanceTo(self.negativeP.x, self.negativeP.y) > 3 and
                not AI.HasMoveTo() then
                AI.SetMoveToPosition(self.negativeP.x, self.negativeP.y)
            end
        end
    end,
    positiveP = AI.PathFinding.Vector3.new(3538.6037597656, -2938.5766601563, 303.43368530273),
    negativeP = AI.PathFinding.Vector3.new(3518.4663085938, -2954.6059570313, 303.35333251953)
})

AI.RegisterBossModule(thaddius)

---
local kelthuzad = MosDefBossModule:new({
    name = "Kel'Thuzad",
    creatureId = {15990},
    frozenTarget = nil,
    mcUnit = nil,
    mcCooldown = 0,
    p2 = false,
    onStart = function(self)
        AI.AUTO_TAUNT = false
        if AI.IsTank() then
            AI.ALLOW_AUTO_REFACE = false
        end
        AI.FocusUnit("kel'thuzad")
        AI.DISABLE_PET_AA = true
        AI.AUTO_CLEANSE = false
        AI.DISABLE_DRAIN = true
        AI.DISABLE_WARLOCK_CURSE = true
        AI.Config.judgementToUse = nil

        AI.do_PriorityTarget = function()
            if not AI.IsTank() then
                -- TargetUnit("Unstoppable Abomination")
                -- if AI.IsValidOffensiveUnit("target") and AI.GetDistanceToUnit("target") <= 10 then
                --     PetAttack()
                --     return true
                -- end                
                TargetUnit("Soul Weaver")
                if AI.IsValidOffensiveUnit("target") and AI.GetDistanceToUnit("target") <= 35 then
                    PetAttack()
                    return true
                end
                TargetUnit("soldier of the frozen wastes")
                if AI.IsValidOffensiveUnit("target") and AI.GetDistanceToUnit("target") <= 35 then
                    PetAttack()
                    return true
                end

                AssistUnit(AI.GetPrimaryTank())
            end
            return false
        end

        AI.PRE_DO_DPS = function(isAoE)
            if AI.IsDps() and AI.IsValidOffensiveUnit("target") and
                strcontains(UnitName("target"), "soldier of the frozen wastes") then
                if AI.IsWarlock() then
                    AI.CastSpell("searing pain", "target")
                    return true
                end
                if AI.IsMage() then
                    AI.CastSpell("ice lance", "target")
                    return true
                end
                -- if AI.IsShaman() and AI.CastSpell("lightning bolt", "target") then
                --     return true
                -- end
                if AI.IsPriest() then
                    AI.CastSpell("mind flay", "target")
                    return true
                end

            end
            return false
        end
    end,
    onStop = function(self)
    end,
    onUpdate = function(self)
        local class = AI.GetClass():lower()
        if self.frozenTarget ~= nil and not AI.HasDebuff("frost blast", self.frozenTarget) then
            self.frozenTarget = nil
        end
        if self.frozenTarget ~= nil and self.frozenTarget ~= UnitName("player") then
            if AI.IsHealer() and AI.CanCast() then
                if AI.IsShaman() and AI.CastSpell("lesser healing wave", self.frozenTarget) then
                    return true
                end
            end
        end

        -- check for MC
        if self.mcUnit ~= nil and (not AI.IsUnitCC(self.mcUnit) and not AI.HasDebuff("polymorph", self.mcUnit)) and
            AI.IsValidOffensiveUnit(self.mcUnit) and GetTime() > self.mcCooldown + 2 then
            local mod = self
            local mcUnit = self.mcUnit
            if UnitName("player") ~= mcUnit and AI.IsDps() then
                if AI.IsWarlock() or AI.IsMage() then
                    local delay = AI.IsWarlock() and 0 or 2
                    if AI.IsWarlock(mcUnit) or AI.IsMage(mcUnit) then
                        delay = 0
                    end
                    AI.RegisterPendingAction(function(self)
                        if AI.IsUnitCC(mcUnit) or not AI.IsValidOffensiveUnit(mcUnit) then
                            return true
                        end
                        local spell = AI.IsWarlock() and "fear" or "polymorph"
                        if not AI.IsSpellInRange(spell, mcUnit) then
                            return false
                        end
                        if AI.IsCasting() and not strcontains(UnitCastingInfo("player"), spell) then
                            AI.StopCasting()
                        end
                        print("CC'ing MC victim")
                        local result = AI.CastSpell(spell, mcUnit)
                        self.mcCooldown = GetTime()                        
                        return result
                    end, delay, "CC_MC_UNIT")
                end
            end
        end

        if UnitGUID("target") == UnitGUID("focus") then
            PetAttack()
        end

        -- if GetTime() - (self.frostFissureTime or 0) < 5 and not AI.IsTank() and not AI.HasMoveTo() then
        --     local obstacles = self:GetObstacles()
        --     if obstacles ~= nil then
        --         local p = AI.PathFinding.FindSafeSpotInCircle("player", 35, obstacles, 5)
        --         AI.SetMoveTo(p.x, p.y)
        --         return true
        --     end
        -- end

        return false
    end,
    dps1p = AI.PathFinding.Vector3.new(3733.1115722656, -5094.7192382813, 142.02334594727),
    healerp = AI.PathFinding.Vector3.new(3723.8518066406, -5124.1596679688, 142.0245513916),
    dps2p = AI.PathFinding.Vector3.new(3706.7487792969, -5090.212890625, 142.02496337891),
    dps3p = AI.PathFinding.Vector3.new(3701.0754394531, -5113.919921875, 141.34918212891),
    frostFissureTime = nil
})

function kelthuzad:SPELL_CAST_START(args)
    if args.spellName:lower() == "frostbolt" then
        if AI.IsPriest() or AI.IsHealer() or AI.IsPaladin() or AI.IsWarlock() then
            AI.DoStaggeredInterrupt()
        end
    end
end

function kelthuzad:CHAT_MSG_MONSTER_YELL(txt, s)
    if strcontains(txt, "phylactery") then
        print("p3 coming")
        AI.RegisterOneShotAction(function(self)
            if AI.IsHealer() and self:IsLocationSafe(self.healerp.x, self.healerp.y) then
                AI.SetMoveToPosition(self.healerp.x, self.healerp.y)
            elseif AI.IsDpsPosition(1) and self:IsLocationSafe(self.dps1p.x, self.dps1p.y) then
                AI.SetMoveToPosition(self.dps1p.x, self.dps1p.y)
            elseif AI.IsDpsPosition(2) and self:IsLocationSafe(self.dps2p.x, self.dps2p.y) then
                AI.SetMoveToPosition(self.dps2p.x, self.dps2p.y)
            elseif AI.IsDpsPosition(3) and self:IsLocationSafe(self.dps3p.x, self.dps3p.y) then
                AI.SetMoveToPosition(self.dps3p.x, self.dps3p.y)
            end
        end, 0.5)
    end
end

function kelthuzad:SPELL_AURA_APPLIED(args)
    if (args.spellId == 27808 or args.spellName == "Frost Blast") and args.target ~= nil then
        self.frozenTarget = args.target
        -- if AI.IsPriest() and UnitName("player") ~= args.target then
        --     AI.MustCastSpell("power word: shield", args.target)
        -- end
    end
    if args.spellId == 28410 then
        -- AI.SayRaid("MC on " .. args.target)
        self.mcUnit = args.target
    end
end

function kelthuzad:SPELL_AURA_REMOVED(args)
    if (args.spellId == 27808 or args.spellName == "Frost Blast") then
        self.frozenTarget = nil
    end
    if args.spellId == 28410 then
        print("mind-control removed from " .. args.target)
        if (AI.IsUnitCC(args.target) or AI.HasDebuff("polymorph", args.target) or AI.HasDebuff("fear", args.target)) and
            AI.IsPaladin() then
            print('cleansing mc target')
            AI.MustCastSpell("cleanse", args.target)
        end
        if AI.IsHealer() and AI.GetDistanceTo(self.healerp.x, self.healerp.y) > 3 and
            self:IsLocationSafe(self.healerp.x, self.healerp.y) then
            AI.SetMoveToPosition(self.healerp.x, self.healerp.y)
        elseif AI.IsDpsPosition(1) and AI.GetDistanceTo(self.dps1p.x, self.dps1p.y) > 3 and
            self:IsLocationSafe(self.dps1p.x, self.dps1p.y) then
            AI.SetMoveToPosition(self.dps1p.x, self.dps1p.y)
        elseif AI.IsDpsPosition(2) and AI.GetDistanceTo(self.dps2p.x, self.dps2p.y) > 3 and
            self:IsLocationSafe(self.dps2p.x, self.dps2p.y) then
            AI.SetMoveToPosition(self.dps2p.x, self.dps2p.y)
        elseif AI.IsDpsPosition(3) and AI.GetDistanceTo(self.dps3p.x, self.dps3p.y) > 3 and
            self:IsLocationSafe(self.dps3p.x, self.dps3p.y) then
            AI.SetMoveToPosition(self.dps3p.x, self.dps3p.y)
        end
    end
    if strcontains(args.spellName, "icy barrier") then
        print("ice-barrier down")
        if AI.IsCasting("target") then
            AI.DoStaggeredInterrupt()
        end
    end
end

function kelthuzad:SMSG_SPELL_CAST_GO2(args)
    if args.spellId == 28410 then
        print("mind-control on " .. args.target)
        self.mcUnit = args.target
    end
    if args.casterGUID == UnitGUID("focus") or strcontains(args.caster, "Kel'Thuzad") then
        -- print("Kel'Thuzad is casting " .. args.spellName .. " spellId:" .. args.spellId .. " on " .. args.target)
    end

    if (strcontains(args.spellName, "frost fissure") or args.spellId == 200659) and not AI.IsTank() then
        self.frostFissureTime = GetTime()
        AI.RegisterPendingAction(function(self)
            print("dodging frost fissure")
            local obstacles = self:GetObstacles()
            if obstacles ~= nil then
                local p = AI.PathFinding.FindSafeSpotInCircle(AI.GetPrimaryTank(), 50, obstacles, 1)
                AI.SetMoveTo(p.x, p.y)
                return true
            end
            return false
        end, 0.5, "DODGE_FISSURE")
    end

    if args.spellId == 200660 and not AI.IsTank() then
        AI.RegisterPendingAction(function(self)
            print("moving back to pre-fissure position")
            if AI.IsHealer() and AI.GetUnitHealthPct(AI.GetPrimaryTank()) < 50 then
                return false
            end
            if AI.IsCasting("target") then
                return false
            end
            if AI.IsHealer() then
                AI.SetMoveToPosition(self.healerp.x, self.healerp.y)
            elseif AI.IsDpsPosition(1) then
                AI.SetMoveToPosition(self.dps1p.x, self.dps1p.y)
            elseif AI.IsDpsPosition(2) then
                AI.SetMoveToPosition(self.dps2p.x, self.dps2p.y)
            elseif AI.IsDpsPosition(3) then
                AI.SetMoveToPosition(self.dps3p.x, self.dps3p.y)
            end
            return true
        end, 0.5, "RETURN_PRE_FISSURE")
    end
end

function kelthuzad:CHAT_MSG_RAID_BOSS_EMOTE(arg1, arg2)
    -- print("CHAT_MSG_RAID_BOSS_EMOTE" .. arg2 .. " says " .. arg1)
    if strcontains(arg1, "strikes!") then
        AI.DISABLE_WARLOCK_CURSE = false
        AI.AUTO_TAUNT = true
        self.p2 = true
        AI.FocusUnit("kel'thuzad")
        if AI.IsTank() and not AI.IsTanking("player", "focus") then
            AI.MustCastSpell("Hand of Reckoning", "focus")
        else
            AI.RegisterPendingAction(function(self)
                if AI.IsValidOffensiveUnit() and strcontains(UnitName("target"), "soul weaver") then
                    return false
                end
                if AI.IsHealer() then
                    AI.SetMoveToPosition(self.healerp.x, self.healerp.y)
                elseif AI.IsDpsPosition(1) then
                    AI.SetMoveToPosition(self.dps1p.x, self.dps1p.y)
                elseif AI.IsDpsPosition(2) then
                    AI.SetMoveToPosition(self.dps2p.x, self.dps2p.y)
                elseif AI.IsDpsPosition(3) then
                    AI.SetMoveToPosition(self.dps3p.x, self.dps3p.y)
                end
                return true
            end, 1)
        end
    end
end

function kelthuzad:GetObstacles()
    local fissures = AI.FindNearbyUnitsByName("Frost Fissure", "shadow fissure")
    if #fissures == 0 then
        return nil
    end
    for _, f in ipairs(fissures) do
        f.radius = 10
    end
    -- local allies = AI.GetAlliesAsObstacles(10)
    -- for _, a in ipairs(allies) do
    --     table.insert(fissures, a)
    -- end
    return fissures
end

function kelthuzad:IsLocationSafe(x, y)
    local obstacles = self:GetObstacles()
    local cx, cy, cz = AI.GetPosition()
    return AI.PathFinding.CanMoveSafelyTo({
        x = x,
        y = y,
        z = z
    }, obstacles)
end

AI.RegisterBossModule(kelthuzad)
