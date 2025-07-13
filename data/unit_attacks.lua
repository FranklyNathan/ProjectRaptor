-- unit_attacks.lua
-- Contains all attack implementations.

local EffectFactory = require("modules.effect_factory")
local WorldQueries = require("modules.world_queries")
local Navigation = require("modules.navigation")
local CombatActions = require("modules.combat_actions")
local AttackPatterns = require("modules.attack_patterns")
local Grid = require("modules.grid")
local Assets = require("modules.assets")

local UnitAttacks = {}

--------------------------------------------------------------------------------
-- ATTACK IMPLEMENTATIONS
--------------------------------------------------------------------------------

-- Helper function to execute attacks based on a pattern generator.
-- This reduces code duplication by handling the common logic of iterating
-- through a pattern's effects and creating the corresponding attack visuals/logic.
local function executePatternAttack(square, power, patternFunc, isHeal, targetType, statusEffect, specialProperties)
    local effects = patternFunc(square)
    local color = isHeal and {0.5, 1, 0.5, 1} or {1, 0, 0, 1}
    -- If targetType isn't specified, determine it based on the attacker's type.
    targetType = targetType or (isHeal and "all" or (square.type == "player" and "enemy" or "player"))

    for _, effectData in ipairs(effects) do
        local s = effectData.shape
        EffectFactory.addAttackEffect(s.x, s.y, s.w, s.h, color, effectData.delay, square, power, isHeal, targetType, nil, statusEffect, specialProperties)
    end
end

UnitAttacks.slash = function(attacker, power, world)
    -- This is the new model for a cycle_target attack.
    -- 1. Get the selected target from the cycle targeting system.
    if not world.cycleTargeting.active or not world.cycleTargeting.targets[world.cycleTargeting.selectedIndex] then
        return false -- Failsafe, should not happen if called correctly.
    end
    local target = world.cycleTargeting.targets[world.cycleTargeting.selectedIndex]

    -- 2. Make the attacker face the target before striking.
    local dx, dy = target.tileX - attacker.tileX, target.tileY - attacker.tileY
    if math.abs(dx) > math.abs(dy) then
        attacker.lastDirection = (dx > 0) and "right" or "left"
    else
        attacker.lastDirection = (dy > 0) and "down" or "up"
    end

    -- 3. Execute the attack effect directly on the target's tile.
    EffectFactory.addAttackEffect(target.x, target.y, target.size, target.size, {1, 0, 0, 1}, 0, attacker, power, false, "enemy")
    return true
end

UnitAttacks.longshot = function(attacker, power, world)
    -- 1. Get the selected target from the cycle targeting system.
    if not world.cycleTargeting.active or not world.cycleTargeting.targets[world.cycleTargeting.selectedIndex] then
        return false -- Failsafe
    end
    local target = world.cycleTargeting.targets[world.cycleTargeting.selectedIndex]

    -- 2. Make the attacker face the target.
    local dx, dy = target.tileX - attacker.tileX, target.tileY - attacker.tileY
    if math.abs(dx) > math.abs(dy) then
        attacker.lastDirection = (dx > 0) and "right" or "left"
    else
        attacker.lastDirection = (dy > 0) and "down" or "up"
    end

    -- 3. Fire a projectile in that direction.
    local isEnemy = (attacker.type == "enemy")
    local newProjectile = EntityFactory.createProjectile(attacker.x, attacker.y, attacker.lastDirection, attacker, power, isEnemy, nil)
    world:queue_add_entity(newProjectile)
    return true
end

UnitAttacks.fireball = function(attacker, power, world)
    local isEnemy = (attacker.type == "enemy")
    local newProjectile = EntityFactory.createProjectile(attacker.x, attacker.y, attacker.lastDirection, attacker, power, isEnemy, nil)
    world:queue_add_entity(newProjectile)
end

UnitAttacks.viscous_strike = function(square, power, world)
    local status = {type = "careening", force = 2, useAttackerDirection = true}
    executePatternAttack(square, power, AttackPatterns.viscous_strike, false, nil, status)
end

UnitAttacks.venom_stab = function(square, power, world)
    local status = {type = "poison", duration = 3} -- Lasts 3 turns
    executePatternAttack(square, power, AttackPatterns.venom_stab, false, nil, status)
end

UnitAttacks.phantom_step = function(square, power, world)
    -- 1. Get the selected target from the cycle targeting system.
    if not world.cycleTargeting.active or not world.cycleTargeting.targets[world.cycleTargeting.selectedIndex] then
        return false -- Failsafe, should not happen if called correctly.
    end
    local target = world.cycleTargeting.targets[world.cycleTargeting.selectedIndex]

    -- 2. Calculate the destination tile behind the target.
    local dx, dy = 0, 0
    if target.lastDirection == "up" then dy = 1
    elseif target.lastDirection == "down" then dy = -1
    elseif target.lastDirection == "left" then dx = 1
    elseif target.lastDirection == "right" then dx = -1
    end
    local teleportTileX, teleportTileY = target.tileX + dx, target.tileY + dy
    local teleportX, teleportY = Grid.toPixels(teleportTileX, teleportTileY)

    -- 3. Teleport the attacker. The input handler already validated this tile is empty.
    square.x, square.y = teleportX, teleportY
    square.targetX, square.targetY = teleportX, teleportY
    square.tileX, square.tileY = teleportTileX, teleportTileY

    -- 4. Make the attacker face the target from the new position.
    square.lastDirection = (target.tileX > square.tileX and "right") or (target.tileX < square.tileX and "left") or (target.tileY > square.tileY and "down") or "up"

    -- 5. Execute the attack on the target's tile.
    local status = {type = "stunned", duration = 1}
    EffectFactory.addAttackEffect(target.x, target.y, target.size, target.size, {1, 0, 0, 1}, 0, square, power, false, "enemy", 0.2, status)

    return true
end

UnitAttacks.mend = function(square, power, world)
    executePatternAttack(square, power, AttackPatterns.viscous_strike, true, "player", nil, {cleansesPoison = true})
end

UnitAttacks.invigorating_aura = function(square, power, world)
    -- This ability targets the tile directly in front of Florges.
    -- We can use the simple_melee pattern to find this tile.
    local pattern = AttackPatterns.simple_melee(square)
    if not pattern or #pattern == 0 then return true end -- Failsafe, consumes turn

    local targetShape = pattern[1].shape
    local targetPixelX, targetPixelY = targetShape.x, targetShape.y

    -- Create a visual effect on the target tile so the player sees the action.
    EffectFactory.addAttackEffect(targetPixelX, targetPixelY, Config.SQUARE_SIZE, Config.SQUARE_SIZE, {0.5, 1, 0.5, 0.7}, 0, square, 0, true, "none")

    -- Check if a friendly unit is on the target tile.
    local targetTileX, targetTileY = Grid.toTile(targetPixelX, targetPixelY)
    local targetUnit = nil
    for _, p in ipairs(world.players) do
        if p.tileX == targetTileX and p.tileY == targetTileY and p.hp > 0 then
            targetUnit = p
            break
        end
    end

    -- If a friendly unit who has already acted is found, refresh their turn.
    if targetUnit and targetUnit.hasActed then
        targetUnit.hasActed = false
        EffectFactory.createDamagePopup(targetUnit, "Refreshed!", false, {0.5, 1, 0.5, 1}) -- Green text
    end

    return true -- Always consume the turn, even if no target is hit.
end

UnitAttacks.eruption = function(attacker, power, world)
    -- This is the new model for a ground_aim AoE attack.
    -- 1. Get the target tile from the ground aiming cursor.
    local targetTileX, targetTileY = world.mapCursorTile.x, world.mapCursorTile.y
    local centerX, centerY = Grid.toPixels(targetTileX, targetTileY)
    -- Center the explosion on the middle of the tile.
    centerX = centerX + Config.SQUARE_SIZE / 2
    centerY = centerY + Config.SQUARE_SIZE / 2

    -- 2. We can still use the ripple pattern generator, but we call it directly with the cursor's position.
    local rippleCenterSize = 1
    local effects = AttackPatterns.ripple(centerX, centerY, rippleCenterSize)
    local color = {1, 0, 0, 1}
    local targetType = (attacker.type == "player" and "enemy" or "player")

    for _, effectData in ipairs(effects) do
        EffectFactory.addAttackEffect(effectData.shape.x, effectData.shape.y, effectData.shape.w, effectData.shape.h, color, effectData.delay, attacker, power, false, targetType)
    end
    return true
end

UnitAttacks.shockwave = function(square, power, world)
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

UnitAttacks.uppercut = function(square, power, world)
    local status = {type = "airborne"}
    executePatternAttack(square, power, AttackPatterns.uppercut, false, nil, status)
end

UnitAttacks.quick_step = function(attacker, power, world)
    -- 1. Get the target tile from the ground aiming cursor.
    local targetTileX, targetTileY = world.mapCursorTile.x, world.mapCursorTile.y

    -- 2. Determine the path and apply 'airborne' to any enemies passed through.
    local dx = targetTileX - attacker.tileX
    local dy = targetTileY - attacker.tileY
    local distance = math.max(math.abs(dx), math.abs(dy))

    if distance > 1 then -- Only check for pass-through if moving more than one tile.
        local dirX = dx / distance
        local dirY = dy / distance

        -- Iterate over the tiles between the start and end point.
        for i = 1, distance - 1 do
            local pathTileX = attacker.tileX + i * dirX
            local pathTileY = attacker.tileY + i * dirY

            for _, enemy in ipairs(world.enemies) do
                if enemy.tileX == pathTileX and enemy.tileY == pathTileY and enemy.hp > 0 then
                    CombatActions.applyStatusEffect(enemy, {type = "airborne"})
                end
            end
        end
    end

    -- 3. Set the attacker's target destination and speed.
    attacker.targetX, attacker.targetY = Grid.toPixels(targetTileX, targetTileY)
    attacker.speedMultiplier = 2
    return true -- Consume the turn.
end

UnitAttacks.sylvan_spire = function(square, power, world)
    -- This is the new model for a ground_aim attack.
    -- 1. Get the target tile from the ground aiming cursor.
    local landTileX, landTileY = world.mapCursorTile.x, world.mapCursorTile.y
    local landX, landY = Grid.toPixels(landTileX, landTileY)
    local landTileX, landTileY = Grid.toTile(landX, landY)

    -- 2. Validate that the target tile is empty.
    if WorldQueries.isTileOccupied(landTileX, landTileY, nil, world) then
        return false -- Attack fails, turn is not consumed.
    end

    -- If a flag already exists, this new one will overwrite it.
    world.flag = nil

    -- 3. Create the flag object in the world.
    world.flag = {
        x = landX,
        y = landY,
        tileX = landTileX,
        tileY = landTileY,
        size = Config.SQUARE_SIZE,
        zoneSize = 5, -- 5x5 tile zone,
        sprite = Assets.images.Flag,
        weight = "Permanent" -- This makes it unmovable by grappling.
    }

    -- Create a visual effect on the target tile so the player sees the action.
    EffectFactory.addAttackEffect(landX, landY, Config.SQUARE_SIZE, Config.SQUARE_SIZE, {0.2, 0.8, 0.3, 0.7}, 0, square, 0, false, "none")

    return true -- Attack succeeds, turn is consumed.
end

UnitAttacks.hookshot = function(attacker, power, world)
    -- This is the new model for a cycle_target hookshot.
    -- 1. Get the selected target from the cycle targeting system.
    if not world.cycleTargeting.active or not world.cycleTargeting.targets[world.cycleTargeting.selectedIndex] then
        return false -- Failsafe, should not happen if called correctly.
    end
    local target = world.cycleTargeting.targets[world.cycleTargeting.selectedIndex]

    -- 2. Make the attacker face the target before firing.
    local dx, dy = target.tileX - attacker.tileX, target.tileY - attacker.tileY
    if math.abs(dx) > math.abs(dy) then
        attacker.lastDirection = (dx > 0) and "right" or "left"
    else
        attacker.lastDirection = (dy > 0) and "down" or "up"
    end

    -- 3. Get the blueprint data to find the range and fire the hook.
    local attackData = AttackBlueprints.hookshot
    local range = attackData.range
    local newHook = EntityFactory.createGrappleHook(attacker, power, range)
    world:queue_add_entity(newHook)
    return true
end

UnitAttacks.aetherfall = function(square, power, world)
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
    local searchRadiusSq = (5 * Config.SQUARE_SIZE)^2
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

return UnitAttacks