-- attack_resolution_system.lua
-- This system is responsible for resolving the damage, healing, and status effects
-- of all active attack effects in the world.

local CombatActions = require("modules.combat_actions")
local CombatFormulas = require("modules.combat_formulas")
local Geometry = require("modules.geometry") -- For triangle beam

local AttackResolutionSystem = {}

function AttackResolutionSystem.update(dt, world)
    for _, effect in ipairs(world.attackEffects) do
        -- Process the effect on the frame it becomes active
        if effect.initialDelay <= 0 and not effect.effectApplied then
            local targets = {}
            if effect.targetType == "enemy" then
                targets = world.enemies
            elseif effect.targetType == "player" then
                targets = world.players
            elseif effect.targetType == "all" then
                targets = world.all_entities
            end

            for _, target in ipairs(targets) do
                -- Only process entities that can be targeted by combat actions (i.e., have health)
                if target.hp then
                    if effect.isHeal then
                        if CombatActions.applyHealToTarget(target, effect.x, effect.y, effect.width, effect.height, effect.power) then
                            -- Handle special properties on successful heal
                            if effect.specialProperties and effect.specialProperties.cleansesPoison then
                                if target.statusEffects and target.statusEffects.poison then
                                    target.statusEffects.poison = nil
                                    target.poisonTickTimer = nil
                                end
                            end
                        end
                    else -- It's a damage effect
                        local damage, isCrit = CombatFormulas.calculateFinalDamage(effect.attacker, target, effect.power, effect.critChanceOverride)
                        if CombatActions.applyDamageToTarget(target, effect.x, effect.y, effect.width, damage, isCrit) then
                            -- Handle status effects on successful hit
                            if effect.statusEffect and effect.statusEffect.type ~= "triangle_beam" then
                                local statusCopy = { -- Create a copy to avoid modifying the original effect data
                                    type = effect.statusEffect.type,
                                    duration = effect.statusEffect.duration,
                                    force = effect.statusEffect.force,
                                    attacker = effect.attacker,
                                    -- Direction is calculated below
                                }
                                
                                -- Default direction is the attacker's facing. This is correct for most status effects and directional pushes.
                                statusCopy.direction = effect.attacker.lastDirection
                                
                                -- For "explosive" careening effects (like from a ripple), we override the direction to be away from the effect's center.
                                if statusCopy.type == "careening" and not effect.statusEffect.useAttackerDirection then
                                    local effectCenterX, effectCenterY = effect.x + effect.width / 2, effect.y + effect.height / 2
                                    local dx, dy = target.x - effectCenterX, target.y - effectCenterY
                                    statusCopy.direction = (math.abs(dx) > math.abs(dy)) and ((dx > 0) and "right" or "left") or ((dy > 0) and "down" or "up")
                                end

                                CombatActions.applyStatusEffect(target, statusCopy)
                            end
                        end
                    end
                end
            end

            -- Special case for triangle beam, which hits all enemies in its path
            if effect.specialProperties and effect.specialProperties.type == "triangle_beam" then
                for _, enemy in ipairs(world.enemies) do
                    for _, line in ipairs(effect.specialProperties.lines) do
                        if enemy.hp > 0 and Geometry.isCircleCollidingWithLine(enemy.x+enemy.size/2, enemy.y+enemy.size/2, enemy.size/2, line.x1, line.y1, line.x2, line.y2, effect.specialProperties.thickness/2) then
                            local damage, isCrit = CombatFormulas.calculateFinalDamage(effect.attacker, enemy, effect.power, effect.critChanceOverride)
                            CombatActions.applyDirectDamage(enemy, damage, isCrit)
                            break -- Beams hit once per enemy, so break after first line collision
                        end
                    end
                end
            end

            effect.effectApplied = true -- Mark as processed
        end
    end
end

return AttackResolutionSystem