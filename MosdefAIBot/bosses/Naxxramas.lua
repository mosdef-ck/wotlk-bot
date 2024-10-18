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
            AI.SetMoveToPosition(tX, tY, 0.006)
        end
    end
end

function grobbulusBossMod:SPELL_AURA_REMOVED(args)
    if (args.spellName:lower() == "mutating injection" or args.spellId == 28169) and args.target:lower() ==
        UnitName("player"):lower() then
        if not AI.IsHealer() then
            AI.SayRaid("mutating injection has expired")
            AI.SetMoveToPosition(self.centerX, self.centerY, 0.003)
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
            TargetUnit("maexxna", 1)

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
        local class = AI.GetClass()
        if AI.IsValidOffensiveUnit("target") and UnitName("target"):lower() == "web wrap" then
            if class == "warlock" and AI.CastSpell("searing pain", "target") then
                return true
            end
            if class == "priest" and AI.CastSpell("mind flay", "target") then return true end
            if class == "mage" and AI.CastSpell("arcane missiles", "target") then return true end
        end
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
    tankX = 0.4274979531765,
    tankY = 0.37671720981598,
    healerX = 0.42541840672493,
    healerY = 0.41028228402138,
    dpsX = 0.44792032241821,
    dpsY = 0.44553908705711,
    -- decimateTime = nil,
    onStart = function(self)
        FocusUnit("Gluth")
        local class = AI.GetClass():lower()
        oldPriorityTargetFn = AI.do_PriorityTarget
        AI.do_PriorityTarget = function()
            if class ~= "mage" then
                if not AI.IsTank() then
                    if AI.IsValidOffensiveUnit("target") and UnitName("target") ~= "Gluth" and
                        AI.GetUnitHealthPct("target") <= 10 then
                        return true
                    end
                    for i = 1, 10 do
                        TargetUnit("zombie chow")
                        if AI.IsValidOffensiveUnit("target") and UnitName("target") ~= "Gluth" and
                            AI.GetUnitHealthPct("target") <= 10 then
                            return true
                        end
                    end
                end
                TargetUnit("Gluth")
            else
                if AI.IsValidOffensiveUnit("target") and UnitName("target"):lower() ~= "zombie chow" then
                    TargetUnit("zombie chow")
                end
            end
            return AI.IsValidOffensiveUnit("target")
        end

        AI.AUTO_TAUNT = false

        if class == "mage" then
            local kiteX, kiteY = 0.46507576107979, 0.47602570056915
            -- AI.SayRaid("kiter headed to kiting position..")
            AI.SetMoveToPosition(kiteX, kiteY)
            AI.ALLOW_AUTO_REFACE = false
            self.previousDpsFunc = AI.DO_DPS
            AI.DO_DPS = function()
                PetAttack()
                if AI.IsValidOffensiveUnit("target") and UnitName("target"):lower() == "zombie chow" and
                    AI.CastSpell("ice lance", "target") then
                    return
                end
            end
        elseif not AI.IsTank() and not AI.IsHealer() then
            -- AI.SayRaid("dps headed to position")
            AI.SetMoveToPosition(self.dpsX, self.dpsY)
            if class == "priest" then
                CancelUnitBuff("player", "vampiric embrace")
                AI.CastSpell("power word: shield", AI.Config.tank)
            end
        elseif AI.IsHealer() then
            -- AI.SayRaid("healer headed to position")
            AI.SetMoveToPosition(self.healerX, self.healerY)
        end

        -- if AI.IsTank() then
        --     local tankX, tankY = 0.4274979531765, 0.37671720981598
        --     AI.SayRaid("tank headed to tanking position")
        --     AI.SetMoveToPosition(tankX, tankY)
        -- end
    end,
    onStop = function(self)
        ClearFocus()
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
        local class = AI.GetClass():lower()
        if class ~= "mage" and not AI.IsHealer() and not AI.HasMoveToPosition() and not AI.AUTO_DPS then
            AI.toggleAutoDps(true)
        end
        return false
    end
})

AI.RegisterBossModule(gluth)

-- heigan the unclean
local heigan = MosDefBossModule:new({
    name = "Heigan The Unclean",
    platformX = 0.51658093929291,
    platformY = 0.41808542609215,
    danceStartX = 0.48749935626984,
    danceStartY = 0.42669451236725,
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
        if AI.IsHealer() and AI.HasDebuff("Necrotic Aura") then
            local alphaTar, _, betaTar, _ = AI.GetMostDamagedFriendly("chain heal")
            local neuroticDuration = AI.GetDebuffDuration("Necrotic Aura")
            if alphaTar then
                if neuroticDuration <= 4 and AI.CastSpell("riptide", AI.Config.tank) then
                    return true
                end
                local tankPct = AI.GetUnitHealthPct(AI.Config.tank)
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
        AI.ResetMoveToPosition()
        if AI.IsTank() then
            -- AI.SayRaid("Tank moving to tanking position")
            AI.SetMoveToPosition(self.tankX, self.tankY)
        elseif AI.IsHealer() then
            -- AI.SayRaid("Healer moving to starting position")
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
    -- print("Unit DIED ", deadUnitName)
    if MaloWUtils_StrContains(deadUnitName, "lady") then
        self.ladyDead = true
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

    local class = AI.GetClass():lower()
    local diff = GetTime() - self.lastMoveTime
    if args.target:lower() == UnitName("player"):lower() and
        (args.spellName:lower() == "consumption" or args.caster:lower() == "void zone") and diff > 10 then

        self.lastMoveTime = GetTime()
        -- AI.SayRaid(UnitName("player") .. " is in Void Zone. Moving to spot " .. self.nextDpsSpot)
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
    -- print("i'm no longer afflicted with " .. args.spellName)
    if args.spellId == 28835 and not self.sirDead and not AI.HasMoveToPosition() then
        if not AI.IsHealer() and not AI.IsTank() then
            -- AI.SayRaid("recovered from marks of Zeliek, moving back to dps him")
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
        -- print("i'm afflicted with " .. amount .. " doses of " .. args.spellName)
    end
    if args.spellId == 28835 and amount >= 4 and not AI.HasMoveToPosition() then -- mark of zeliek
        if not AI.IsHealer() and not AI.IsTank() then
            -- AI.SayRaid("Too much stacks of Mark of Zeliek, moving away for a moment")
            AI.SetMoveToPosition(self.healerStartX, self.healerStartY)
        end
    end
end

AI.RegisterBossModule(fourHorsemen)

-- THADDIUS
local thaddius = MosDefBossModule:new({
    name = "Thaddius",
    onStart = function(self)
        local class = AI.GetClass()
        if AI.IsHealer() then
            AI.SetMoveToPosition(self.healerX, self.healerY)
        elseif class == "warlock" then
            AI.SetMoveToPosition(self.lockX, self.lockY)
        elseif class == "priest" then
            AI.SetMoveToPosition(self.spriestX, self.spriestY)
        elseif class == "mage" then
            AI.SetMoveToPosition(self.mageX, self.mageY)
        end
    end,
    onStop = function(self)
    end,
    lockX = 0.27281373739243,
    lockY = 0.10839419811964,
    healerX = 0.2879327237606,
    healerY = 0.13413137197495,
    spriestX = 0.29793554544449,
    spriestY = 0.12010706961155,
    mageX = 0.28832644224167,
    mageY = 0.094801776111126
})

AI.RegisterBossModule(thaddius)

-- SAPPHIRON

local sapphiron = MosDefBossModule:new({
    name = "Sapphiron",
    onStart = function(self)
        local class = AI.GetClass()
        if class == "priest" then
            AI.CastSpell("power word: shield", AI.Config.tank)
        end
    end,
    onStop = function(self)
    end
})

function sapphiron:SPELL_AURA_APPLIED(args)
    if args.spellId == 28522 then
        local target = args.target
        if UnitName("player") ~= target then
            local tX, tY = AI.GetPosition(target)
            AI.SetMoveToPosition(tX, tY, 0.006)
        end
    end
end

AI.RegisterBossModule(sapphiron)

---
local kelthuzad = MosDefBossModule:new({
    name = "Kel'Thuzad",
    creatureId = {15990},
    warlockX = 0.36869874596596,
    warlockY = 0.21998670697212,
    spriestX = 0.35231751203537,
    spriestY = 0.18740244209766,
    mageX = 0.39841964840889,
    mageY = 0.19535994529724,
    healerX = 0.38290336728096,
    healerY = 0.16442823410034,
    frozenTarget = nil,
    onStart = function(self)
        AI.AUTO_TAUNT = false
        oldPriorityTargetFn = AI.do_PriorityTarget
        AI.do_PriorityTarget = function()
            if not AI.IsTank() then
                TargetUnit("Soul Weaver")
                if AI.IsValidOffensiveUnit("target") and CheckInteractDistance("target", 4) then
                    return true
                end
                TargetUnit("soldier of the frozen wastes")
                if AI.IsValidOffensiveUnit("target") and CheckInteractDistance("target", 4) then
                    return true
                end
                TargetUnit("Unstoppable Abomination")
                if AI.IsValidOffensiveUnit("target") and CheckInteractDistance("target", 4) then
                    return true
                end
            end
            TargetUnit("Kel'Thuzad")
            return AI.IsValidOffensiveUnit("target")
        end
    end,
    onStop = function(self)
        AI.AUTO_TAUNT = true
        if oldPriorityTargetFn ~= nil then
            AI.do_PriorityTarget = oldPriorityTargetFn
        end
    end,
    onUpdate = function(self)
        local class = AI.GetClass():lower()
        if self.frozenTarget ~= nil and not AI.HasDebuff("frost blast", self.frozenTarget) then
            self.frozenTarget = nil
        end
        if self.frozenTarget ~= nil and (class == "priest" or class == "shaman") and self.frozenTarget ~=
            UnitName("player") and AI.GetUnitHealthPct(self.frozenTarget) <= 80 then
            -- if class == "priest" and AI.CanCast() and AI.CastSpell("power word: shield", self.frozenTarget) then
            --     return true
            -- end
            if class == "shaman" and AI.CanCast() and AI.CastSpell("lesser healing wave", self.frozenTarget) then
                return true
            end
        end

        if AI.IsValidOffensiveUnit("target") and UnitName("target"):lower() == "soldier of the frozen wastes" then
            if class == "warlock" and AI.CastSpell("searing pain", "target") then
                return true
            end
            if class == "mage" and AI.CastSpell("ice lance", "target") then
                return true
            end
            if class == "priest" and AI.CastSpell("mind flay", "target") then
                return true
            end
        end
        return false
    end
})

function kelthuzad:SPELL_AURA_APPLIED(args)
    if (args.spellId == 27808 or args.spellName == "Frost Blast") and args.target ~= nil then
        self.frozenTarget = args.target
        --AI.SayRaid(args.target.. " has been frozen!")
    end
end

function kelthuzad:SPELL_CAST_SUCCESS(args)
    if args.spellName == "Frost Blast" and args.target ~= nil then
        self.frozenTarget = args.target
        --AI.SayRaid(args.target.. " has been frozen!")
    end
end

function kelthuzad:CHAT_MSG_RAID_BOSS_EMOTE(arg1, arg2)
    --print("CHAT_MSG_RAID_BOSS_EMOTE" .. arg2 .. " says " .. arg1)
    if MaloWUtils_StrContains(arg1, "strikes!") then
        local class = AI.GetClass():lower()
        if class == "warlock" then
            AI.SetMoveToPosition(self.warlockX, self.warlockY)
        elseif class == "priest" then
            AI.SetMoveToPosition(self.spriestX, self.spriestY)
        elseif class == "mage" then
            AI.SetMoveToPosition(self.mageX, self.mageY)
        elseif class == "shaman" then
            AI.SetMoveToPosition(self.healerX, self.healerY)
        end
    end
end

AI.RegisterBossModule(kelthuzad)
