local rad45 = 0.785398
local rad90 = 1.570796
local rad22_5 = 0.3926991
local rad10 = 0.1745329
local rad5 = rad10 / 2
local rad025 = rad5 / 2
local pi2 = math.pi * 2
local oldPriorityTargetFn = nil

local stoneWarder = MosDefBossModule:new({
    name = "Archavon Warder",
    creatureId = {32353}
})

function stoneWarder:SPELL_AURA_APPLIED(args)
    if args.spellName:lower() == "rock shower" and args.target == UnitName("player") then
        local allies = AI.GetRaidOrPartyMemberUnits()
        for i, a in ipairs(allies) do
            if not AI.HasDebuff("rock shower", a) and not AI.HasMoveTo() then
                local ax, ay = AI.GetPosition(a)
                AI.SetMoveTo(ax, ay)
            end
        end
    end
end

AI.RegisterBossModule(stoneWarder)

--
local archavon = MosDefBossModule:new({
    name = "Archavon The Stone Watcher",
    creatureId = {31125},
    impaledTarget = nil,
    shardTarget = nil,
    onStart = function(self)
    end,
    onStop = function(self)
    end,
    onUpdate = function(self)
        if AI.IsHealer() and self.shardTarget ~= nil or self.impaledTarget ~= nil then
            if AI.GetUnitHealthPct(self.shardTarget or self.impaledTarget) <= 80 and
                AI.CastSpell("lesser healing wave", self.shardTarget or self.impaledTarget) then
                return true
            end
        end
        if AI.IsTank() and AI.HasBuff("enrage", "target") and AI.CastSpell("Hand of Reckoning", "target") then
            return true
        end
        if AI.IsShaman() and AI.IsValidOffensiveUnit() and AI.GetUnitHealthPct("target") < 90 and
            AI.CastSpell("fire elemental totem") then
            return true
        end
        return false
    end
})

function archavon:SPELL_AURA_APPLIED(args)
    if args.spellName:lower() == "rock shards" then
        self.shardTarget = args.target
    end
    if args.spellName:lower() == "impale" then
        AI.SayRaid("I'm impaled")
        self.impaledTarget = args.target
    end
end

function archavon:SPELL_AURA_REMOVED(args)
    if args.spellName:lower() == "rock shards" then
        self.shardTarget = nil
    end
    if args.spellName:lower() == "impale" then
        self.impaledTarget = nil
    end
end

AI.RegisterBossModule(archavon)

-- emalon
local emalon = MosDefBossModule:new({
    name = "Emalon the Storm Watcher",
    creatureId = {33993},
    onStart = function(self)
        -- AI.DISABLE_DRAIN = true
        if UnitName("target") ~= "Emalon the Storm Watcher" then
            TargetUnit("emalon")
        end         
    end,
    onStop = function(self)
        AI.toggleAutoDps(false)
    end,
    onUpdate = function(self)
        -- if AI.IsPriest() then
        --     if AI.IsUnitValidFriendlyTarget(AI.Config.tank) and AI.GetUnitHealthPct(AI.Config.tank) <= 50 and
        --         not AI.HasDebuff("weakened soul", AI.Config.tank) and AI.CastSpell("power word: shield", AI.Config.tank) then
        --         return true
        --     end
        -- end
    end
})

function emalon:CHAT_MSG_RAID_BOSS_EMOTE(s, t)
    if strcontains(s, "overcharges") then
        if AI.IsTank() and AI.GetUnitHealthPct("target") > 10 then
            AI.RegisterOneShotAction(function(self)
                local minions = AI.FindNearbyUnitsByName("tempest minion")
                for i, o in ipairs(minions) do
                    if o:HasAura("overcharged") then
                        o:Target()
                        SetRaidTarget("target", 1)
                        AI.SendAddonMessage('set-focused-target', o.guid)
                    end
                end
            end, 1)
        end
    end
end
function emalon:SPELL_CAST_START(args)
    if not AI.IsTank() and args.spellName:lower() == "lightning nova" then
        if UnitName("target") ~= "Emalon the Storm Watcher" then
            TargetUnit("emalon")
        end
        local p = AI.PathFinding.FindSafeSpotWithinRadiusCorridor("target", 21, 25)
        AI.SetMoveTo(p.x, p.y)
    end
end

AI.RegisterBossModule(emalon)

local koralon = MosDefBossModule:new({
    name = "Koralon the Flame Watcher",
    creatureId = {35013},
    onStart = function(self)
        if AI.IsHeroicRaidOrDungeon() and not AI.HasBuff("lesser flask of resistance") and not AI.IsTank() then
            AI.UseContainerItem("lesser flask of resistance")
        end
        AI.Config.startHealOverrideThreshold = 95
        if not AI.IsValidOffensiveUnit() then
            TargetUnit("koralon")
        end        
        if AI.IsTank() then
            AI.RegisterOneShotAction(function(self)
                AI.MustCastSpell("hand of salvation", AI.GetPrimaryHealer())
            end, 1)
        end        
    end,
    onStop = function(self)
        AI.toggleAutoDps(false)
    end,
    onUpdate = function(self)
        if AI.HasDebuff("flaming cinder") and not AI.HasMoveTo() and not AI.IsTank() then
            local p = self:findSafeSpot()
            -- print("safe spot "..table2str(p))
            if p then
                AI.SetMoveTo(p.x, p.y)
            end
        end
    end
})

function koralon:findSafeSpot()
    local tankX, tankY = AI.GetPosition(AI.GetPrimaryTank())
    local cinders = AI.FindNearbyDynamicObjects("flaming cinder")
    -- print(table2str(cinders))
    for i, c in ipairs(cinders) do
        c.radius = c.radius * 2
    end
    if not AI.IsHealer() then
        local healer = AI.GetObjectInfo(AI.GetPrimaryHealer())
        healer.radius = 6
        table.insert(cinders, healer)
    end
    local p = AI.PathFinding.FindSafeSpotInCircle(AI.GetPrimaryTank(), 11, cinders)
    return p;
end

function koralon:SPELL_AURA_APPLIED(args)
    if strcontains(args.spellName, "meteor fists") then
        if AI.IsDps() and not AI.HasMoveTo() then
            local x, y = AI.GetPosition(AI.GetPrimaryTank())
            if AI.GetDistanceTo(x, y) > 11 then
                local p = self:findSafeSpot()
                if p then
                    AI.SetMoveTo(p.x, p.y)
                end
            end
        end
    end
end

function koralon:SPELL_AURA_REMOVED(args)
    -- if strcontains(args.spellName, "meteor fists") then
    --     self.meteorFistsTarget = nil
    -- end
end

function koralon:SPELL_DAMAGE(args)
    if args.spellName:lower() == "meteor fists" then
        if AI.IsDps() and not AI.HasMoveTo() then
            local x, y = AI.GetPosition(AI.GetPrimaryTank())
            if AI.GetDistanceTo(x, y) > 11 then
                local p = self:findSafeSpot()
                if p then
                    AI.SetMoveTo(p.x, p.y)
                end
            end
        end
        -- if AI.IsPriest() then
        --     AI.MustCastSpell("power word: shield", args.target)
        -- end   
    end
end

AI.RegisterBossModule(koralon)

local toravon = MosDefBossModule:new({
    name = "Toravon the Ice Watcher",
    creatureId = {38433},
    onStart = function(self)
        if AI.IsHeroicRaidOrDungeon() and not AI.HasBuff("lesser flask of resistance") and not AI.IsTank() then
            AI.UseContainerItem("lesser flask of resistance")
        end        
        AI.Config.startHealOverrideThreshold = 95
    end,
    onStop = function(self)
        AI.do_PriorityTarget = nil
    end,
    onUpdate = function(self)
        if AI.IsPriest() then
            if AI.IsUnitValidFriendlyTarget(AI.Config.tank) and AI.GetUnitHealthPct(AI.Config.tank) <= 30 and
                not AI.HasDebuff("weakened soul", AI.Config.tank) and AI.CastSpell("power word: shield", AI.Config.tank) then
                return true
            end
        end
    end
})

AI.RegisterBossModule(toravon)
