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

function Vector3.new(x, y, z)
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

function AI.PathFinding.CanMoveSafelyTo(target, obstacles)
    local x, y, z
    if type(target) == "string" then
        x, y, z = AI.GetPosition(target)
    else
        x = target.x
        y = target.y
        z = target.z
    end
    local dest = AI.PathFinding.Vector3.new(x, y, z)
    local dist = AI.GetDistanceTo(x, y)
    local gridSize = 3.5
    if dist <= 10 then
        gridSize = 0.5
    end
    local mapId = GetCurrentMapID()
    local iterations = 300
    local path = CalculatePathWhileAvoidingAStar(mapId, AI.PathFinding.Vector3.new(AI.GetPosition()),
        AI.PathFinding.Vector3.new(x, y, z), obstacles, gridSize, iterations)
    if type(path) == "table" then
        return true
    end
    return false
end

function AI.PathFinding.MoveSafelyTo(target, obstacles, onArrive)
    local x, y, z
    if type(target) == "string" then
        x, y, z = AI.GetPosition(target)
    else
        x = target.x
        y = target.y
        z = target.z
    end
    local dest = AI.PathFinding.Vector3.new(x, y, z)
    local dist = AI.GetDistanceTo(x, y)
    local gridSize = 3
    if dist <= 10 then
        gridSize = 1
    end
    local mapId = GetCurrentMapID()
    local iterations = 300
    local path = CalculatePathWhileAvoidingAStar(mapId, AI.PathFinding.Vector3.new(AI.GetPosition()),
        AI.PathFinding.Vector3.new(x, y, z), obstacles, gridSize, iterations)
    if type(path) == "table" then
        AI.SetMoveToPath(path, 0, onArrive)
        -- print("successfully MoveSafelyTo  target")
        return true
    end
    print("AI.PathFinding.MoveSafelyTo failed")
    return false
end

function AI.PathFinding.MoveToSafeLocationWithinPolygon(polygon, obstacles, safeDist, onArrive)
    local iterations = 200
    local gridSize = 5
    polygon = polygon or AI.PathFinding.createCircularPolygon("player", 35)
    local path = FindSafeLocationInPolygonAStar(GetCurrentMapID(), AI.PathFinding.Vector3.new(AI.GetPosition()),
        obstacles, polygon, gridSize, safeDist or 0.5, iterations)
    if type(path) == "table" then
        AI.SetMoveToPath(path, 0, onArrive)
        return true
    end
    return false
end

function AI.PathFinding.MoveDirectlyToSafeLocationWithinPolygon(polygon, obstacles, safeDist, onArrive)
    local iterations = 200
    local gridSize = 5
    polygon = polygon or AI.PathFinding.createCircularPolygon("player", 50)
    local path = FindSafeLocationInPolygonAStar(GetCurrentMapID(), AI.PathFinding.Vector3.new(AI.GetPosition()),
        obstacles, polygon, gridSize, safeDist or 0.5, iterations)
    if type(path) == "table" and #path > 0 then
        local lastWp = path[#path]
        AI.SetMoveTo(lastWp.x, lastWp.y, 0.5, onArrive)
        return true
    end
end

function AI.PathFinding.FindSafeSpotInCircle(center, radius, obstacles, safeDistance, stepSize)
    local mapId = GetCurrentMapID()
    if type(center) == "string" then
        local x, y, z = AI.GetPosition(center)
        if not x or not y or not z then
            x, y, z = AI.GetPosition("player")
        end
        center = {
            x = x,
            y = y,
            z = z
        }
    elseif type(center) == "table" then
        center = AI.PathFinding.Vector3.new(center.x, center.y, center.z)
    end
    local pos = FindSafeSpotWithinCircle(mapId, AI.PathFinding.Vector3.new(AI.GetPosition()),
        center or AI.PathFinding.Vector3.new(AI.GetPosition()), radius, stepSize or 1, obstacles or {},
        safeDistance or 0)
    return pos
end

function AI.PathFinding.FindSafeSpotOnBoundary(center, radius, obstacles, safeDistance)
    local mapId = GetCurrentMapID()
    if type(center) == "string" then
        local x, y, z = AI.GetPosition(center)
        if not x or not y or not z then
            x, y, z = AI.GetPosition("player")
        end
        center = {
            x = x,
            y = y,
            z = z
        }
    elseif type(center) == "table" then
        center = AI.PathFinding.Vector3.new(center.x, center.y, center.z)
    end
    local pos = FindSafeSpotOnBoundary(mapId, AI.PathFinding.Vector3.new(AI.GetPosition()),
        center or AI.PathFinding.Vector3.new(AI.GetPosition()), radius, safeDistance or 0, obstacles or {})
    return pos
end

function AI.PathFinding.FindSafeSpotWithinRadiusCorridor(center, startRadius, endRadius, obstacles, safeDistance,
    stepSize)
    local mapId = GetCurrentMapID()
    if type(center) == "string" then
        local x, y, z = AI.GetPosition(center)
        if not x or not y or not z then
            x, y, z = AI.GetPosition("player")
        end
        center = {
            x = x,
            y = y,
            z = z
        }
    end
    local startp = AI.PathFinding.Vector3.new(AI.GetPosition())
    stepSize = stepSize or 1
    safeDistance = safeDistance or 0.0
    obstacles = obstacles or {}
    -- print("FindSafeSpotWithinRadiusCorridor args center: "..table2str(center).. " startp " .. table2str(startp) .. " startRadius: "..tostring(startRadius).. " endRadius: "..tostring(endRadius).. " safeDistance: "..tostring(safeDistance).. " stepSize: "..tostring(stepSize).. " obstacles: "..table2str(obstacles))
    local pos = FindSafeSpotWithinRadiusCorridor(mapId, startp, center or startp, startRadius, endRadius, stepSize,
        safeDistance, obstacles)
    return pos
end

-- Generate circular polygon around a center point
function AI.PathFinding.createCircularPolygon(center, radius, numPoints)
    local polygon = {}
    numPoints = numPoints or 8 -- Default to 16 points for a decent circle approximation
    if type(center) == "string" then
        local x, y, z = AI.GetPosition(center)
        if not x or not y or not z then
            x, y, z = AI.GetPosition("player")
        end
        center = {
            x = x,
            y = y,
            z = z
        }
    end
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
    table.insert(polygon, Vector3.new(left, bottom, z)) -- Bottom-left
    table.insert(polygon, Vector3.new(right, bottom, z)) -- Bottom-right
    table.insert(polygon, Vector3.new(right, top, z)) -- Top-right
    table.insert(polygon, Vector3.new(left, top, z)) -- Top-left

    return polygon
end

function AI.PathFinding.computeCentroid(polygon)
    local x, y = 0, 0
    local size = #polygon
    for i, o in ipairs(polygon) do
        x = x + o.x
        y = y + o.y
    end
    x = x / size
    y = y / size
    return x, y
end

-- Calculates the coordinates the player must move to in order to intercept an orb,
-- but ONLY if the orb is heading in the player's general direction.
-- @param playerPos: Table {x=num, y=num, z=num}
-- @param runSpeed: Player's movement speed (number)
-- @param orbPos: Table {x=num, y=num, z=num}
-- @param currentSpeed: Orb's movement speed (number)
-- @param facing: Orb's direction of travel in radians (number)
-- @param leadTime: How many seconds *ahead* of the orb the player should arrive (number, e.g., 0.75)
-- @return Intercept coordinate table {x=num, y=num, z=num} or nil if impossible/heading away
function AI.PathFinding.getInterceptPoint(playerPos, runSpeed, orbPos, currentSpeed, facing, leadTime, maxAngleDegrees)
    -- 1. Calculate Orb Direction Vector (Already normalized since it's pure cos/sin)
    local orbDirX = math.cos(facing)
    local orbDirY = math.sin(facing)

    maxAngleDegrees = maxAngleDegrees or 90

    -- 2. Calculate Vector from Orb to Player
    local toPlayerX = playerPos.x - orbPos.x
    local toPlayerY = playerPos.y - orbPos.y

    -- 3. Normalize the Orb-to-Player Vector
    local distanceToPlayer = math.sqrt((toPlayerX * toPlayerX) + (toPlayerY * toPlayerY))

    local minDistance = 2

    -- Prevent division by zero if the player is standing exactly on the orb
    if distanceToPlayer < minDistance then
        return nil
    end

    local toPlayerNormX = toPlayerX / distanceToPlayer
    local toPlayerNormY = toPlayerY / distanceToPlayer

    -- 4. Calculate Normalized Dot Product (gives the cosine of the angle between vectors)
    local cosAngle = (orbDirX * toPlayerNormX) + (orbDirY * toPlayerNormY)

    -- 5. Configurable Cone Verification
    -- Convert user's threshold angle to its cosine equivalent
    local minCosThreshold = math.cos(math.rad(maxAngleDegrees))

    -- If cosAngle is lower than the threshold, the angle deviation is too wide
    if cosAngle < minCosThreshold then
        return nil
    end

    -- 6. Calculate actual Orb Velocity Vector
    local v_ox = currentSpeed * orbDirX
    local v_oy = currentSpeed * orbDirY

    -- 7. Apply Time Buffer (Shift the orb's starting position forward in time)
    local shifted_xo = orbPos.x + (v_ox * leadTime)
    local shifted_yo = orbPos.y + (v_oy * leadTime)

    -- 8. Calculate Relative Distance Components for Interception Path
    local dx = shifted_xo - playerPos.x
    local dy = shifted_yo - playerPos.y

    -- 9. Set up Quadratic Coefficients (At^2 + Bt + C = 0)
    local A = (v_ox * v_ox) + (v_oy * v_oy) - (runSpeed * runSpeed)
    local B = 2 * ((dx * v_ox) + (dy * v_oy))
    local C = (dx * dx) + (dy * dy)

    local t = nil

    -- 10. Solve for Time (t)
    if math.abs(A) < 0.0001 then
        if math.abs(B) > 0.0001 then
            t = -C / B
        end
    else
        local discriminant = (B * B) - (4 * A * C)

        if discriminant >= 0 then
            local sqrt_disc = math.sqrt(discriminant)
            local t1 = (-B - sqrt_disc) / (2 * A)
            local t2 = (-B + sqrt_disc) / (2 * A)

            if t1 > 0 and t2 > 0 then
                t = math.min(t1, t2)
            elseif t1 > 0 then
                t = t1
            elseif t2 > 0 then
                t = t2
            end
        end
    end

    -- 11. Return the target coordinate table if interception is valid
    if t and t >= 0 then
        return {
            x = shifted_xo + (v_ox * t),
            y = shifted_yo + (v_oy * t),
            z = playerPos.z
        }
    else
        return nil
    end
end
