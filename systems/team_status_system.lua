-- team_status_system.lua
-- Manages team-wide status effects, like Magnezone Square's L-ability.

local EventBus = require("modules.event_bus")

local TeamStatusSystem = {}

-- This system is now event-driven and only needs to listen for the end of the player's turn.
EventBus:register("player_turn_ended", function(data)
    local world = data.world
    if world.playerTeamStatus.duration and world.playerTeamStatus.duration > 0 then
        world.playerTeamStatus.duration = world.playerTeamStatus.duration - 1
        if world.playerTeamStatus.duration <= 0 then
            -- Reset all effects when the duration expires.
            world.playerTeamStatus.isHealingFromAttacks = nil
            world.playerTeamStatus.duration = nil
        end
    end
end)

return TeamStatusSystem