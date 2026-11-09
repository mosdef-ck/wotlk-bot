local lichking = MosDefBossModule:new({
    name = "The Lich King",
    creatureId = {36597},
    onStart = function(self)
        AI.FocusUnit("the lich king")
        AI.Config.startHealOverrideThreshold = 90
        AI.do_PriorityTarget = function()
            if not AI.IsTank() then
                if AI.IsPriest() then
                    AI.DoTargetChain("ice sphere", "Val'kyr Shadowguard")
                else
                    AI.DoTargetChain("Val'kyr Shadowguard")
                end
                return AI.IsValidOffensiveUnit() and AI.GetDistanceToUnit("target") <= 40
            end
        end

        AI.PRE_DO_DPS = function(self)
            if AI.IsValidOffensiveUnit() and strcontains(UnitName("target"), "shadowguard") then
                if AI.IsPaladin() and AI.CastSpell("hammer of justice", "target") then
                    return true
                end
            end
        end

        if AI.IsHeroicRaidOrDungeon() and not AI.HasBuff("lesser flask of resistance") and not AI.IsTank() then
            AI.UseContainerItem("lesser flask of resistance")
        end
        AI.Config.judgementToUse = "judgement of light"
        -- AI.Config.useHealingWaveOnToons = true
    end,
    onStop = function(self)
    end,
    onUpdate = function(self)
        if AI.Config.enableSpeedHacks and AI.GetRunSpeed() < AI.Config.targetSpeed then
            AI.SetRunSpeed(AI.Config.targetSpeed)
            AI.SetFlySpeed(AI.Config.targetSpeed)
        end

        -- Handle Necrotic Plague mechanic: if we have the plague and we're near LK ads, request cleanse from nearby healers or paladins. If there's no LK ads nearby, request cleanse if we're far away from allies to prevent plague from spreading.
        if UnitName("player") == self.plagueTarget and GetTime() > self.nextRequestForCleanse then
            if self:IsCloseToAds() then
                print("i'm close to ads, requesting cleanse")
                AI.SendAddonMessage("cleanse-me")
                self.nextRequestForCleanse = GetTime() + 30
            else
                local allies = AI.GetRaidOrPartyMemberUnits()
                for _, ally in ipairs(allies) do
                    if AI.GetDistance3DToUnit(ally) <= 10 then
                        self.nextRequestForCleanse = GetTime() + 5
                        break
                    end
                end
                print("i'm far from allies, requesting cleanse")
                AI.SendAddonMessage("cleanse-me")
                self.nextRequestForCleanse = GetTime() + 30
            end
        end
        if not self.p2 and AI.GetUnitHealthPct("focus") <= 70 and strcontains(UnitName("focus"), "lich king") then
            print("entering phase 2")
            self.p2 = true
            if not AI.IsTank() then
                AI.RegisterPendingAction(function(self)
                    if not AI.IsCasting() then
                        local p = AI.PathFinding.Vector3.new(AI.GetPosition(AI.GetPrimaryTank()))
                        AI.PathFinding.MoveSafelyTo(p, self:GetObstacles())
                        return true
                    end
                    return false
                end)
            end
        end
    end,
    arenaCenterP = AI.PathFinding.Vector3.new(506.75491333008, -2126.1564941406, 840.85711669922),
    arenaRadiusStart = 68,
    arenaRadiusEnd = 43,
    plagueTarget = nil,
    nextRequestForCleanse = 0,
    p2 = false
})

function lichking:IsCloseToAds()
    local ads = AI.FindNearbyUnitsByName("drudge ghoul", "shambling horror")
    for _, ad in ipairs(ads) do
        if not ad.isDead and ad.distance <= 10 then
            return true
        end
    end
    return false
end

function lichking:ON_ADDON_MESSAGE(from, cmd, args)
    if strcontains(cmd, "cleanse-me") and (AI.IsPaladin() or AI.IsHealer()) then
        -- print("received cleanse request from " .. from)
        local spell = AI.IsPaladin() and "cleanse" or "cleanse spirit"
        AI.RegisterPendingAction(function(self)
            local result = AI.CleanseFriendly(spell, from, "disease")
            if result then
                print("cleansing " .. from .. " with " .. spell)
                AI.SendAddonMessage("clear-necrotic-plague", from)
            end
            return result
        end)
    end
    if strcontains(cmd, "clear-necrotic-plague") then
        print("received clear plague message, clearing plague target: " .. args)
        if UnitName("player") == args and not AI.IsHealer() then
            local p = AI.PathFinding.Vector3.new(AI.GetPosition(AI.GetPrimaryHealer()))
            AI.PathFinding.MoveSafelyTo(p, self:GetObstacles())
            print("moving back to healer after cleanse")
        end
        self.plagueTarget = nil
    end
    if strcontains(cmd, "dodge-shadow-trap") and AI.IsDps() then
        local x, y, z = strsplit(",", args)
        print("dodging shadow trap: " .. x .. ", " .. y .. ", " .. z)
        -- local p = AI.PathFinding.Vector3.new(tonumber(x), tonumber(y), tonumber(z))
        AI.SetMoveTo(x, y)
    end
    if strcontains(cmd, "dodge-defile") and AI.IsDps() then
        local x, y, z = strsplit(",", args)
        print("dodging defile: " .. x .. ", " .. y .. ", " .. z)
        -- local p = AI.PathFinding.Vector3.new(tonumber(x), tonumber(y), tonumber(z))
        AI.SetMoveTo(x, y)
    end
end

function lichking:GetObstacles()
    local traps = AI.FindNearbyUnitsByName(39137, "shadow trap", "defile")
    for i, trap in ipairs(traps) do
        trap.radius = 10
        if strcontains(trap.name, "defile") then
            trap.radius = 15
        end
    end
    return traps
end

function lichking:SMSG_SPELL_CAST_START2(args)
    if strcontains(args.spellName, "defile") and UnitName("player") == args.target then
        print("moving to prepare for defile")
        local obstacles = self:GetObstacles()
        local allies = AI.GetAlliesAsObstacles(40)
        for _, ally in ipairs(allies) do
            table.insert(obstacles, ally)
        end
        local p = AI.PathFinding.FindSafeSpotWithinRadiusCorridor(self.arenaCenterP, self.arenaRadiusEnd - 2,
            self.arenaRadiusEnd, obstacles, 0)
        if p then
            if AI.PathFinding.MoveSafelyTo(p, obstacles) then
                print("safely moved to prepare for defile")
            else
                print("unsafe moving to prepare for defile")
                AI.SetMoveTo(p.x, p.y)
            end
        end
    end
end

function lichking:SMSG_SPELL_CAST_GO2(args)
    local caster = args.caster
    if (strcontains(args.spellName, "summon shadow trap") and args.spellId == 73540) and AI.IsHealer() then
        AI.RegisterOneShotAction(function(self)
            local obstacles = self:GetObstacles()
            -- local p = AI.PathFinding.FindSafeSpotInCircle(self.arenaCenterP, self.arenaRadiusEnd, obstacles, 2)
            local p = AI.PathFinding.FindSafeSpotInCircle(AI.GetPrimaryTank(), 15, obstacles, 1)
            -- AI.PathFinding.MoveSafelyTo(p, obstacles)
            AI.SetMoveTo(p.x, p.y)
            AI.SendAddonMessage("dodge-shadow-trap", p.x, p.y, p.z)
            print("dodging shadow trap")
        end, 2, "DODGE_SHADOW_TRAP")
    end
    if (strcontains(args.spellName, "defile") and args.spellId == 72762) and AI.IsHealer() then
        AI.RegisterOneShotAction(function(self)
            local obstacles = self:GetObstacles()
            local target = args.target
            local p = AI.PathFinding.Vector3.new(AI.GetPosition(target))
            p.radius = 15
            table.insert(obstacles, p)
            local p = AI.PathFinding.FindSafeSpotInCircle(AI.GetPrimaryTank(),  10, obstacles, 1)
            AI.SetMoveTo(p.x, p.y)
            AI.SendAddonMessage("dodge-defile", p.x, p.y, p.z)
            print("dodging defile")
        end, 0.2, "DODGE_DEFILE")
    end
    if strcontains(args.spellName, "necrotic plague") then
        self.plagueTarget = args.target
        print("necrotic plague on: " .. args.target)
        if UnitName("player") == args.target then
            -- if alrdy close to ads, request cleanse. otherwise move close to tank to spread plague and then request cleanse
            if self:IsCloseToAds() then
                print("i'm close to ads, requesting cleanse")
                AI.SendAddonMessage("cleanse-me")
                self.nextRequestForCleanse = GetTime() + 30
                return
            end
            local p = AI.PathFinding.FindSafeSpotInCircle(AI.GetPrimaryTank(), 10, self:GetObstacles(), 2)
            print("moving to tank to spread plague")
            AI.SetMoveTo(p.x, p.y, p.z, 0, function(self)
                AI.SendAddonMessage("cleanse-me")
                self.nextRequestForCleanse = GetTime() + 30
            end)
        end
    end

    if strcontains(args.spellName, "quake") then
        if not AI.IsTank() then
            AI.RegisterPendingAction(function(self)
                if #(AI.FindNearbyUnitsByName("ice sphere")) > 0 then
                    return false
                end
                print("moving to center")
                AI.StopCasting()
                AI.StopMoving()
                AI.SetMoveTo(self.arenaCenterP.x, self.arenaCenterP.y)
                return true
            end, 0, "MOVE_TO_CENTER")
        end
    end

    if strcontains(args.spellName, "summon val'kyr") and not AI.IsTank() then
        print("valkyre coming")
        AI.SetFlying(1)
    end
    if strcontains(args.spellName, "eject all") and not AI.IsTank() then
        print("valkyre has ejected passsenger")
        AI.SetFlying(1)
    end

    if strcontains(args.spellName, "soul reaper") then
        print("soul reaper on tank")
        if AI.IsPriest() then
            AI.MustCastSpell("power word: shield", args.target)
        end
        if AI.IsHealer() then
            AI.MustCastSpell("nature's swiftness")
            AI.MustCastSpell("tidal force")
        end
        if AI.IsTank() then
            if AI.CanCastSpell("hand of salvation", args.target, true) then
                AI.MustCastSpell("hand of salvation", args.target)
            elseif AI.CanCastSpell("divine protection", args.target, true) then
                AI.MustCastSpell("divine protection")
            end
        end
    end

    if strcontains(caster, "lich") or strcontains(caster, "val'kyr") then
        local ignores =
            {"summon drudge", "summon shadow trap", "remorseless winter", "pain and suffering", "summon ice"}
        for _, ignore in ipairs(ignores) do
            if strcontains(args.spellName, ignore) then
                return
            end
        end
        print("smsg_go spell: " .. args.spellName .. " spellId: " .. args.spellId)
    end
end

function lichking:SPELL_AURA_APPLIED(args)
    -- if strcontains(args.spellName, "infest") then
    --     print("infest on: " .. args.target)
    --     self.infestTarget = args.target
    -- end

    if strcontains(args.spellName, "enrage") then
        -- print("shambling horror enraged")
        if AI.IsTank() then
            local horrors = AI.FindNearbyUnitsByName("shambling horror")
            for _, horror in ipairs(horrors) do
                if horror:HasAura("enrage") then
                    horror:Focus()
                    break
                end
            end
            AI.MustCastSpell("hand of reckoning", "focus")
        end
    end
end
function lichking:SPELL_AURA_REMOVED(args)
    if strcontains(args.spellName, "infest") then
        self.infestTarget = nil
    end
    if strcontains(args.spellName, "enrage") then
        print("shambling horror enraged removed")
        AI.FocusUnit("the lich king")
    end
end

function lichking:CHAT_MSG_MONSTER_YELL(s, t)

end

AI.RegisterBossModule(lichking)

