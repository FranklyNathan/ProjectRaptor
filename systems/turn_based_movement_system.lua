-- turn_based_movement_system.lua
-- This system handles moving a unit along a predefined path, one tile at a time.

local Grid = require("modules.grid")
local WorldQueries = require("modules.world_queries")

local TurnBasedMovementSystem = {}

-- Helper to format attack names into Title Case (e.g., "invigorating_aura" -> "Invigorating Aura").
local function formatAttackName(name)
    local s = name:gsub("_", " ")
    s = s:gsub("^%l", string.upper)
    s = s:gsub(" (%l)", function(c) return " " .. c:upper() end)
    return s
end

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
                        -- Populate with attacks from the blueprint's attack list.
                        if blueprint and blueprint.attacks then
                            for _, attackName in ipairs(blueprint.attacks) do
                                -- Only show attacks that are actually usable from the current position.
                                local attackData = AttackBlueprints[attackName]
                                if attackData then
                                    local style = attackData.targeting_style
                                    local showAttack = false

                                    -- Attacks that don't need a pre-existing target can always be shown in the menu.
                                    if style == "ground_aim" or style == "no_target" then
                                        showAttack = true
                                    -- For directional, cycle, and auto-hit attacks, check if any valid targets exist from the current position.
                                    elseif style == "directional_aim" or style == "cycle_target" or style == "auto_hit_all" then
                                        if #WorldQueries.findValidTargetsForAttack(entity, attackName, world) > 0 then
                                            showAttack = true
                                        end
                                    end

                                    if showAttack then
                                        table.insert(menuOptions, {text = formatAttackName(attackName), key = attackName})
                                    end
                                end
                            end
                        end
                        table.insert(menuOptions, {text = "Wait", key = "wait"})

                        world.actionMenu.active = true
                        world.actionMenu.unit = entity
                        world.actionMenu.options = menuOptions
                        world.actionMenu.selectedIndex = 1
                    end
                end
            end
        end
    end
end

return TurnBasedMovementSystem