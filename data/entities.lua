-- entities.lua
-- Contains functions for creating game entities.
-- It relies on the global Config, CharacterBlueprints, and EnemyBlueprints tables.

local Assets = require("modules.assets")
local Grid = require("modules.grid")

local EntityFactory = {}

function EntityFactory.createSquare(startTileX, startTileY, type, subType)
    local square = {}
    -- Core grid position (for game logic)
    square.tileX = startTileX
    square.tileY = startTileY
    -- Visual pixel position (for rendering and smooth movement)
    square.x, square.y = Grid.toPixels(startTileX, startTileY)
    square.size = Config.SQUARE_SIZE
    square.speed = Config.SLIDE_SPEED
    square.type = type or "player" -- "player" or "enemy"
    square.lastDirection = "down" -- Default starting direction
    square.components = {} -- All components will be stored here
    square.hasActed = false -- For turn-based logic

    -- Set properties based on type/playerType
    if square.type == "player" then
        square.playerType = subType -- e.g., "drapionsquare"
        local blueprint = CharacterBlueprints[subType]
        -- The 'color' property is now used for effects like the death shatter.
        -- We'll set it to the character's dominant color for visual consistency.
        square.color = {blueprint.dominantColor[1], blueprint.dominantColor[2], blueprint.dominantColor[3], 1}
        square.maxHp = blueprint.maxHp
        square.baseAttackStat = blueprint.attackStat
        square.baseDefenseStat = blueprint.defenseStat
        square.isFlying = blueprint.isFlying or false -- Add the flying trait to the entity
        square.weight = blueprint.weight or 1 -- Default to a light weight
        square.movement = blueprint.movement or 5 -- Default movement range in tiles

        -- A mapping from the internal player type to the asset name for scalability.
        local playerSpriteMap = {
            drapionsquare = "Drapion",
            florgessquare = "Florges",
            magnezonesquare = "Magnezone",
            tangrowthsquare = "Tangrowth",
            venusaursquare = "Venusaur",
            electiviresquare = "Electivire",
            sceptilesquare = "Sceptile",
            pidgeotsquare = "Pidgeot"
        }

        local spriteName = playerSpriteMap[subType]
        if spriteName and Assets.animations[spriteName] then
            square.components.animation = {
                animations = {
                    down = Assets.animations[spriteName].down:clone(),
                    left = Assets.animations[spriteName].left:clone(),
                    right = Assets.animations[spriteName].right:clone(),
                    up = Assets.animations[spriteName].up:clone()
                },
                current = "down",
                spriteSheet = Assets.images[spriteName]
            }
        end
        square.speedMultiplier = 1 -- For special movement speeds like dashes
        square.inventory = {} -- For future item system
    elseif square.type == "enemy" then
        square.enemyType = subType -- e.g., "standard"
        local blueprint = EnemyBlueprints[subType]
        square.color = {blueprint.color[1], blueprint.color[2], blueprint.color[3], 1}
        square.maxHp = blueprint.maxHp
        square.baseAttackStat = blueprint.attackStat
        square.baseDefenseStat = blueprint.defenseStat
        square.movement = blueprint.movement or 4 -- Default movement range in tiles
        square.weight = blueprint.weight or 5 -- Default to a medium weight

        -- Add animation component for enemies
        local enemySpriteMap = {
            brawler = "Brawler",
            archer = "Archer",
            punter = "Punter"
        }

        local spriteName = enemySpriteMap[subType]
        if spriteName and Assets.animations[spriteName] then
            square.components.animation = {
                animations = {
                    down = Assets.animations[spriteName].down:clone(),
                    left = Assets.animations[spriteName].left:clone(),
                    right = Assets.animations[spriteName].right:clone(),
                    up = Assets.animations[spriteName].up:clone()
                },
                current = "down",
                spriteSheet = Assets.images[spriteName]
            }
        end
    end

    square.hp = square.maxHp -- All squares start with full HP

    -- A scalable way to handle status effects
    square.statusEffects = {}

    -- Add an AI component to players
    if square.type == "player" then
        square.components.ai = { behavior = "player_ally", last_attack_key = nil, move_timer = 0, path = {} }
    end

    -- Add an AI component to enemies
    if square.type == "enemy" then
        square.components.ai = {}
    end

    -- Initialize current and target positions
    square.targetX = square.x
    square.targetY = square.y

    return square
end

function EntityFactory.createProjectile(x, y, direction, attacker, power, isEnemy, statusEffect)
    local projectile = {}
    projectile.x = x
    projectile.y = y
    projectile.size = Config.SQUARE_SIZE
    projectile.type = "projectile" -- A new type for rendering/filtering

    projectile.components = {}
    projectile.components.projectile = {
        direction = direction,
        moveStep = Config.SQUARE_SIZE,
        moveDelay = 0.05,
        timer = 0.05,
        attacker = attacker,
        power = power,
        isEnemyProjectile = isEnemy,
        statusEffect = statusEffect
    }

    -- Projectiles don't need a full renderable component yet,
    -- as the renderer has a special loop for them.

    return projectile
end

function EntityFactory.createGrappleHook(attacker, power, range)
    local hook = {}
    hook.x = attacker.x
    hook.y = attacker.y
    hook.size = Config.SQUARE_SIZE / 2 -- Make it smaller than a full tile
    hook.type = "grapple_hook" -- A new type for specific systems
    hook.color = {0.6, 0.3, 0.1, 1} -- Brown

    hook.components = {}
    hook.components.grapple_hook = {
        attacker = attacker,
        power = power,
        direction = attacker.lastDirection,
        speed = Config.SLIDE_SPEED * 4, -- Very fast
        maxDistance = (range or 7) * Config.SQUARE_SIZE,
        distanceTraveled = 0,
        state = "firing" -- "firing", "retracting", "hit"
    }

    return hook
end

return EntityFactory