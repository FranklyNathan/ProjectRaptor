-- grapple_hook_system.lua
-- Manages the movement and state of grappling hook projectiles.
local Grid = require("modules.grid")
local WorldQueries = require("modules.world_queries")

local GrappleHookSystem = {}

function GrappleHookSystem.update(dt, world)
    -- Loop through all entities to find active grapple hooks
    for i = #world.all_entities, 1, -1 do
        local entity = world.all_entities[i]
        if entity.type == "grapple_hook" and entity.components.grapple_hook then
            local hook = entity.components.grapple_hook

            if hook.state == "firing" then
                -- 1. Move the hook forward
                local moveAmount = hook.speed * dt
                if hook.direction == "up" then
                    entity.y = entity.y - moveAmount
                elseif hook.direction == "down" then
                    entity.y = entity.y + moveAmount
                elseif hook.direction == "left" then
                    entity.x = entity.x - moveAmount
                elseif hook.direction == "right" then
                    entity.x = entity.x + moveAmount
                end

                -- 2. Update distance traveled
                hook.distanceTraveled = hook.distanceTraveled + moveAmount

                -- 3. Check for collision with any valid target
                local potentialTargets = {}
                for _, p in ipairs(world.players) do table.insert(potentialTargets, p) end
                for _, e in ipairs(world.enemies) do table.insert(potentialTargets, e) end
                if world.flag then table.insert(potentialTargets, world.flag) end

                for _, target in ipairs(potentialTargets) do
                    -- The hook can't hit its own attacker or dead units.
                    if target ~= hook.attacker and (target.hp == nil or target.hp > 0) then
                        -- Simple AABB collision check
                        if entity.x < target.x + target.size and entity.x + entity.size > target.x and
                           entity.y < target.y + target.size and entity.y + entity.size > target.y then
                            -- Collision detected!
                            hook.state = "hit"
                            hook.target = target -- Store what was hit
                            break -- Stop checking for other targets
                        end
                    end
                end

                -- 4. If no collision, check if max distance is reached
                if hook.state == "firing" and hook.distanceTraveled >= hook.maxDistance then
                    -- For now, just remove the hook if it misses
                    entity.isMarkedForDeletion = true
                end
            elseif hook.state == "hit" then
                local attacker = hook.attacker
                local target = hook.target

                if not attacker or not target then
                    entity.isMarkedForDeletion = true
                else
                    -- 1. Get weights
                    local attackerWeight = attacker.weight or 1
                    local targetWeight = target.weight or 1

                    -- 2. Compare weights and determine movement
                    local pullAttacker = false
                    local pullTarget = false
                    local pullBoth = false

                    if targetWeight == "Permanent" then
                        pullAttacker = true
                    elseif attackerWeight < targetWeight then
                        pullAttacker = true
                    elseif attackerWeight > targetWeight then
                        pullTarget = true
                    else -- attackerWeight == targetWeight
                        pullBoth = true
                    end

                    -- 3. Calculate destinations and initiate movement
                    local step = Config.SQUARE_SIZE
                    local pullSpeed = 4 -- Speed multiplier for the pull

                    if pullAttacker then
                        -- Attacker is pulled to the tile adjacent to the target
                        local destX, destY = target.x, target.y
                        if hook.direction == "up" then destY = destY + step
                        elseif hook.direction == "down" then destY = destY - step
                        elseif hook.direction == "left" then destX = destX + step
                        elseif hook.direction == "right" then destX = destX - step
                        end
                        attacker.targetX, attacker.targetY = destX, destY
                        attacker.speedMultiplier = pullSpeed
                    elseif pullTarget then
                        -- Target is pulled to the tile adjacent to the attacker
                        local destX, destY = attacker.x, attacker.y
                        if hook.direction == "up" then destY = attacker.y - step
                        elseif hook.direction == "down" then destY = attacker.y + step
                        elseif hook.direction == "left" then destX = attacker.x - step
                        elseif hook.direction == "right" then destX = attacker.x + step
                        end
                        target.targetX, target.targetY = destX, destY
                        target.speedMultiplier = pullSpeed
                    elseif pullBoth then
                        -- Both are pulled towards each other, meeting in the middle.
                        local moveTiles = math.floor((hook.distanceTraveled / Config.SQUARE_SIZE) / 2)
                        local movePixels = moveTiles * Config.SQUARE_SIZE

                        -- Set destinations for both attacker and target
                        attacker.targetX, attacker.targetY = Grid.getDestination(attacker.x, attacker.y, hook.direction, movePixels)
                        target.targetX, target.targetY = Grid.getDestination(target.x, target.y, hook.direction, -movePixels)
                        attacker.speedMultiplier, target.speedMultiplier = pullSpeed, pullSpeed
                    end

                    -- 4. Mark the hook for deletion
                    entity.isMarkedForDeletion = true
                end
            end
        end
    end
end

return GrappleHookSystem