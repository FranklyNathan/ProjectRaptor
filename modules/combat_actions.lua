-- combat_actions.lua
-- Contains functions that directly apply combat results like damage and healing to entities.

local EffectFactory = require("modules.effect_factory")

local world_ref -- A reference to the main world object

local CombatActions = {}

function CombatActions.init(world)
    world_ref = world
end

function CombatActions.applyDamageToTarget(targetSquare, hitTileX, hitTileY, hitTileSize, damageAmount, isCrit)
    if targetSquare and targetSquare.hp and targetSquare.hp > 0 then
        local targetCenterX, targetCenterY = targetSquare.x + targetSquare.size / 2, targetSquare.y + targetSquare.size / 2
        if targetCenterX >= hitTileX and targetCenterX < hitTileX + hitTileSize and targetCenterY >= hitTileY and targetCenterY < hitTileY + hitTileSize then
            -- The target is in the hit area. Now apply the damage via the centralized function.
            CombatActions.applyDirectDamage(targetSquare, damageAmount, isCrit)
            return true -- A "hit" occurred
        end
    end
    return false
end

function CombatActions.applyHealToTarget(targetSquare, healTileX, healTileY, healTileSize, healAmount)
    if targetSquare and targetSquare.hp and targetSquare.hp > 0 then
        local targetCenterX, targetCenterY = targetSquare.x + targetSquare.size / 2, targetSquare.y + targetSquare.size / 2
        if targetCenterX >= healTileX and targetCenterX < healTileX + healTileSize and targetCenterY >= healTileY and targetCenterY < healTileY + healTileSize then
            targetSquare.hp = math.floor(targetSquare.hp + healAmount)
            if targetSquare.hp > targetSquare.maxHp then targetSquare.hp = targetSquare.maxHp end
            return true
        end
    end
    return false
end

function CombatActions.applyDirectHeal(target, healAmount)
    if target and target.hp and target.hp > 0 then
        target.hp = math.floor(target.hp + healAmount)
        if target.hp > target.maxHp then target.hp = target.maxHp end
        return true
    end
    return false
end

function CombatActions.applyStatusEffect(target, effectData)
    if target and target.statusEffects and effectData and effectData.type then
        -- This will overwrite any existing effect of the same type.
        -- This is generally desired for things like stun, but might need more
        -- complex logic later for stacking effects.
        target.statusEffects[effectData.type] = effectData

        -- Check for Purple Square's passive to double careen distance
        if effectData.type == "careening" and world_ref.passives.purpleCareenDouble then
            effectData.force = effectData.force * 2
        end
    end
end

function CombatActions.applyDirectDamage(target, damageAmount, isCrit)
    if not target or not target.hp or target.hp <= 0 then return end

    -- Check for Purple Square's shield first.
    if target.components.shielded then
        target.components.shielded = nil -- Consume the shield
        -- Create a "Blocked!" popup instead of a damage number.
        EffectFactory.createDamagePopup(target, "Blocked!", false, {0.7, 0.7, 1, 1}) -- Light blue text
        return -- Stop further processing, no damage is taken.
    end

    if target.type == "player" and world_ref.playerTeamStatus.isHealingFromAttacks then
        return CombatActions.applyDirectHeal(target, damageAmount)
    end

    local roundedDamage = math.floor(damageAmount)
    if roundedDamage > 0 then
        target.hp = target.hp - roundedDamage
        EffectFactory.createDamagePopup(target, roundedDamage, isCrit)
        target.components.shake = { timer = 0.2, intensity = 2 }
        if target.hp < 0 then target.hp = 0 end
    end
end

return CombatActions