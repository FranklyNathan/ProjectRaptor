-- entities.lua
-- Contains functions for creating game entities.
-- It relies on the global Config, CharacterBlueprints, and EnemyBlueprints tables.

local Assets = require("modules.assets")
local EntityFactory = {}

function EntityFactory.createSquare(startX, startY, type, subType)
    local square = {}
    square.size = Config.SQUARE_SIZE
    square.moveStep = Config.MOVE_STEP
    square.speed = Config.SLIDE_SPEED
    square.type = type or "player" -- "player" or "enemy"
    square.lastDirection = "down" -- Default starting direction
    square.components = {} -- All components will be stored here

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
        square.pendingAttackKey = nil -- For player: stores 'j' or 'k' or 'l' if attack is queued

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

    square.actionBarMax = 1 -- Default time for the first action
    square.actionBarCurrent = square.actionBarMax -- Action bar starts full
    square.hp = square.maxHp -- All squares start with full HP

    -- A scalable way to handle status effects
    square.statusEffects = {}

    -- Add an AI component to players
    if square.type == "player" then
        square.components.ai = { behavior = "player_ally", last_attack_key = nil, move_timer = 0, path = {} }
    end

    -- Add an AI component to enemies
    if square.type == "enemy" then
        local blueprint = EnemyBlueprints[subType]
        square.components.ai = { move_timer = math.random() * blueprint.moveDelay, move_delay = blueprint.moveDelay }
    end

    -- Initialize current and target positions
    square.x = math.floor((startX / Config.MOVE_STEP) + 0.5) * Config.MOVE_STEP
    square.y = math.floor((startY / Config.MOVE_STEP) + 0.5) * Config.MOVE_STEP
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
        moveStep = Config.MOVE_STEP,
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

return EntityFactory