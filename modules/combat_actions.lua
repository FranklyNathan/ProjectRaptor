-- combat_actions.lua
-- Contains functions that directly apply combat results like damage and healing to entities.

local EffectFactory = require("modules.effect_factory")

local world_ref -- A reference to the main world object

local CombatActions = {}

function CombatActions.init(world)
    world_ref = world
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

        -- Standardize airborne to be a 2-second, time-based visual effect.
        if effectData.type == "airborne" then
            effectData.duration = 2 -- 2 seconds
        end

        -- Check for Tangrowth Square's passive to double careen distance
        if effectData.type == "careening" and world_ref.passives.tangrowthCareenDouble then
            effectData.force = effectData.force * 2
        end
    end
end

function CombatActions.applyDirectDamage(target, damageAmount, isCrit)
    if not target or not target.hp or target.hp <= 0 then return end

    -- Check for Tangrowth Square's shield first.
    if target.components.shielded then
        target.components.shielded = nil -- Consume the shield
        -- Create a "Blocked!" popup instead of a damage number.
        EffectFactory.createDamagePopup(target, "Blocked!", false, {0.7, 0.7, 1, 1}) -- Light blue text
        return -- Stop further processing, no damage is taken.
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