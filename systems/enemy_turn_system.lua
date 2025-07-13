-- enemy_turn_system.lua
-- Manages the AI logic for enemies during their turn.

local Pathfinding = require("modules.pathfinding")
local WorldQueries = require("modules.world_queries")
local AttackPatterns = require("modules.attack_patterns")
local UnitAttacks = require("data.unit_attacks")
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

-- Finds the best tile in a unit's range from which to attack a target using a directional pattern.
local function findBestAttackPosition(enemy, target, patternFunc, reachableTiles, world)
    if not patternFunc then return nil end
    
    local bestPosKey, closestDistSq = nil, math.huge
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
            -- This is a valid attack spot. Is it the best one so far (closest to target)?
            local distSq = (tileX - target.tileX)^2 + (tileY - target.tileY)^2
            if distSq < closestDistSq then
                closestDistSq = distSq
                bestPosKey = posKey
            end
        end
    end
    return bestPosKey -- Return the best spot found, or nil.
end

-- Finds the best tile in a unit's range from which to use a cycle_target attack on a target.
local function findBestCycleTargetAttackPosition(enemy, target, attackName, reachableTiles, world)
    local bestPosKey, closestDistSq = nil, math.huge
    -- Create a temporary copy of the enemy to test positions without modifying the real one.
    local tempEnemy = {}
    for k, v in pairs(enemy) do tempEnemy[k] = v end
    
    for posKey, _ in pairs(reachableTiles) do
        local tileX = tonumber(string.match(posKey, "(-?%d+)"))
        local tileY = tonumber(string.match(posKey, ",(-?%d+)"))
        tempEnemy.tileX, tempEnemy.tileY = tileX, tileY
        
        local validTargets = WorldQueries.findValidTargetsForAttack(tempEnemy, attackName, world)
        for _, validTarget in ipairs(validTargets) do
            if validTarget == target then
                -- This is a valid attack spot. Is it the best one so far (closest to target)?
                local distSq = (tileX - target.tileX)^2 + (tileY - target.tileY)^2
                if distSq < closestDistSq then
                    closestDistSq = distSq
                    bestPosKey = posKey
                end
                break -- Found a valid spot for this tile, no need to check other targets from this same tile.
            end
        end
    end
    return bestPosKey
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

    -- If any unit is currently moving or an attack is resolving, wait.
    for _, entity in ipairs(world.all_entities) do if entity.components.movement_path then return end end
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
        local attackName = blueprint and blueprint.attacks and blueprint.attacks[1]
        if not attackName then actingEnemy.hasActed = true; return end
        local attackData = AttackBlueprints[attackName]
        if not attackData then actingEnemy.hasActed = true; return end

        -- 2. Determine if an attack is possible and from where.
        local canAttackNow = false
        local bestAttackPosKey = nil
        local reachableTiles, came_from = Pathfinding.calculateReachableTiles(actingEnemy, world)

        if attackData.targeting_style == "cycle_target" then
            -- Check if we can attack from the current position.
            local currentTargets = WorldQueries.findValidTargetsForAttack(actingEnemy, attackName, world)
            for _, t in ipairs(currentTargets) do if t == targetPlayer then canAttackNow = true; break end end

            -- If not, find a better position.
            if not canAttackNow then
                bestAttackPosKey = findBestCycleTargetAttackPosition(actingEnemy, targetPlayer, attackName, reachableTiles, world)
            end

        elseif attackData.targeting_style == "directional_aim" then
            local patternFunc = AttackPatterns[attackName]
            if patternFunc and WorldQueries.isTargetInPattern(actingEnemy, patternFunc, {targetPlayer}, world) then
                canAttackNow = true
            else
                bestAttackPosKey = findBestAttackPosition(actingEnemy, targetPlayer, patternFunc, reachableTiles, world)
            end
        end

        -- 3. Execute the chosen action.
        if canAttackNow then
            -- Attack from current position.
            if attackData.targeting_style == "cycle_target" then
                -- The AI needs to "select" its target for the attack function to work.
                world.cycleTargeting.active = true
                world.cycleTargeting.targets = {targetPlayer}
                world.cycleTargeting.selectedIndex = 1
            end
            UnitAttacks[attackName](actingEnemy, attackData.power, world)
            world.cycleTargeting.active = false -- Clean up
            actingEnemy.hasActed = true
            return

        elseif bestAttackPosKey then
            -- Move to the best attack position. The AI will attack on its next update after moving.
            local startKey = actingEnemy.tileX .. "," .. actingEnemy.tileY
            local path = Pathfinding.reconstructPath(came_from, startKey, bestAttackPosKey)
            if path and #path > 0 then actingEnemy.components.movement_path = path; return end

        else
            -- Cannot attack, so just move closer. This consumes the turn.
            local moveOnlyDestinationKey = findClosestReachableTile(actingEnemy, targetPlayer, reachableTiles)
            if moveOnlyDestinationKey then
                local startKey = actingEnemy.tileX .. "," .. actingEnemy.tileY
                local path = Pathfinding.reconstructPath(came_from, startKey, moveOnlyDestinationKey)
                if path and #path > 0 then actingEnemy.components.movement_path = path end
            end
        end

        -- After moving (or failing to), the enemy's turn is over.
        actingEnemy.hasActed = true
    else
        -- No more enemies to act, which means the enemy turn is over.
        world.turnShouldEnd = true
    end
end

return EnemyTurnSystem