-- team_status_system.lua
-- Manages team-wide status effects, like Magnezone Square's L-ability.

local EventBus = require("modules.event_bus")

local TeamStatusSystem = {}

-- This system is event-driven. It listens for events and applies team-wide status changes.
-- With Ion Shield removed, this system is currently not active but is kept for future abilities.
EventBus:register("enemy_turn_ended", function(data)
    -- No team-wide effects currently tick down at the end of the enemy's turn.
end)

return TeamStatusSystem