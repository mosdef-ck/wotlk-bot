local oldPriorityTargetFn = nil

local stoneWarder = MosDefBossModule:new({
    name = "Archavon Warder",
    creatureId = {32353}
})

function stoneWarder:SPELL_AURA_APPLIED(args)
    if not AI.IsTank() and args.target == UnitName("player") and args.spellName:lower() == "rock shower" then
        for i, unit in ipairs(AI.GetRaidOrPartyMemberUnits()) do
            if UnitIsPlayer(unit) and not AI.HasDebuff("rock shower", unit) and not AI.IsTanking(unit, "target") then
                AI.SetMoveToPosition(AI.GetPosition(unit))
                break
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
        AI.DISABLE_DRAIN = true
    end,
    onEnd = function(self)
        AI.DISABLE_DRAIN = false
    end,
    onUpdate = function(self)
        if AI.IsPriest() then
            if AI.IsUnitValidFriendlyTarget(AI.Config.tank) and AI.GetUnitHealthPct(AI.Config.tank) <= 50 and
                not AI.HasDebuff("weakened soul", AI.Config.tank) and AI.CastSpell("power word: shield", AI.Config.tank) then
                return true
            end
        end
    end
})

function emalon:SPELL_AURA_APPLIED(args)
    if args.spellName:lower() == "Overcharged" then
        TargetUnit(args.target)
        FocusUnit("target")
    end
end

AI.RegisterBossModule(emalon)
