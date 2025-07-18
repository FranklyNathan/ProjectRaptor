-- pathfinding.lua
-- Contains pathfinding algorithms for turn-based movement.

local WorldQueries = require("modules.world_queries")
local Grid = require("modules.grid")

local Pathfinding = {}

-- Calculates all valid landing tiles for a unit using Breadth-First Search (BFS).
-- Also returns the path data required to reconstruct the path to any tile.
function Pathfinding.calculateReachableTiles(startUnit, world)
    local reachable = {} -- Stores valid landing spots and their movement cost.
    local came_from = {} -- Stores path history for reconstruction.
    local frontier = {{tileX = startUnit.tileX, tileY = startUnit.tileY, cost = 0}} -- The queue of tiles to visit.
    local cost_so_far = {} -- Stores the cost to reach any visited tile (including invalid landing spots for flying units).
    local startPosKey = startUnit.tileX .. "," .. startUnit.tileY

    cost_so_far[startPosKey] = 0
    -- The starting tile is always a valid "landing" spot. The value is now a table.
    reachable[startPosKey] = { cost = 0, landable = true }

    local head = 1
    while head <= #frontier do
        local current = frontier[head]
        head = head + 1

        local neighbors = {
            {dx = 0, dy = -1}, -- Up
            {dx = 0, dy = 1},  -- Down
            {dx = -1, dy = 0}, -- Left
            {dx = 1, dy = 0}   -- Right
        }

        -- Explore neighbors
        for _, move in ipairs(neighbors) do
            local nextTileX, nextTileY = current.tileX + move.dx, current.tileY + move.dy
            local nextCost = current.cost + 1
            local nextPosKey = nextTileX .. "," .. nextTileY
            
            -- Check if the neighbor is within map boundaries before proceeding.
            if nextTileX >= 0 and nextTileX < world.map.width and nextTileY >= 0 and nextTileY < world.map.height then
                if nextCost <= startUnit.movement then
                    -- If we haven't visited this tile, or found a cheaper path to it
                    if not cost_so_far[nextPosKey] or nextCost < cost_so_far[nextPosKey] then
                        local isObstacle = WorldQueries.isTileAnObstacle(nextTileX, nextTileY, world)
                        local occupyingUnit = WorldQueries.getUnitAt(nextTileX, nextTileY, startUnit, world)

                        local canPass = false
                        local canLand = false

                        if isObstacle then
                            canPass = startUnit.isFlying -- Can only pass over obstacles if flying.
                            canLand = false -- Cannot land on obstacles.
                        elseif occupyingUnit then
                            -- Players can pass through other players. Enemies cannot pass through anyone.
                            canPass = startUnit.isFlying or (startUnit.type == "player" and occupyingUnit.type == "player")
                            canLand = false -- Cannot land on occupied tiles.
                        else -- Tile is empty
                            canPass = true
                            canLand = true
                        end

                        if canPass then
                            cost_so_far[nextPosKey] = nextCost
                            came_from[nextPosKey] = {tileX = current.tileX, tileY = current.tileY}
                            -- Add to reachable tiles, but only mark as landable if it's truly empty.
                            reachable[nextPosKey] = { cost = nextCost, landable = canLand }
                            table.insert(frontier, {tileX = nextTileX, tileY = nextTileY, cost = nextCost})
                        end
                    end
                end
            end
        end
    end

    return reachable, came_from
end

-- Reconstructs a path from a 'came_from' map generated by a search algorithm.
-- Returns a list of *pixel* coordinates to follow, for the MovementSystem.
function Pathfinding.reconstructPath(came_from, startPosKey, goalPosKey)
    local path = {}
    local currentKey = goalPosKey
    while currentKey and currentKey ~= startPosKey do
        local tileX = tonumber(string.match(currentKey, "(-?%d+)"))
        local tileY = tonumber(string.match(currentKey, ",(-?%d+)"))
        local pixelX, pixelY = Grid.toPixels(tileX, tileY)
        table.insert(path, 1, {x = pixelX, y = pixelY})

        local prev_node = came_from[currentKey]
        if prev_node then
            currentKey = prev_node.tileX .. "," .. prev_node.tileY
        else
            currentKey = nil -- Path is broken, stop.
        end
    end
    return path
end

return Pathfinding