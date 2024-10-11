local oldPriorityTargetFn = nil
---- Grobbulus
local grobbulusBossMod = MosDefBossModule:new({
    name = "Grobbulus",
    centerX = 0.61085414886475,
    centerY = 0.4671525657177,
    onStart = function()
        AI.Print("Engaging Grobbulus")
        if AI.IsHealer() then
            AI.AUTO_CLEANSE = false
        end
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
    if (args.spellName:lower() == "mutating injection" or args.spellId == 28169) and args.target:lower() ==
        UnitName("player"):lower() then
            if not AI.IsHealer() then
                AI.SayRaid("I have mutating injection moving towards tank")
                local tX, tY = AI.GetPosition(AI.Config.tank)
            end
    end
end

function grobbulusBossMod:SPELL_AURA_REMOVED(args)
    if (args.spellName:lower() == "mutating injection" or args.spellId == 28169) and args.target:lower() ==
        UnitName("player"):lower() then
            if not AI.IsHealer() then
                AI.SayRaid("mutating injection has expired")
                AI.SetMoveToPosition(centerX, centerY, 0.003)
            end            
    end
end

AI.RegisterBossModule(grobbulusBossMod)

---- maexxna
local maexxna = MosDefBossModule:new({
    name = "Maexxna",
    onStart = function()
        AI.Print("Engaging maexxna")
        oldPriorityTargetFn = AI.do_PriorityTarget
        AI.do_PriorityTarget = function()
            if not AI.IsTank() then
                TargetUnit("web wrap")
                if AI.IsValidOffensiveUnit("target") then
                    return true
                end
            end
            TargetUnit("maexxna")

            if AI.IsValidOffensiveUnit("target") then
                return true
            end

            return false
        end
    end,
    onStop = function()
        if oldPriorityTargetFn ~= nil then
            AI.do_PriorityTarget = oldPriorityTargetFn
        end
    end,
    onUpdate = function()
        return AI.IsHealer() and AI.CleanseRaid("Cleanse Spirit", "Curse", "Poison", "Disease")
    end
})

AI.RegisterBossModule(maexxna)

-- instructor razuvious
local razuvious = MosDefBossModule:new({
    name = "instructor razuvious",
    onStart = function()
        AI.AUTO_TAUNT = false
    end,
    onStop = function()
        AI.AUTO_TAUNT = true
    end,
    onUpdate = function()
        if AI.IsHealer() then
            return false
        end

        TargetUnit("instructor razuvious")
        if not AI.IsValidOffensiveUnit("target") then
            return false
        end

        if AI.IsPossessing() then
            -- auto-attack if not alrdy
            if GetCVar("autoInteract") ~= 1 then
                SetCVar("autoInteract", 1)
                InteractUnit("target")
            end
            if AI.IsTanking("playerpet", "target") or AI.IsTanking("player", "target") then
                if AI.HasPossessionSpellCooldown("bone barrier") == false then
                    AI.UsePossessionSpell("bone barrier")
                    return true
                end
            end
            if not AI.HasDebuff("taunt", "target") and AI.HasPossessionSpellCooldown("bone barrier") == false and
                AI.UsePossessionSpell("taunt") then
                return true
            end
            if AI.UsePossessionSpell("blood strike") then
                return true
            end
        else
            -- restore disabled autoInteract
            if GetCVar("autoInteract") ~= 0 then
                SetCVar("autoInteract", 0)
            end
        end
        return false
    end
})

AI.RegisterBossModule(razuvious)

-- Gluth
local gluth = MosDefBossModule:new({
    name = "Gluth",
    previousDpsFunc = nil,
    onStart = function(self)
        AI.Print("Engaging Gluth")
        local class = AI.GetClass():lower()
        oldPriorityTargetFn = AI.do_PriorityTarget
        AI.do_PriorityTarget = function()
            if class ~= "mage" then
                if not AI.IsTank() then
                    TargetNearestEnemy()
                    if AI.IsValidOffensiveUnit("target") and UnitName("target") ~= "Gluth" and
                        CheckInteractDistance("target", 3) then
                        return true
                    end
                end
                TargetUnit("Gluth")
            else
                if AI.IsValidOffensiveUnit("target") and UnitName("target"):lower() ~= "zombie chow" then
                    TargetUnit("zombie chow")
                end
            end
            if AI.IsValidOffensiveUnit("target") then
                return true
            end
            return false
        end

        AI.AUTO_TAUNT = false
        if class == "mage" then
            local kiteX, kiteY = 0.47161412239075, 0.46050518751144
            self.previousDpsFunc = AI.DO_DPS
            AI.DO_DPS = function()
                if AI.IsValidOffensiveUnit("target") and UnitName("target"):lower() == "zombie chow" and
                    AI.CastSpell("ice lance", "target") then
                    return
                end
            end
            AI.SayRaid("kiter headed to kiting position..")
            AI.SetMoveToPosition(kiteX, kiteY)
            AI.ALLOW_AUTO_REFACE = false
        elseif not AI.IsTank() then
            local dpsX, dpsY = 0.44864216446877, 0.42136773467064
            AI.SayRaid("dps and healer headed to position")
            AI.SetMoveToPosition(dpsX, dpsY)
        end
        if AI.IsTank() then
            local tankX, tankY = 0.4274979531765, 0.37671720981598
            AI.SayRaid("tank headed to tanking position")
            AI.SetMoveToPosition(tankX, tankY)
        end
    end,
    onStop = function(self)
        local class = AI.GetClass():lower()
        if oldPriorityTargetFn ~= nil then
            AI.do_PriorityTarget = oldPriorityTargetFn
        end
        if class == "mage" then
            AI.DO_DPS = self.previousDpsFunc
            AI.ALLOW_AUTO_REFACE = true
        end
        AI.AUTO_TAUNT = true
    end,
    onUpdate = function(self)
        return false
    end
})

AI.RegisterBossModule(gluth)

-- heigan the unclean
local heigan = MosDefBossModule:new({
    name = "Heigan The Unclean",
    platformX = 0.517210966236496,
    platformY = 0.41791427135468,
    danceStartX = 0.49928018450737,
    danceStartY = 0.40855741500854,
    onStart = function(self)
        if not AI.IsTank() then
            AI.SetMoveToPosition(self.platformX, self.platformY, 0.001)
            AI.SayRaid("headed to safety platform")
        end
    end,
    onStop = function()
    end,
    onUpdate = function()
        return false
    end
})

function heigan:CHAT_MSG_RAID_BOSS_EMOTE(arg1, arg2)
    -- print("CHAT_MSG_RAID_BOSS_EMOTE" .. arg2 .. "says " .. arg1)
    if arg1:lower() == "%s teleports and begins to channel a spell!" then
        AI.DISABLE_CDS = true
        if not AI.IsTank() then
            AI.SayRaid("Heigan dance has began")
            AI.SetMoveToPosition(self.danceStartX, self.danceStartY, 0.001)
        end
    elseif arg1:lower() == "%s rushes to attack once more!" then
        AI.DISABLE_CDS = false
        if not AI.IsTank() then
            AI.SetMoveToPosition(self.platformX, self.platformY, 0.001)
            AI.SayRaid("headed to safety platform")
        end
    end
end

heigan:RegisterEvent("CHAT_MSG_RAID_BOSS_EMOTE")
AI.RegisterBossModule(heigan)

-- loatheb
local loatheb = MosDefBossModule:new({
    name = "Loatheb",
    onStart = function()
    end,
    onStop = function()
    end,
    onUpdate = function()
        if AI.IsHealer() then
            local alphaTar, _, betaTar, _ = AI.GetMostDamagedFriendly("chain heal")
            local neuroticDuration = AI.GetDebuffDuration("Necrotic Aura")
            if alphaTar then
                if neuroticDuration <= 4 and AI.CastSpell("riptide", alphaTar) then
                    return true
                end
                if neuroticDuration <= 2 and UnitName(alphaTar):lower() == UnitName(AI.Config.tank):lower() and betaTar and
                    AI.CastSpell("chain heal", betaTar) then
                    return true
                end
            end
        end
        return AI.IsHealer() and AI.HasDebuff("Necrotic Aura")
    end
})
AI.RegisterBossModule(loatheb)

-- four horsemen
local fourHorsemen = MosDefBossModule:new({
    name = "Baron Rivendare",
    onStart = function(self)
        AI.Print("Four Horsemen Engaged")
        AI.ResetMoveToPosition()
        if AI.IsTank() then
            AI.SayRaid("Tank moving to tanking position")
            AI.SetMoveToPosition(self.tankX, self.tankY)
        elseif AI.IsHealer() then
            AI.SayRaid("Healer moving to starting position")
            AI.SetMoveToPosition(self.healerStartX, self.healerStartY)
        else
            local class = AI.GetClass():lower()
            if class == "warlock" then
                AI.SetMoveToPosition(self.ws1X, self.ws1Y)
            elseif class == "mage" then
                AI.SetMoveToPosition(self.ms1X, self.ms1Y)
            else
                AI.SetMoveToPosition(self.ss1X, self.ss1Y)
            end
            -- AI.SayRaid("DPS moving to start position")
        end
        oldPriorityTargetFn = AI.do_PriorityTarget
        AI.do_PriorityTarget = function()
            AI.DISABLE_CDS = true
            if AI.IsTank() then
                TargetUnit("Baron Rivendare")
                if not AI.IsValidOffensiveUnit("target") or self.baronDead then
                    TargetUnit("Thane")
                end
            else
                local distToCaster = AI.GetDistanceTo(self.dpsSharedSpotX, self.dpsSharedSpotY)
                local distToTank = AI.GetDistanceTo(self.healerStartX, self.healerStartY)
                if distToCaster < distToTank then
                    TargetUnit("Lady Blaumeux")
                    if not AI.IsValidOffensiveUnit("target") or self.ladyDead then
                        TargetUnit("Sir Zeliek")
                    end
                else
                    TargetUnit("Baron")
                    if not AI.IsValidOffensiveUnit("target") or self.sirDead then
                        TargetUnit("Thane")
                    end
                end
                -- TargetUnit("Lady Blaumeux")
                -- if not AI.IsValidOffensiveUnit("target") or self.ladyDead then
                --     TargetUnit("Baron")
                -- end
                -- if not AI.IsValidOffensiveUnit("target") or self.baronDead then
                --     TargetUnit("Sir Zeliek")
                -- end
                -- if not AI.IsValidOffensiveUnit("target") or self.sirDead then
                --     TargetUnit("Thane")
                -- end
            end
            return AI.IsValidOffensiveUnit("target")
        end
    end,
    onStop = function(self)
        if oldPriorityTargetFn ~= nil then
            AI.do_PriorityTarget = oldPriorityTargetFn
        end
        self.ladyDead = false
        self.baronDead = false
        self.thaneDead = false
        self.sirDead = false
        self.nextDpsSpot = 2
        self.lastMoveTime = 0
    end,
    onUpdate = function()
        if AI.IsValidOffensiveUnit("target") and AI.GetUnitHealthPct("target") < 90 and AI.DISABLE_CDS then
            AI.DISABLE_CDS = false
        end
    end,
    tankX = 0.32215738296509,
    tankY = 0.69158202409744,
    healerStartX = 0.32264873385429,
    healerStartY = 0.69287812709808,
    ws1X = 0.35932332277298,
    ws1Y = 0.71502774953842,
    ws2X = 0.3552431166172,
    ws2Y = 0.7153537273407,
    ws3X = 0.35573527216911,
    ws3Y = 0.72158169746399,
    ws4X = 0.3566389977932,
    ws4Y = 0.72713899612427,
    ws5X = 0.35622170567513,
    ws5Y = 0.73209685087204,
    ms1X = 0.35331401228905,
    ms1Y = 0.7164266705513,
    ms2X = 0.34923788905144,
    ms2Y = 0.71817749738693,
    ms3X = 0.34656739234924,
    ms3Y = 0.72116667032242,
    ms4X = 0.34451803565025,
    ms4Y = 0.72606873512268,
    ms5X = 0.3413659632206,
    ms5Y = 0.7302160859108,
    ss1X = 0.33663696050644,
    ss1Y = 0.73543947935104,
    ss2X = 0.33530557155609,
    ss2Y = 0.74060422182083,
    ss3X = 0.33560484647751,
    ss3Y = 0.74612545967102,
    ss4X = 0.33593302965164,
    ss4Y = 0.75077700614929,
    ss5X = 0.33588114380836,
    ss5Y = 0.75639921426773,
    dpsSharedSpotX = 0.34718710184097,
    dpsSharedSpotY = 0.73557162284851,
    nextDpsSpot = 2,
    baronDead = false,
    ladyDead = false,
    thaneDead = false,
    sirDead = false,
    lastMoveTime = 0
})

function fourHorsemen:UNIT_DIED(unit)
    local deadUnitName = unit:lower()
    print("Unit DIED ", deadUnitName)
    if MaloWUtils_StrContains(deadUnitName, "lady") then
        self.ladyDead = true
        AI.SayRaid(unit .. " has died moving dps to Baron's location")
        AI.DISABLE_CDS = false
        if not AI.IsTank() and not AI.IsHealer() then
            AI.SetMoveToPosition(self.healerStartX, self.healerStartY)
        end
    elseif MaloWUtils_StrContains(deadUnitName, "baron") then
        self.baronDead = true
        if not AI.IsTank() and not AI.IsHealer() then
            AI.SetMoveToPosition(self.dpsSharedSpotX, self.dpsSharedSpotY)
        end
    elseif MaloWUtils_StrContains(deadUnitName, "sir") then
        self.sirDead = true
        if not AI.IsTank() and not AI.IsHealer() then
            AI.SetMoveToPosition(self.healerStartX, self.healerStartY)
        end
    end
end

function fourHorsemen:SPELL_DAMAGE(args)
    if AI.IsTank() or AI.IsHealer() then
        return
    end
    if args.target:lower() == UnitName("player"):lower() then
        print("I'm taking " .. args.spellName .. " spell dmg from " .. args.caster)
    end

    local class = AI.GetClass():lower()
    local diff = GetTime() - self.lastMoveTime
    if args.target:lower() == UnitName("player"):lower() and
        (args.spellName:lower() == "consumption" or args.caster:lower() == "void zone") and diff > 10 then

        self.lastMoveTime = GetTime()
        AI.SayRaid(UnitName("player") .. " is in Void Zone. Moving to spot " .. self.nextDpsSpot)
        if self.nextDpsSpot == 2 then
            if class == "warlock" then
                AI.SetMoveToPosition(self.ws2X, self.ws2Y)
            elseif class == "mage" then
                AI.SetMoveToPosition(self.ms2X, self.ms2Y)
            else
                AI.SetMoveToPosition(self.ss2X, self.ss2Y)
            end
            self.nextDpsSpot = 3
        elseif self.nextDpsSpot == 3 then
            if class == "warlock" then
                AI.SetMoveToPosition(self.ws3X, self.ws3Y)
            elseif class == "mage" then
                AI.SetMoveToPosition(self.ms3X, self.ms3Y)
            else
                AI.SetMoveToPosition(self.ss3X, self.ss3Y)
            end
            self.nextDpsSpot = 4
        elseif self.nextDpsSpot == 4 then
            if class == "warlock" then
                AI.SetMoveToPosition(self.ws4X, self.ws4Y)
            elseif class == "mage" then
                AI.SetMoveToPosition(self.ms4X, self.ms4Y)
            else
                AI.SetMoveToPosition(self.ss4X, self.ss4Y)
            end
            self.nextDpsSpot = 5
        elseif self.nextDpsSpot == 5 then
            if class == "warlock" then
                AI.SetMoveToPosition(self.ws5X, self.ws5Y)
            elseif class == "mage" then
                AI.SetMoveToPosition(self.ms5X, self.ms5Y)
            else
                AI.SetMoveToPosition(self.ss5X, self.ss5Y)
            end
            self.nextDpsSpot = 6
        elseif self.nextDpsSpot == 6 then
            AI.SetMoveToPosition(self.dpsSharedSpotX, self.dpsSharedSpotY)
            self.nextDpsSpot = 2
        end
    end
end

function fourHorsemen:SPELL_AURA_REMOVED(args)
    if args.target:lower() ~= UnitName("player"):lower() then
        return
    end
    print("i'm no longer afflicted with " .. args.spellName)
    if args.spellId == 28835 and not self.sirDead and not AI.HasMoveToPosition() then
        if not AI.IsHealer() and not AI.IsTank() then
            AI.SayRaid("recovered from marks of Zeliek, moving back to dps him")
            AI.SetMoveToPosition(self.dpsSharedSpotX, self.dpsSharedSpotY)
        end
    end
end

function fourHorsemen:SPELL_AURA_APPLIED_DOSE(args)
    local amount = args.arg2
    if args.target:lower() ~= UnitName("player"):lower() then
        return
    end
    if args.spellId == 28832 or args.spellId == 28833 or args.spellId == 28834 or args.spellId == 28835 then
        print("i'm afflicted with " .. amount .. " doses of " .. args.spellName)
    end
    if args.spellId == 28835 and amount >= 4 and not AI.HasMoveToPosition() then -- mark of zeliek
        if not AI.IsHealer() and not AI.IsTank() then
            AI.SayRaid("Too much stacks of Mark of Zeliek, moving away for a moment")
            AI.SetMoveToPosition(self.healerStartX, self.healerStartY)
        end
    end
end

AI.RegisterBossModule(fourHorsemen)
