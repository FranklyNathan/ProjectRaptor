-- player_attacks.lua
-- Contains all player attack implementations.

local EffectFactory = require("modules.effect_factory")
local WorldQueries = require("modules.world_queries")
local Navigation = require("modules.navigation")
local CombatActions = require("modules.combat_actions")
local AttackPatterns = require("modules.attack_patterns")
local Assets = require("modules.assets")

local PlayerAttacks = {}

--------------------------------------------------------------------------------
-- ATTACK IMPLEMENTATIONS
--------------------------------------------------------------------------------

-- Helper function to execute attacks based on a pattern generator.
-- This reduces code duplication by handling the common logic of iterating
-- through a pattern's effects and creating the corresponding attack visuals/logic.
local function executePatternAttack(square, power, patternFunc, isHeal, targetType, statusEffect, specialProperties)
    local effects = patternFunc(square)
    local color = isHeal and {0.5, 1, 0.5, 1} or {1, 0, 0, 1}
    targetType = targetType or (isHeal and "all" or "enemy")

    for _, effectData in ipairs(effects) do
        local s = effectData.shape
        EffectFactory.addAttackEffect(s.x, s.y, s.w, s.h, color, effectData.delay, square, power, isHeal, targetType, nil, statusEffect, specialProperties)
    end
end

PlayerAttacks.drapion_j = function(square, power, world)
    local effects = AttackPatterns.drapion_j(square)
    for _, effectData in ipairs(effects) do
        local s = effectData.shape
        EffectFactory.addAttackEffect(s.x, s.y, s.w, s.h, {1, 0, 0, 1}, effectData.delay, square, power, false, "enemy", nil, {type = "careening", force = 10, useAttackerDirection = true})
    end
end

PlayerAttacks.drapion_k = function(square, power, world)
    local status = {type = "poison", duration = 3} -- Lasts 3 turns
    executePatternAttack(square, power, AttackPatterns.drapion_k, false, "enemy", status)
end

PlayerAttacks.drapion_l = function(square, power, world)
    local closestEnemy, shortestDistanceSq = nil, math.huge
    for _, enemy in ipairs(world.enemies) do
        if enemy.hp > 0 then
            local distSq = (enemy.x - square.x)^2 + (enemy.y - square.y)^2
            if distSq < shortestDistanceSq then
                shortestDistanceSq, closestEnemy = distSq, enemy
            end
        end
    end
    if closestEnemy then
        local teleportX, teleportY = closestEnemy.x, closestEnemy.y
        if closestEnemy.lastDirection == "up" then teleportY = closestEnemy.y + Config.MOVE_STEP
        elseif closestEnemy.lastDirection == "down" then teleportY = closestEnemy.y - Config.MOVE_STEP
        elseif closestEnemy.lastDirection == "left" then teleportX = closestEnemy.x + Config.MOVE_STEP
        elseif closestEnemy.lastDirection == "right" then teleportX = closestEnemy.x - Config.MOVE_STEP
        end
        local windowWidth, windowHeight = Config.VIRTUAL_WIDTH, Config.VIRTUAL_HEIGHT
        teleportX = math.max(0, math.min(teleportX, windowWidth - Config.SQUARE_SIZE))
        teleportY = math.max(0, math.min(teleportY, windowHeight - Config.SQUARE_SIZE))
        if not WorldQueries.isTileOccupied(teleportX, teleportY, Config.SQUARE_SIZE, square, world) then
            square.x, square.y, square.targetX, square.targetY = teleportX, teleportY, teleportX, teleportY
            square.lastDirection = closestEnemy.lastDirection
            local attackX, attackY = square.x, square.y
            if square.lastDirection == "up" then attackY = square.y - Config.MOVE_STEP
            elseif square.lastDirection == "down" then attackY = square.y + Config.MOVE_STEP
            elseif square.lastDirection == "left" then attackX = square.x - Config.MOVE_STEP
            elseif square.lastDirection == "right" then attackX = square.x + Config.MOVE_STEP
            end
            EffectFactory.addAttackEffect(attackX, attackY, Config.SQUARE_SIZE, Config.SQUARE_SIZE, {1, 0, 0, 1}, 0, square, power, false, "enemy", 0.2, {type = "stunned", duration = 1})
        end
    end
end

PlayerAttacks.florges_j = function(square, power, world)
    executePatternAttack(square, power, AttackPatterns.florges_j, false, "enemy")
end

PlayerAttacks.florges_k = function(square, power, world)
    executePatternAttack(square, power, AttackPatterns.florges_k, true, "player", nil, {cleansesPoison = true})
end

PlayerAttacks.florges_l = function(square, power, world)
    local effectSize = Config.MOVE_STEP * 11
    local effectOriginX, effectOriginY = square.x - (Config.MOVE_STEP * 5), square.y - (Config.MOVE_STEP * 5)
    EffectFactory.addAttackEffect(effectOriginX, effectOriginY, effectSize, effectSize, {0, 0, 1, 1}, 0, square, 0, false, "player")
    for _, p in ipairs(world.players) do
        if p ~= square and p.hp > 0 then
            local pCenterX, pCenterY = p.x + p.size / 2, p.y + p.size / 2
            if pCenterX >= effectOriginX and pCenterX < effectOriginX + effectSize and pCenterY >= effectOriginY and pCenterY < effectOriginY + effectSize then
                p.actionBarCurrent = p.actionBarMax
            end
        end
    end
end

PlayerAttacks.venusaur_j = function(square, power, world)
    local newProjectile = EntityFactory.createProjectile(square.x, square.y, square.lastDirection, square, power, false, nil)
    world:queue_add_entity(newProjectile)
end

PlayerAttacks.venusaur_k = function(square, power, world)
    executePatternAttack(square, power, AttackPatterns.venusaur_k, false, "enemy")
end

PlayerAttacks.venusaur_l = function(square, power, world)
    for _, enemy in ipairs(world.enemies) do
        if enemy.hp > 0 then
            -- Create a 0-power attack effect on each enemy that carries the "paralyzed" status.
            EffectFactory.addAttackEffect(
                enemy.x, enemy.y, enemy.size, enemy.size,
                {1, 1, 0, 0.7}, -- Venusaur visual effect
                0, -- delay
                square, -- attacker
                0, -- power
                false, -- isHeal
                "enemy", -- targetType
                nil, -- critChanceOverride
                {type = "paralyzed", duration = 2} -- statusEffect, lasts 2 turns
            )
        end
    end
end

PlayerAttacks.magnezone_j = function(square, power, world)
    executePatternAttack(square, power, AttackPatterns.magnezone_j, false, "enemy")
end

PlayerAttacks.magnezone_k = function(square, power, world)
    -- Pulls all enemies to be 1 tile away from the square.
    local occupiedDestinations = {}
    local adjacentTiles = {
        {dx = 0, dy = -1}, {dx = 1, dy = -1}, {dx = 1, dy = 0}, {dx = 1, dy = 1},
        {dx = 0, dy = 1}, {dx = -1, dy = 1}, {dx = -1, dy = 0}, {dx = -1, dy = -1}
    }

    -- Add a visual effect for the pull
    local effectSize = Config.MOVE_STEP * 7
    EffectFactory.addAttackEffect(square.x - effectSize/2 + square.size/2, square.y - effectSize/2 + square.size/2, effectSize, effectSize, {1, 1, 1, 0.5}, 0, square, 0, false, "enemy")

    local snappedPlayerX = math.floor((square.x / Config.MOVE_STEP) + 0.5) * Config.MOVE_STEP
    local snappedPlayerY = math.floor((square.y / Config.MOVE_STEP) + 0.5) * Config.MOVE_STEP

    for _, enemy in ipairs(world.enemies) do
        if enemy.hp > 0 then
            local foundSpot = false
            for _, tile in ipairs(adjacentTiles) do
                local destX = snappedPlayerX + tile.dx * Config.MOVE_STEP
                local destY = snappedPlayerY + tile.dy * Config.MOVE_STEP
                local destKey = destX .. "," .. destY

                if not occupiedDestinations[destKey] and not WorldQueries.isTileOccupied(destX, destY, enemy.size, enemy, world) then
                    -- Found an empty spot, assign it to the enemy
                    enemy.targetX = destX
                    enemy.targetY = destY
                    occupiedDestinations[destKey] = true -- Mark this spot as taken for this turn
                    foundSpot = true
                    break
                end
            end
        end
    end
end

PlayerAttacks.magnezone_l = function(square, power, world)
    -- For the next 3 seconds, all enemy attacks heal players.
    world.playerTeamStatus.isHealingFromAttacks = true -- The active buff flag
    world.playerTeamStatus.duration = 1 -- Lasts for 1 full turn cycle (player and enemy)

    -- Add a visual shield effect on all players
    for _, p in ipairs(world.players) do
        if p.hp > 0 then
            p.shieldEffectTimer = 1.5 -- Visual effect timer in seconds, can be different from turn duration
        end
    end
end

PlayerAttacks.electivire_j = function(square, power, world)
    -- This function toggles the continuous attack state.
    -- The actual attack logic is handled in main.lua's update loop.
    if square.continuousAttack then
        -- If already active, pressing the button again stops it.
        square.continuousAttack = nil
    else
        -- Otherwise, start the attack.
        square.continuousAttack = { name = "random_ripple", timer = 0, power = power }
    end
end

PlayerAttacks.electivire_k = function(square, power, world)
    -- This attack connects all living players with a damaging beam.
    if #world.players < 2 then return end -- Need at least 2 players to form a line

    local beamThickness = Config.SQUARE_SIZE * 2 -- 2 tiles thick

    -- Create a list of lines to draw between players
    local lines = {}
    for i = 1, #world.players do
        local p1 = world.players[i]
        local p2 = world.players[i % #world.players + 1] -- Wrap around to form a closed loop
        table.insert(lines, {
            x1 = p1.x + p1.size/2, y1 = p1.y + p1.size/2,
            x2 = p2.x + p2.size/2, y2 = p2.y + p2.size/2
        })
    end

    -- Create a special attack effect to represent the beams
    EffectFactory.addAttackEffect(0, 0, 0, 0, {1, 0, 0, 1}, 0, square, power, false, "enemy", nil, nil, {type = "triangle_beam", lines = lines, thickness = beamThickness})
end

PlayerAttacks.electivire_l = function(square, power, world)
    -- A simple non-damaging dash forward at 2x speed.
    Navigation.createDash(square, square.lastDirection, 4, 2, world)
end


-- Helper function for grappling hook logic.
-- Prioritizes targets: Careening Enemies > Flags > Normal Enemies.
local function executeGrapple(square, power, world)
    local target = nil
    local targetType = nil

    -- Priority 1: Careening enemies
    for _, enemy in ipairs(world.enemies) do
        if enemy.hp > 0 and enemy.statusEffects.careening then
            target = enemy
            targetType = "enemy"
            break
        end
    end

    -- Priority 2: Flags
    if not target and world.flag then
        target = world.flag
        targetType = "flag"
    end

    -- Priority 3: Nearest normal enemy
    if not target then
        local shortestDistSq = math.huge
        for _, enemy in ipairs(world.enemies) do
            if enemy.hp > 0 then
                local distSq = (square.x - enemy.x)^2 + (square.y - enemy.y)^2
                if distSq < shortestDistSq then
                    shortestDistSq, target, targetType = distSq, enemy, "enemy"
                end
            end
        end
    end

    if not target then return end -- No valid target found

    if targetType == "flag" then
        -- Grappling to a flag: Dash to it and knock up enemies in the path.
        -- This is the new Sceptile K behavior.
        table.insert(world.grappleLineEffects, {attacker = square, target = target, lifetime = 0.5})

        square.components.dash_to_target = {
            targetX = world.flag.x,
            targetY = world.flag.y,
            speed = Config.SLIDE_SPEED * 5, -- Very fast dash
            power = power,
            statusEffect = {type = "airborne", duration = 2},
            hitEnemies = {} -- Keep track of who has been hit to avoid multi-hits.
        }
    elseif targetType == "enemy" then
        -- Grappling an enemy: Pull both to a midpoint.
        -- This is the Tangrowth J behavior.
        local wasCareening = target.statusEffects.careening ~= nil
        if wasCareening then target.statusEffects.careening = nil end

        local midX = math.floor(((square.x + target.x) / 2 / Config.MOVE_STEP) + 0.5) * Config.MOVE_STEP
        local midY = math.floor(((square.y + target.y) / 2 / Config.MOVE_STEP) + 0.5) * Config.MOVE_STEP

        square.targetX, square.targetY = midX, midY
        target.targetX, target.targetY = midX, midY

        square.speedMultiplier = 2
        target.speedMultiplier = 2

        square.components.grapple_collision_effect = {
            power = wasCareening and power * 2 or power,
            rippleSize = 2,
            statusEffect = {type = "careening", force = 1, attacker = square}
        }

        table.insert(world.grappleLineEffects, {attacker = square, target = target, lifetime = math.huge})
    end
end

PlayerAttacks.tangrowth_j = executeGrapple

PlayerAttacks.tangrowth_k = function(square, power, world)
    -- Apply a one-hit shield to all living allies.
    for _, p in ipairs(world.players) do
        if p.hp > 0 then
            p.components.shielded = true
        end
    end
end

PlayerAttacks.tangrowth_l = function(square, power, world)
    -- Part 1: Find the 3 closest enemies.
    local potentialTargets = {}
    for _, enemy in ipairs(world.enemies) do
        if enemy.hp > 0 then
            local distSq = (square.x - enemy.x)^2 + (square.y - enemy.y)^2
            table.insert(potentialTargets, {enemy = enemy, distSq = distSq})
        end
    end

    -- Sort targets by distance (closest first)
    table.sort(potentialTargets, function(a, b) return a.distSq < b.distSq end)

    -- Get the top 3 targets
    local targets = {}
    for i = 1, math.min(3, #potentialTargets) do
        table.insert(targets, potentialTargets[i].enemy)
    end

    -- Part 2: Pull the selected enemies towards the square.
    local occupiedDestinations = {}
    local adjacentTiles = {
        {dx = 0, dy = -1}, {dx = 1, dy = -1}, {dx = 1, dy = 0}, {dx = 1, dy = 1},
        {dx = 0, dy = 1}, {dx = -1, dy = 1}, {dx = -1, dy = 0}, {dx = -1, dy = -1}
    }

    local snappedPlayerX = math.floor((square.x / Config.MOVE_STEP) + 0.5) * Config.MOVE_STEP
    local snappedPlayerY = math.floor((square.y / Config.MOVE_STEP) + 0.5) * Config.MOVE_STEP

    for _, enemy in ipairs(targets) do
        -- Add a temporary visual line for the grapple.
        table.insert(world.grappleLineEffects, {attacker = square, target = enemy, lifetime = 0.5})

        -- If the grappled enemy is careening, stop it.
        if enemy.statusEffects.careening then
            enemy.statusEffects.careening = nil
        end

        local foundSpot = false
        for _, tile in ipairs(adjacentTiles) do
            local destX = snappedPlayerX + tile.dx * Config.MOVE_STEP
            local destY = snappedPlayerY + tile.dy * Config.MOVE_STEP
            local destKey = destX .. "," .. destY

            if not occupiedDestinations[destKey] and not WorldQueries.isTileOccupied(destX, destY, enemy.size, enemy, world) then
                enemy.targetX, enemy.targetY = destX, destY
                enemy.speedMultiplier = 2 -- Increase speed for the pull
                occupiedDestinations[destKey] = true
                foundSpot = true
                break
            end
        end
    end

    -- Part 3: If any enemies were actually targeted, add a component to trigger the ripple effect when they arrive.
    if #targets > 0 then
        square.components.mass_grapple_pending = {
            power = power,
            targets = targets,
            statusEffect = {type = "careening", force = 1, attacker = square}
        }
    end
end

PlayerAttacks.sceptile_j = function(square, power, world)
    -- If a flag already exists, this new one will overwrite it.
    -- We first set it to nil to clear any old reference.
    world.flag = nil

    -- 1. Find the nearest enemy to target.
    local nearestEnemy, shortestDistSq = nil, math.huge
    for _, enemy in ipairs(world.enemies) do
        if enemy.hp > 0 then
            local distSq = (enemy.x - square.x)^2 + (enemy.y - square.y)^2
            if distSq < shortestDistSq then
                shortestDistSq, nearestEnemy = distSq, enemy
            end
        end
    end

    -- 2. Determine the direction to throw the flag.
    local dirX, dirY
    if nearestEnemy then
        dirX, dirY = nearestEnemy.x - square.x, nearestEnemy.y - square.y
    else
        -- If no enemy, throw in the direction Sceptile is facing.
        if square.lastDirection == "up" then dirX, dirY = 0, -1
        elseif square.lastDirection == "down" then dirX, dirY = 0, 1
        elseif square.lastDirection == "left" then dirX, dirY = -1, 0
        else dirX, dirY = 1, 0 -- "right"
        end
    end

    -- Normalize the direction vector
    local dist = math.sqrt(dirX*dirX + dirY*dirY)
    if dist > 0 then dirX, dirY = dirX / dist, dirY / dist end

    -- 3. Calculate the landing spot, 7 tiles away.
    local flagDistance = 7 * Config.MOVE_STEP
    local landX = math.floor(((square.x + dirX * flagDistance) / Config.MOVE_STEP) + 0.5) * Config.MOVE_STEP
    local landY = math.floor(((square.y + dirY * flagDistance) / Config.MOVE_STEP) + 0.5) * Config.MOVE_STEP

    -- 4. Check for an enemy at the landing spot and create a damage effect ONLY if one is there.
    local enemyOnTile = false
    for _, enemy in ipairs(world.enemies) do
        if enemy.hp > 0 then
            local enemyCenterX, enemyCenterY = enemy.x + enemy.size / 2, enemy.y + enemy.size / 2
            if enemyCenterX >= landX and enemyCenterX < landX + Config.SQUARE_SIZE and
               enemyCenterY >= landY and enemyCenterY < landY + Config.SQUARE_SIZE then
                enemyOnTile = true
                break
            end
        end
    end

    if enemyOnTile then
        EffectFactory.addAttackEffect(landX, landY, Config.SQUARE_SIZE, Config.SQUARE_SIZE, {1, 0, 0, 1}, 0, square, power, false, "enemy")
    end

    -- 5. Create the flag object in the world.
    world.flag = {
        x = landX,
        y = landY,
        size = Config.SQUARE_SIZE,
        zoneSize = 5, -- 5x5 tile zone
        sprite = Assets.images.Flag
    }
end

PlayerAttacks.sceptile_k = executeGrapple

PlayerAttacks.sceptile_l = function(square, power, world)
    -- Only works if the flag is on the field.
    if world.flag then
        -- 1. Calculate the flag's zone of influence.
        local zoneRadiusInTiles = math.floor(world.flag.zoneSize / 2)
        local zoneTopLeftX = world.flag.x - zoneRadiusInTiles * Config.MOVE_STEP
        local zoneTopLeftY = world.flag.y - zoneRadiusInTiles * Config.MOVE_STEP
        local zonePixelSize = world.flag.zoneSize * Config.MOVE_STEP
        local flagZone = {
            x1 = zoneTopLeftX,
            y1 = zoneTopLeftY,
            x2 = zoneTopLeftX + zonePixelSize,
            y2 = zoneTopLeftY + zonePixelSize
        }

        -- 2. Apply a one-hit shield to all allies inside the zone.
        for _, p in ipairs(world.players) do
            if p.hp > 0 then
                local pCenterX, pCenterY = p.x + p.size / 2, p.y + p.size / 2
                if pCenterX >= flagZone.x1 and pCenterX < flagZone.x2 and pCenterY >= flagZone.y1 and pCenterY < flagZone.y2 then
                    p.components.shielded = true
                end
            end
        end
    end
end

PlayerAttacks.pidgeot_l = function(square, power, world)
    -- This attack is complex and will be managed by a dedicated system.
    -- This function's job is to find targets and initiate the attack state.

    -- 1. Find all airborne enemies.
    local airborneEnemies = {}
    for _, enemy in ipairs(world.enemies) do
        if enemy.hp > 0 and enemy.statusEffects.airborne then
            table.insert(airborneEnemies, enemy)
        end
    end

    if #airborneEnemies == 0 then return false end -- No valid targets, attack doesn't fire.

    -- 2. Find the closest airborne enemy to Pidgeot.
    local primaryTarget, shortestDistSq = nil, math.huge
    for _, enemy in ipairs(airborneEnemies) do
        local distSq = (enemy.x - square.x)^2 + (enemy.y - square.y)^2
        if distSq < shortestDistSq then
            shortestDistSq, primaryTarget = distSq, enemy
        end
    end

    -- 3. Find other nearby airborne enemies (within 5 tiles).
    local uniqueTargets = {primaryTarget}
    local searchRadiusSq = (5 * Config.MOVE_STEP)^2
    for _, enemy in ipairs(airborneEnemies) do
        if enemy ~= primaryTarget and #uniqueTargets < 3 then
            local distSq = (enemy.x - primaryTarget.x)^2 + (enemy.y - primaryTarget.y)^2
            if distSq <= searchRadiusSq then
                table.insert(uniqueTargets, enemy)
            end
        end
    end

    -- 4. Build the final target list for the attack sequence.
    local finalTargets = {}
    if #uniqueTargets == 1 then
        -- If there's only one target, hit it 3 times.
        finalTargets = {uniqueTargets[1], uniqueTargets[1], uniqueTargets[1]}
    else
        -- If multiple targets, hit each one once.
        finalTargets = uniqueTargets
    end

    -- 5. Initiate the attack by adding a component to Pidgeot.
    square.components.pidgeot_l_attack = {
        targets = finalTargets,
        hitsRemaining = #finalTargets,
        hitTimer = 0.3, -- Time before the first hit
        hitDelay = 0.3, -- Time between subsequent hits
        damageValues = {power, power, power * 1.5} -- Damage for 1st, 2nd, 3rd hit
    }

    -- Make Pidgeot untargetable during the ultimate.
    square.statusEffects.phasing = {duration = math.huge} -- Will be removed by the new system.

    return true -- Attack successfully initiated.
end

-- Pidgeot J: Quick Attack - A short, non-damaging dash forward.
PlayerAttacks.pidgeot_j = function(square, power, world)
    Navigation.createDash(square, square.lastDirection, 3, 2, world) -- 3 tiles, 2x speed
end

-- Pidgeot K: Gust - A cone of wind that damages and pushes enemies.
PlayerAttacks.pidgeot_k = function(square, power, world)
    local status = {type = "careening", force = 2, attacker = square, useAttackerDirection = true}
    -- Use a cone-shaped pattern similar to Drapion's J attack
    executePatternAttack(square, power, AttackPatterns.drapion_j, false, "enemy", status)
end
return PlayerAttacks