-- death_system.lua
-- Handles all logic related to entities reaching 0 HP.

local EffectFactory = require("modules.effect_factory")

local DeathSystem = {}

function DeathSystem.update(dt, world)
    -- A single loop to check all entities that can "die"
    for _, entity in ipairs(world.all_entities) do
        -- Only process entities that have health and are not already marked for deletion
        if entity.hp and entity.hp <= 0 and not entity.isMarkedForDeletion then
            -- Common death logic
            EffectFactory.createShatterEffect(entity.x, entity.y, entity.size, entity.color)
            entity.isMarkedForDeletion = true
        end
    end
end

return DeathSystem