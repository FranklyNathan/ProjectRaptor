-- aetherfall_system.lua
-- Manages the reactive "Aetherfall" passive for Pidgeot.

local EventBus = require("modules.event_bus")
local WorldQueries = require("modules.world_queries")
local Grid = require("modules.grid")
local EffectFactory = require("modules.effect_factory")

local AetherfallSystem = {}

-- Helper to find all units with the Aetherfall passive on a given team.
local function find_aetherfall_units(world, teamType)
    -- The PassiveSystem now populates this list each frame with all *living* units
    -- that have the Aetherfall passive. This is much more efficient and robust.
    return world.teamPassives[teamType].Aetherfall
end

-- Helper to find all empty tiles adjacent to a target.
local function find_adjacent_open_tiles(target, world)
    local openTiles = {}
    local neighbors = {{dx=0,dy=-1},{dx=0,dy=1},{dx=-1,dy=0},{dx=1,dy=0}}
    for _, move in ipairs(neighbors) do
        local checkX, checkY = target.tileX + move.dx, target.tileY + move.dy
        if not WorldQueries.isTileOccupied(checkX, checkY, nil, world) then
            table.insert(openTiles, {tileX = checkX, tileY = checkY})
        end
    end
    return openTiles
end

-- This function contains the core logic for triggering the passive.
local function check_and_trigger_aetherfall(airborne_target, reacting_team_type, world)
    local reacting_units = find_aetherfall_units(world, reacting_team_type)

    for _, reactor in ipairs(reacting_units) do
        -- Check all conditions for this unit
        local distance = math.abs(reactor.tileX - airborne_target.tileX) + math.abs(reactor.tileY - airborne_target.tileY)
        local canReact = not reactor.hasActed and
                         distance <= 10 and
                         not reactor.components.aetherfall_attack -- Don't trigger if already attacking

        if canReact then
            local openTiles = find_adjacent_open_tiles(airborne_target, world)
            if #openTiles > 0 then
                -- Take control of the airborne status to prevent it from timing out.
                if airborne_target.statusEffects and airborne_target.statusEffects.airborne then
                    airborne_target.statusEffects.airborne.duration = math.huge
                end

                -- Trigger the attack!
                reactor.components.aetherfall_attack = {
                    target = airborne_target,
                    hitLocations = openTiles,
                    hitsRemaining = #openTiles,
                    hitTimer = 0.1, -- Short delay before the first hit
                    hitDelay = 0.2, -- Time between subsequent hits
                }
                -- One unit reacts, that's enough.
                break
            end
        end
    end
end

-- Listen for a status effect to trigger the passive.
EventBus:register("status_applied", function(data)
    local world = data.world
    local target = data.target
    local effect = data.effect

    -- Condition 1: Was the 'airborne' status applied?
    if not world or effect.type ~= "airborne" then
        return
    end

    -- Condition 2: Determine which team should react.
    if target.type == "enemy" then
        -- An enemy became airborne, check if the player team can react.
        check_and_trigger_aetherfall(target, "player", world)
    elseif target.type == "player" then
        -- A player became airborne, check if the enemy team can react.
        check_and_trigger_aetherfall(target, "enemy", world)
    end
end)

function AetherfallSystem.update(dt, world)
    -- This will process any active Aetherfall attacks for all entities.
    for _, unit in ipairs(world.all_entities) do
        if unit.components.aetherfall_attack then
            local attack = unit.components.aetherfall_attack
            attack.hitTimer = attack.hitTimer - dt

            if attack.hitTimer <= 0 then
                if attack.hitsRemaining > 0 then
                    local target = attack.target
                    if not target or target.hp <= 0 then
                        -- Target died mid-combo, end the attack immediately.
                        unit.components.aetherfall_attack = nil
                    else
                        -- Get the next location to warp to.
                        local locationIndex = #attack.hitLocations - attack.hitsRemaining + 1
                        local warpTile = attack.hitLocations[locationIndex]

                        -- Teleport the unit
                        unit.tileX, unit.tileY = warpTile.tileX, warpTile.tileY
                        unit.x, unit.y = Grid.toPixels(warpTile.tileX, warpTile.tileY)
                        unit.targetX, unit.targetY = unit.x, unit.y

                        -- Make the unit face the target
                        local dx, dy = target.tileX - unit.tileX, target.tileY - unit.tileY
                        if math.abs(dx) > math.abs(dy) then unit.lastDirection = (dx > 0) and "right" or "left"
                        else unit.lastDirection = (dy > 0) and "down" or "up" end

                        -- Execute a "Slash" attack effect.
                        local slashPower = AttackBlueprints.slash.power or 20
                        local targetType = (unit.type == "player") and "enemy" or "player"
                        EffectFactory.addAttackEffect(target.x, target.y, target.size, target.size, {1, 0, 0, 1}, 0, unit, slashPower, false, targetType)

                        -- Update state for the next hit
                        attack.hitsRemaining = attack.hitsRemaining - 1
                        attack.hitTimer = attack.hitDelay
                    end
                end

                -- Re-check component existence before checking hitsRemaining, as it might have been nilled above.
                if unit.components.aetherfall_attack and unit.components.aetherfall_attack.hitsRemaining <= 0 then
                    -- Attack is over. End the airborne status on the target.
                    if attack.target and attack.target.statusEffects then
                        attack.target.statusEffects.airborne = nil
                    end
                    -- Clean up the component. The unit's turn is NOT consumed.
                    unit.components.aetherfall_attack = nil
                end
            end
        end
    end
end

return AetherfallSystem