-- world_queries.lua
-- Contains functions for querying the state of the game world, like collision checks.

local Geometry = require("modules.geometry")
local Grid = require("modules.grid")

local WorldQueries = {}
function WorldQueries.isTileOccupied(tileX, tileY, excludeSquare, world)
    -- Check for the Sylvan Spire flag first.
    if world.flag and world.flag.tileX == tileX and world.flag.tileY == tileY then
        return true
    end

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
            -- Convert the pixel-based rectangle into tile boundaries.
            local startTileX, startTileY = Grid.toTile(s.x, s.y)
            -- Important: The end tile is the one containing the bottom-right corner pixel.
            local endTileX, endTileY = Grid.toTile(s.x + s.w - 1, s.y + s.h - 1)

            for _, target in ipairs(targets) do
                -- We only care about living targets. The `target.hp == nil` check is for the flag.
                if target and (target.hp == nil or target.hp > 0) then
                    -- Check if the target's single tile falls within the pattern's tile-based AABB.
                    if target.tileX >= startTileX and target.tileX <= endTileX and
                       target.tileY >= startTileY and target.tileY <= endTileY then
                        return true -- Found a target within one of the pattern's shapes
                    end
                end
            end
        end
    end
    return false -- No targets were found within the entire pattern
end

-- Finds all valid targets for a given attack, based on its blueprint properties.
function WorldQueries.findValidTargetsForAttack(attacker, attackName, world)
    local attackData = AttackBlueprints[attackName]
    if not attackData then return {} end

    local validTargets = {}
    local style = attackData.targeting_style

    if style == "cycle_target" then
        -- Determine who to target (enemies, allies, etc.)
        local potentialTargets = {}
        local affects = attackData.affects or (attackData.type == "support" and "allies" or "enemies")

        -- Correctly determine the target list based on the attacker's perspective.
        -- An "enemy" to a player is an AI unit, and an "enemy" to an AI unit is a player.
        local targetEnemies = (attacker.type == "player") and world.enemies or world.players
        local targetAllies = (attacker.type == "player") and world.players or world.enemies

        if affects == "enemies" then
            for _, unit in ipairs(targetEnemies) do table.insert(potentialTargets, unit) end
        elseif affects == "allies" then
            for _, unit in ipairs(targetAllies) do table.insert(potentialTargets, unit) end
        elseif affects == "all" then
            for _, unit in ipairs(targetEnemies) do table.insert(potentialTargets, unit) end
            for _, unit in ipairs(targetAllies) do table.insert(potentialTargets, unit) end
        end

        -- Special case for hookshot: also allow targeting the flag
        if attackName == "hookshot" and world.flag then
            table.insert(potentialTargets, world.flag)
        end

        -- Determine range
        local range = attackData.range
        if attackName == "phantom_step" then range = attacker.movement end -- Dynamic range
        local minRange = attackData.min_range or 1

        if not range then return {} end -- Can't find targets for an attack without a defined range

        for _, target in ipairs(potentialTargets) do
            local isSelf = (target == attacker)
            local isDead = (target.hp and target.hp <= 0)

            if not isSelf and not isDead then
                local dist = math.abs(attacker.tileX - target.tileX) + math.abs(attacker.tileY - target.tileY)
                if dist >= minRange and dist <= range then
                    -- Special validation for hookshot (must be in a straight, unblocked line)
                    if attackName == "hookshot" then
                        local isStraightLine = (attacker.tileX == target.tileX or attacker.tileY == target.tileY)
                        if isStraightLine then
                            local isBlocked = false
                            if attacker.tileX == target.tileX then -- Vertical line
                                local dirY = (target.tileY > attacker.tileY) and 1 or -1
                                for i = 1, dist - 1 do
                                    if WorldQueries.isTileOccupied(attacker.tileX, attacker.tileY + i * dirY, attacker, world) then
                                        isBlocked = true
                                        break
                                    end
                                end
                            else -- Horizontal line
                                local dirX = (target.tileX > attacker.tileX) and 1 or -1
                                for i = 1, dist - 1 do
                                    if WorldQueries.isTileOccupied(attacker.tileX + i * dirX, attacker.tileY, attacker, world) then
                                        isBlocked = true
                                        break
                                    end
                                end
                            end

                            if not isBlocked then
                                table.insert(validTargets, target)
                            end
                        end
                    -- Special validation for phantom_step (tile behind must be empty)
                    elseif attackName == "phantom_step" then
                        local dx, dy = 0, 0
                        if target.lastDirection == "up" then dy = 1 elseif target.lastDirection == "down" then dy = -1 elseif target.lastDirection == "left" then dx = 1 elseif target.lastDirection == "right" then dx = -1 end
                        local behindTileX, behindTileY = target.tileX + dx, target.tileY + dy
                        if not WorldQueries.isTileOccupied(behindTileX, behindTileY, nil, world) then
                            table.insert(validTargets, target)
                        end
                    else
                        table.insert(validTargets, target)
                    end
                end
            end
        end
    elseif style == "auto_hit_all" then
        -- This style doesn't need pre-calculated targets, it just hits.
        -- We can return a dummy table to indicate the attack is always valid if conditions are met.
        if attackName == "shockwave" then return {true} end -- Always available if you have enemies.
    end

    return validTargets
end

return WorldQueries