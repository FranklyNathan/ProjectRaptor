-- world_queries.lua
-- Contains functions for querying the state of the game world, like collision checks.

local Geometry = require("modules.geometry")

local WorldQueries = {}
function WorldQueries.isTileOccupied(tileX, tileY, excludeSquare, world)
    for _, s in ipairs(world.all_entities) do
        -- Only check against players and enemies, not projectiles etc.
        if (s.type == "player" or s.type == "enemy") and s ~= excludeSquare and s.hp > 0 then
            if s.tileX == tileX and s.tileY == tileY then
                return true
            end
        end
    end
    return false
end

function WorldQueries.isTileOccupiedBySameTeam(tileX, tileY, originalSquare, world)
    local teamToCheck = (originalSquare.type == "player") and world.players or world.enemies
    for _, s in ipairs(teamToCheck) do
        if s ~= originalSquare and s.hp > 0 and s.tileX == tileX and s.tileY == tileY then
            return true
        end
    end
    return false
end

function WorldQueries.isTargetInPattern(attacker, patternFunc, targets, world)
    if not patternFunc or not targets then return false end

    local effects = patternFunc(attacker, world) -- Pass world to the pattern generator
    for _, effectData in ipairs(effects) do
        local s = effectData.shape

        if s.type == "rect" then
            for _, target in ipairs(targets) do
                if target.hp > 0 then
                    local targetCenterX = target.x + target.size / 2
                    local targetCenterY = target.y + target.size / 2
                    if targetCenterX >= s.x and targetCenterX < s.x + s.w and
                       targetCenterY >= s.y and targetCenterY < s.y + s.h then
                        return true -- Found a target within one of the pattern's shapes
                    end
                end
            end
        -- Handle line-based patterns for attacks like Electivire K
        elseif s.type == "line_set" then
            for _, target in ipairs(targets) do
                if target.hp > 0 then
                    for _, line in ipairs(s.lines) do
                        if Geometry.isCircleCollidingWithLine(target.x+target.size/2, target.y+target.size/2, target.size/2, line.x1, line.y1, line.x2, line.y2, s.thickness/2) then
                            return true -- Found a target intersecting a beam
                        end
                    end
                end
            end
        end
    end
    return false -- No targets were found within the entire pattern
end

return WorldQueries