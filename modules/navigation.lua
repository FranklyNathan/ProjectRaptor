-- navigation.lua
-- Contains functions for pathfinding and calculating special movements.

local Grid = require("modules.grid")
local WorldQueries = require("modules.world_queries")

local Navigation = {}

function Navigation.createDash(square, direction, distance, speedMultiplier, world)
    local finalX, finalY = square.x, square.y
    local step = Config.SQUARE_SIZE
    local mapWidth, mapHeight = Config.MAP_WIDTH_TILES * Config.SQUARE_SIZE, Config.MAP_HEIGHT_TILES * Config.SQUARE_SIZE

    for i = 1, distance do
        local nextX, nextY = finalX, finalY
        if direction == "up" then nextY = finalY - step
        elseif direction == "down" then nextY = finalY + step
        elseif direction == "left" then nextX = finalX - step
        elseif direction == "right" then nextX = finalX + step
        end

        -- Check for obstacles (other units or screen bounds)
        local isOutOfBounds = nextX < 0 or nextX >= mapWidth or nextY < 0 or nextY >= mapHeight
        local nextTileX, nextTileY = Grid.toTile(nextX, nextY)
        if isOutOfBounds or WorldQueries.isTileOccupied(nextTileX, nextTileY, square, world) then
            break -- Stop before hitting an obstacle
        end
        finalX, finalY = nextX, nextY
    end
    square.targetX = finalX
    square.targetY = finalY
    square.speedMultiplier = speedMultiplier or 1
end

function Navigation.findPath(startSquare, targetSquare, world)
    local path = {}
    if not startSquare or not targetSquare then return path end

    local dx = targetSquare.x - startSquare.x
    local dy = targetSquare.y - startSquare.y
    local step = Config.SQUARE_SIZE
    local currentX, currentY = startSquare.x, startSquare.y

    -- Generate horizontal moves
    local xDir = (dx > 0) and 1 or -1
    -- The '- 1' ensures the path stops one tile before the target,
    -- preventing the AI from trying to step on the enemy's square.
    for i = 1, (math.abs(dx) / step) - 1 do
        local nextX = currentX + xDir * step
        local nextTileX, nextTileY = Grid.toTile(nextX, currentY)
        if not WorldQueries.isTileOccupied(nextTileX, nextTileY, startSquare, world) then
            table.insert(path, {x = nextX, y = currentY})
            currentX = nextX
        else
            return {} -- Path is blocked, give up for now.
        end
    end

    -- Generate vertical moves
    local yDir = (dy > 0) and 1 or -1
    for i = 1, (math.abs(dy) / step) - 1 do
        local nextY = currentY + yDir * step
        local nextTileX, nextTileY = Grid.toTile(currentX, nextY)
        if not WorldQueries.isTileOccupied(nextTileX, nextTileY, startSquare, world) then
            table.insert(path, {x = currentX, y = nextY})
            currentY = nextY
        else
            return {} -- Path is blocked, give up for now.
        end
    end

    return path
end

function Navigation.repositionForAttack(square, target, world, attackPatternFunc)
    if not square or not target then return end
    if not attackPatternFunc then return end -- Need a pattern to reposition

    local step = Config.SQUARE_SIZE
    local bestX, bestY, bestDistSq = square.x, square.y, math.huge
    local mapPixelWidth = Config.MAP_WIDTH_TILES * Config.SQUARE_SIZE
    local mapPixelHeight = Config.MAP_HEIGHT_TILES * Config.SQUARE_SIZE

    -- Create a temporary square object once, outside the loops, for efficiency.
    -- We will update its properties on each iteration instead of creating a new table.
    local tempSquare = {
        size = square.size,
        lastDirection = square.lastDirection,
        x = 0, y = 0 -- These will be updated in the loop
    }

    -- Check positions within a reasonable range (e.g., up to 8 steps)
    for dx = -8, 8 do
        for dy = -8, 8 do
            -- Skip the current position (0,0) and diagonals (for simplicity)
            local isCenterTile = (dx == 0 and dy == 0)
            local isDiagonalTile = (math.abs(dx) == math.abs(dy) and dx ~= 0)

            -- This is the idiomatic Lua 5.1 way to skip an iteration.
            -- We wrap the code we want to run in a conditional block.
            if not (isCenterTile or isDiagonalTile) then
                local potentialX, potentialY = square.x + dx * step, square.y + dy * step

                -- Check bounds and occupancy
                local isOutOfBounds = potentialX < 0 or potentialX > mapPixelWidth - square.size or
                                   potentialY < 0 or potentialY > mapPixelHeight - square.size
                local potentialTileX, potentialTileY = Grid.toTile(potentialX, potentialY)
                local isOccupied = WorldQueries.isTileOccupied(potentialTileX, potentialTileY, square, world)

                if not isOutOfBounds and not isOccupied then
                    -- Update the temp square's position
                    tempSquare.x = potentialX
                    tempSquare.y = potentialY

                    -- Determine the optimal direction from the potential position to the target.
                    -- This allows the AI to find spots that require turning to attack.
                    local dx_from_potential, dy_from_potential = target.x - potentialX, target.y - potentialY
                    if math.abs(dx_from_potential) > math.abs(dy_from_potential) then
                        tempSquare.lastDirection = (dx_from_potential > 0) and "right" or "left"
                    else
                        tempSquare.lastDirection = (dy_from_potential > 0) and "down" or "up"
                    end

                    -- Check if the attack pattern hits from this new position and orientation.
                    if WorldQueries.isTargetInPattern(tempSquare, attackPatternFunc, {target}, world) then
                        -- Prioritize positions closer to the target
                        local distSq = (potentialX - target.x)^2 + (potentialY - target.y)^2
                        if distSq < bestDistSq then
                            bestX, bestY, bestDistSq = potentialX, potentialY, distSq
                        end
                    end
                end
            end
        end
    end

    if bestDistSq < math.huge then -- Found a valid repositioning spot
        -- Instead of moving directly to the best spot, find the path there
        -- and only take the first step. This ensures one-tile-per-turn movement.
        local tempTarget = { x = bestX, y = bestY }
        local pathToBestSpot = Navigation.findPath(square, tempTarget, world)

        if #pathToBestSpot > 0 then
            local nextStep = pathToBestSpot[1]
            square.targetX, square.targetY = nextStep.x, nextStep.y

            -- Update last direction to face target more accurately
            if target then
                local dx, dy = target.x - square.x, target.y - square.y
                if math.abs(dx) > math.abs(dy) then
                    square.lastDirection = (dx > 0) and "right" or "left"
                else
                    square.lastDirection = (dy > 0) and "down" or "up"
                end
            end
        end
    end
end

return Navigation