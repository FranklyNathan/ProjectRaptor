-- turn_based_movement_system.lua
-- This system handles moving a unit along a predefined path, one tile at a time.

local Grid = require("modules.grid")
local EnemyAttacks = require("data.enemy_attacks")

local TurnBasedMovementSystem = {}

function TurnBasedMovementSystem.update(dt, world)
    -- This system moves any entity that has a movement path.
    for _, entity in ipairs(world.all_entities) do
        if entity.components.movement_path then
            -- Check if the unit is close enough to its current target tile.
            -- Using a small epsilon to handle floating-point inaccuracies from dt-based movement.
            local epsilon = 1
            if math.abs(entity.x - entity.targetX) < epsilon and math.abs(entity.y - entity.targetY) < epsilon then
                -- Snap to the target position to prevent error accumulation.
                entity.x, entity.y = entity.targetX, entity.targetY
                -- Update the logical tile position to match.
                entity.tileX, entity.tileY = Grid.toTile(entity.x, entity.y)

                if #entity.components.movement_path > 0 then
                    -- It has arrived. Get the next step from the path.
                    local nextStep = table.remove(entity.components.movement_path, 1)

                    -- Update the entity's facing direction for the upcoming move
                    -- by comparing the next step's coords to the entity's current position.
                    -- This must be done *before* setting the new target.
                    if nextStep.x > entity.x then entity.lastDirection = "right"
                    elseif nextStep.x < entity.x then entity.lastDirection = "left"
                    elseif nextStep.y > entity.y then entity.lastDirection = "down"
                    elseif nextStep.y < entity.y then entity.lastDirection = "up" end

                    -- Set the next tile as the new target.
                    entity.targetX = nextStep.x
                    entity.targetY = nextStep.y
                else
                    -- The path is now empty, which means movement is complete.
                    entity.components.movement_path = nil -- Clean up the component.
                    -- Only player units trigger state changes upon finishing a move.
                    if entity.type == "player" then -- Player finished moving
                        -- Movement is done, open the action menu.
                        world.playerTurnState = "action_menu"

                        local blueprint = CharacterBlueprints[entity.playerType]
                        local menuOptions = {}
                        -- Populate with attacks. The keys 'j', 'k', 'l' are important.
                        if blueprint and blueprint.attacks then
                            for key, attackData in pairs(blueprint.attacks) do
                                -- Use a more descriptive name for the menu
                                table.insert(menuOptions, {text = attackData.name:gsub("_", " "):gsub("^%l", string.upper), key = key})
                            end
                        end
                        table.insert(menuOptions, {text = "Wait", key = "wait"})

                        world.actionMenu.active = true
                        world.actionMenu.unit = entity
                        world.actionMenu.options = menuOptions
                        world.actionMenu.selectedIndex = 1
                    elseif entity.type == "enemy" then -- Enemy finished moving
                        -- Check for and execute a queued action (like attacking).
                        if entity.components.queued_action then
                            local action = entity.components.queued_action
                            if action.type == "attack" then
                                -- Make the enemy face its target before attacking
                                local dx, dy = action.target.x - entity.x, action.target.y - entity.y
                                if math.abs(dx) > math.abs(dy) then entity.lastDirection = (dx > 0) and "right" or "left" else entity.lastDirection = (dy > 0) and "down" or "up" end
                                EnemyAttacks[action.attackData.name](entity, action.attackData, world)
                            end
                            entity.components.queued_action = nil -- Clean up the component
                        end
                        entity.hasActed = true -- The enemy's turn is now complete.
                    end
                end
            end
        end
    end
end

return TurnBasedMovementSystem