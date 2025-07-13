-- enemy_attacks.lua
-- Contains all enemy attack implementations and patterns.

local AttackPatterns = require("modules.attack_patterns")
local EffectFactory = require("modules.effect_factory")

local EnemyAttacks = {}

--------------------------------------------------------------------------------
-- ENEMY ATTACK IMPLEMENTATIONS
--------------------------------------------------------------------------------

-- Helper function to execute enemy attacks based on a pattern.
local function executeEnemyPatternAttack(enemy, attackData, patternFunc, statusEffect, world)
    local effects = patternFunc(enemy)
    local color = {1, 0, 0, 1} -- Red for damage
    local targetType = "player"

    for _, effectData in ipairs(effects) do
        local s = effectData.shape
        EffectFactory.addAttackEffect(s.x, s.y, s.w, s.h, color, effectData.delay, enemy, attackData.power, false, targetType, nil, statusEffect)
    end
end

EnemyAttacks.standard_melee = function(enemy, attackData, world)
    executeEnemyPatternAttack(enemy, attackData, AttackPatterns.standard_melee, nil, world)
end

EnemyAttacks.archer_shot = function(enemy, attackData, world)
    local newProjectile = EntityFactory.createProjectile(enemy.x, enemy.y, enemy.lastDirection, enemy, attackData.power, true, nil)
    world:queue_add_entity(newProjectile)
end

EnemyAttacks.punter_spin = function(enemy, attackData, world)
    local status = {type = "careening", force = 2}
    executeEnemyPatternAttack(enemy, attackData, function() return AttackPatterns.radiating_spokes(enemy, 1, 0.02) end, status, world)
end

EnemyAttacks.archer_barrage = function(enemy, attackData, world)
    local directions = {"up", "down", "left", "right"}
    local status = {type = "poison", duration = 2} -- Lasts 2 turns
    for _, dir in ipairs(directions) do
        local newProjectile = EntityFactory.createProjectile(enemy.x, enemy.y, dir, enemy, attackData.power, true, status)
        world:queue_add_entity(newProjectile)
    end
end

return EnemyAttacks