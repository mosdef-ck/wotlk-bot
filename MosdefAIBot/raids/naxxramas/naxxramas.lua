local oldPriorityTargetFn = nil

-- noth
local noth = MosDefBossModule:new({
    name = "Noth the Plaguebringer",
    creatureId = {15954},
    onStart = function(self)
        AI.AUTO_TAUNT = false
        oldPriorityTargetFn = AI.do_PriorityTarget
        AI.do_PriorityTarget = function()
            TargetUnit("plagued conqueror", 1)
            return AI.DoTargetChain("plagued conqueror")
        end
        AI.PRE_DO_DPS = function(isAoe)
            if AI.IsDps() then
                return GetTime() < self.lastBlinkTime + 5
            end
            return false
        end
        if AI.IsPriest() then
            CancelUnitBuff("player", "vampiric embrace")
            AI.CastSpell("power word: shield", AI.Config.tank)
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
        if AI.IsTank() then
            if AI.IsValidOffensiveUnit() and strcontains(UnitName("target"), "Noth") and not AI.IsTanking("player") and
                AI.CastSpell("Hand of Reckoning", "target") then
                return true
            end
        end
        return false
    end,
    lastBlinkTime = 0
})

function noth:CHAT_MSG_RAID_BOSS_EMOTE(s, t)
    -- print("Noth has blinked")
    if strcontains(s, "blinks") then
        self.lastBlinkTime = GetTime()
    end
end

AI.RegisterBossModule(noth)

-- anub
local anubRehkan = MosDefBossModule:new({
    name = "Anub'Rekhan",
    creatureId = {15956},
    onStart = function(self)
        if AI.IsTank() then
            AI.ALLOW_AUTO_REFACE = false
        end
        TargetUnit("anub'rehkan")
        FocusUnit("target")
        AI.RegisterOneShotAction(function(self)
            if AI.IsHealer() then
                AI.SetMoveTo(self.centerP.x, self.centerP.y)
            elseif AI.IsDpsPosition(1) then
                AI.SetMoveTo(self.dps1p.x, self.dps1p.y)
            elseif AI.IsDpsPosition(2) then
                AI.SetMoveTo(self.dps2p.x, self.dps2p.y)
            elseif AI.IsDpsPosition(3) then
                AI.SetMoveTo(self.dps3p.x, self.dps3p.y)
            end
        end, 1)
    end,
    onStop = function(self)
        AI.ALLOW_AUTO_REFACE = true
    end,
    onUpdate = function(self)
        return false
    end,
    centerP = AI.PathFinding.Vector3.new(3272.4348144531, -3476.4177246094, 287.07574462891),
    dps1p = AI.PathFinding.Vector3.new(3274.8842773438, -3468.2561035156, 287.07574462891),
    dps2p = AI.PathFinding.Vector3.new(3273.5114746094, -3455.4321289063, 287.07574462891),
    dps3p = AI.PathFinding.Vector3.new(3275.2368164063, -3489.8125, 287.07574462891)
})
function anubRehkan:SPELL_CAST_START(args)
    if strcontains(args.spellName:lower(), "locust swarm") then
        if not AI.IsTank() then
            AI.SetMoveTo(self.centerP.x, self.centerP.y)
        end
    end
end

function anubRehkan:SPELL_AURA_REMOVED(args)
    if strcontains(args.spellName:lower(), "locust swarm") then
        if AI.IsHealer() then
            AI.SetMoveTo(self.centerP.x, self.centerP.y)
        elseif AI.IsDpsPosition(1) then
            AI.SetMoveTo(self.dps1p.x, self.dps1p.y)
        elseif AI.IsDpsPosition(2) then
            AI.SetMoveTo(self.dps2p.x, self.dps2p.y)
        elseif AI.IsDpsPosition(3) then
            AI.SetMoveTo(self.dps3p.x, self.dps3p.y)
        end
    end
end
AI.RegisterBossModule(anubRehkan)

-- faerlina
local faerlina = MosDefBossModule:new({
    name = "Grand Window Faerlina",
    creatureId = {15953},
    healerX = 0.46267950534821,
    healerY = 0.35050496459007,
    dps3X = 0.45977458357811,
    dps3Y = 0.33480566740036,
    dps1X = 0.46309423446655,
    dps1Y = 0.36603483557701,
    dps2X = 0.4590063393116,
    dps2Y = 0.38329195976257,
    lastFearTime = 0,
    onStart = function(self)
        if AI.IsTank() then
            AI.ALLOW_AUTO_REFACE = false
        end
        if AI.IsHealer() then
            AI.AUTO_CLEANSE = false
            if AI.IsHeroicRaidOrDungeon() then
                TargetUnit("Grand")
                FocusUnit("target")
                AI.SetMoveToPosition(self.healerX, self.healerY)
            end
        elseif AI.IsDps() then
            if AI.IsHeroicRaidOrDungeon() then
                if AI.IsPriest() then
                    AI.CastSpell("power word: shield", AI.Config.tank)
                    AI.SetMoveToPosition(self.dps1X, self.dps1Y)
                elseif AI.IsWarlock() then
                    TargetUnit("naxxramas follower")
                    if UnitName("target") == "Naxxramas Follower" then
                        FocusUnit("target")
                    end
                    AI.SetMoveToPosition(self.dps2X, self.dps2Y)
                else
                    AI.SetMoveToPosition(self.dps3X, self.dps3Y)
                end
            end
        end
    end,
    onStop = function()
        AI.AUTO_CLEANSE = true
        AI.ALLOW_AUTO_REFACE = true
    end,
    onUpdate = function(self)
        if AI.IsHeroicRaidOrDungeon() then
            if AI.IsHealer() then
                if AI.GetDistanceTo(self.healerX, self.healerY) > 0.009 then
                    AI.SetMoveToPosition(self.healerX, self.healerY)
                    return true
                end
            elseif AI.IsDps() then
                if AI.IsPriest() then
                    if AI.GetDistanceTo(self.dps1X, self.dps1Y) > 0.009 then
                        AI.SetMoveToPosition(self.dps1X, self.dps1Y)
                        return true

                    end
                elseif AI.IsWarlock() then
                    if AI.GetDistanceTo(self.dps2X, self.dps2Y) > 0.009 then
                        AI.SetMoveToPosition(self.dps2X, self.dps2Y)
                        return true
                    end
                    if UnitExists("focus") and not AI.HasMoveToPosition() and not AI.HasMyDebuff("fear", "focus") and
                        AI.CastSpell("fear", "focus") and GetTime() > self.lastFearTime then
                        self.lastFearTime = GetTime() + 20
                        return true
                    end
                else
                    if AI.GetDistanceTo(self.dps3X, self.dps3Y) > 0.009 then
                        AI.SetMoveToPosition(self.dps3X, self.dps3Y)
                        return true
                    end
                end

                local hp = AI.GetUnitHealthPct("focus")
                if AI.IsShaman() and (AI.HasBuff("enrage", "focus") or hp > 95) and
                    AI.CastSpell("healing wave", AI.Config.tank) then
                    return true
                end
            end
        end
        return false
    end
})

-- AI.RegisterBossModule(faerlina)

---- Grobbulus
local grobbulusBossMod = MosDefBossModule:new({
    name = "Grobbulus",
    creatureId = {15931},
    startx = nil,
    starty = nil,
    startz = nil,
    onStart = function(self)
        if AI.IsHealer() then
            AI.AUTO_CLEANSE = false
        end
        if not strcontains(UnitName("focus"), "grobbulus") then
            TargetUnit("Grobbulus")
            FocusUnit("target")
        end
        if AI.IsWarlock() and not AI.HasBuff("demonic circle: summon") then
            AI.MustCastSpell("demonic circle: summon")
        end
        self.startx, self.starty, self.startz = AI.GetPosition()
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
        if args.target:lower() == UnitName("player"):lower() then
            local x, y, z = AI.GetPosition(AI.GetPrimaryTank())
            AI.SetMoveTo(x, y, z)
        end
        if AI.IsPriest() then
            AI.MustCastSpell("power word: shield", args.target)
        end
    end
end

function grobbulusBossMod:SPELL_AURA_REMOVED(args)
    if (args.spellName:lower() == "mutating injection" or args.spellId == 28169) and args.target:lower() ==
        UnitName("player"):lower() then
        print("mutation expired")
        AI.SetMoveTo(self.startx, self.starty, self.startz)
        if AI.IsWarlock() then
            AI.CastSpell("demonic circle: teleport")
        end
        if AI.IsMage() then
            AI.CastSpell("blink")
        end
    end
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
        oldPriorityTargetFn = AI.do_PriorityTarget
        AI.do_PriorityTarget = function()
            if not AI.IsTank() then
                return AI.DoTargetChain("web wrap", "spiderling")
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
        if AI.IsHealer() or (AI.IsDps() and AI.IsShaman()) then
            if not AI.IsHealer() and AI.CleanseRaid("Cure Toxins", "Poison", "Disease") then
                return true
            end

            if AI.IsHeroicRaidOrDungeon() and not AI.AUTO_AOE then
                -- print("onUpdate heroic druidUp " .. tostring(self.druidIsUp) .. " priestUp " ..tostring(self.priestIsUp))
                if not self.druidIsUp then
                    if UnitName("focus") ~= "Naturalistic Druid" then
                        TargetUnit("naturalistic druid")
                        FocusUnit("target")
                    end
                    if AI.GetUnitHealthPct("focus") >= 100 and UnitName("focus") == "Naturalistic Druid" then
                        print("Naturalist druid fully healed")
                        self.druidIsUp = true
                    end
                end
                if self.druidIsUp and not self.priestIsUp then
                    if UnitName("focus") ~= "Faithful Priest" then
                        TargetUnit("faithful")
                        FocusUnit("target")
                    end
                    if AI.GetUnitHealthPct("focus") >= 100 and UnitName("focus") == "Faithful Priest" then
                        print("Faithful priest fully healed")
                        self.priestIsUp = true
                    end
                end
                local missingHp = AI.GetMissingHealth(AI.Config.tank)
                local spellEffect = AI.GetSpellEffect("healing wave")
                local focusHp = AI.GetUnitHealthPct("focus")
                -- print("missingHp " .. missingHp .. " spellEffect " .. spellEffect .. " focusHp " .. focusHp)
                if (not self.druidIsUp or not self.priestIsUp) and missingHp < spellEffect and focusHp < 100 then
                    if not self.druidIsUp and AI.CastSpell("chain heal", "focus") then
                        return true
                    end
                    -- fully heal the priest yet until maexxna enrages
                    if not self.priestIsUp and (focusHp < 90 or AI.GetUnitHealthPct("target") <= 30) and
                        AI.CastSpell("chain heal", "focus") then
                        return true
                    end
                end
            end
        end

        return false
    end
})

function maexxna:SPELL_AURA_REMOVED(args)
    -- if args.spellName:lower() == "web spray" and (AI.IsPriest() or AI.IsShaman()) then
    --     AI.RegisterPendingAction(function()
    --         AI.StopCasting()
    --         if AI.IsPriest() then
    --             return AI.CastSpell("power word: shield", AI.Config.tank)
    --         elseif AI.IsShaman() and AI.IsDps() then
    --             return AI.CastSpell("lesser healing wave", AI.Config.tank)
    --         end
    --         return true
    --     end)
    -- end
end

AI.RegisterBossModule(maexxna)

-- instructor razuvious
local razuvious = MosDefBossModule:new({
    name = "instructor razuvious",
    creatureId = {16061},
    onStart = function()
        AI.AUTO_TAUNT = false
        if not AI.IsHeroicRaidOrDungeon() then
            if AI.IsDpsPosition(2) then
                local crystals = AI.FindNearbyUnitsByName("obedience crystal")
                local closestToTank = nil
                local tank = AI.GetObjectInfo(AI.GetPrimaryTank())
                local dist = 100
                for i, o in ipairs(crystals) do
                    if tank:GetDistanceTo(o.x, o.y) <= dist then
                        closestToTank = o
                        dist = tank:GetDistanceTo(o.x, o.y)
                    end
                end
                if closestToTank then
                    closestToTank:InteractWith()
                    self.selectedCrystal = closestToTank
                    AI.SendAddonMessage('selected-crystal', closestToTank.guid)
                end
            end
        end
    end,
    onStop = function()
        AI.AUTO_TAUNT = true
        -- SetCVar("autoInteract", 0)
    end,
    onUpdate = function()
        if not AI.IsHeroicRaidOrDungeon() then
            if AI.IsPossessing() then
                -- auto-attack if not alrdy
                if GetCVar("autoInteract") ~= 1 then
                    SetCVar("autoInteract", 1)
                    InteractUnit("target")
                end
                if AI.IsTanking("playerpet", "target") and not AI.HasPossessionSpellCooldown("bone barrier") and
                    AI.UsePossessionSpell("bone barrier") then
                    return true
                end
                if not AI.HasDebuff("taunt", "target") and not AI.HasPossessionSpellCooldown("bone barrier") and
                    AI.UsePossessionSpell("taunt", "target") then
                    return true
                end

                if AI.UsePossessionSpell("blood strike") then
                    return true
                end
            end
        else
            if AI.IsTank() then
                if UnitName("focus") ~= "Death Knight Understudy" or not AI.IsValidOffensiveUnit("focus") then
                    TargetUnit("Death Knight Understudy")
                    FocusUnit("target")
                    TargetLastEnemy()
                end
                if AI.IsValidOffensiveUnit("focus") and AI.CastSpell("Hand of Reckoning", "focus") then
                    return true
                end
            end
        end
        return false
    end,
    selectedCrystal = nil
})

function AI.ON_ADDON_MESSAGE(from, cmd, params)
    if AI.IsDpsPosition(3) and cmd == "selected-crystal" and params then
        local guid = tonumber(params)
        local crystals = AI.FindNearbyUnitsByName("obedience crystal")
        for i, o in ipairs(crystals) do
            if o.guid ~= guid then
                self.selectedCrystal = o
                o:InteractWith()
                break
            end
        end
    end
end

AI.RegisterBossModule(razuvious)

-- Gluth
local gluth = MosDefBossModule:new({
    name = "Gluth",
    previousDpsFunc = nil,
    tankX = 0.4274979531765,
    tankY = 0.37671720981598,
    healerX = 0.42418614029884,
    healerY = 0.40798491239548,
    dpsX = 0.44792032241821,
    dpsY = 0.44553908705711,
    kiteX = 0.46507576107979,
    kiteY = 0.47602570056915,
    kiter = "mosdefelsham",
    -- decimateTime = nil,
    onStart = function(self)
        FocusUnit("Gluth")
        local class = AI.GetClass():lower()
        oldPriorityTargetFn = AI.do_PriorityTarget
        AI.do_PriorityTarget = function()
            local class = AI.GetClass():lower()
            if UnitName("player"):lower() ~= self.kiter then
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
                if class == "shaman" then
                    for i = 1, 10 do
                        TargetUnit("zombie chow")
                        if AI.IsValidOffensiveUnit("target") and AI.GetMyDebuffDuration("flame shock") <= 2 then
                            return true
                        end
                    end
                elseif AI.IsValidOffensiveUnit("target") and UnitName("target"):lower() ~= "zombie chow" then
                    TargetUnit("zombie chow")
                end
            end
            return AI.IsValidOffensiveUnit("target")
        end

        AI.AUTO_TAUNT = false
        if AI.IsTank() then
            AI.ALLOW_AUTO_REFACE = false
        end

        if UnitName("player"):lower() == self.kiter then
            -- AI.SayRaid("kiter headed to kiting position..")
            AI.SetMoveToPosition(self.kiteX, self.kiteY)
            AI.ALLOW_AUTO_REFACE = false
            self.previousDpsFunc = AI.DO_DPS
            AI.DO_DPS = function()
                PetAttack()
                if AI.IsValidOffensiveUnit("target") and UnitName("target"):lower() == "zombie chow" then
                    if (class == "mage" and AI.CastSpell("ice lance", "target")) or
                        (class == "shaman" and AI.CastSpell("flame shock", "target")) then
                        return
                    end
                end
            end
        elseif AI.IsDps() then
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
        if UnitName("player"):lower() == self.kiter or AI.IsTank() then
            if not AI.IsTank() then
                AI.DO_DPS = self.previousDpsFunc
            end
            AI.ALLOW_AUTO_REFACE = true
        end
        AI.AUTO_TAUNT = true
    end,
    onUpdate = function(self)
        local class = AI.GetClass():lower()
        if not AI.IsHealer() and not AI.HasMoveToPosition() and not AI.AUTO_DPS and UnitName("player"):lower() ~=
            self.kiter then
            AI.toggleAutoDps(true)
        end

        if AI.IsTank() and AI.HasBuff("enrage", "target") and AI.CastSpell("Hand of Reckoning", "target") then
            return true
        end

        if AI.IsDps() and UnitName("player"):lower() ~= self.kiter and UnitName("target") ~= "Gluth" then
            if not AI.AUTO_AOE then
                if class == "warlock" and AI.CastSpell("searing pain", "target") then
                    return true
                elseif class == "priest" then
                    if AI.CastSpell("mind blast", "target") then
                        return true
                    end
                    if AI.CastSpell("mind flay", "target") then
                        return true
                    end
                end
            end
        end
        return false
    end
})

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
    danceStartP = AI.PathFinding.Vector3.new(2806.4020996094, -3684.9084472656, 273.65112304688)
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
        oldPriorityTargetFn = AI.do_PriorityTarget
        AI.do_PriorityTarget = function()
            return AI.DoTargetChain("plagued mushroom-men")
        end
    end,
    onStop = function()
        AI.ALLOW_AUTO_REFACE = true
    end,
    onUpdate = function()
        if AI.IsTank() then
            if AI.GetUnitHealthPct("player") < 50 then
                AI.UseInventorySlot(13)
            end
        end
        if AI.IsHealer() then
            if AI.IsShaman() then
                local alphaTar, _, betaTar, _ = AI.GetMostDamagedFriendly("chain heal")
                local neuroticDuration = AI.GetDebuffDuration("Necrotic Aura")
                if alphaTar then
                    if neuroticDuration <= 4 and AI.CastSpell("riptide", AI.Config.tank) then
                        return true
                    end
                    local tankPct = AI.GetUnitHealthPct(AI.Config.tank)
                    if neuroticDuration <= 2 and neuroticDuration > 0 and UnitName(alphaTar):lower() ==
                        UnitName(AI.Config.tank):lower() and betaTar and AI.CastSpell("chain heal", betaTar) then
                        return true
                    end
                    if neuroticDuration == 0 and AI.CastSpell("healing wave", AI.Config.tank) then
                        return true
                    end
                end
            end
            if AI.IsDruid() then
                local alphaTar, _, betaTar, _ = AI.GetMostDamagedFriendly("regrowth")
                local neuroticDuration = AI.GetDebuffDuration("Necrotic Aura")
                if alphaTar then
                    if neuroticDuration <= 3 and AI.CastSpell("wild growth", AI.Config.tank) then
                        return true
                    end
                    local tankPct = AI.GetUnitHealthPct(AI.Config.tank)
                    if neuroticDuration <= 1.5 and not AI.HasMyBuff("regrowth", AI.Config.tank) and
                        AI.CastSpell("regrowth", AI.Config.tank) then
                        return true
                    end
                    if neuroticDuration == 0 then
                        if AI.HasMyBuff("regrowth", AI.Config.tank) and AI.CastSpell("swiftmend", AI.Config.tank) then
                            return true
                        end
                        if AI.CastSpell("healing touch", AI.Config.tank) then
                            return true
                        end
                    end
                end
            end
        end

        if AI.IsPriest() then
            -- if AI.IsValidOffensiveUnit() and MaloWUtils_StrContains(UnitName("target"), "plagued") and
            --     AI.CastSpell("mind flay", "target") then
            --     return true
            -- end
            if AI.GetUnitHealthPct(AI.Config.tank) <= 50 and not AI.HasDebuff("weakened soul", AI.Config.tank) and
                AI.CastSpell("power word: shield", AI.Config.tank) then
                return true
            end
        end

        -- if AI.IsWarlock() then
        --     if AI.IsValidOffensiveUnit() and MaloWUtils_StrContains(UnitName("target"), "plagued") and not AI.HasMyDebuff("fear") and 
        --         AI.CastSpell("fear", "target") then
        --         return true
        --     end
        -- end

        local protectiveMushrooms = AI.FindNearbyUnitsByName("protective mushroom")
        local mushroomMen = AI.FindNearbyUnitsByName("plagued mushroom-men")
        if #protectiveMushrooms > 0 and #mushroomMen == 0 and protectiveMushrooms[1].distance > 4 and not AI.IsCasting() then
            print("moving to mushroom")
            AI.SetMoveTo(protectiveMushrooms[1].x, protectiveMushrooms[1].y)
        end

        return AI.IsHealer() and AI.HasDebuff("Necrotic Aura")
    end
})
AI.RegisterBossModule(loatheb)

-- four horsemen
local fourHorsemen = MosDefBossModule:new({
    name = "Baron Rivendare",
    onStart = function(self)
        self.lastMoveTime = 0
        AI.DISABLE_CDS = true
        AI.DISABLE_THREAT_MANAGEMENT = true
        AI.ResetMoveToPosition()
        if AI.IsTank() then
            AI.SetMoveToPosition(self.tankX, self.tankY)
        elseif AI.IsHealer() then
            AI.ALLOW_AUTO_REFACE = false
            AI.SetMoveToPosition(self.healerStartX, self.healerStartY)
        else
            local class = AI.GetClass():lower()
            if AI.IsWarlock() then
                AI.SetMoveToPosition(self.ws1X, self.ws1Y)
            elseif AI.IsPriest() then
                AI.SetMoveToPosition(self.ss1X, self.ss1Y)
            else
                AI.SetMoveToPosition(self.ms1X, self.ms1Y)
            end
        end
        oldPriorityTargetFn = AI.do_PriorityTarget
        AI.do_PriorityTarget = function()
            if AI.IsTank() then
                TargetUnit("Baron Rivendare")
                if not AI.IsValidOffensiveUnit("target") or self.baronDead then
                    TargetUnit("Thane")
                end
            elseif AI.IsDps() then
                local distToCaster = AI.GetDistanceTo(self.dpsSharedSpotX, self.dpsSharedSpotY)
                local distToTank = AI.GetDistanceTo(self.tankX, self.tankY)
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
    onUpdate = function(self)
        if AI.IsValidOffensiveUnit("target") and AI.GetUnitHealthPct("target") < 99 and AI.DISABLE_CDS then
            AI.DISABLE_CDS = false
        end

        if AI.IsTank() and AI.GetUnitHealthPct() < 50 then
            AI.UseInventorySlot(13)
            AI.UseInventorySlot(14)
        end

        if AI.IsDps() and AI.GetDebuffDuration("mark of zeliek") <= 7 and not AI.HasMoveToPosition() and self.baronDead and
            not self.sirDead then
            local distToCaster = AI.GetDistanceTo(self.dpsSharedSpotX, self.dpsSharedSpotY)
            local distToTank = AI.GetDistanceTo(self.tankX, self.tankY)
            if distToTank < distToCaster then
                AI.SetMoveToPosition(self.dpsSharedSpotX, self.dpsSharedSpotY)
            end
        end

        if AI.IsHeroicRaidOrDungeon() and AI.IsPriest() and self.ladyDead and AI.GetUnitHealthPct(AI.Config.healer) <=
            50 and not AI.HasDebuff("weakened soul", AI.Config.healer) and
            AI.CastSpell("power word: shield", AI.Config.healer) then
            return true
        end

        if AI.IsShaman() and AI.IsDps() then
            if AI.IsValidOffensiveUnit("target") and AI.IsCasting("target") and AI.CanHitTarget("target") and
                AI.CastSpell("wind shear", "target") then
                return true
            end
            if self.ladyDead and AI.CastSpell("grounding totem") then
                return true
            end
        end
    end,
    tankX = 0.31262734532356,
    tankY = 0.67970395088196,
    healerStartX = 0.31858479976654,
    healerStartY = 0.68796998262405,
    ws1X = 0.35628947615623,
    ws1Y = 0.71463131904602,
    ws2X = 0.3552134335041,
    ws2Y = 0.72276091575623,
    ws3X = 0.35360595583916,
    ws3Y = 0.73163449764252,
    ws4X = 0.35400208830833,
    ws4Y = 0.7398596405983,
    ms1X = 0.34758281707764,
    ms1Y = 0.72168546915054,
    ms2X = 0.3444185256958,
    ms2Y = 0.72977632284164,
    ms3X = 0.34375894069672,
    ms3Y = 0.7402783036232,
    ms4X = 0.34328207373619,
    ms4Y = 0.74799561500549,
    ss1X = 0.35061359405518,
    ss1Y = 0.71677279472351,
    ss2X = 0.34993267059326,
    ss2Y = 0.72615784406662,
    ss3X = 0.34892436861992,
    ss3Y = 0.73521333932877,
    ss4X = 0.34841755032539,
    ss4Y = 0.74378019571304,
    dpsSharedSpotX = 0.34718710184097,
    dpsSharedSpotY = 0.73557162284851,
    nextDpsSpot = 2,
    baronDead = false,
    ladyDead = false,
    thaneDead = false,
    sirDead = false,
    lastMoveTime = 0,
    movementFn = coroutine.create(function(bossMod)
        while true do
            if bossMod.nextDpsSpot == 2 then
                if AI.IsWarlock() then
                    AI.SetMoveToPosition(bossMod.ws2X, bossMod.ws2Y)
                elseif AI.IsPriest() then
                    AI.SetMoveToPosition(bossMod.ss2X, bossMod.ss2Y)
                else
                    AI.SetMoveToPosition(bossMod.ms2X, bossMod.ms2Y)
                end
                bossMod.nextDpsSpot = 3
            elseif bossMod.nextDpsSpot == 3 then
                if AI.IsWarlock() then
                    AI.SetMoveToPosition(bossMod.ws3X, bossMod.ws3Y)
                elseif AI.IsPriest() then
                    AI.SetMoveToPosition(bossMod.ss3X, bossMod.ss3Y)
                else
                    AI.SetMoveToPosition(bossMod.ms3X, bossMod.ms3Y)
                end
                bossMod.nextDpsSpot = 4
            elseif bossMod.nextDpsSpot == 4 then
                if AI.IsWarlock() then
                    AI.SetMoveToPosition(bossMod.ws4X, bossMod.ws4Y)
                elseif AI.IsPriest() then
                    AI.SetMoveToPosition(bossMod.ss4X, bossMod.ss4Y)
                else
                    AI.SetMoveToPosition(bossMod.ms4X, bossMod.ms4Y)
                end
                bossMod.nextDpsSpot = 2
            end
            coroutine.yield()
        end
    end)
})

function fourHorsemen:UNIT_DIED(unit)
    local deadUnitName = unit:lower()
    -- print("Unit DIED ", deadUnitName)
    if MaloWUtils_StrContains(deadUnitName, "lady") then
        self.ladyDead = true
        AI.DISABLE_CDS = false
        if AI.IsDps() then
            -- if not AI.IsShaman() then
            --     AI.SetMoveToPosition(self.healerStartX, self.healerStartY)
            -- else
            --     AI.SetMoveToPosition(self.ms1X, self.ms1Y)
            --     self.nextDpsSpot = 2
            -- end
            AI.SetMoveToPosition(self.healerStartX, self.healerStartY)
        end
    elseif MaloWUtils_StrContains(deadUnitName, "baron") then
        self.baronDead = true
        if AI.IsDps() then
            local class = AI.GetClass():lower()
            if AI.IsPriest() then
                AI.SetMoveToPosition(self.ss1X, self.ss1Y)
            elseif AI.IsWarlock() then
                AI.SetMoveToPosition(self.ws1X, self.ws1Y)
            else
                AI.SetMoveToPosition(self.ms1X, self.ms1Y)
            end
            self.nextDpsSpot = 2
        end
    elseif MaloWUtils_StrContains(deadUnitName, "sir") then
        self.sirDead = true
        if AI.IsDps() then
            AI.SetMoveToPosition(self.healerStartX, self.healerStartY)
        end
    end
end

function fourHorsemen:SPELL_CAST_SUCCESS(args)
    if not AI.IsDps() then
        return
    end
    local class = AI.GetClass():lower()
    local diff = GetTime() - self.lastMoveTime
    if args.target == UnitName("player") and args.spellName:lower() == "void zone" then
        -- AI.SayRaid("void zone on me!")
        self.lastMoveTime = GetTime()
        coroutine.resume(self.movementFn, self)
    end
end

-- function fourHorsemen:SPELL_DAMAGE(args)
--     if not AI.IsDps() then
--         return
--     end

--     local class = AI.GetClass():lower()
--     local diff = GetTime() - self.lastMoveTime
--     if args.target == UnitName("player") and
--         (args.spellName:lower() == "consumption" or args.caster:lower() == "void zone") and diff > 5 then

--         self.lastMoveTime = GetTime()
--         coroutine.resume(self.movementFn, self)
--     end
-- end

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
    if args.spellId == 28835 and amount >= 4 and not AI.HasMoveToPosition() and AI.IsDps() then
        -- AI.SayRaid("Too much stacks of Mark of Zeliek, moving away for a moment")
        AI.SetMoveToPosition(self.healerStartX, self.healerStartY)
    end
end

AI.RegisterBossModule(fourHorsemen)

-- THADDIUS
local thaddius = MosDefBossModule:new({
    name = "Thaddius",
    onStart = function(self)
    end,
    onStop = function(self)
    end,
    onUpdate = function(self)
        local plr = AI.GetObjectInfo("player")
        if plr:HasAura("positive charge") and AI.GetDistanceTo(self.positiveX, self.positiveY) > 3 and
            not AI.HasMoveTo() then
            AI.SetMoveToPosition(self.positiveX, self.positiveY)
        elseif plr:HasAura("negative charge") and AI.GetDistanceTo(self.negativeX, self.negativeY) > 3 and
            not AI.HasMoveTo() then
            AI.SetMoveToPosition(self.negativeX, self.negativeY)
        end
    end,
    positiveX = 0.27245682477951,
    positiveY = 0.10747250169516,
    negativeX = 0.2879327237606,
    negativeY = 0.13413137197495
})

AI.RegisterBossModule(thaddius)

-- SAPPHIRON
local sapphiron = MosDefBossModule:new({
    name = "Sapphiron",
    onStart = function(self)
        if AI.IsTank() then
            AI.ALLOW_AUTO_REFACE = false
        end
        local class = AI.GetClass()
        if class == "priest" then
            AI.CastSpell("power word: shield", AI.Config.tank)
        end
    end,
    onStop = function(self)
    end,
    onUpdate = function(self)
        if AI.IsHealer() and AI.IsShaman() and AI.CleanseRaid("Cleanse Spirit", "Curse", "Poison", "Disease") then
            return true
        end
    end
})

function sapphiron:SPELL_AURA_APPLIED(args)
    if args.spellId == 28522 then
        local target = args.target
        if UnitName("player") ~= target then
            -- local tX, tY = AI.GetPosition(target)
            -- AI.SetMoveToPosition(tX, tY, 0.009)
            -- FollowUnit(target)
        end
    end
end

AI.RegisterBossModule(sapphiron)

---
local kelthuzad = MosDefBossModule:new({
    name = "Kel'Thuzad",
    creatureId = {15990},
    frozenTarget = nil,
    mcUnit = nil,
    onStart = function(self)
        AI.AUTO_TAUNT = false
        if AI.IsTank() then
            AI.ALLOW_AUTO_REFACE = false
        end
        oldPriorityTargetFn = AI.do_PriorityTarget

        if UnitName("focus") ~= "Kel'Thuzad" then
            TargetUnit("Kel'thuzad")
            FocusUnit("target")
        end

        AI.do_PriorityTarget = function()
            if not AI.IsTank() then
                TargetUnit("Soul Weaver")
                if AI.IsValidOffensiveUnit("target") and AI.GetDistanceToUnit("target") <= 35 then
                    return true
                end
                TargetUnit("soldier of the frozen wastes")
                if AI.IsValidOffensiveUnit("target") and AI.GetDistanceToUnit("target") <= 35 then
                    return true
                end
                TargetUnit("Unstoppable Abomination")
                if AI.IsValidOffensiveUnit("target") and AI.GetDistanceToUnit("target") <= 35 then
                    return true
                end
            end
            -- TargetUnit("Kel'Thuzad")
            -- return AI.IsValidOffensiveUnit("target")
            return false
        end

        AI.PRE_DO_DPS = function(isAoE)
            if AI.IsValidOffensiveUnit("target") and UnitName("target"):lower() == "soldier of the frozen wastes" and
                AI.IsDps() then
                if AI.IsWarlock() and AI.CastSpell("searing pain", "target") then
                    return true
                end
                if AI.IsMage() and AI.CastSpell("scorch", "target") then
                    return true
                end
                if AI.IsPriest() and AI.CastSpell("mind flay", "target") then
                    return true
                end
                if AI.IsShaman() and AI.CastSpell("lightning bolt", "target") then
                    return true
                end
            end
            return false
        end
    end,
    onStop = function(self)
        AI.AUTO_TAUNT = true
        AI.ALLOW_AUTO_REFACE = true
        AI.PRE_DO_DPS = nil
        if oldPriorityTargetFn ~= nil then
            AI.do_PriorityTarget = oldPriorityTargetFn
        end
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
                if AI.IsDruid() then
                    if not AI.HasMyBuff("rejuvenation", self.frozenTarget) and
                        AI.CastSpell("rejuvenation", self.frozenTarget) then
                        return true
                    end

                    if not AI.HasMyBuff("regrowth", self.frozenTarget) and AI.CastSpell("regrowth", self.frozenTarget) then
                        return true
                    end
                    if (AI.HasMyBuff("regrowth", self.frozenTarget) or AI.HasMyBuff("rejuvenation", self.frozenTarget)) and
                        (AI.CastSpell("swiftmend") or AI.CastSpell("nourish")) then
                        return true
                    end
                end
            end
        end

        -- check for MC
        if self.mcUnit ~= nil then
            local mod = self
            if UnitName("player") ~= self.mcUnit and AI.IsDps() then
                if AI.IsWarlock() then
                    AI.RegisterPendingAction(function()
                        if not AI.HasMyDebuff("fear", mod.mcUnit) and not AI.HasDebuff("hex", mod.mcUnit) then
                            return AI.CastSpell("fear", mod.mcUnit)
                        end
                        return false
                    end, null, "CC_MC_UNIT")
                end

                AI.RegisterPendingAction(function()
                    if not AI.HasMyDebuff("hex", mod.mcUnit) and not AI.HasDebuff("fear", mod.mcUnit) then
                        return AI.CastSpell("hex", mod.mcUnit)
                    end
                    return false
                end, 3, "CC_MC_UNIT")
            end
        end
        return false
    end,
    dps1p = AI.PathFinding.Vector3.new(3733.1115722656, -5094.7192382813, 142.02334594727),
    healerp = AI.PathFinding.Vector3.new(3723.8518066406, -5124.1596679688, 142.0245513916),
    dps2p = AI.PathFinding.Vector3.new(3706.7487792969, -5090.212890625, 142.02496337891),
    dps3p = AI.PathFinding.Vector3.new(3701.0754394531, -5113.919921875, 141.34918212891)

})

function kelthuzad:SPELL_CAST_START(args)
    if args.spellName:lower() == "frostbolt" then
        AI.DoStaggeredInterrupt()
    end
end

function kelthuzad:SPELL_AURA_APPLIED(args)
    if (args.spellId == 27808 or args.spellName == "Frost Blast") and args.target ~= nil then
        self.frozenTarget = args.target
    end
    if args.spellName:lower() == "chains of kel'thuzad" then
        AI.SayRaid("MC on " .. args.target)
        self.mcUnit = args.target
    end
end

function kelthuzad:SPELL_AURA_REMOVED(args)
    if (args.spellId == 27808 or args.spellName == "Frost Blast") then
        self.frozenTarget = nil
    end
    if args.spellName:lower() == "chains of kel'thuzad" then
        self.mcUnit = nil
    end
end

function kelthuzad:CHAT_MSG_RAID_BOSS_EMOTE(arg1, arg2)
    -- print("CHAT_MSG_RAID_BOSS_EMOTE" .. arg2 .. " says " .. arg1)
    if strcontains(arg1, "strikes!") then
        TargetUnit("kel'thuzad")
        FocusUnit("target")
        if AI.IsTank() then
            AI.MustCastSpell("Hand of Reckoning", "focus")
        else
            AI.RegisterOneShotAction(function(self)
                if AI.IsHealer() then
                    AI.SetMoveToPosition(self.healerp.x, self.healerp.y)
                elseif AI.IsDpsPosition(1) then
                    AI.SetMoveToPosition(self.dps1p.x, self.dps1p.y)
                elseif AI.IsDpsPosition(2) then
                    AI.SetMoveToPosition(self.dps2p.x, self.dps2p.y)
                elseif AI.IsDpsPosition(3) then
                    AI.SetMoveToPosition(self.dps3p.x, self.dps3p.y)
                end
            end, 3)
        end
    end
end

AI.RegisterBossModule(kelthuzad)
