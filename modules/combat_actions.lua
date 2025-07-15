-- combat_actions.lua
-- Contains functions that directly apply combat results like damage and healing to entities.

local EventBus = require("modules.event_bus")
local EffectFactory = require("modules.effect_factory")

local CombatActions = {}

function CombatActions.applyDirectHeal(target, healAmount)
    if target and target.hp and target.hp > 0 then
        target.hp = math.floor(target.hp + healAmount)
        if target.hp > target.maxHp then target.hp = target.maxHp end
        return true
    end
    return false
end

function CombatActions.applyStatusEffect(target, effectData, world)
    if target and target.statusEffects and effectData and effectData.type and world then
        -- This will overwrite any existing effect of the same type.
        -- Trim leading/trailing whitespace from the effect type to prevent errors.
        effectData.type = effectData.type:match("^%s*(.-)%s*$")

        -- Now set the effect on the target
        target.statusEffects[effectData.type] = effectData

        -- Standardize airborne to be a 2-second, time-based visual effect.
        if effectData.type == "airborne" then
            effectData.duration = 2 -- 2 seconds
        end

        -- Check for the "Whiplash" passive on the attacker's team to double careen distance.
        if effectData.type == "careening" and effectData.attacker and #world.teamPassives[effectData.attacker.type].Whiplash > 0 then
            effectData.force = effectData.force * 2
        end

        -- Announce that a status was applied so other systems can react.
        EventBus:dispatch("status_applied", {target = target, effect = effectData, world = world})
    end
end

-- The attacker is passed in to correctly attribute kills for passives like Bloodrush.
function CombatActions.applyDirectDamage(target, damageAmount, isCrit, attacker)
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
        local wasAlive = target.hp > 0
        target.hp = target.hp - roundedDamage
        EffectFactory.createDamagePopup(target, roundedDamage, isCrit)
        target.components.shake = { timer = 0.2, intensity = 2 }
        if target.hp < 0 then target.hp = 0 end

        -- If the unit was alive and is now at 0 HP, it just died.
        if wasAlive and target.hp <= 0 then
            -- Announce the death to any interested systems (quests, passives, etc.)
            -- This is the primary source for kill-related events.
            EventBus:dispatch("unit_died", { victim = target, killer = attacker })
        end
    end
end

function CombatActions.executeShockwave(attacker, attackData, world)
    if not attacker or not attackData or not world then return false end
    for _, entity in ipairs(world.all_entities) do
        if entity.hp ~= nil and entity.hp > 0 and entity.type ~= attacker.type then
            -- Shockwave hits all enemies within range of the *attacker*, not the target.
            local distance = math.abs(attacker.tileX - entity.tileX) + math.abs(attacker.tileY - entity.tileY)
            if distance <= attackData.range then                
                CombatActions.applyStatusEffect(entity, {type = "paralyzed", duration = 2, attacker = attacker}, world)
            end
        end
    end
    return true
end

return CombatActions