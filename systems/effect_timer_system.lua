-- effect_timer_system.lua
-- This system is responsible for updating simple countdown timers on entities for visual effects.

local EffectTimerSystem = {}

function EffectTimerSystem.update(dt, world)
    -- 1. Update timers on entity components
    for _, s in ipairs(world.all_entities) do
        -- Update shake timer
        if s.components.shake then
            s.components.shake.timer = s.components.shake.timer - dt
            if s.components.shake.timer <= 0 then
                s.components.shake = nil -- Remove the component to end the effect
            end
        end

        -- Update time-based status effects like 'airborne'
        if s.statusEffects and s.statusEffects.airborne then
            local effect = s.statusEffects.airborne
            -- Only tick down the duration if it's not being controlled by another system.
            if not effect.aetherfall_controlled then
                effect.duration = effect.duration - dt
                if effect.duration <= 0 then
                    s.statusEffects.airborne = nil
                end
            end
        end
    end

    -- 2. Update standalone visual effects
    -- Afterimages
    for i = #world.afterimageEffects, 1, -1 do
        local effect = world.afterimageEffects[i]
        effect.lifetime = effect.lifetime - dt
        if effect.lifetime <= 0 then
            table.remove(world.afterimageEffects, i)
        end
    end

    -- Damage Popups
    for i = #world.damagePopups, 1, -1 do
        local popup = world.damagePopups[i]
        popup.lifetime = popup.lifetime - dt
        if popup.lifetime <= 0 then
            table.remove(world.damagePopups, i)
        else
            popup.y = popup.y + popup.vy * dt -- Move it upwards
        end
    end

    -- Particle Effects
    for i = #world.particleEffects, 1, -1 do
        local p = world.particleEffects[i]
        p.lifetime = p.lifetime - dt
        if p.lifetime <= 0 then
            table.remove(world.particleEffects, i)
        else
            p.x = p.x + p.vx * dt
            p.y = p.y + p.vy * dt
        end
    end

    -- Attack Effects (hit tiles)
    for i = #world.attackEffects, 1, -1 do
        local effect = world.attackEffects[i]
        if effect.initialDelay > 0 then
            effect.initialDelay = effect.initialDelay - dt
        else
            effect.currentFlashTimer = effect.currentFlashTimer - dt
            if effect.currentFlashTimer <= 0 then
                table.remove(world.attackEffects, i)
            end
        end
    end
end

return EffectTimerSystem