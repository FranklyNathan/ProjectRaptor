-- pidgeot_system.lua
-- Handles the execution of Pidgeot's multi-hit warp attack (Pidgeot L).

local CombatActions = require("modules.combat_actions")
local EffectFactory = require("modules.effect_factory")
local CombatFormulas = require("modules.combat_formulas")

local PidgeotSystem = {}

function PidgeotSystem.update(dt, world)
    for _, pidgeot in ipairs(world.players) do
        if pidgeot.components.pidgeot_l_attack then
            local attack = pidgeot.components.pidgeot_l_attack

            attack.hitTimer = attack.hitTimer - dt

            if attack.hitTimer <= 0 and attack.hitsRemaining > 0 then
                local targetIndex = #attack.targets - attack.hitsRemaining + 1
                local target = attack.targets[targetIndex]

                -- If the target is dead or invalid, skip to the next hit immediately.
                if not target or target.hp <= 0 then
                    attack.hitsRemaining = attack.hitsRemaining - 1
                    -- Set timer to 0 to process the next hit in the very next frame.
                    attack.hitTimer = 0
                else
                    -- Target is valid, execute the hit.
                    -- "Freeze" the target in the air by resetting its airborne duration.
                    if target.statusEffects.airborne then
                        target.statusEffects.airborne.duration = 2 -- Reset to max duration
                    end

                    -- Choose a random side to warp to.
                    local adjacentTiles = {{dx=0,dy=-1},{dx=0,dy=1},{dx=-1,dy=0},{dx=1,dy=0}}
                    local warpPos = adjacentTiles[math.random(#adjacentTiles)]
                    local warpX = target.x + warpPos.dx * Config.SQUARE_SIZE
                    local warpY = target.y + warpPos.dy * Config.SQUARE_SIZE

                    -- Teleport Pidgeot and make it face the target.
                    pidgeot.x, pidgeot.targetX = warpX, warpX
                    pidgeot.y, pidgeot.targetY = warpY, warpY
                    if warpPos.dx ~= 0 then pidgeot.lastDirection = warpPos.dx > 0 and "left" or "right"
                    else pidgeot.lastDirection = warpPos.dy > 0 and "up" or "down" end

                    -- Apply damage based on the hit sequence. 
                    local damageIndex = #attack.damageValues - attack.hitsRemaining + 1
                    local damagePower = attack.damageValues[damageIndex] or attack.damageValues[#attack.damageValues]
                    local damage, isCrit = CombatFormulas.calculateFinalDamage(pidgeot, target, damagePower, nil)
                    CombatActions.applyDirectDamage(target, damage, isCrit)
                    EffectFactory.addAttackEffect(target.x, target.y, target.size, target.size, {1,1,1,1}, 0, pidgeot, 0, false, "none")

                    -- Update state for the next hit.
                    attack.hitsRemaining = attack.hitsRemaining - 1
                    attack.hitTimer = attack.hitsRemaining > 0 and attack.hitDelay or 0
                end
            end

            if attack.hitsRemaining <= 0 then
                -- Attack is over. Remove airborne status from all unique targets.
                local uniqueTargets = {}
                for _, target in ipairs(attack.targets) do
                    uniqueTargets[target] = true
                end

                for target, _ in pairs(uniqueTargets) do
                    if target.statusEffects then
                        target.statusEffects.airborne = nil
                    end
                end

                pidgeot.components.pidgeot_l_attack = nil
                pidgeot.statusEffects.phasing = nil -- Make Pidgeot targetable again.
            end
        end
    end
end

return PidgeotSystem