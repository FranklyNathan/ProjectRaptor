-- range_calculator.lua
-- Calculates the full attack range ("danger zone") for a given unit.

local Pathfinding = require("modules.pathfinding")
local AttackPatterns = require("modules.attack_patterns")
local Grid = require("modules.grid")

local RangeCalculator = {}

-- Calculates all tiles a unit can attack from any of its reachable positions.
function RangeCalculator.calculateAttackableTiles(unit, world)
    if not unit or not unit.movement or not unit.playerType then return {} end

    local attackableTiles = {} -- Using a set to avoid duplicates: { ["x,y"] = true }
    local reachableTiles, _ = Pathfinding.calculateReachableTiles(unit, world)

    local blueprint = CharacterBlueprints[unit.playerType]
    if not blueprint or not blueprint.attacks then return {} end

    -- Create a temporary unit to simulate positions and directions without modifying the real one.
    local tempUnit = {
        tileX = 0, tileY = 0,
        x = 0, y = 0,
        size = unit.size,
        lastDirection = "down"
    }
    local directions = {"up", "down", "left", "right"}

    -- For each tile the unit can move to...
    for posKey, _ in pairs(reachableTiles) do
        local tileX = tonumber(string.match(posKey, "(-?%d+)"))
        local tileY = tonumber(string.match(posKey, ",(-?%d+)"))

        -- Update the temp unit's position
        tempUnit.tileX, tempUnit.tileY = tileX, tileY
        tempUnit.x, tempUnit.y = Grid.toPixels(tileX, tileY)

        -- ...check every attack it has...
        for _, attackName in ipairs(blueprint.attacks) do
            local attackData = AttackBlueprints[attackName]
            if attackData then
                if attackData.targeting_style == "cycle_target" then
                    -- Handle cycle_target attacks (like slash) by calculating their Manhattan distance range.
                    local range = attackData.range
                    local minRange = attackData.min_range or 1
                    if range then
                        -- From the current reachable tile (tileX, tileY), find all tiles within attack range.
                        for dx = -range, range do
                            for dy = -range, range do
                                local manhattanDist = math.abs(dx) + math.abs(dy)
                                if manhattanDist >= minRange and manhattanDist <= range then
                                    local attackTileX, attackTileY = tileX + dx, tileY + dy
                                    -- Check map bounds before adding.
                                    if attackTileX >= 0 and attackTileX < Config.MAP_WIDTH_TILES and attackTileY >= 0 and attackTileY < Config.MAP_HEIGHT_TILES then
                                        attackableTiles[attackTileX .. "," .. attackTileY] = true
                                    end
                                end
                            end
                        end
                    end
                else -- Handle directional patterns
                    local patternFunc = AttackPatterns[attackName]
                    if patternFunc then
                        -- ...in every possible direction.
                        for _, dir in ipairs(directions) do
                            tempUnit.lastDirection = dir
                            local attackShapes = patternFunc(tempUnit, world)
                            -- Convert the shapes' pixel coordinates back to tiles and add to the set.
                            for _, effectData in ipairs(attackShapes) do
                                local s = effectData.shape
                                local startTileX, startTileY = Grid.toTile(s.x, s.y)
                                local endTileX, endTileY = Grid.toTile(s.x + s.w - 1, s.y + s.h - 1)
                                for ty = startTileY, endTileY do for tx = startTileX, endTileX do attackableTiles[tx .. "," .. ty] = true end end
                            end
                        end
                    end
                end
            end
        end
    end

    return attackableTiles
end

return RangeCalculator