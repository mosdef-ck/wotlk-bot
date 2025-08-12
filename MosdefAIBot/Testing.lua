function AI.TestPathFinding()
    local mapId = GetCurrentMapID()
    local allies = AI.GetRaidOrPartyMemberUnits()
    local obstacles = {}
    for i, ally in ipairs(allies) do
        if UnitName(ally) ~= UnitName("player") then
            local info = AI.GetObjectInfo(ally)
            table.insert(obstacles, {
                x = info.x,
                y = info.y,
                z = info.z,
                radius = 10
            })
        end
    end
    local cx, cy, cz = AI.GetPosition()
    local tx, ty, tz = AI.GetPosition("target");
    -- MalowUtils_PrintScrollable("generating path " .. table2str({
    --     mapId = mapId,
    --     cx = cx,
    --     cy = cy,
    --     cz = cz,
    --     tx = tx,
    --     ty = ty,
    --     tz = tz,
    --     obstacles = obstacles
    -- }))

    local gridSize = 0.5
    local steps = 200
    if AI.CalcDistance(cx, cy, tx, ty) > 40 then
        -- gridSize = 3
    end

    local path = CalculatePathWhileAvoidingPFP(mapId, AI.PathFinding.Vector3.new(cx, cy, cz),
        AI.PathFinding.Vector3.new(tx, ty, tz), obstacles, gridSize, steps)
    if path and type(path) == "table" then
        print(table2str(path))
        AI.SetMoveToPath(path)
    else
        print("failed to generate PFP")
    end
end

function AI.TestObjectAvoidance()
    local allies = AI.GetRaidOrPartyMemberUnits()
    local guids = {}
    for i, ally in ipairs(allies) do
        if UnitName(ally) ~= UnitName("player") then
            table.insert(guids, UnitGUID(ally))
        end
    end
    return AI.SetObjectAvoidance({
        guids = guids,
        radius = 10,
        safeDistance = 3,
        gridSize = 1
    })
end

function AI.TestDetourNavigation()
    local mapId = GetCurrentMapID()
    local cx, cy, cz = AI.GetPosition()
    local tx, ty, tz = AI.GetPosition("target");
    print("generating path " .. table2str({
        mapId = mapId,
        cx = cx,
        cy = cy,
        cz = cz,
        tx = tx,
        ty = ty,
        tz = tz
    }))
    local path = CalculatePathToDetour(mapId, AI.PathFinding.Vector3.new(cx, cy, cz),
        AI.PathFinding.Vector3.new(tx, ty, tz))

    if path and type(path) == "table" then
        print(table2str(path))
        AI.SetMoveToPath(path)
    else
        print("failed to generate path")
    end
end

function AI.TestDetourAvoidingNavigation()
    local mapId = GetCurrentMapID()
    local cx, cy, cz = AI.GetPosition()
    local tx, ty, tz = AI.GetPosition("target");
    print("generating path " .. table2str({
        mapId = mapId,
        cx = cx,
        cy = cy,
        cz = cz,
        tx = tx,
        ty = ty,
        tz = tz
    }))
    local allies = AI.GetRaidOrPartyMemberUnits()
    local obstacles = {}
    for i, ally in ipairs(allies) do
        if UnitName(ally) ~= UnitName("player") then
            local info = AI.GetObjectInfo(ally)
            table.insert(obstacles, {
                x = info.x,
                y = info.y,
                z = info.z,
                radius = 5
            })
        end
    end
    local path = CalculatePathDetourWhileAvoiding(mapId, AI.PathFinding.Vector3.new(cx, cy, cz),
        AI.PathFinding.Vector3.new(tx, ty, tz), obstacles)

    if path and type(path) == "table" then
        print("My Path" .. table2str(path))
        AI.SetMoveToPath(path)
    else
        print("failed to generate path")
    end
end

function AI.TestDetourAvoidingNavigationLocal()
    local mapId = GetCurrentMapID()
    local cx, cy, cz = AI.GetPosition()
    local tx, ty, tz = AI.GetPosition("target");
    print("generating path " .. table2str({
        mapId = mapId,
        cx = cx,
        cy = cy,
        cz = cz,
        tx = tx,
        ty = ty,
        tz = tz
    }))
    local dist = AI.GetDistanceTo(tx, ty);
    local npcs = AI.FindNearbyUnitsByName("kirin tor")
    local obstacles = {}
    for i, o in ipairs(npcs) do
        if o.distance <= dist * 2 then
            table.insert(obstacles, {
                x = o.x,
                y = o.y,
                z = o.z,
                radius = 1
            })
        end
    end
    local path = CalculatePathDetourWhileAvoiding(mapId, AI.PathFinding.Vector3.new(cx, cy, cz),
        AI.PathFinding.Vector3.new(tx, ty, tz), obstacles)

    if path and type(path) == "table" then
        print("My Path" .. table2str(path))
        AI.SetMoveToPath(path)
    else
        print("failed to generate path")
    end
end

function AI.TestDetourNavigationObjectAvoidance()
    local mapId = GetCurrentMapID()
    local cx, cy, cz = AI.GetPosition()
    local tx, ty, tz = AI.GetPosition("target");
    local dist = AI.GetDistanceTo(tx, ty);

    local npcs = AI.FindNearbyUnitsByName("kirin tor")
    local obstacles = {}
    for i, o in ipairs(npcs) do
        if o.distance <= dist then
            table.insert(obstacles, {
                x = o.x,
                y = o.y,
                z = o.z,
                radius = 10
            })
        end
    end

    -- MalowUtils_PrintScrollable("generating path " .. table2str({
    --     mapId = mapId,
    --     cx = cx,
    --     cy = cy,
    --     cz = cz,
    --     tx = tx,
    --     ty = ty,
    --     tz = tz,
    --     obstacles = obstacles
    -- }))
    local gridSize = 1
    local steps = 1000
    if AI.CalcDistance(cx, cy, tx, ty) > 20 then
        gridSize = 7
    end

    local path = CalculatePathWhileAvoidingAStar(mapId, AI.PathFinding.Vector3.new(cx, cy, cz),
        AI.PathFinding.Vector3.new(tx, ty, tz), obstacles, gridSize, steps)
    -- local path = CalculatePathWhileAvoidingPFP(mapId, AI.PathFinding.Vector3.new(cx, cy, cz),
    --     AI.PathFinding.Vector3.new(tx, ty, tz), obstacles, gridSize, steps)
    if path and type(path) == "table" then
        print(table2str(path))
        AI.SetMoveToPath(path, 0.7, function()
            print("Will Current path intersect obstacles " .. tostring(AI.IsCurrentPathSafeFromObstacles(obstacles)))
        end)
    else
        print("failed to generate AStar path")
    end
end

function AI.TestSafeLocationInPolygon()
    local mapId = GetCurrentMapID()
    local cx, cy, cz = AI.GetPosition()
    local tx, ty, tz = AI.GetPosition("target");
    local dist = AI.GetDistanceTo(tx, ty);
    local polygon = AI.PathFinding.createCircularPolygon({
        x = tx,
        y = ty,
        z = tz
    }, 20)

    local npcs = AI.FindNearbyUnitsByName("kirin tor")
    local obstacles = {}
    for i, o in ipairs(npcs) do
        if o.distance <= dist then
            table.insert(obstacles, {
                x = o.x,
                y = o.y,
                z = o.z,
                radius = 10
            })
        end
    end

    -- MalowUtils_PrintScrollable("generating path " .. table2str({
    --     mapId = mapId,
    --     cx = cx,
    --     cy = cy,
    --     cz = cz,
    --     tx = tx,
    --     ty = ty,
    --     tz = tz,
    --     obstacles = obstacles
    -- }))
    local gridSize = 3
    local steps = 1000
    if AI.CalcDistance(cx, cy, tx, ty) > 20 then
        gridSize = 5
    end

    local path = FindSafeLocationInPolygonAStar(mapId, AI.PathFinding.Vector3.new(cx, cy, cz), obstacles, polygon,
        gridSize, 1.0, steps)
    if path and type(path) == "table" then
        print(table2str(path))
        AI.SetMoveToPath(path, 0.7, function()
            print("Will Current path intersect obstacles " .. tostring(AI.IsCurrentPathSafeFromObstacles(obstacles)))
        end)
    else
        print("failed to generate AStar path")
    end
end

function AI.TestNavigateClouds()
    RunMacroText("/say .cast 70766")
    local start = AI.PathFinding.Vector3.new(AI.GetPosition())
    local p = AI.PathFinding.Vector3.new(4263.6015625, 2484.4033203125, 364.86950683594)
    local clouds = AI.FindNearbyUnitsByName("dream cloud")
    table_removeif(clouds, function(c)
        return c:GetDistanceTo(p.x, p.y) > 50
    end)
    local cloudGuids = {}

    if #clouds > 0 then
        local count = 0
        local nextCloud = clouds[1]
        while count < 5 and nextCloud do
            table.insert(cloudGuids, nextCloud)
            count = count + 1
            table_removeif(clouds, function(c)
                return c == nextCloud
            end)
            nextCloud = clouds[1]
        end
    end

    local wps = {}
    local start = AI.PathFinding.Vector3.new(AI.GetPosition())
    for i, c in ipairs(cloudGuids) do
        local wp = AI.PathFinding.Vector3.new(c.x, c.y, c.z)
        table.insert(wps, wp)
    end
    table.insert(wps, start)

    JumpOrAscendStart()
    AI.SetMoveToPath(wps)
end

function AI.TestBloodQueenPathing()
    local flameKiteWp1 = {AI.PathFinding.Vector3.new(4614.0141601563, 2789.9033203125, 400.13821411133),
                          AI.PathFinding.Vector3.new(4601.3940429688, 2797.3210449219, 400.13665771484),
                          AI.PathFinding.Vector3.new(4586.1357421875, 2796.5583496094, 400.13702392578),
                          AI.PathFinding.Vector3.new(4588.408203125, 2790.8203125, 400.13562011719),
                          AI.PathFinding.Vector3.new(4597.654296875, 2789.1013183594, 400.13671875)}

    local flameKiteWp2 = {AI.PathFinding.Vector3.new(4580.189453125, 2792.396484375, 400.13793945313),
                          AI.PathFinding.Vector3.new(4571.3754882813, 2773.2924804688, 400.13824462891),
                          AI.PathFinding.Vector3.new(4576.5073242188, 2748.380859375, 400.13809204102),
                          AI.PathFinding.Vector3.new(4584.2192382813, 2752.8449707031, 400.13809204102),
                          AI.PathFinding.Vector3.new(4585.8740234375, 2760.6655273438, 400.13711547852)}

    local flameKiteWp3 = {AI.PathFinding.Vector3.new(4609.0229492188, 2745.013671875, 400.13714599609),
                          AI.PathFinding.Vector3.new(4586.5673828125, 2742.0473632813, 400.13714599609),
                          AI.PathFinding.Vector3.new(4587.8442382813, 2750.728515625, 400.13714599609),
                          AI.PathFinding.Vector3.new(4600.1879882813, 2750.86328125, 400.13714599609),
                          AI.PathFinding.Vector3.new(4600.0249023438, 2750.5217285156, 400.13711547852),
                          AI.PathFinding.Vector3.new(4594.3720703125, 2755.861328125, 400.13711547852)}
    local nextKiteIdx = 1
    AI.SetMoveToPath(flameKiteWp3)
end
