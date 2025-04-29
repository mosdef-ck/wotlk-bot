AI.PathFinding = {}

-- Vector2 class (same as before)
local Vector2 = {}
local Vector3 = {}
AI.PathFinding.Vector2 = Vector2
AI.PathFinding.Vector3 = Vector3

Vector2.__index = Vector2
Vector3.__index = Vector3

function Vector2.new(x, y)
    return setmetatable({
        x = x or 0,
        y = y or 0
    }, Vector2)
end

function Vector2:distanceTo(other)
    local dx = self.x - other.x
    local dy = self.y - other.y
    return math.sqrt(dx * dx + dy * dy)
end

function Vector2:subtract(other)
    return Vector2.new(self.x - other.x, self.y - other.y)
end

function Vector2:add(other)
    return Vector2.new(self.x + other.x, self.y + other.y)
end

function Vector2:multiply(scalar)
    return Vector2.new(self.x * scalar, self.y * scalar)
end

function Vector2:normalize()
    local length = self:distanceTo(Vector2.new(0, 0))
    if length > 0 then
        return Vector2.new(self.x / length, self.y / length)
    end
    return Vector2.new(0, 0)
end

function Vector2:dot(other)
    return self.x * other.x + self.y * other.y
end

function Vector3.new(x,y,z)
    return setmetatable({
        x = x or 0,
        y = y or 0,
        z = z or 0
    }, Vector3)
end

function Vector3:distanceTo(other)
    local dx = self.x - other.x
    local dy = self.y - other.y
    local dz = self.z - other.z
    return math.sqrt(dx * dx + dy * dy + dz * dz)
end

function Vector3:to2D()
    return Vector2.new(self.x, self.y);
end

-- Simple priority queue for A*
local PriorityQueue = {}
PriorityQueue.__index = PriorityQueue

function PriorityQueue.new()
    return setmetatable({
        items = {}
    }, PriorityQueue)
end

function PriorityQueue:put(item, priority)
    table.insert(self.items, {
        item = item,
        priority = priority
    })
    table.sort(self.items, function(a, b)
        return a.priority < b.priority
    end)
end

function PriorityQueue:pop()
    if #self.items > 0 then
        return table.remove(self.items, 1).item
    end
    return nil
end

function PriorityQueue:empty()
    return #self.items == 0
end

local function isInBounds(x, y, gridWidth, gridHeight)
    return x >= 1 and x <= gridWidth and y >= 1 and y <= gridHeight
end

local function isValidGridCoord(x, y, gridWidth, gridHeight)
    return x >= 1 and x <= gridWidth and y >= 1 and y <= gridHeight
end

-- Helper function to calculate Manhattan distance (for heuristic)
local function manhattanDistance(nodeA, nodeB)
    return math.abs(nodeA.x - nodeB.x) + math.abs(nodeA.y - nodeB.y)
end

-- Helper function to calculate Euclidean distance
local function euclideanDistance(nodeA, nodeB)
    return math.sqrt((nodeA.x - nodeB.x) ^ 2 + (nodeA.y - nodeB.y) ^ 2)
end

local function tableContains(tab, val)
    for _, v in ipairs(tab) do
        if v == val then
            return true
        end
    end
    return false
end

local function catmullRom(p0, p1, p2, p3, t)
    local t2 = t * t
    local t3 = t2 * t
    local f1 = -0.5 * t3 + t2 - 0.5 * t
    local f2 = 1.5 * t3 - 2.5 * t2 + 1
    local f3 = -1.5 * t3 + 2 * t2 + 0.5 * t
    local f4 = 0.5 * t3 - 0.5 * t2

    local x = p0.x * f1 + p1.x * f2 + p2.x * f3 + p3.x * f4
    local y = p0.y * f1 + p1.y * f2 + p2.y * f3 + p3.y * f4

    return Vector2.new(x, y)
end

-- Smooth path function
local function smoothPath(rawPath, segmentsPerSegment)
    if #rawPath < 2 then
        return rawPath
    end

    local smoothedPath = {}
    segmentsPerSegment = segmentsPerSegment or 5 -- Points between each pair of waypoints

    -- Add extra points at start and end for spline continuity
    local p0 = rawPath[1]:subtract(rawPath[2]:subtract(rawPath[1]))
    local pLast = rawPath[#rawPath]:add(rawPath[#rawPath]:subtract(rawPath[#rawPath - 1]))
    local points = {p0}
    for _, p in ipairs(rawPath) do
        table.insert(points, p)
    end
    table.insert(points, pLast)

    -- Generate spline points
    for i = 2, #points - 2 do
        local p0 = points[i - 1]
        local p1 = points[i]
        local p2 = points[i + 1]
        local p3 = points[i + 2]

        for j = 0, segmentsPerSegment - (i == #points - 2 and 1 or 0) do
            local t = j / segmentsPerSegment
            local point = catmullRom(p0, p1, p2, p3, t)
            table.insert(smoothedPath, point)
        end
    end

    -- Ensure exact start and end points
    smoothedPath[1] = rawPath[1]
    smoothedPath[#smoothedPath] = rawPath[#rawPath]

    return smoothedPath
end

-- Point-in-polygon test (ray-casting algorithm)
local function isPointInPolygon(point, polygon)
    local x, y = point.x, point.y
    local inside = false
    for i = 1, #polygon do
        local j = i % #polygon + 1
        local vi = polygon[i]
        local vj = polygon[j]

        if ((vi.y > y) ~= (vj.y > y)) and (x < (vj.x - vi.x) * (y - vi.y) / (vj.y - vi.y) + vi.x) then
            inside = not inside
        end
    end
    return inside
end

-- Find nearest point on polygon boundary (Lua 5.1 compatible)
local function nearestPointOnPolygon(point, polygon)
    local closestPoint = nil
    local minDist = math.huge

    for i = 1, #polygon do
        local j = i % #polygon + 1
        local p1 = polygon[i]
        local p2 = polygon[j]

        -- Line segment from p1 to p2
        local dir = p2:subtract(p1)
        local len = dir:distanceTo(Vector2.new(0, 0))

        -- Skip if segment length is zero (degenerate case)
        if len ~= 0 then
            local t = math.max(0, math.min(1, ((point.x - p1.x) * dir.x + (point.y - p1.y) * dir.y) / (len * len)))
            local projection = p1:add(dir:multiply(t))

            local dist = point:distanceTo(projection)
            if dist < minDist then
                minDist = dist
                closestPoint = projection
            end
        end
    end

    return closestPoint
end

function math.sign(x)
    if x > 0 then
        return 1
    elseif x < 0 then
        return -1
    else
        return 0
    end
end

function AI.PathFinding.findSafePathAStar(mapId, cPos, tPos, obstacles, obstacleRadius, gridSize)
        
    local start = Vector2.new(math.floor(cPos.x / gridSize) * gridSize, math.floor(cPos.y / gridSize) * gridSize)
    local goal = Vector2.new(math.floor(tPos.x / gridSize) * gridSize, math.floor(tPos.y / gridSize) * gridSize)

    local directions = {Vector2.new(gridSize, 0), -- right
    Vector2.new(-gridSize, 0), -- left
    Vector2.new(0, gridSize), -- up
    Vector2.new(0, -gridSize), -- down
    Vector2.new(gridSize, gridSize), -- up-right
    Vector2.new(-gridSize, gridSize), -- up-left
    Vector2.new(gridSize, -gridSize), -- down-right
    Vector2.new(-gridSize, -gridSize) -- down-left
    }

    local openSet = PriorityQueue.new()
    local cameFrom = {}
    local gScore = {} -- Cost from start to current position
    local fScore = {} -- Estimated total cost (gScore + heuristic)

    local function key(pos)
        return pos.x .. "," .. pos.y
    end

    -- Heuristic: Euclidean distance to goal
    local function heuristic(pos)
        return pos:distanceTo(goal)
    end

    -- Check if position is safe from death rays
    local function isSafe(pos)
        if not IsPointTraversable(mapId, pos.x, pos.y, cPos.z) then --weed out points we can't physically walk to.
            return false
        end
        for _, ray in ipairs(obstacles) do
            if pos:distanceTo(ray) <= obstacleRadius then
                return false
            end
        end
        return true
    end

    -- Initialize
    openSet:put(start, 0)
    gScore[key(start)] = 0
    fScore[key(start)] = heuristic(start)

    local maxIterations = 1000
    local currentIteration = 0
    while not openSet:empty() and currentIteration <= maxIterations do
        currentIteration = currentIteration + 1
        local current = openSet:pop()
        local currentKey = key(current)

        if current:distanceTo(goal) <= gridSize then
            -- Reconstruct path
            local path = {}
            local pos = current
            while pos do
                table.insert(path, 1, pos)
                pos = cameFrom[key(pos)]
            end

            -- local smoothedPath = smoothPath(path, 3)
            return path
            -- return smoothedPath
        end

        for _, direction in ipairs(directions) do
            local neighbor = current:add(direction)
            local neighborKey = key(neighbor)

            if isSafe(neighbor) then
                local tentativeGScore = gScore[currentKey] + direction:distanceTo(Vector2.new(0, 0))

                if not gScore[neighborKey] or tentativeGScore < gScore[neighborKey] then
                    cameFrom[neighborKey] = current
                    gScore[neighborKey] = tentativeGScore
                    fScore[neighborKey] = tentativeGScore + heuristic(neighbor)
                    openSet:put(neighbor, fScore[neighborKey])
                end
            end
        end
    end

    return nil -- No path found
end

-- Generate circular polygon around a center point
function AI.PathFinding.createCircularPolygon(center, radius, numPoints)
    local polygon = {}
    numPoints = numPoints or 16  -- Default to 16 points for a decent circle approximation
    
    for i = 0, numPoints - 1 do
        local angle = 2 * math.pi * i / numPoints
        local x = center.x + radius * math.cos(angle)
        local y = center.y + radius * math.sin(angle)
        local z = center.z or 0
        table.insert(polygon, Vector3.new(x, y, z))
    end
    
    return polygon
end

-- Generate square polygon around a center point
function AI.PathFinding.createSquarePolygon(center, halfSize)
    local polygon = {}
    -- halfSize is half the side length, so full side length = 2 * halfSize
    local left = center.x - halfSize
    local right = center.x + halfSize
    local bottom = center.y - halfSize
    local top = center.y + halfSize
    local z = center.z or 0
    
    -- Define corners in clockwise order
    table.insert(polygon, Vector3.new(left, bottom, z))   -- Bottom-left
    table.insert(polygon, Vector3.new(right, bottom, z))  -- Bottom-right
    table.insert(polygon, Vector3.new(right, top, z))     -- Top-right
    table.insert(polygon, Vector3.new(left, top, z))      -- Top-left
    
    return polygon
end


function AI.PathFinding.findPathToSafeLocation(mapId, cPos, dangers, gridSize, safeDistance, polygon)
    local currentPos = cPos
    local path = {currentPos}

    local function snapToGrid(pos)
        return Vector2.new(math.floor(pos.x / gridSize) * gridSize, math.floor(pos.y / gridSize) * gridSize)
    end

    local directions = {Vector2.new(gridSize, 0), -- right
    Vector2.new(-gridSize, 0), -- left
    Vector2.new(0, gridSize), -- up
    Vector2.new(0, -gridSize), -- down
    Vector2.new(gridSize, gridSize), -- up-right
    Vector2.new(-gridSize, gridSize), -- up-left
    Vector2.new(gridSize, -gridSize), -- down-right
    Vector2.new(-gridSize, -gridSize) -- down-left
    }

    -- Initial safety check
    local isSafe = true
    for _, ray in ipairs(dangers) do
        local dist = currentPos:distanceTo(ray) - ray.radius
        if dist < (ray.radius + safeDistance) then
            isSafe = false
            break
        end
    end

    if isSafe then
        isSafe = IsPointTraversable(mapId, currentPos.x, currentPos.y, cPos.z)
    end
    if isSafe then
        print("Character is already in a safe location!")
        return nil
    end

    local maxSteps = 200
    local steps = 0

    -- If starting outside polygon, move to nearest boundary point
    if not isPointInPolygon(currentPos, polygon) then
        local entryPoint = nearestPointOnPolygon(currentPos, polygon)
        if entryPoint then
            currentPos = entryPoint
            table.insert(path, currentPos)
            -- print(string.format("Moved to polygon boundary at (%.1f, %.1f)", currentPos.x, currentPos.y))
        else
            -- print("Could not find a valid entry point into the polygon!")
            return path
        end
    end

    -- Snap to grid for subsequent moves
    local gridPos = snapToGrid(currentPos)
    if gridPos:distanceTo(currentPos) > 0 and isPointInPolygon(gridPos, polygon) then
        currentPos = gridPos
        table.insert(path, currentPos)
    end

    while steps < maxSteps do
        local minDistToRay = math.huge
        local isSafe = true
        for _, ray in ipairs(dangers) do
            local dist = currentPos:distanceTo(ray) - ray.radius
            minDistToRay = math.min(minDistToRay, dist)
            if dist < (ray.radius + safeDistance) then
                isSafe = false
            end
        end
        
        isSafe = IsPointTraversable(mapId, currentPos.x, currentPos.y, cPos.z)
        if isSafe then
            break
        end

        local bestDirection = nil
        local bestDistance = -math.huge

        for _, direction in ipairs(directions) do
            local testPos = currentPos:add(direction)
            if isPointInPolygon(testPos, polygon) then
                local testMinDist = math.huge
                for _, ray in ipairs(dangers) do
                    local dist = testPos:distanceTo(ray) - ray.radius
                    testMinDist = math.min(testMinDist, dist)
                end

                if testMinDist > bestDistance then
                    bestDistance = testMinDist
                    bestDirection = direction
                end
            end
        end

        if bestDirection then
            currentPos = currentPos:add(bestDirection)
            table.insert(path, currentPos)
        else
            print("No valid direction found within polygon, character may be stuck!")
            break
        end

        steps = steps + 1
    end
    if steps == maxSteps then
        print("exhausted steps")
    end
    return path
end