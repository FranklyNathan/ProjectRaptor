-- dash_system.lua
-- Handles the logic for entities performing a high-speed dash to a target point.

local CombatActions = require("modules.combat_actions")
local CombatFormulas = require("modules.combat_formulas")
local Geometry = require("modules.geometry")

local DashSystem = {}

function DashSystem.update(dt, world)
    for _, entity in ipairs(world.all_entities) do
        if entity.components.dash_to_target then
            local dash = entity.components.dash_to_target
            local prevX, prevY = entity.x, entity.y

            -- 1. Move towards the target
            local dx = dash.targetX - entity.x
            local dy = dash.targetY - entity.y
            local dist = math.sqrt(dx*dx + dy*dy)
            local moveAmount = dash.speed * dt

            if dist > moveAmount then
                entity.x = entity.x + (dx / dist) * moveAmount
                entity.y = entity.y + (dy / dist) * moveAmount
            else
                -- Arrived at destination
                entity.x, entity.y = dash.targetX, dash.targetY
                entity.targetX, entity.targetY = dash.targetX, dash.targetY -- Sync grid position
                entity.components.dash_to_target = nil -- End the dash
            end

            -- 2. Check for collisions with enemies along the path traveled this frame
            for _, enemy in ipairs(world.enemies) do
                -- Only check enemies that haven't been hit by this dash yet.
                if enemy.hp > 0 and not dash.hitEnemies[enemy] then
                    if Geometry.isCircleCollidingWithLine(enemy.x + enemy.size/2, enemy.y + enemy.size/2, enemy.size/2, prevX, prevY, entity.x, entity.y, entity.size/2) then
                        -- Collision detected!
                        local damage, isCrit = CombatFormulas.calculateFinalDamage(entity, enemy, dash.power, nil)
                        CombatActions.applyDirectDamage(enemy, damage, isCrit)
                        CombatActions.applyStatusEffect(enemy, {type = "airborne"})
                        dash.hitEnemies[enemy] = true -- Mark enemy as hit
                    end
                end
            end

            if not entity.components.dash_to_target then break end -- Stop if dash ended
        end
    end
end

return DashSystem