local oldPriorityTargetFn = nil
local rad30 = 0.5235988
local rad22_5 = 0.3926991
local rad10 = 0.1745329
local rad5 = 0.08726646
local pi2 = math.pi * 2
local pi = math.pi
local rad45 = 0.785398
local rad90 = 1.570796
local rad100 = 1.745329
local rad120 = 2.094395
local rad135 = 2.356194

local gormok = MosDefBossModule:new({
    name = "Gormok the Impaler",
    creatureId = {34796},
    onStart = function(self)
        AI.Config.startHealOverrideThreshold = 95
        TargetUnit("gormok")
        FocusUnit("target")
        AI.Config.manaTideThreshold = 20
        AI.do_PriorityTarget = function()
            if AI.IsDps() then
                return AI.DoTargetChain("snobold", "gormok")
            end
            return false
        end
        AI.PRE_DO_DPS = function(isAoE)
            if AI.IsDps() then
                if GetTime() < self.stompTime + 1 then
                    return true
                end

                if self:IsSnobolled() then
                    if AI.IsValidOffensiveUnit("target") and not AI.HasMoveTo() then
                        AI.SetFacingUnit("target")
                        if AI.IsWarlock() and
                            AI.DoCastSpellChain("target", "corruption", "curse of agony", "drain life") then
                            return true
                        end
                        if AI.IsPriest() and
                            AI.DoCastSpellChain("target", "shadow word: pain", "devouring plague", "mind flay") then
                            return true
                        end
                        if AI.IsMage() and
                            AI.DoCastSpellChain("target", "living bomb", "fire blast", "dragon's breath",
                                "cone of cold", "ice lance") then
                            return true
                        end
                    end
                end

                if AI.IsValidOffensiveUnit("target") and AI.GetDistanceToUnit("target") > 35 and not AI.HasMoveTo() then
                    local obstacles = self:GetFirebombs()
                    local gormork = AI.GetObjectInfo("focus")
                    gormork.radius = 16
                    table.insert(obstacles, gormork)
                    local p = AI.PathFinding.FindSafeSpotInCircle("target", 30, obstacles, 1)
                    if p then
                        if not AI.PathFinding.MoveSafelyTo(p, obstacles) then
                            print("no safe path to reach vassal")
                        end
                    else
                        print('no safe spot to reach vassal')
                    end
                end
            end
            return false
        end

        if AI.IsHeroicRaidOrDungeon() and not AI.IsTank() then
            if AI.IsDps() then
                if not AI.HasBuff("flask of the frost wyrm") then
                    AI.UseContainerItem("flask of the frost wyrm")
                end
            else
                if not AI.HasBuff("lesser flask of resistance") then
                    AI.UseContainerItem("lesser flask of resistance")
                end
            end
        end

    end,
    onStop = function(self)
        AI.do_PriorityTarget = nil
        AI.PRE_DO_DPS = nil
    end,
    onUpdate = function(self)
        if not AI.IsTank() then
            if GetTime() <= self.stompTime + 1 then
                return true;
            end
            if not strcontains(UnitName("focus"), "gormok") then
                TargetUnit("gormok")
                FocusUnit("target")
            end

            if AI.IsValidOffensiveUnit("focus") then
                AI.DISABLE_CDS = AI.GetUnitHealthPct("focus") > 60
            end

            if self:IsSnobolled() and AI.GetDistanceTo(self.centerP.x, self.centerP.y) > 10 and not AI.HasMoveTo() and
                not AI.IsCasting() then
                -- print("i have snobolled aura, moving to tank")
                local p = AI.PathFinding.FindSafeSpotWithinRadiusCorridor(self.centerP, 1, 10, self:GetFirebombs(true))
                if not p then
                    p = AI.PathFinding.FindSafeSpotWithinRadiusCorridor(self.centerP, 1, 10, self:GetFirebombs(true))
                    if not p then
                        p = AI.PathFinding
                                .FindSafeSpotWithinRadiusCorridor(self.centerP, 1, 10, self:GetFirebombs(true))
                    end
                end
                if p then
                    AI.SetMoveTo(p.x, p.y)
                else
                    print('no safe spot to kite vassal to')
                end
            end

            if AI.IsValidOffensiveUnit("focus") and AI.GetDistanceToUnit("focus") < 16 and not AI.HasMoveTo() and
                not self:IsSnobolled() and not AI.IsCasting() and GetTime() > self.lastAdjustTime + 10 then
                print("too close to gormok, moving away")
                local p
                -- if AI.IsHealer() then

                -- else
                --     p = AI.PathFinding.Vector3.new(AI.GetPosition(AI.GetPrimaryHealer()))
                -- end
                p = self:FindSafeSpot()
                if p then
                    AI.SetMoveTo(p.x, p.y)
                    self.lastAdjustTime = GetTime()
                else
                    print("no safe spot in corridor window");
                end
            end

        end

    end,
    stompTime = 0,
    centerP = AI.PathFinding.Vector3.new(563.60998535156, 139.43699645996, 393.90866088867),
    lastAdjustTime = 0,
    acidMawStartP = AI.PathFinding.Vector3.new(537.25640869141, 144.97256469727, 394.55151367188)
})

function gormok:UNIT_DIED(unit)
    if strcontains(unit, "gormok") then
        print("gormok is dead, ending module")
        self:onStop()
        self.enabled = false
    end
end

function gormok:GetFirebombs(ignoreGormok)
    local obstacles = AI.FindNearbyUnitsByName("fire bomb")
    -- for i = #obstacles, 1, -1 do
    --     if not obstacles[i]:HasAura(66318) then
    --         table.remove(obstacles, i)
    --     end
    -- end
    for i, o in ipairs(obstacles) do
        o.radius = 8.5
    end
    if not ignoreGormok then
        local gormork = AI.GetObjectInfo("focus")
        if gormok then
            gormork.radius = 15
            table.insert(obstacles, gormork)
        end
    end
    return obstacles
end

function gormok:GetClosestFireBomb()
    local obstacles = AI.FindNearbyUnitsByName("fire bomb")
    return #obstacles > 0 and obstacles[1] or nil
end

function gormok:FindSafeSpot(includeStartPosition)
    local obstacles = self:GetFirebombs()
    if includeStartPosition then
        local x, y, z = AI.GetPosition("player")
        local p = AI.PathFinding.Vector3.new(x, y, z)
        p.radius = 8.5
        table.insert(obstacles, p)
    end
    local p
    if self:IsSnobolled() then
        p = AI.PathFinding.FindSafeSpotWithinRadiusCorridor(self.centerP, 1, 7, self:GetFirebombs(true), 2)
    else
        p = AI.PathFinding.FindSafeSpotWithinRadiusCorridor(self.centerP, 17, 20, obstacles, 2)
        if not p then
            p = AI.PathFinding.FindSafeSpotWithinRadiusCorridor(self.centerP, 17, 20, obstacles, 2)
        end
    end
    return p
end

function gormok:SPELL_DAMAGE(args)
    if strcontains(args.spellName, "staggering stomp") then
        AI.StopMoving()
    end
    if not AI.IsTank() and strcontains(args.spellName, "fire bomb") and self:IsSnobolled() and not AI.HasMoveTo() then
        local p = AI.PathFinding.FindSafeSpotWithinRadiusCorridor(self.centerP, 1, 10, self:GetFirebombs(true), 2)
        if p then
            AI.SetMoveTo(p.x, p.y)
        end
    end
end

function gormok:IsSnobolled()
    local plrInfo = AI.GetObjectInfo("player")
    if AI.HasDebuff("snobolled!") or plrInfo:HasAura(66406) then
        return true
    end
    local vassals = AI.FindNearbyUnitsByName("vassal")
    for i, v in ipairs(vassals) do
        if not v.isDead and v.targetGUID == UnitGUID("player") then
            return true
        end
    end
    return false
end

function gormok:SPELL_AURA_APPLIED(args)
    if not AI.IsTank() and strcontains(args.spellName, "fire bomb") and args.target == UnitName("player") and
        not AI.HasMoveTo() then
        -- print("fire bomb on me")
        local fireBomb = self:GetClosestFireBomb()
        if fireBomb and fireBomb.distance <= 8.5 then
            local p = self:FindSafeSpot()
            if p then
                AI.SetMoveTo(p.x, p.y)
            end
        end
    end
end

function gormok:SMSG_SPELL_CAST_START(spellId, spellName, casterGuid, targetGuid, src, dest)
    if strcontains(spellName, "fire bomb") and not AI.IsTank() then
        -- print("casting fire bomb")
        AI.RegisterOneShotAction(function(self)
            local fireBomb = self:GetClosestFireBomb()
            if fireBomb and fireBomb.distance <= 8.5 then
                print("fire bomb incoming")
                local p = self:FindSafeSpot(true)
                if p then
                    AI.SetMoveTo(p.x, p.y)
                else
                    print('no safe spot from fire bomb')
                end
            end
        end, 0.2)
        -- AI.SendAddonMessage("move-to", p.x, p.y, p.z)
    end
    if strcontains(spellName, "staggering stomp") then
        -- print("gormok is casting staggering stomp")
        self.stompTime = GetTime()
        if not AI.IsTank() then
            if AI.HasMoveTo() then
                AI.ResetMoveTo()
                AI.StopMoving()
            end
            if AI.GetDistanceToUnit("focus") < 22 then
                AI.StopCasting()
            end
        end
    end
end

function gormok:SMSG_SPELL_CAST_GO(spellId, spellName, casterGuid, targetGuid, src, dest)
    -- if strcontains(args.spellName, "staggering stomp") then
    --     -- print("gormok is casting staggering stomp")
    --     self.stompTime = GetTime()
    --     if not AI.IsTank() then
    --         if AI.HasMoveTo() then
    --             AI.ResetMoveTo()
    --             AI.StopMoving()
    --         end
    --         if AI.GetDistanceToUnit("focus") < 22 then
    --             AI.StopCasting()
    --         end
    --     end
    -- end
end

function gormok:ON_ADDON_MESSAGE(from, cmd, params)
    if cmd == "move-to" and AI.IsDps() and not self:IsSnobolled() then
        print('moving to avoid fire bomb')
        local p = AI.PathFinding.Vector3.new(splitstr3(params, ","))
        AI.SetMoveTo(p.x, p.y)
    end
end

AI.RegisterBossModule(gormok)

local acidmaw = MosDefBossModule:new({
    name = "Acidmaw/Dreadscale",
    creatureId = {35144, 34799},
    onStart = function(self)
        AI.Config.manaTideThreshold = 20
        AI.do_PriorityTarget = function()
            if AI.IsDps() then
                return AI.DoTargetChain("acidmaw")
            end
            return false
        end
        -- if AI.IsHeroicRaidOrDungeon() and not AI.HasBuff("lesser flask of resistance") and not AI.IsTank() then
        --     AI.UseContainerItem("lesser flask of resistance")
        -- end
        AI.RegisterOneShotAction(function()
            if AI.IsDps() then
                local obstacles = AI.GetAlliesAsObstacles(15)
                local p = AI.PathFinding.FindSafeSpotInCircle(
                    AI.PathFinding.Vector3.new(AI.GetPosition(AI.GetPrimaryHealer())), 30, obstacles, 1)
                if p then
                    AI.SetMoveTo(p.x, p.y)
                end
            end
        end, 1)
    end,
    onStop = function(self)
        AI.do_PriorityTarget = nil
    end
})

function acidmaw:SPELL_AURA_APPLIED(args)
    if strcontains(args.spellName, "burning bile") and
        (args.target ~= UnitName("player") and AI.GetDistanceToUnit(args.target) <= 15) and not AI.IsTank() then
        local allies = AI.GetRaidOrPartyMemberUnits()
        local obstacles = {}
        for i, a in ipairs(allies) do
            if AI.HasDebuff("burning bile", a) then
                local info = AI.GetObjectInfo(a)
                info.radius = 10
                table.insert(obstacles, info)
            end
        end
        local p = AI.PathFinding.FindSafeSpotInCircle(args.target, 25, obstacles, 5)
        if p then
            AI.SetMoveTo(p.x, p.y)
        end
    end
end

function acidmaw:UNIT_DIED(unit)
    if strcontains(unit, "dreadscale") then
        -- print("Dreadscale is dead, ending module")
        self:onStop()
        self.enabled = false
    end
end

AI.RegisterBossModule(acidmaw)

local iceHowl = MosDefBossModule:new({
    name = "Icehowl",
    creatureId = {34797, 35470},
    onStart = function(self)
        TargetUnit("icehowl")
        FocusUnit("target")
        if AI.IsHeroicRaidOrDungeon() and not AI.IsTank() then
            if AI.IsDps() then
                if not AI.HasBuff("flask of the frost wyrm") then
                    AI.UseContainerItem("flask of the frost wyrm")
                end
            else
                if not AI.HasBuff("lesser flask of resistance") then
                    AI.UseContainerItem("lesser flask of resistance")
                end
            end
        end
        AI.Config.manaTideThreshold = 20
    end,
    onUpdate = function(self)
    end,
    onStop = function(self)
        AI.do_PriorityTarget = nil
    end,
    spotA = AI.PathFinding.Vector3.new(511.69815063477, 124.03265380859, 395.1955871582),
    spotB = AI.PathFinding.Vector3.new(511.61187744141, 155.73526000977, 395.19808959961)
})

function iceHowl:CHAT_MSG_RAID_BOSS_EMOTE(s, t)
    if strcontains(s, "glares at") and not AI.IsTank() then
        -- print("icehowl gaze emote received, moving to safe spot")
        AI.RegisterOneShotAction(function()
            local boss = AI.GetObjectInfo("focus")
            if boss then
                local victim = AI.GetObjectInfoByGUID(boss.targetGUID)
                if victim then
                    if victim.guid ~= UnitGUID(AI.GetPrimaryTank()) then
                        -- print("icehowl gaze on " .. victim.name or "n/a")
                        if AI.GetDistanceTo(self.spotA.x, self.spotA.y) <= 10 then
                            AI.SetMoveTo(self.spotB.x, self.spotB.y)
                        elseif AI.GetDistanceTo(self.spotB.x, self.spotB.y) <= 10 then
                            AI.SetMoveTo(self.spotA.x, self.spotA.y)
                        end
                    end
                else
                    -- print("icehowl targetting isn't set, extracting name from emote txt")
                    local targetName = s:match("glares at ([^%s]+)")
                    -- print("icehowl gaze on " .. targetName)
                    if targetName and not strcontains(targetName, AI.GetPrimaryTank()) then
                        if AI.GetDistanceTo(self.spotA.x, self.spotA.y) <= 10 then
                            AI.SetMoveTo(self.spotB.x, self.spotB.y)
                        elseif AI.GetDistanceTo(self.spotB.x, self.spotB.y) <= 10 then
                            AI.SetMoveTo(self.spotA.x, self.spotA.y)
                        end
                    end
                end
            end
        end, 0.5, "REACT_TO_GAZE")
    end
    if strcontains(s, "crashes") and AI.IsDps() then
        AI.UseInventorySlot(10)
        AI.UseInventorySlot(13)
        AI.UseInventorySlot(14)
    end
end

AI.RegisterBossModule(iceHowl)

local jaraxxus = MosDefBossModule:new({
    name = "Lord Jaraxxus",
    creatureId = {34780},
    onStart = function(self)
        TargetUnit("lord jaraxxus")
        FocusUnit("target")
        AI.Config.starFormationRadius = 15
        AI.Config.startHealOverrideThreshold = 90
        AI.do_PriorityTarget = function()
            if AI.IsDps() then
                return AI.DoTargetChain("nether portal", "mistress", "infernal volcano")
            elseif AI.IsTank() then
                return AI.DoTargetChain("mistress", "felflame infernal")
            end
            return false
        end
        AI.PRE_DO_DPS = function(isAoE)
            if AI.IsDps() and AI.IsValidOffensiveUnit("target") and AI.GetDistanceToUnit("target") > 35 and
                not AI.HasMoveTo() and not AI.HasDebuff("legion flame") then
                local p = AI.PathFinding.FindSafeSpotInCircle("target", 35)
                if p then
                    AI.SetMoveTo(p.x, p.y)
                end
            end
            return false
        end

        -- if AI.IsHeroicRaidOrDungeon() and not AI.HasBuff("lesser flask of resistance") and not AI.IsTank() then
        --     AI.UseContainerItem("lesser flask of resistance")
        -- end
        if AI.IsHealer() then
            AI.AUTO_CLEANSE = false
        end
        AI.AUTO_PURGE = false
        AI.DISABLE_CDS = true
    end,
    onStop = function(self)
        AI.do_PriorityTarget = nil
        AI.PRE_DO_DPS = nil
        AI.doPost_Update = nil
        AI.AUTO_PURGE = true
    end,
    onUpdate = function(self)
        if AI.IsHealer() and self.incinerateTarget then
            if UnitHealth(AI.GetPrimaryTank()) > 25000 and
                ((AI.HasBuff("tidal waves") and AI.CastSpell("healing wave", self.incinerateTarget)) or
                    AI.CastSpell("chain heal", self.incinerateTarget)) then
                return true
            end
        end
        if AI.IsHealer() and UnitHealth(AI.GetPrimaryTank()) > 30000 and
            AI.CleanseFriendly("cleanse spirit", AI.GetPrimaryTank(), "magic") then
            return true
        end
    end,
    centerP = AI.PathFinding.Vector3.new(563.57653808594, 139.72964477539, 393.90853881836),
    legionFlameKiteRadius = {35, 30, 25},
    nextLegionFlameKiteRadiusIdx = 1,
    lastFlameApplyTime = 0
})

function jaraxxus:CHAT_MSG_RAID_BOSS_EMOTE(s, t)
    if strcontains(s, "nether portal") then
        AI.RegisterOneShotAction(function()
            TargetUnit("nether portal")
            if AI.IsDps() then
                AI.UseInventorySlot(10)
                -- AI.UseInventorySlot(13)
                -- AI.UseInventorySlot(14)
            end
            if AI.IsDps() and AI.GetDistanceToUnit("target") <= 10 then
                local portal = AI.GetObjectInfo("target")
                portal.radius = 5
                local p = AI.PathFinding.FindSafeSpotWithinRadiusCorridor(self.centerP, 12, 16, {portal}, 5)
                if p then
                    AI.SetMoveTo(p.x, p.y)
                end
            end
        end, 0.5, "REACT_TO_PORTAL")
    end
    if strcontains(s, "volcano") then
        AI.RegisterOneShotAction(function()
            TargetUnit("infernal volcano")
            if AI.IsDps() then
                AI.UseInventorySlot(10)
                AI.UseInventorySlot(13)
                AI.UseInventorySlot(14)
            end
            if not AI.IsTank() and AI.GetDistanceToUnit("target") <= 10 then
                local volcano = AI.GetObjectInfo("target")
                if volcano then
                    volcano.radius = 5
                    local p = AI.PathFinding.FindSafeSpotWithinRadiusCorridor(self.centerP, 12, 16, {volcano}, 5)
                    if p then
                        AI.SetMoveTo(p.x, p.y)
                    end
                end
            end
        end, 0.5, "REACT_TO_VOLCANO")
    end
end

function jaraxxus:SPELL_CAST_START(args)
    if strcontains(args.spellName, "fel fireball") and not AI.IsHealer() then
        TargetUnit("lord jaraxxus")
        FocusUnit("target")
        AI.DoStaggeredInterrupt()
    end
end

function jaraxxus:SPELL_AURA_APPLIED(args)
    -- if strcontains(args.spellName, "nether power") and AI.IsMage() then
    --     TargetUnit("jaraxxus")
    --     FocusUnit("target")
    --     AI.MustCastSpell("spellsteal", "focus")
    -- end

    if strcontains(args.spellName, "bloodlust") then
        AI.DISABLE_CDS = false
    end

    if strcontains(args.spellName, "incinerate flesh") then
        self.incinerateTarget = args.target
    end

    if strcontains(args.spellName, "fel fireball") then
        if AI.IsPriest() then
            AI.MustCastSpell("dispel magic", args.target)
        end
    end

    if strcontains(args.spellName, "legion flame") and AI.IsDps() and GetTime() > self.lastFlameApplyTime + 5 then
        self.lastFlameApplyTime = GetTime()
        if AI.IsPriest() then
            AI.MustCastSpell("power word: shield", args.target)
        end
        if AI.IsPaladin() then
            AI.MustCastSpell("sacred shield", args.target)
        end
        if AI.IsHealer() then
            AI.MustCastSpell("riptide", args.target)
        end
        if args.target == UnitName("player") then
            if AI.IsMage() and AI.CanCastSpell("ice block", nil, true) then
                AI.MustCastSpell("ice block", nil)
                AI.RegisterOneShotAction(function()
                    CancelUnitBuff("player", "ice block")
                end, 1)
                return
            end
            local delay = strcontains(UnitName("target"), "volcano") and 2 or 1
            AI.RegisterOneShotAction(function(self)
                local x, y, z = AI.GetPosition()
                local facing = AI.CalcFacing(self.centerP.x, self.centerP.y, x, y)
                local r = self.legionFlameKiteRadius[self.nextLegionFlameKiteRadiusIdx]
                print("current legion flame kite radius: " .. r .. " idx: " .. self.nextLegionFlameKiteRadiusIdx)
                local numPoints = 16
                local stepSize = pi2 / numPoints
                local path = {}
                for i = 1, numPoints, 1 do
                    local nfacing = normalizeAngle(facing)
                    local px = self.centerP.x + r * math.cos(nfacing)
                    local py = self.centerP.y + r * math.sin(nfacing)
                    local pz = z
                    table.insert(path, AI.PathFinding.Vector3.new(px, py, pz))
                    if self.nextLegionFlameKiteRadiusIdx % 2 == 0 then
                        facing = facing - stepSize
                    else
                        facing = facing + stepSize
                    end
                end
                -- print("kiting legion flame")
                -- print("path is :"..table2str(path))
                AI.SetMoveToPath(path)
                if AI.IsWarlock() then
                    AI.MustCastSpell("shadow ward")
                end
                if AI.IsMage() then
                    AI.MustCastSpell("fire ward")
                end
                if self.nextLegionFlameKiteRadiusIdx + 1 > #self.legionFlameKiteRadius then
                    self.nextLegionFlameKiteRadiusIdx = 1
                else
                    self.nextLegionFlameKiteRadiusIdx = self.nextLegionFlameKiteRadiusIdx + 1
                end
                AI.SendAddonMessage("set-next-kite-radius", self.nextLegionFlameKiteRadiusIdx)
            end, delay, "REACT_TO_LEGION_FLAME")
        else
            local info = AI.GetObjectInfo(args.target)
            info.radius = 5
            AI.SetObjectAvoidance({
                guids = {info},
                safeDistance = 3,
                polygon = AI.PathFinding.createCircularPolygon(self.centerP, 40)
            })
        end
        -- print('next legion flame kite radius idx: ' .. self.nextLegionFlameKiteRadiusIdx)
    end
end

function jaraxxus:SPELL_DAMAGE(args)
    if not AI.IsTank() and strcontains(args.spellName, "fel streak") and args.target == UnitName("player") and
        not AI.HasMoveTo() then
        -- print('fel streak on me, moving to safe spot')
        local infernal = AI.FindNearbyUnitsByName("felflame infernal")
        if #infernal > 0 then
            infernal[1].radius = 10
            local p = AI.PathFinding.FindSafeSpotWithinRadiusCorridor(self.centerP, 12, 17, {infernal[1]}, 2)
            if p then
                AI.SetMoveTo(p.x, p.y)
            end
        end
    end
end

function jaraxxus:SPELL_AURA_REMOVED(args)
    if strcontains(args.spellName, "incinerate flesh") then
        self.incinerateTarget = nil
    end

    if strcontains(args.spellName, "legion flame") then
        -- print("legion flame removed, clearing avoidance")
        if args.target == UnitName("player") then
            local delay = (AI.HasBuff("ice block") or AI.HasBuff("hand of protection")) and 0.5 or 7
            AI.RegisterOneShotAction(function()
                local obstacles = AI.GetAlliesAsObstacles(10)
                local p = AI.PathFinding.FindSafeSpotWithinRadiusCorridor(self.centerP, 12, 17, obstacles, 5)
                if p then
                    AI.SetMoveTo(p.x, p.y)
                end
                print("moving back to battle zone")
            end, delay, "BACK_TO_BATTLEZONE")
        else
            AI.ClearObjectAvoidance()
        end
    end
end

function jaraxxus:ON_ADDON_MESSAGE(from, cmd, params)
    if cmd == 'set-next-kite-radius' then
        local idx = tonumber(params)
        if idx and idx > 0 and idx <= #self.legionFlameKiteRadius then
            self.nextLegionFlameKiteRadiusIdx = idx
            print("next legion flame kite radius index set to: " .. self.nextLegionFlameKiteRadiusIdx)
        else
            print("invalid legion flame kite radius index received: " .. params)
        end
    end
end

AI.RegisterBossModule(jaraxxus)

local factionsChampions = MosDefBossModule:new({
    name = "Factions Champions",
    creatureId = {34461, 34460, 34469, 34467, 34468, 34465, 34471, 34466, 34473, 34472, 34463, 34470, 34474, 34475},
    onStart = function(self)
        AI.Config.startHealOverrideThreshold = 95
        -- if AI.IsHealer() then
        AI.AUTO_CLEANSE = false
        AI.AUTO_PURGE = false
        -- end

        AI.do_PriorityTarget = function()
            if not AI.IsTank() then
                return AI.DoTargetChain("saamul", "melador", "velanaa", "anthar")
            end
            -- return AI.DoTargetChain("shaabad", "irieth", "alyssia", "noozle", "serissa", "kavina", "schocuul",
            -- "anthar")
            -- end
            return false
        end
        AI.PRE_DO_DPS = function(isAoE)
            -- if AI.IsDps() and AI.IsValidOffensiveUnit("target") and AI.GetDistanceToUnit("target") >= 35 and
            --     not AI.HasMoveTo() then
            --     local p = AI.PathFinding.FindSafeSpotInCircle("target", 35)
            --     if p then
            --         AI.SetMoveTo(p.x, p.y)
            --     end
            -- end
            if AI.IsDps() and AI.IsValidOffensiveUnit() and self:IsMeleeTarget(UnitName("target")) then
                local threat = AI.GetThreatPct("target")
                if threat > 90 or AI.IsTanking("player", "target") then
                    return true
                end
            end
            return false
        end

        if AI.IsTank() then
            AI.RegisterOneShotAction(function()
                -- local targets = AI.FindNearbyUnitsByName("saamul", "melador", "velanaa", "anthar")
                local targets = {"shaabad", "serissa", "noozle", "alyssia", "kavina"}
                local ccers = {"Mosdeflocka", "Mosdeffmage"}
                for i, target in ipairs(targets) do
                    local ts = AI.FindNearbyUnitsByName(target)
                    if #ts > 0 then
                        local t = ts[1]
                        if not t.isDead then
                            local guid = t.guid
                            AI.SendAddonMessage("set-cc-target", guid)
                            t:Target()
                            SetRaidTarget("target", i)
                            break
                        end
                    end
                end
            end, 1)
        end

        if AI.IsHeroicRaidOrDungeon() and not AI.HasBuff("lesser flask of resistance") and not AI.IsTank() then
            AI.UseContainerItem("lesser flask of resistance")
        end
    end,
    onStop = function(self)
        AI.do_PriorityTarget = nil
        AI.PRE_DO_DPS = nil
    end,
    onUpdate = function(self)
        if self.ccTarget then
            local ccTarget = AI.GetObjectInfoByGUID(self.ccTarget)
            if ccTarget and not ccTarget.isDead and not AI.IsUnitCC(ccTarget) and self.currentCCerOrder ==
                self:GetCCerOrder() and AI.CanCast() and UnitGUID("target") ~= ccTarget.guid then
                local spell = ternary(AI.IsWarlock(), "fear", "polymorph")
                ccTarget:Target()

                if AI.CastSpell(spell, "target") then
                    -- print('CCing ' .. UnitName('focus'))                                    
                    if self.ccCount >= 3 then
                        local nextCCer = self:GetCCerOrder()
                        if nextCCer == 2 then
                            nextCCer = 1
                        else
                            nextCCer = 2
                        end
                        AI.SendAddonMessage("set-cc-order", nextCCer)
                        self.ccCount = 0
                        self.currentCCerOrder = nextCCer
                        print("CC count reached 3, switching to next CCer: " .. nextCCer)
                    end
                    return true
                end
            end
        end

        if AI.IsCasting("target") and AI.IsDps() and self:IsHealerTarget(UnitName("target")) then
            if AI.IsWarlock() and AI.CastSpell("death coil", "target") then
                return true
            end
            AI.DoStaggeredInterrupt()
        end

        if AI.IsPriest() and self:IsHealerTarget(UnitName("target")) and  AI.HasPurgeableBuff("target") and AI.CastSpell("dispel magic", "target") then
            -- print("dispelling " .. UnitName("target"))
            return true
        end

        -- if AI.IsPriest() and AI.CleanseRaid("dispel magic", "magic") and GetTime() > self.lastCleanseTime + 5 then
        --     self.lastCleanseTime = GetTime()
        --     return true
        -- end

        -- if (AI.IsHealer() or AI.IsPriest()) and AI.IsUnitCC(AI.GetPrimaryTank()) then
        --     -- print("cleansing tank")
        --     local spell = AI.IsHealer() and "cleanse spirit" or "dispel magic"
        --     return AI.CleanseFriendly(spell, AI.GetPrimaryTank(), "magic")
        -- end

        if AI.IsMage() and AI.GetUnitHealthPct() < 20 and AI.CastSpell("ice block") then
            return true
        end

        if AI.IsPriest() and AI.GetDistanceToUnit("target") <= 9 and AI.CastSpell("psychic scream") then
            return true
        end

    end,
    ccTarget = nil,
    lastCleanseTime = 0,
    ccCount = 0,
    currentCCerOrder = 2
})

function factionsChampions:GetCCerOrder()
    if UnitName("player") == "Mosdeflocka" then
        return 1
    elseif UnitName("player") == "Mosdeffmage" then
        return 2
    end
    return nil
end

function factionsChampions:IsHealerTarget(targetName)
    local healers = {"saamul", "melador", "velanaa", "anthar"}
    for i, h in ipairs(healers) do
        if strcontains(targetName, h) then
            return true
        end
    end
    return false
end

function factionsChampions:IsMeleeTarget(targetName)
    local melee = {"tyrius", "irieth", "shaabad", "shocuul"}
    for i, m in ipairs(melee) do
        if strcontains(targetName, m) then
            return true
        end
    end
    return false
end

function factionsChampions:ON_ADDON_MESSAGE(from, cmd, params)
    if cmd == "set-cc-target" and AI.IsDps() then
        local guid = params
        self.ccTarget = guid
        print("setting CC target to " .. guid)
    end
    if cmd == "set-cc-order" and AI.IsDps() then
        local order = tonumber(params)
        if order then
            self.currentCCerOrder = order
            print("setting current CCer order to " .. order)
        end
    end
end

function factionsChampions:SPELL_AURA_APPLIED(args)
    if (strcontains(args.spellName, "heroism") or strcontains(args.spellName, "hand of protection") or
        strcontains(args.spellName, "divine shield") or strcontains(args.spellName, "ice block")) and
        not strcontains(args.target, "mosdef") and AI.IsPriest() then
        AI.RegisterPendingAction(function()
            --print("heroism or hand of protection cast on champions, dispelling")
            TargetUnit(args.target)
            return AI.CastAOESpell("mass dispel", "target")
        end, 0, "mass_dispel_" .. args.spellName)
    end

    if (strcontains(args.spellName, "polymorph") or strcontains(args.spellName, "fear") or
        strcontains(args.spellName, "hammer of justice") or strcontains(args.spellName, "silence") or
        strcontains(args.spellName, "unstable affliction") or strcontains(args.spellName, "repentance")) and
        strcontains(args.target, "mosdef") then
        -- print(args.spellName .. " applied on " .. args.target)
        if not strcontains(args.target, UnitName("player")) and (AI.IsPriest() or AI.IsHealer() or AI.IsPaladin()) then
            AI.RegisterPendingAction(function()
                local spell
                if AI.IsHealer() then
                    spell = "cleanse spirit"
                elseif AI.IsPriest() then
                    spell = "dispel magic"
                else
                    spell = "cleanse"
                end
                -- print("cleansing " .. args.target)
                return AI.CleanseFriendly(spell, args.target, "magic")
            end, 0, "cleanse_" .. args.spellName)
        end
    end

    if (strcontains(args.spellName, "fear") or strcontains(args.spellName, "polymorph")) and
        not strcontains(args.target, "mosdef") and args.caster == UnitName("player") then
        self.ccCount = self.ccCount + 1
        print("CC count increased to " .. self.ccCount)

    end
end

AI.RegisterBossModule(factionsChampions)

local essenceInteractRadius = 10
local twinValk = MosDefBossModule:new({
    name = "Twin Valkyr",
    creatureId = {34496, 34497},
    onStart = function(self)
        AI.DISABLE_CDS = true
        AI.Config.startHealOverrideThreshold = 95
        if AI.IsHeroicRaidOrDungeon() and not AI.HasBuff("lesser flask of resistance") and not AI.IsTank() then
            AI.UseContainerItem("lesser flask of resistance")
        end
        if AI.IsTank() then
            AI.ALLOW_AUTO_REFACE = false
        end
        if not AI.IsTank() then
            AI.RegisterOneShotAction(function()
                local darkEssence = AI.FindNearbyUnitsByName("dark essence")
                local lightEssence = AI.FindNearbyUnitsByName("light essence")
                local plr = AI.GetObjectInfo("player")
                if plr:HasAura('light essence') and darkEssence[1].distance > essenceInteractRadius then
                    AI.SetMoveTo(darkEssence[1].x, darkEssence[1].y)
                end
                if plr:HasAura('dark essence') and lightEssence[1].distance > essenceInteractRadius then
                    AI.SetMoveTo(lightEssence[1].x, lightEssence[1].y)
                end
            end, 5)

        end
    end,
    onStop = function(self)
        AI.do_PriorityTarget = nil
        AI.PRE_DO_DPS = nil
        AI.ALLOW_AUTO_REFACE = true
        AI.DISABLE_CDS = false
    end,
    onUpdate = function(self)
        if AI.IsHealer() and UnitHealth(AI.GetPrimaryTank()) > 25000 and self.touchedTarget and
            UnitHealth(self.touchedTarget) <= 10000 and
            ((AI.HasBuff("tidal waves") and AI.CastSpell("healing wave", self.touchedTarget)) or
                AI.CastSpell("chain heal", self.touchedTarget)) then
            return true
        end
        if AI.IsDps() and strcontains(UnitCastingInfo("target"), "twin's pact") then
            AI.UseInventorySlot(10)
            AI.UseInventorySlot(13)
            AI.UseInventorySlot(14)
        end
    end,
    pactTime = 0,
    touchedTarget = nil
})

function twinValk:SPELL_CAST_START(args)
    if strcontains(args.spellName, "twin's pact") then
        TargetUnit(args.caster)
        FocusUnit("target")
        -- print("twin's pact incoming caster: " .. args.caster)
        self.pactTime = GetTime()
        local plr = AI.GetObjectInfo("player")
        if AI.IsHealer() then
            if strcontains(args.caster, "darkbane") and not plr:HasAura("light essence") then
                local lightEssence = AI.FindNearbyUnitsByName("light essence")
                AI.SendAddonMessage("use-essence", lightEssence[1].guid)
                if lightEssence[1].distance > essenceInteractRadius then
                    AI.SayRaid("moving to light essence")
                    AI.SetMoveTo(lightEssence[1].x, lightEssence[1].y, lightEssence[1].z, 0, function()
                        print("grabbing light essence due to darkbane twin's pact casting")
                        lightEssence[1]:InteractWith()
                    end)
                else
                    print("grabbing light essence due to darkbane twin's pact casting")
                    lightEssence[1]:InteractWith()
                end
            end
            if strcontains(args.caster, "lightbane") and not plr:HasAura("dark essence") then
                local darkEssence = AI.FindNearbyUnitsByName("dark essence")
                AI.SendAddonMessage("use-essence", darkEssence[1].guid)
                if (darkEssence[1].distance > essenceInteractRadius) then
                    AI.SayRaid("moving to dark essence")
                    AI.SetMoveTo(darkEssence[1].x, darkEssence[1].y, darkEssence[1].z, 0, function()
                        print("grabbing dark essence due to lightbane twin's pact casting")
                        darkEssence[1]:InteractWith()
                    end)
                else
                    print("grabbing dark essence due to lightbane twin's pact casting")
                    darkEssence[1]:InteractWith()
                end
            end
        elseif AI.IsDps() then
            AI.RegisterPendingAction(function()
                local success = AI.UseInventorySlot(10)
                AI.UseInventorySlot(13)
                AI.UseInventorySlot(14)
                -- print("activating CDs")
                return success
            end)
        end
        -- print("big heal incoming")        
    end

    local plr = AI.GetObjectInfo("player")
    if strcontains(args.spellName, "light vortex") and not plr:HasAura("light essence") then
        local lightEssence = AI.FindNearbyUnitsByName("light essence")
        local darkEssence = AI.FindNearbyUnitsByName("dark essence")
        if AI.IsHealer() then
            AI.SendAddonMessage("use-essence", lightEssence[1].guid, darkEssence[1].guid)
            AI.RegisterPendingAction(function()
                if not AI.IsCasting() then
                    if lightEssence[1].distance > essenceInteractRadius then
                        AI.SetMoveTo(lightEssence[1].x, lightEssence[1].y, lightEssence[1].z, 0, function()
                            print("grabbing light essence")
                            lightEssence[1]:InteractWith()
                            print("got light essence, moving to dark essence position")
                            AI.SetMoveTo(darkEssence[1].x, darkEssence[1].y)
                        end)
                    else
                        lightEssence[1]:InteractWith()
                        print("got light essence, moving to dark essence position")
                        AI.SetMoveTo(darkEssence[1].x, darkEssence[1].y)
                    end
                    return true
                end
            end)
        end
    end

    if strcontains(args.spellName, "dark vortex") and not plr:HasAura("dark essence") then
        local darkEssence = AI.FindNearbyUnitsByName("dark essence")
        local lightEssence = AI.FindNearbyUnitsByName("light essence")
        if AI.IsHealer() then
            AI.SendAddonMessage("use-essence", darkEssence[1].guid, lightEssence[1].guid)
            AI.RegisterPendingAction(function()
                if not AI.IsCasting() then
                    if darkEssence[1].distance > essenceInteractRadius then
                        AI.SetMoveTo(darkEssence[1].x, darkEssence[1].y, darkEssence[1].z, 0, function()
                            darkEssence[1]:InteractWith()
                            print("got dark essence, moving to light essence position")
                            AI.SetMoveTo(lightEssence[1].x, lightEssence[1].y)
                        end)
                    else
                        darkEssence[1]:InteractWith()
                        print("got dark essence, moving to light essence position")
                        AI.SetMoveTo(lightEssence[1].x, lightEssence[1].y)
                    end
                    return true
                end
            end)
        end
    end
end

function twinValk:SPELL_AURA_APPLIED(args)
    if strcontains(args.spellName, "touch of ") then
        self.touchedTarget = args.target
    end
end

function twinValk:SPELL_AURA_REMOVED(args)
    if strcontains(args.spellName, "shield of lights") or strcontains(args.spellName, "shield of darkness") then
        TargetUnit(args.target)
        FocusUnit("target")
        if not AI.IsTank() then
            AI.RegisterPendingAction(function(self)
                if self.touchedTarget == nil and (not AI.IsHealer() or not AI.IsCasting()) and UnitHealth("player") >=
                    15000 then
                    local darkEssence = AI.FindNearbyUnitsByName("dark essence")
                    local lightEssence = AI.FindNearbyUnitsByName("light essence")
                    local plr = AI.GetObjectInfo("player")
                    if plr:HasAura('light essence') and darkEssence[1].distance >= essenceInteractRadius then
                        -- AI.SayRaid("moving to dark essence position")
                        AI.SetMoveTo(darkEssence[1].x, darkEssence[1].y)
                    end
                    if plr:HasAura('dark essence') and lightEssence[1].distance >= essenceInteractRadius then
                        -- AI.SayRaid("moving to light essence position")
                        AI.SetMoveTo(lightEssence[1].x, lightEssence[1].y)
                    end
                    print("successfully moved to next essence position")
                    return true
                end
            end, 1)
        end
        if not AI.IsHealer() and AI.IsCasting("focus") then
            -- print("interrupting heals")
            AI.DoStaggeredInterrupt()
        end
    end
    if strcontains(args.spellName, "touch of ") then
        self.touchedTarget = nil
    end
end

function twinValk:ON_ADDON_MESSAGE(from, cmd, params)
    if cmd == "use-essence" and not AI.IsHealer() then
        -- print("received command params: " .. params)
        local startEssenceGUID, nextEssenceGUID = splitstr2(params, ",")
        if startEssenceGUID == nil then
            startEssenceGUID = params
        end
        local essence = AI.GetObjectInfoByGUID(startEssenceGUID)
        local nextEssence = AI.GetObjectInfoByGUID(nextEssenceGUID or "")
        if essence then
            if essence.distance <= essenceInteractRadius then
                print("essence is close, interacting")
                essence:InteractWith()
                if nextEssence then
                    AI.SetMoveTo(nextEssence.x, nextEssence.y)
                end
            elseif AI.IsDps() then
                AI.SetMoveTo(essence.x, essence.y, essence.z, 0, function(self)
                    print("switching essence")
                    essence:InteractWith()
                    if nextEssence then
                        AI.SetMoveTo(nextEssence.x, nextEssence.y)
                    end
                end)
            end
        end
    end
end

AI.RegisterBossModule(twinValk)

local anub = MosDefBossModule:new({
    name = "Anub'arak",
    creatureId = {34564},
    onStart = function(self)
        -- AI.Config.startHealOverrideThreshold = 95
        AI.Config.manaTideThreshold = 10
        AI.DISABLE_DRAIN = true
        if AI.IsTank() then
            AI.ALLOW_AUTO_REFACE = false
        end
        AI.do_PriorityTarget = function()
            return false
        end
        AI.Config.judgmentToUse = "judgement of light"
        AI.PRE_DO_DPS = function(isAoE)
            -- if not self.hasBurrowed and AI.IsDps() and AI.IsValidOffensiveUnit("target") and
            --     AI.GetDistanceToUnit("target") >= 35 and not AI.HasMoveTo() then
            --     local obstacles = AI.FindNearbyDynamicObjects("permafrost")
            --     local p = AI.PathFinding.FindSafeSpotInCircle("target", 35, obstacles, 3)
            --     if p then
            --         print('moving to dps target '..UnitName("target"))
            --         AI.PathFinding.MoveSafelyTo(p, obstacles)
            --         -- AI.SetMoveTo(p.x, p.y)
            --     end
            -- end
            -- if AI.IsWarlock() then            
            -- end            
            if AI.IsMage() then
                local hasFrostSpheres = self:HasFrostSpheres()

                if hasFrostSpheres then
                    AI.DISABLE_PET_AA = true
                    RunMacroText("/petattack [@frost sphere]")
                else
                    AI.DISABLE_PET_AA = false
                    RunMacroText("/petattack [@target]")
                end
            end
            return false
        end

        if AI.IsHeroicRaidOrDungeon() and not AI.HasBuff("flask of the frost wyrm") and not AI.IsTank() then
            AI.UseContainerItem("flask of the frost wyrm")
        end
        -- AI.DISABLE_PET_AA = true
        if AI.IsDps() then
            AI.RegisterPendingAction(function(self)
                AI.UseInventorySlot(13)
                AI.UseInventorySlot(14)
                return AI.UseInventorySlot(10)
            end, 5, "PROC_TRINKERTS")
        end
    end,
    onStop = function(self)
        AI.do_PriorityTarget = nil
        AI.PRE_DO_DPS = nil
        AI.DISABLE_DRAIN = false
    end,
    onUpdate = function(self)
        if AI.IsTank() and strcontains(UnitName("target"), "burrower") and (AI.HasDebuff("permafrost", "target") or AI.HasDebuff(66193, "target")) and AI.CastSpell("hammer of justice", "target") then
            return true
        end
        if AI.IsHealer() and self.p2 then            
            local tank = AI.GetPrimaryTank()
            local spell = AI.HasBuff("tidal waves") and "healing wave" or "chain heal"
            if UnitHealth(tank) <= 35000 and AI.CastSpell(spell, tank) then
                return true
            end
        end
        if AI.IsDps() and self.p2 then
            AI.UseInventorySlot(13)
            AI.UseInventorySlot(14)
            AI.UseInventorySlot(10)
        end
        if self.hasBurrowed and not AI.IsTank() then
            if AI.IsHealer() and AI.IsMoving() then
                local healTar, missingHp, secondTar, secondTarHp = AI.GetMostDamagedFriendly("riptide")
                if healTar and missingHp > AI.GetSpellEffect("riptide") and AI.CastSpell("riptide", healTar) then
                    return true
                end
            end
            if GetFollowTarget() ~= UnitGUID(AI.GetPrimaryTank()) then
                SetFollowTarget(UnitGUID(AI.GetPrimaryTank()))
            end
        end
    end,
    p2 = false,
    hasBurrowed = false,
    hasEmerged = false,
    focusedBurrower = nil,
    penetratedTarget = nil
})

function anub:SPELL_CAST_START(args)
    if strcontains(args.spellName, "leeching swarm") then
        AI.Config.startHealOverrideThreshold = 40
        self.p2 = true
        print("p2 started")
    end
    if strcontains(args.spellName, "shadow strike") then
        local caster = self:GetShadowStrikeCaster()
        if caster and AI.IsPriest() then
            -- print("got shadowstrike caster")
            caster:Focus()
            AI.DoStaggeredInterrupt()
        end
    end
end

function anub:SPELL_AURA_APPLIED(args)
    if strcontains(args.spellName, "penetrating cold") and self.p2 then
        self.penetratedTarget = args.target
        if AI.IsPriest() and AI.IsUnitValidFriendlyTarget(args.target) and
            not AI.HasDebuff("weakened soul", args.target) then
            AI.MustCastSpell("power word: shield", args.target)
        end
        if self.p2 and AI.IsPaladin() and AI.IsUnitValidFriendlyTarget(args.target) and
            not AI.HasBuff("sacred shield", args.target) then
            AI.MustCastSpell("sacred shield", args.target)
        end
    end
end

function anub:SPELL_AURA_REMOVED(args)
    if strcontains(args.spellName, "penetrating cold") then
        self.penetratedTarget = nil
    end
end

function anub:HasFrostSpheres()
    local spheres = AI.FindNearbyUnitsByName("frost sphere")
    for i, o in ipairs(spheres) do
        if not o.isDead and o.selectable then
            return true
        end
    end
    return false
end

function anub:GetShadowStrikeCaster()
    local burrower = AI.FindNearbyUnitsByName("burrower")
    for i, o in ipairs(burrower) do
        if o:IsCasting() then
            return o
        end
    end
    return nil
end

function anub:CHAT_MSG_RAID_BOSS_EMOTE(s, t)
    if strcontains(s, "burrows into the") then
        self.hasBurrowed = true

        -- print("anub'arak burrow emote received, moving to safe spot")        
    end
    if strcontains(s, "emerges from") then
        AI.DISABLE_PET_AA = false
        self.hasBurrowed = false
        self.hasEmerged = true
        AI.DISABLE_CDS = false
    end
end

AI.RegisterBossModule(anub)
