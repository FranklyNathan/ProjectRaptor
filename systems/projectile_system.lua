-- projectile_system.lua
-- Handles the movement and collision logic for all projectiles.

local Grid = require("modules.grid")
local EffectFactory = require("modules.effect_factory")

local ProjectileSystem = {}

-- Helper to check for a permanent object at a tile
local function isTilePermanent(tileX, tileY, world)
    if world.flag and world.flag.tileX == tileX and world.flag.tileY == tileY then
        -- The flag is considered a permanent, solid object.
        if world.flag.weight == "Permanent" then
            return true
        end
    end
    return false
end

function ProjectileSystem.update(dt, world)
    -- Iterate backwards to safely remove projectiles
    for i = #world.projectiles, 1, -1 do
        local p = world.projectiles[i]
        local projComp = p.components.projectile

        projComp.timer = projComp.timer - dt
        if projComp.timer <= 0 then
            projComp.timer = projComp.timer + projComp.moveDelay

            -- Move the projectile one step
            p.x, p.y = Grid.getDestination(p.x, p.y, projComp.direction, projComp.moveStep)
            local currentTileX, currentTileY = Grid.toTile(p.x, p.y)

            -- Check for map boundary collision
            if currentTileX < 0 or currentTileX >= Config.MAP_WIDTH_TILES or
               currentTileY < 0 or currentTileY >= Config.MAP_HEIGHT_TILES then
                p.isMarkedForDeletion = true
            else
                -- Check for collision with a permanent object (like Sceptile's flag)
                if isTilePermanent(currentTileX, currentTileY, world) then
                    p.isMarkedForDeletion = true
                else
                    -- Check for collision with units
                    local targetType = projComp.isEnemyProjectile and "player" or "enemy"
                    local targets = (targetType == "player") and world.players or world.enemies

                    for _, target in ipairs(targets) do
                        if target.hp > 0 and not projComp.hitTargets[target] and target.tileX == currentTileX and target.tileY == currentTileY then
                            -- Collision detected! Create an attack effect to deal damage.
                            EffectFactory.addAttackEffect(target.x, target.y, target.size, target.size, {1, 0.5, 0, 1}, 0, projComp.attacker, projComp.power, false, targetType, nil, projComp.statusEffect)

                            -- Mark target as hit to prevent re-hitting
                            projComp.hitTargets[target] = true

                            -- If the projectile is not piercing, destroy it.
                            if not projComp.isPiercing then
                                p.isMarkedForDeletion = true
                                break -- Stop checking other targets for this projectile
                            end
                        end
                    end
                end
            end
        end
    end
end

return ProjectileSystem