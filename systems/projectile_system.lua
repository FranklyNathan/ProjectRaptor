-- projectile_system.lua
-- This system is responsible for updating all projectile entities.

local CombatFormulas = require("modules.combat_formulas")
local CombatActions = require("modules.combat_actions")
local EffectFactory = require("modules.effect_factory")

local ProjectileSystem = {}

function ProjectileSystem.update(dt, world)
    local mapWidth, mapHeight = Config.MAP_WIDTH_TILES * Config.SQUARE_SIZE, Config.MAP_HEIGHT_TILES * Config.SQUARE_SIZE
    local venusaurSquareCritBonus = world.passives.venusaurCritBonus

    for _, entity in ipairs(world.projectiles) do
        if entity.components and entity.components.projectile then
            local proj = entity.components.projectile
            local beamMoved = false

            -- Advance beam position
            proj.timer = proj.timer - dt
            if proj.timer <= 0 then
                if proj.direction == "up" then entity.y = entity.y - proj.moveStep
                elseif proj.direction == "down" then entity.y = entity.y + proj.moveStep
                elseif proj.direction == "left" then entity.x = entity.x - proj.moveStep
                elseif proj.direction == "right" then entity.x = entity.x + proj.moveStep
                end
                proj.timer = proj.moveDelay -- Reset timer for next step
                beamMoved = true
            end

            -- Check for collision if beam moved
            if beamMoved then
                local beamHit = false
                local targets = proj.isEnemyProjectile and world.players or world.enemies

                for _, target in ipairs(targets) do
                    local totalBonusCrit = (proj.attacker.type == "player" and venusaurSquareCritBonus or 0)
                    local damage, isCrit = CombatFormulas.calculateFinalDamage(proj.attacker, target, proj.power, totalBonusCrit)
                    if CombatActions.applyDamageToTarget(target, entity.x, entity.y, entity.size, damage, isCrit) then
                        beamHit = true
                        EffectFactory.addAttackEffect(entity.x, entity.y, entity.size, entity.size, {1, 0, 0, 1}, 0, proj.attacker, 0, false, target.type)
                        if proj.statusEffect then
                            CombatActions.applyStatusEffect(target, proj.statusEffect)
                        end
                        break
                    end
                end

                -- Remove beam if it hit a target or went off-screen
                local beamOffScreen = entity.x < 0 or entity.x >= mapWidth or entity.y < 0 or entity.y >= mapHeight
                if beamHit or beamOffScreen then
                    entity.isMarkedForDeletion = true
                end
            end
        end
    end
end

return ProjectileSystem