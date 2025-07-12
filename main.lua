-- main.lua
-- Orchestrator for the Grid Combat game.
-- Loads all modules and runs the main game loop.

-- Load data, modules, and systems
local World = require("modules.world")
EnemyBlueprints = require("data.enemy_blueprints")
Config = require("config")
local Assets = require("modules.assets")
local AnimationSystem = require("systems/animation_system")
CharacterBlueprints = require("data.character_blueprints")
EntityFactory = require("data.entities")
local AISystems = require("systems.ai_systems")
local StatusSystem = require("systems.status_system")
local CareeningSystem = require("systems.careening_system")
local StatSystem = require("systems.stat_system")
local ActionBarSystem = require("systems.action_bar_system")
local EffectTimerSystem = require("systems.effect_timer_system")
local ProjectileSystem = require("systems.projectile_system")
local MovementSystem = require("systems.movement_system")
local PlayerAttackSystem = require("systems.player_attack_system")
local PlayerSwitchSystem = require("systems.player_switch_system")
local PassiveSystem = require("systems.passive_system")
local TeamStatusSystem = require("systems.team_status_system")
local AttackResolutionSystem = require("systems.attack_resolution_system")
local ContinuousAttackSystem = require("systems.continuous_attack_system")
local DashSystem = require("systems.dash_system")
local GrappleSystem = require("systems.grapple_system")
local PidgeotSystem = require("systems/pidgeot_system")
local DeathSystem = require("systems.death_system")
local GameTimerSystem = require("systems.game_timer_system")
local WinConditionSystem = require("systems.win_condition_system")
local ActivePlayerValidationSystem = require("systems/active_player_validation_system")
local Renderer = require("modules.renderer")
local CombatActions = require("modules.combat_actions")
local ActivePlayerSyncSystem = require("systems/active_player_sync_system")
local EventBus = require("modules.event_bus")
local InputHandler = require("modules.input_handler")

world = World.new() -- The single instance of our game world
GameFont = nil -- Will hold our loaded font

local canvas
local scale = 1

-- A data-driven list of systems to run in the main update loop.
-- This makes adding, removing, or reordering systems trivial.
-- The order is important: Intent -> Action -> Resolution
local update_systems = {
    -- 1. State and timer updates
    GameTimerSystem,
    StatSystem,
    StatusSystem,
    ActionBarSystem,
    EffectTimerSystem,
    PassiveSystem,
    PlayerSwitchSystem,
    TeamStatusSystem,
    -- 2. Movement and Animation (update physical state)
    MovementSystem,
    AnimationSystem,
    -- 3. AI and Player Actions (decide what to do)
    PlayerAttackSystem,
    AISystems,
    -- 4. Update ongoing effects of actions
    ContinuousAttackSystem,
    ProjectileSystem,
    DashSystem,
    GrappleSystem,
    PidgeotSystem,
    CareeningSystem,
    -- 5. Resolve the consequences of actions
    AttackResolutionSystem,
    DeathSystem,
}

-- love.load() is called once when the game starts.
-- It's used to initialize game variables and load assets.
function love.load()
    love.graphics.setDefaultFilter("nearest", "nearest") -- Ensures crisp scaling

    -- Load all game assets (images, animations, sounds)
    Assets.load()

    -- Load the custom font. Replace with your actual font file and its native size.
    -- For pixel fonts, using the intended size (e.g., 8, 16) is crucial for sharpness.
    GameFont = love.graphics.newFont("assets/Px437_DOS-V_TWN16.ttf", 16)

    canvas = love.graphics.newCanvas(Config.VIRTUAL_WIDTH, Config.VIRTUAL_HEIGHT)
    canvas:setFilter("nearest", "nearest")

    -- Initialize factories and modules that need a reference to the world
    local EffectFactory = require("modules.effect_factory")
    CombatActions.init(world)
    EffectFactory.init(world)

    -- Register global event listeners
    EventBus:register("enemy_died", function(data)
        -- This handles Drapion's passive ability.
        if world.passives.drapionActive then
            for _, p in ipairs(world.players) do
                if p.hp > 0 then p.actionBarCurrent = p.actionBarMax end
            end
        end
    end)

    local windowWidth, windowHeight = Config.VIRTUAL_WIDTH, Config.VIRTUAL_HEIGHT

    -- Center the spawn area vertically
    local playerSpawnYOffset = 5 * Config.MOVE_STEP
    local spawnPositions = {
        {x = windowWidth / 2, y = windowHeight / 2 + playerSpawnYOffset}, -- Center
        {x = windowWidth / 2 - (2 * Config.MOVE_STEP), y = windowHeight / 2 + playerSpawnYOffset}, -- Left
        {x = windowWidth / 2 + (2 * Config.MOVE_STEP), y = windowHeight / 2 + playerSpawnYOffset}  -- Right
    }

    -- 1. Populate the roster with all possible characters
    -- All characters are initially created off-screen. Their positions will be set when they are added to the active party.
    for type, _ in pairs(CharacterBlueprints) do
        world.roster[type] = EntityFactory.createSquare(-100, -100, "player", type)
    end

    -- 2. Set up the character grid layout and the initial active party
    local allTypes = {}
    for type, _ in pairs(CharacterBlueprints) do table.insert(allTypes, type) end

    for y = 1, 3 do -- Always create a 3x3 grid
        world.characterGrid[y] = {}
        for x = 1, 3 do
            -- This will place characters and leave remaining slots as nil,
            -- which prevents crashes when the UI tries to access an empty row.
            world.characterGrid[y][x] = table.remove(allTypes, 1)
        end
    end

    -- 3. Build the initial `players` table from the top row of the grid and assign their starting positions.
    for i = 1, 3 do
        local playerType = world.characterGrid[1][i]
        if playerType then
            local playerObject = world.roster[playerType]
            local spawnPos = spawnPositions[i]
            if spawnPos then
                -- Set the starting position for the active party member
                playerObject.x = spawnPos.x
                playerObject.y = spawnPos.y
                playerObject.targetX = spawnPos.x
                playerObject.targetY = spawnPos.y
            end
            world:queue_add_entity(playerObject)
        end
    end

    -- Create enemy squares (light grey)
    world:queue_add_entity(EntityFactory.createSquare(windowWidth / 2 + 100, windowHeight / 2 + 40, "enemy", "brawler"))
    world:queue_add_entity(EntityFactory.createSquare(windowWidth / 2 - 100, windowHeight / 2 - 80, "enemy", "brawler"))
    world:queue_add_entity(EntityFactory.createSquare(windowWidth / 2, windowHeight / 2 + 100, "enemy", "archer"))
    world:queue_add_entity(EntityFactory.createSquare(windowWidth / 2 - 100, windowHeight / 2 + 100, "enemy", "punter"))
    world:queue_add_entity(EntityFactory.createSquare(windowWidth / 2 + 100, windowHeight / 2 - 80, "enemy", "archer"))
    world:queue_add_entity(EntityFactory.createSquare(windowWidth / 2, windowHeight / 2 - 80, "enemy", "punter"))

    -- Set the background color
    love.graphics.setBackgroundColor(0.1, 0.1, 0.1, 1) -- Dark grey

end

-- love.update(dt) is called every frame.
-- dt is the time elapsed since the last frame (delta time).
-- It's used for game logic, such as updating player positions and attacks.
function love.update(dt)
    -- Only update game logic if not paused
    if world.gameState == "gameplay" then
        -- Main system update loop
        for _, system in ipairs(update_systems) do
            system.update(dt, world)
        end

        -- Handle continuous input after attacks have been processed for the frame.
        InputHandler.handle_movement_input(world)

        -- Process all entity additions and deletions that were queued by the systems.
        world:process_additions_and_deletions()

        -- Run systems that must happen *after* entity deletion
        ActivePlayerValidationSystem.update(world)
        ActivePlayerSyncSystem.update(world)
        WinConditionSystem.update(world)

    elseif world.gameState == "party_select" then
        -- When paused, we want all character sprites on the select screen to animate.
        -- We loop through the entire roster and update their 'down' animation specifically.
        for _, entity in pairs(world.roster) do
            if entity and entity.components.animation then
                local downAnim = entity.components.animation.animations.down
                downAnim:resume() -- Ensure the animation is playing before updating it.
                downAnim:update(dt)
            end
        end
    end -- End of if world.gameState == "gameplay"
end

-- love.keypressed(key) is used for discrete actions, like switching players or attacking.
function love.keypressed(key)
    -- Pass the current state to the handler and get the new state back.
    world.gameState = InputHandler.handle_key_press(key, world.gameState, world)
end

function love.resize(w, h)
    -- Calculate the new scale factor to fit the virtual resolution inside the new window size, preserving aspect ratio.
    local scaleX = w / Config.VIRTUAL_WIDTH
    local scaleY = h / Config.VIRTUAL_HEIGHT
    -- By flooring the scale factor, we ensure we only scale by whole numbers (1x, 2x, 3x, etc.),
    -- which preserves a perfect pixel grid and eliminates distortion.
    -- We use math.max(1, ...) to prevent the scale from becoming 0 on very small windows.
    scale = math.max(1, math.floor(math.min(scaleX, scaleY)))
end


function love.draw()
    -- 1. Draw the entire game world to the off-screen canvas at its native resolution.
    love.graphics.setCanvas(canvas)
    love.graphics.clear()
    Renderer.draw_frame(world)
    love.graphics.setCanvas()

    -- 2. Draw the canvas to the screen, scaled and centered to fit the window.
    -- This creates letterboxing/pillarboxing as needed.
    local w, h = love.graphics.getDimensions()
    local canvasX = math.floor((w - Config.VIRTUAL_WIDTH * scale) / 2)
    local canvasY = math.floor((h - Config.VIRTUAL_HEIGHT * scale) / 2)

    love.graphics.draw(canvas, canvasX, canvasY, 0, scale, scale)
end

-- love.quit() is called when the game closes.
-- You can use it to save game state or clean up resources.
function love.quit()
    -- No specific cleanup needed for this simple game.
end
        
