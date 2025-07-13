-- status_system.lua
-- This system is event-driven and handles the effects of statuses at the end of turns.

local EventBus = require("modules.event_bus")
local EffectFactory = require("modules.effect_factory")

-- Helper function to process end-of-turn effects for a list of entities.
local function process_turn_end_for_team(entities)
    for _, entity in ipairs(entities) do
        if entity.hp > 0 and entity.statusEffects then
            -- 1. Apply poison damage
            if entity.statusEffects.poison then
                local damage = Config.POISON_DAMAGE_PER_TURN
                local roundedDamage = math.floor(damage)
                if roundedDamage > 0 then
                    entity.hp = entity.hp - roundedDamage
                    if entity.hp < 0 then entity.hp = 0 end
                    -- Create a custom purple damage popup for poison
                    EffectFactory.createDamagePopup(entity, roundedDamage, false, {0.5, 0, 0.5, 1})
                end
            end

            -- 2. Tick down turn-based durations
            -- We iterate backwards to safely remove items.
            local effectsToRemove = {}
            for effectType, effectData in pairs(entity.statusEffects) do
                -- Some effects like 'airborne' or 'phasing' are managed by other systems
                -- and don't use turn-based durations. We ignore them here.
                local isTurnBased = effectData.duration and effectData.duration ~= math.huge and
                                    effectType ~= "airborne" and effectType ~= "phasing"

                if isTurnBased then
                    effectData.duration = effectData.duration - 1
                    if effectData.duration <= 0 then
                        table.insert(effectsToRemove, effectType)
                    end
                end
            end

            -- Remove expired effects
            for _, effectType in ipairs(effectsToRemove) do
                entity.statusEffects[effectType] = nil
            end
        end
    end
end

-- Register listeners for turn-end events
EventBus:register("player_turn_ended", function(data)
    process_turn_end_for_team(data.world.players)
end)

EventBus:register("enemy_turn_ended", function(data)
    process_turn_end_for_team(data.world.enemies)
end)