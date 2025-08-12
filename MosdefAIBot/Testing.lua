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

    local path = FindSafeLocationInPolygonAStar(mapId, AI.PathFinding.Vector3.new(cx, cy, cz), obstacles, polygon, gridSize, 1.0, steps)
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
