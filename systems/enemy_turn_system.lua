-- enemy_turn_system.lua
-- Manages the AI logic for enemies during their turn.

local Pathfinding = require("modules.pathfinding")
local WorldQueries = require("modules.world_queries")
local AttackPatterns = require("modules.attack_patterns")
local EnemyAttacks = require("data.enemy_attacks")
local Grid = require("modules.grid")

local EnemyTurnSystem = {}

-- Helper to find the closest player to an enemy.
local function findClosestPlayer(enemy, world)
    local closestPlayer, shortestDistSq = nil, math.huge
    for _, player in ipairs(world.players) do
        if player.hp > 0 then
            local distSq = (player.tileX - enemy.tileX)^2 + (player.tileY - enemy.tileY)^2
            if distSq < shortestDistSq then
                shortestDistSq, closestPlayer = distSq, player
            end
        end
    end
    return closestPlayer
end

-- Finds the best tile in a unit's range from which to attack a target.
local function findBestAttackPosition(enemy, target, patternFunc, reachableTiles, world)
    if not patternFunc then return nil end

    -- Create a temporary enemy object to test positions without modifying the real one.
    -- It needs both tile and pixel coordinates for the pattern functions to work correctly.
    local tempEnemy = { tileX = 0, tileY = 0, x = 0, y = 0, size = enemy.size, lastDirection = "down" }

    for posKey, _ in pairs(reachableTiles) do
        local tileX = tonumber(string.match(posKey, "(-?%d+)"))
        local tileY = tonumber(string.match(posKey, ",(-?%d+)"))
        tempEnemy.tileX, tempEnemy.tileY = tileX, tileY
        tempEnemy.x, tempEnemy.y = Grid.toPixels(tileX, tileY)

        -- Make the temporary unit face the target from its potential new spot.
        local dx, dy = target.tileX - tempEnemy.tileX, target.tileY - tempEnemy.tileY
        if math.abs(dx) > math.abs(dy) then tempEnemy.lastDirection = (dx > 0) and "right" or "left"
        else tempEnemy.lastDirection = (dy > 0) and "down" or "up" end

        -- Check if the target is in the attack pattern from this new position.
        if WorldQueries.isTargetInPattern(tempEnemy, patternFunc, {target}, world) then
            return posKey -- For now, we return the first valid spot we find.
        end
    end
    return nil -- No suitable attack position found.
end

-- Finds the reachable tile that is closest to the target.
local function findClosestReachableTile(enemy, target, reachableTiles)
    local closestKey, closestDistSq = nil, math.huge
    for posKey, _ in pairs(reachableTiles) do
        if posKey ~= (enemy.tileX .. "," .. enemy.tileY) then
            local tileX = tonumber(string.match(posKey, "(-?%d+)"))
            local tileY = tonumber(string.match(posKey, ",(-?%d+)"))
            local distSq = (tileX - target.tileX)^2 + (tileY - target.tileY)^2
            if distSq < closestDistSq then closestDistSq, closestKey = distSq, posKey end
        end
    end
    return closestKey
end

function EnemyTurnSystem.update(dt, world)
    if world.turn ~= "enemy" then return end

    -- If any unit is currently moving, wait for it to finish before processing the next one.
    for _, entity in ipairs(world.all_entities) do
        if entity.components.movement_path then
            return
        end
    end

    -- If any attack animation is playing, wait for it to finish before processing the next unit.
    if #world.attackEffects > 0 then
        return
    end

    -- Find the next enemy that has not yet acted.
    local actingEnemy = nil
    for _, enemy in ipairs(world.enemies) do
        if not enemy.hasActed and enemy.hp > 0 then
            actingEnemy = enemy
            break
        end
    end

    if actingEnemy then
        local targetPlayer = findClosestPlayer(actingEnemy, world)
        if not targetPlayer then actingEnemy.hasActed = true; return end

        -- 1. Decide which attack to use (for now, always the first one).
        local blueprint = EnemyBlueprints[actingEnemy.enemyType]
        local attackData = blueprint and blueprint.attacks and blueprint.attacks[1]
        if not attackData then actingEnemy.hasActed = true; return end
        local patternFunc = AttackPatterns[attackData.name]

        -- 2. Check if the enemy can attack from its current position.
        if patternFunc and WorldQueries.isTargetInPattern(actingEnemy, patternFunc, {targetPlayer}, world) then
            EnemyAttacks[attackData.name](actingEnemy, attackData, world)
            actingEnemy.hasActed = true -- Mark as acted
            return
        end

        -- 3. If not, find a tile to move to.
        local reachableTiles, came_from = Pathfinding.calculateReachableTiles(actingEnemy, world)
        local bestAttackPosKey = findBestAttackPosition(actingEnemy, targetPlayer, patternFunc, reachableTiles, world)

        if bestAttackPosKey then
            -- Found a spot to move to and then attack.
            local startKey = actingEnemy.tileX .. "," .. actingEnemy.tileY
            local path = Pathfinding.reconstructPath(came_from, startKey, bestAttackPosKey)
            if path and #path > 0 then
                actingEnemy.components.movement_path = path
                -- Queue the attack to be performed after the move is complete.
                actingEnemy.components.queued_action = { type = "attack", attackData = attackData, target = targetPlayer }
            end
        else
            -- Cannot get in range to attack, so just move closer.
            local moveOnlyDestinationKey = findClosestReachableTile(actingEnemy, targetPlayer, reachableTiles)
            if moveOnlyDestinationKey then
                local startKey = actingEnemy.tileX .. "," .. actingEnemy.tileY
                local path = Pathfinding.reconstructPath(came_from, startKey, moveOnlyDestinationKey)
                if path and #path > 0 then
                    actingEnemy.components.movement_path = path
                    -- Queue a "wait" action since no attack is possible.
                    actingEnemy.components.queued_action = { type = "wait" }
                end
            end
        end

        -- After making a decision (or failing to), the enemy's thinking phase for this turn is over.
        actingEnemy.hasActed = true
    else
        -- No more enemies to act, which means the enemy turn is over.
        world:endTurn()
    end
end

return EnemyTurnSystem