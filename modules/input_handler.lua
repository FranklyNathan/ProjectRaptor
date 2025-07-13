-- input_handler.lua
-- Contains all logic for processing player keyboard input.

local Pathfinding = require("modules.pathfinding")
local AttackHandler = require("modules.attack_handler")
local AttackPatterns = require("modules.attack_patterns")
local WorldQueries = require("modules.world_queries")
local Grid = require("modules.grid")

local InputHandler = {}

--------------------------------------------------------------------------------
-- TURN-BASED HELPER FUNCTIONS
--------------------------------------------------------------------------------

-- Checks if all living player units have taken their action for the turn.
local function allPlayersHaveActed(world)
    for _, player in ipairs(world.players) do
        if player.hp > 0 and not player.hasActed then
            return false -- Found a player who hasn't acted yet.
        end
    end
    return true -- All living players have acted.
end

-- Jumps the cursor to the next available player unit.
local function focus_next_available_player(world)
    for _, player in ipairs(world.players) do
        if player.hp > 0 and not player.hasActed then
            world.mapCursorTile.x = player.tileX
            world.mapCursorTile.y = player.tileY
            return -- Found the first available player and focused.
        end
    end
end

-- Helper to move the cursor and update the movement path if applicable.
local function move_cursor(dx, dy, world)
    local newTileX = world.mapCursorTile.x + dx
    local newTileY = world.mapCursorTile.y + dy

    -- Clamp cursor to screen bounds
    world.mapCursorTile.x = math.max(0, math.min(newTileX, Config.MAP_WIDTH_TILES - 1))
    world.mapCursorTile.y = math.max(0, math.min(newTileY, Config.MAP_HEIGHT_TILES - 1))

    -- If a unit is selected, update the movement path
    if world.playerTurnState == "unit_selected" then
        local goalPosKey = world.mapCursorTile.x .. "," .. world.mapCursorTile.y
        if world.reachableTiles and world.reachableTiles[goalPosKey] then
            local startPosKey = world.selectedUnit.tileX .. "," .. world.selectedUnit.tileY
            world.movementPath = Pathfinding.reconstructPath(world.came_from, startPosKey, goalPosKey)
        else
            world.movementPath = nil -- Cursor is on an unreachable tile
        end
    end
end

-- Finds a player unit at a specific tile coordinate.
local function getPlayerUnitAt(tileX, tileY, world)
    for _, p in ipairs(world.players) do
        if p.hp > 0 and p.tileX == tileX and p.tileY == tileY then
            return p
        end
    end
    return nil
end

-- Handles input when the player is freely moving the cursor around the map.
local function handle_free_roam_input(key, world)
    if key == "j" then -- Universal "Confirm" / "Action" key
        local unit = getPlayerUnitAt(world.mapCursorTile.x, world.mapCursorTile.y, world)
        if unit and not unit.hasActed then
            -- If the cursor is on an available player unit, select it.
            world.selectedUnit = unit
            world.playerTurnState = "unit_selected"
            -- Calculate movement range and pathing data
            world.reachableTiles, world.came_from = Pathfinding.calculateReachableTiles(unit, world)
            world.movementPath = {} -- Start with an empty path
        else
            -- If the cursor is on an empty tile, open the map menu.
            local isOccupied = WorldQueries.isTileOccupied(world.mapCursorTile.x, world.mapCursorTile.y, nil, world)
            if not isOccupied then
                world.playerTurnState = "map_menu"
                world.mapMenu.active = true
                world.mapMenu.options = {{text = "End Turn", key = "end_turn"}}
                world.mapMenu.selectedIndex = 1
            end
        end
    end
end

-- Handles input when a unit is selected and the player is choosing a destination.
local function handle_unit_selected_input(key, world)
    if key == "j" then -- Confirm Move
        if world.movementPath and #world.movementPath > 0 then
            world.selectedUnit.components.movement_path = world.movementPath
            world.playerTurnState = "unit_moving"
            world.selectedUnit = nil
            world.reachableTiles = nil
            world.movementPath = nil
        end
        return -- Exit to prevent cursor update on confirm
    elseif key == "k" then -- Cancel
        world.playerTurnState = "free_roam"
        world.selectedUnit = nil
        world.reachableTiles = nil
        world.movementPath = nil
        return -- Exit to prevent cursor update on cancel
    end
end

-- Handles input when the post-move action menu is open.
local function handle_action_menu_input(key, world)
    local menu = world.actionMenu
    if not menu.active then return end

    if key == "w" then
        -- Wrap around to the bottom when moving up from the top.
        menu.selectedIndex = (menu.selectedIndex - 2 + #menu.options) % #menu.options + 1
    elseif key == "s" then
        -- Wrap around to the top when moving down from the bottom.
        menu.selectedIndex = menu.selectedIndex % #menu.options + 1
    elseif key == "k" then -- Cancel action menu
        -- For now, cancelling the menu is the same as selecting "Wait".
        -- In the future, this could undo the movement.
        menu.unit.hasActed = true
        menu.active = false
        world.playerTurnState = "free_roam"
        if allPlayersHaveActed(world) then
            world:endTurn()
        else
            focus_next_available_player(world)
        end
    elseif key == "j" then -- Confirm action

        local selectedOption = menu.options[menu.selectedIndex]
        if not selectedOption then return end

        if selectedOption.key == "wait" then
            menu.unit.hasActed = true
            menu.active = false
            world.playerTurnState = "free_roam"
            if allPlayersHaveActed(world) then
                world:endTurn()
            else
                focus_next_available_player(world)
            end
        else -- It's an attack
            world.playerTurnState = "attack_targeting"
            world.selectedAttackKey = selectedOption.key
-- Pre-calculate the attack AoE for rendering
            local attackData = CharacterBlueprints[menu.unit.playerType].attacks[world.selectedAttackKey]
            local patternFunc = AttackPatterns[attackData.name]
            if patternFunc then
                world.attackAoETiles = patternFunc(menu.unit, world)
            else
                world.attackAoETiles = {} -- No pattern, no preview
            end
        end
    end
end

-- Handles input when the map menu is open.
local function handle_map_menu_input(key, world)
    local menu = world.mapMenu
    if not menu.active then return end

    -- Navigation (for future expansion)
    if key == "w" then
        menu.selectedIndex = (menu.selectedIndex - 2 + #menu.options) % #menu.options + 1
    elseif key == "s" then
        menu.selectedIndex = menu.selectedIndex % #menu.options + 1
    elseif key == "k" then -- Cancel
        menu.active = false
        world.playerTurnState = "free_roam"
    elseif key == "j" then -- Confirm
        local selectedOption = menu.options[menu.selectedIndex]
        if selectedOption and selectedOption.key == "end_turn" then
            menu.active = false
            world.playerTurnState = "free_roam" -- State will change to "enemy" anyway
            world:endTurn()
        end
    end
end

-- Handles input when the player is aiming an attack.
local function handle_attack_targeting_input(key, world)
    local unit = world.actionMenu.unit -- The unit who is attacking
    if not unit then return end

    local directionChanged = false
    if key == "w" then unit.lastDirection = "up"; directionChanged = true
    elseif key == "s" then unit.lastDirection = "down"; directionChanged = true
    elseif key == "a" then unit.lastDirection = "left"; directionChanged = true
    elseif key == "d" then unit.lastDirection = "right"; directionChanged = true
    elseif key == "j" then -- Confirm Attack
        AttackHandler.execute(unit, world.selectedAttackKey, world)
        unit.hasActed = true
        world.playerTurnState = "free_roam"
        world.actionMenu = { active = false, unit = nil, options = {}, selectedIndex = 1 }
        world.selectedAttackKey = nil
        world.attackAoETiles = nil
        if allPlayersHaveActed(world) then
            world:endTurn()
        else
            focus_next_available_player(world)
        end
    elseif key == "k" then -- Cancel Attack
        world.playerTurnState = "action_menu"
        world.actionMenu.active = true
        world.selectedAttackKey = nil
        world.attackAoETiles = nil
    end

    if directionChanged then
        -- Recalculate the attack AoE for rendering
        local attackData = CharacterBlueprints[unit.playerType].attacks[world.selectedAttackKey]
        local patternFunc = AttackPatterns[attackData.name]
        if patternFunc then
            world.attackAoETiles = patternFunc(unit, world)
        end
    end
end


--------------------------------------------------------------------------------
-- STATE-SPECIFIC HANDLERS
--------------------------------------------------------------------------------

local stateHandlers = {}

-- Handles all input during active gameplay.
stateHandlers.gameplay = function(key, world)
    if world.turn ~= "player" then return end -- Only accept input on the player's turn

    -- Delegate to the correct handler based on the player's current action.
    if world.playerTurnState == "free_roam" then
        handle_free_roam_input(key, world)
    elseif world.playerTurnState == "unit_selected" then
        handle_unit_selected_input(key, world)
    elseif world.playerTurnState == "unit_moving" then
        -- Input is locked while a unit is moving.
    elseif world.playerTurnState == "action_menu" then
        handle_action_menu_input(key, world)
    elseif world.playerTurnState == "attack_targeting" then
        handle_attack_targeting_input(key, world)
    elseif world.playerTurnState == "map_menu" then
        handle_map_menu_input(key, world)
    end
end

-- Handles all input for the party selection menu.
stateHandlers.party_select = function(key, world)
    if key == "w" then world.cursorPos.y = math.max(1, world.cursorPos.y - 1)
    elseif key == "s" then world.cursorPos.y = math.min(3, world.cursorPos.y + 1)
    elseif key == "a" then world.cursorPos.x = math.max(1, world.cursorPos.x - 1)
    elseif key == "d" then world.cursorPos.x = math.min(3, world.cursorPos.x + 1)
    elseif key == "j" then
        if not world.selectedSquare then
            if world.characterGrid[world.cursorPos.y] and world.characterGrid[world.cursorPos.y][world.cursorPos.x] then
                world.selectedSquare = {x = world.cursorPos.x, y = world.cursorPos.y}
            end
        else
            local secondSquareType = world.characterGrid[world.cursorPos.y] and world.characterGrid[world.cursorPos.y][world.cursorPos.x]
            if secondSquareType then
                local firstSquareType = world.characterGrid[world.selectedSquare.y][world.selectedSquare.x]
                world.characterGrid[world.selectedSquare.y][world.selectedSquare.x] = secondSquareType
                world.characterGrid[world.cursorPos.y][world.cursorPos.x] = firstSquareType
            end
            world.selectedSquare = nil
        end
    end
end

--------------------------------------------------------------------------------
-- MAIN HANDLER FUNCTIONS
--------------------------------------------------------------------------------

-- This function handles discrete key presses and delegates to the correct state handler.
function InputHandler.handle_key_press(key, currentGameState, world)
    -- Global keybinds that should work in any state
    if key == "f11" then
        local isFullscreen, fstype = love.window.getFullscreen()
        love.window.setFullscreen(not isFullscreen, fstype)
    end

    -- The Escape key is a global toggle that switches between states.
    if key == "escape" then
        if currentGameState == "gameplay" then
            return "party_select" -- Switch to the menu
        elseif currentGameState == "party_select" then
            -- This is where the logic for applying party changes when unpausing lives now.
            local oldPlayerTypes = {}
            for _, p in ipairs(world.players) do table.insert(oldPlayerTypes, p.playerType) end
            local newPlayerTypes = {}
            for i = 1, 3 do if world.characterGrid[1][i] then table.insert(newPlayerTypes, world.characterGrid[1][i]) end end

            local partyChanged = #oldPlayerTypes ~= #newPlayerTypes
            if not partyChanged then
                for i = 1, #oldPlayerTypes do if oldPlayerTypes[i] ~= newPlayerTypes[i] then partyChanged = true; break end end
            end

            if partyChanged then
                -- Store the positions of the current party members to assign to the new party
                local oldPositions = {}
                for _, p in ipairs(world.players) do
                    table.insert(oldPositions, {x = p.x, y = p.y, targetX = p.targetX, targetY = p.targetY})
                end

                -- Mark all current players for deletion
                for _, p in ipairs(world.players) do
                    p.isMarkedForDeletion = true
                end

                -- Queue the new party members for addition
                for i, playerType in ipairs(newPlayerTypes) do
                    local playerObject = world.roster[playerType]
                    -- We only add them if they are alive. The roster preserves their state (HP, etc.)
                    if playerObject.hp > 0 then
                        -- Assign the position of the player being replaced. This prevents new members from spawning off-screen.
                        if oldPositions[i] then
                            playerObject.x, playerObject.y, playerObject.targetX, playerObject.targetY = oldPositions[i].x, oldPositions[i].y, oldPositions[i].targetX, oldPositions[i].targetY
                        else
                            -- If there's no old position (e.g., adding a new member to a smaller party),
                            -- give them a default starting position to avoid spawning at (0,0).
                            local newX = 100 + (i - 1) * 50
                            local newY = 100
                            playerObject.x, playerObject.y, playerObject.targetX, playerObject.targetY = newX, newY, newX, newY
                        end

                        world:queue_add_entity(playerObject)
                    end
                end
            end
            world.selectedSquare = nil -- Reset selection on unpause
            return "gameplay" -- Switch back to gameplay
        end
    end

    -- Find the correct handler for the current state and call it.
    local handler = stateHandlers[currentGameState]
    if handler then
        handler(key, world)
    end

    -- Return the current state, as no state change was triggered by this key.
    return currentGameState
end

-- This function handles continuous key-down checks for cursor movement.
function InputHandler.handle_continuous_input(dt, world)
    -- This function should only run during the player's turn in specific states.
    if world.turn ~= "player" or (world.playerTurnState ~= "free_roam" and world.playerTurnState ~= "unit_selected") then
        world.cursorInput.activeKey = nil -- Reset when not in a valid state
        return
    end

    local cursor = world.cursorInput
    local dx, dy = 0, 0
    local currentKey = nil

    -- Determine which key is being pressed, giving priority to W/S over A/D.
    if love.keyboard.isDown("w") then currentKey = "w"; dy = -1
    elseif love.keyboard.isDown("s") then currentKey = "s"; dy = 1
    elseif love.keyboard.isDown("a") then currentKey = "a"; dx = -1
    elseif love.keyboard.isDown("d") then currentKey = "d"; dx = 1
    end

    if currentKey then
        if currentKey ~= cursor.activeKey then
            -- A new key is pressed. Move immediately and set the initial delay.
            move_cursor(dx, dy, world)
            cursor.activeKey = currentKey
            cursor.timer = cursor.initialDelay
        else
            -- The same key is being held. Wait for the timer.
            cursor.timer = cursor.timer - dt
            if cursor.timer <= 0 then
                move_cursor(dx, dy, world)
                cursor.timer = cursor.timer + cursor.repeatDelay -- Add to prevent timer drift
            end
        end
    else
        -- No key is pressed. Reset the state.
        cursor.activeKey = nil
    end
end

return InputHandler