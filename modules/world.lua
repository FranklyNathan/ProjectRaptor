-- world.lua
-- The World object is the single source of truth for all entity data and collections.

local EventBus = require("modules.event_bus")
local Grid = require("modules.grid")
local EntityFactory = require("data.entities")

local World = {}
World.__index = World

function World.new()
    local self = setmetatable({}, World)
    self.all_entities = {}
    self.players = {}
    self.enemies = {}
    self.projectiles = {}
    self.attackEffects = {}
    self.particleEffects = {}
    self.damagePopups = {}
    self.switchPlayerEffects = {}
    self.grappleLineEffects = {}
    self.new_entities = {}
    self.afterimageEffects = {}
    self.playerTeamStatus = { -- For team-wide status effects like Magnezone Square's L-ability
        isHealingFromAttacks = nil,
        duration = nil
    }

    -- Turn-based state
    self.turn = "player" -- "player" or "enemy"
    self.selectedUnit = nil -- The unit currently selected by the player
    self.playerTurnState = "free_roam" -- e.g., "free_roam", "unit_selected", "unit_moving", "action_menu", "attack_targeting", "map_menu"
    self.mapCursorTile = {x = 0, y = 0} -- The player's cursor on the game grid, in tile coordinates
    self.reachableTiles = nil -- Will hold the table of tiles the selected unit can move to
    self.came_from = nil -- Holds pathfinding data for path reconstruction
    self.movementPath = nil -- Will hold the list of nodes for the movement arrow
    self.actionMenu = { active = false, unit = nil, options = {}, selectedIndex = 1 } -- For post-move actions
    self.mapMenu = { active = false, options = {}, selectedIndex = 1 } -- For actions on empty tiles
    self.selectedAttackKey = nil -- The key ('j', 'k', 'l') of the attack being targeted
    self.attackAoETiles = nil -- The shape of the attack for the targeting preview
    self.cursorInput = {
        timer = 0,
        initialDelay = 0.35, -- Time before repeat starts
        repeatDelay = 0.08,  -- Time between subsequent repeats
        activeKey = nil
    }

    -- Game State and UI
    self.gameState = "gameplay"
    self.roster = {}
    self.characterGrid = {}
    self.cursorPos = {x = 1, y = 1}
    self.selectedSquare = nil
    self.playerToKeepActive = nil -- Used to re-select the correct player after a party swap.

    -- A table to hold the state of team-wide passives, calculated once per frame.
    self.passives = {
        electivireActive = false,
        venusaurCritBonus = 0,
        florgesActive = false,
        drapionActive = false,
        tangrowthCareenDouble = false,
        sceptileSpeedBoost = false
    }

    -- Define the full roster in a fixed order based on the asset load sequence.
    -- This order determines their position in the party select grid.
    local characterOrder = {
        "drapionsquare", "sceptilesquare", "pidgeotsquare",
        "venusaursquare", "florgessquare", "magnezonesquare",
        "tangrowthsquare", "electiviresquare"
    }

    -- Create all playable characters and store them in the roster.
    -- The roster holds the state of all characters (like HP), even when they are not in the active party.
    -- We create them at a default (0,0) position. Their actual starting positions
    -- will be set when they are added to the active party or swapped in.

    -- Define the starting positions for the player party (bottom-middle of the screen).
    local mapWidthInTiles = Config.VIRTUAL_WIDTH / Config.MOVE_STEP
    local mapHeightInTiles = Config.VIRTUAL_HEIGHT / Config.MOVE_STEP
    local centerX = math.floor(mapWidthInTiles / 2)
    local spawnY = mapHeightInTiles - 4 -- A few tiles from the bottom
    local spawnPositions = {
        {tileX = centerX - 2, tileY = spawnY}, -- Left
        {tileX = centerX,     tileY = spawnY}, -- Center
        {tileX = centerX + 2, tileY = spawnY}  -- Right
    }

    -- Create all playable characters and store them in the roster.
    for _, playerType in ipairs(characterOrder) do
        local playerEntity = EntityFactory.createSquare(0, 0, "player", playerType)
        self.roster[playerType] = playerEntity
    end

    -- Populate the initial active party with the first 3 characters from the fixed order and place them.
    for i = 1, 3 do
        local playerType = characterOrder[i]
        if playerType then
            local playerEntity = self.roster[playerType]
            local spawnPos = spawnPositions[i] -- This is now in tile coordinates
            playerEntity.tileX, playerEntity.tileY = spawnPos.tileX, spawnPos.tileY
            playerEntity.x, playerEntity.y = Grid.toPixels(spawnPos.tileX, spawnPos.tileY)
            playerEntity.targetX, playerEntity.targetY = playerEntity.x, playerEntity.y
            self:_add_entity(playerEntity)
        end
    end

    -- Set the initial cursor position to the first player.
    if self.players[1] then
        self.mapCursorTile.x = self.players[1].tileX
        self.mapCursorTile.y = self.players[1].tileY
    end

    -- Populate the 3x3 character selection grid based on the fixed order.
    local gridX, gridY = 1, 1
    for _, playerType in ipairs(characterOrder) do
        -- Ensure the row exists before trying to add to it.
        if not self.characterGrid[gridY] then self.characterGrid[gridY] = {} end

        self.characterGrid[gridY][gridX] = playerType
        gridX = gridX + 1
        if gridX > 3 then
            gridX = 1
            gridY = gridY + 1
        end
    end

    return self
end

-- Manages the transition between player and enemy turns.
function World:endTurn()
    if self.turn == "player" then
        -- Announce that the player's turn has ended so systems can react.
        EventBus:dispatch("player_turn_ended", {world = self})

        self.turn = "enemy"
        -- Reset enemy state for their turn.
        for _, enemy in ipairs(self.enemies) do
            enemy.hasActed = false
        end
        -- Clean up any lingering player selection UI state.
        self.selectedUnit = nil
        self.reachableTiles = nil
        self.movementPath = nil
        self.came_from = nil
        self.playerTurnState = "free_roam"
    elseif self.turn == "enemy" then
        -- Announce that the enemy's turn has ended.
        EventBus:dispatch("enemy_turn_ended", {world = self})

        self.turn = "player"
        -- Reset player state for their turn.
        for _, player in ipairs(self.players) do
            player.hasActed = false
        end
        self.playerTurnState = "free_roam"

        -- At the start of the player's turn, move the cursor to the first available unit.
        for _, p in ipairs(self.players) do
            if p.hp > 0 and not p.hasActed then
                self.mapCursorTile.x = p.tileX
                self.mapCursorTile.y = p.tileY
                break -- Found the first one, stop searching.
            end
        end
    end
end

-- Queues a new entity to be added at the end of the frame.
function World:queue_add_entity(entity)
    if not entity then return end
    table.insert(self.new_entities, entity)
end

-- Adds an entity to all relevant lists.
function World:_add_entity(entity)
    if not entity then return end
    -- When an entity is added, it should not be marked for deletion.
    -- This cleans up state from previous removals (e.g. a dead character from the roster being re-added)
    -- and prevents duplication bugs during party swaps.
    entity.isMarkedForDeletion = nil
    table.insert(self.all_entities, entity)
    if entity.type == "player" then
        table.insert(self.players, entity)
    elseif entity.type == "enemy" then
        table.insert(self.enemies, entity)
    elseif entity.type == "projectile" then
        table.insert(self.projectiles, entity)
    end
end

-- Removes an entity from its specific list.
function World:_remove_from_specific_list(entity)
    local list = (entity.type == "player" and self.players) or
                 (entity.type == "enemy" and self.enemies) or
                 (entity.type == "projectile" and self.projectiles)
    if not list then return end
    for i = #list, 1, -1 do
        if list[i] == entity then
            table.remove(list, i)
            return
        end
    end
end

-- Processes all additions and deletions at the end of the frame.
function World:process_additions_and_deletions()
    -- Process deletions first
    for i = #self.all_entities, 1, -1 do
        local entity = self.all_entities[i]
        if entity.isMarkedForDeletion then
            self:_remove_from_specific_list(entity)
            table.remove(self.all_entities, i)
        end
    end

    -- Process additions
    for _, entity in ipairs(self.new_entities) do
        self:_add_entity(entity)
    end
    self.new_entities = {} -- Clear the queue
end

return World