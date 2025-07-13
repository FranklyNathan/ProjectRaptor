-- passive_system.lua
-- Manages team-wide passive abilities.

local Geometry = require("modules.geometry")
local EffectFactory = require("modules.effect_factory")
local CombatActions = require("modules.combat_actions")

local PassiveSystem = {}

-- This system updates the state of team-wide passives and applies their continuous effects.
function PassiveSystem.update(dt, world)
    -- 1. Update passive states
    world.passives.venusaurCritBonus = 0
    world.passives.florgesActive = false
    world.passives.drapionActive = false
    world.passives.tangrowthCareenDouble = false
    world.passives.sceptileSpeedBoost = false

    for _, p in ipairs(world.players) do
        if p.hp > 0 then
            local blueprint = CharacterBlueprints[p.playerType]
            if blueprint and blueprint.passive == "venusaur_crit_bonus" then
                world.passives.venusaurCritBonus = 0.10
            elseif blueprint and blueprint.passive == "florges_regen" then
                world.passives.florgesActive = true
            elseif blueprint and blueprint.passive == "drapion_action_on_kill" then
                world.passives.drapionActive = true
            elseif blueprint and blueprint.passive == "tangrowth_careen_double" then
                world.passives.tangrowthCareenDouble = true
            elseif blueprint and blueprint.passive == "sceptile_speed_boost" then
                world.passives.sceptileSpeedBoost = true
            end
        end
    end

    -- 2. Apply continuous passive effects
    -- Florgessquare's Passive (HP Regeneration)
    if world.passives.florgesActive then
        for _, p in ipairs(world.players) do
            if p.hp > 0 and p.hp < p.maxHp then
                CombatActions.applyDirectHeal(p, 3 * dt)
            end
        end
    end
end

return PassiveSystem