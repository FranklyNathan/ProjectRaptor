-- attack_handler.lua
-- This module is responsible for dispatching player attacks.

local Unitattacks = require("data.unit_attacks")

local AttackHandler = {}

function AttackHandler.execute(square, attackName, world)
    local attackData = AttackBlueprints[attackName]

    if attackData and Unitattacks[attackName] then
        local result = Unitattacks[attackName](square, attackData.power, world)
        -- If the attack function returns a boolean, use it. Otherwise, assume it fired successfully.
        if type(result) == "boolean" then
            return result
        else
            return true
        end
    end
    return false -- Attack not found
end

return AttackHandler