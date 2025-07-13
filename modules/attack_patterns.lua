-- attack_patterns.lua
-- A centralized repository for shared attack pattern generators to reduce code duplication.

local AttackPatterns = {}
local Grid = require("modules.grid")

-- Creates a rectangular pattern from the entity to the edge of the screen.
-- Used by archers, Venusaur Square, etc.
function AttackPatterns.line_of_sight(entity)
    local sx, sy, size = entity.x, entity.y, entity.size
    local mapWidth, mapHeight = Config.MAP_WIDTH_TILES * Config.SQUARE_SIZE, Config.MAP_HEIGHT_TILES * Config.SQUARE_SIZE
    local attackOriginX, attackOriginY, attackWidth, attackHeight

    if entity.lastDirection == "up" then
        attackOriginX, attackOriginY = sx, 0
        attackWidth, attackHeight = size, sy
    elseif entity.lastDirection == "down" then
        attackOriginX, attackOriginY = sx, sy + size
        attackWidth, attackHeight = size, mapHeight - (sy + size)
    elseif entity.lastDirection == "left" then
        attackOriginX, attackOriginY = 0, sy
        attackWidth, attackHeight = sx, size
    elseif entity.lastDirection == "right" then
        attackOriginX, attackOriginY = sx + size, sy
        attackWidth, attackHeight = mapWidth - (sx + size), size
    end
    return {{shape = {type = "rect", x = attackOriginX, y = attackOriginY, w = attackWidth, h = attackHeight}, delay = 0}}
end

-- Creates a 3-stage expanding ripple pattern.
function AttackPatterns.ripple(centerX, centerY, rippleCenterSize)
    local step = Config.SQUARE_SIZE
    local size1 = rippleCenterSize * step
    local size2 = (rippleCenterSize + 2) * step
    local size3 = (rippleCenterSize + 4) * step
    return {
        {shape = {type = "rect", x = centerX - size1 / 2, y = centerY - size1 / 2, w = size1, h = size1}, delay = 0},
        {shape = {type = "rect", x = centerX - size2 / 2, y = centerY - size2 / 2, w = size2, h = size2}, delay = Config.FLASH_DURATION},
        {shape = {type = "rect", x = centerX - size3 / 2, y = centerY - size3 / 2, w = size3, h = size3}, delay = Config.FLASH_DURATION * 2},
    }
end

--------------------------------------------------------------------------------
-- ATTACK PATTERNS
--------------------------------------------------------------------------------

-- A simple 1x1 tile attack in front of the entity.
function AttackPatterns.simple_melee(square)
    local attackOriginX, attackOriginY
    local step = Config.SQUARE_SIZE
    if square.lastDirection == "up" then
        attackOriginX, attackOriginY = square.x, square.y - step
    elseif square.lastDirection == "down" then
        attackOriginX, attackOriginY = square.x, square.y + step
    elseif square.lastDirection == "left" then
        attackOriginX, attackOriginY = square.x - step, square.y
    elseif square.lastDirection == "right" then
        attackOriginX, attackOriginY = square.x + step, square.y
    end
    return {{shape = {type = "rect", x = attackOriginX, y = attackOriginY, w = Config.SQUARE_SIZE, h = Config.SQUARE_SIZE}, delay = 0}}
end

AttackPatterns.uppercut = AttackPatterns.simple_melee
AttackPatterns.venom_stab = AttackPatterns.simple_melee
AttackPatterns.invigorating_aura = AttackPatterns.simple_melee

function AttackPatterns.viscous_strike(square)
    local attackOriginX, attackOriginY, attackWidth, attackHeight
    if square.lastDirection == "up" then
        attackOriginX, attackOriginY, attackWidth, attackHeight = square.x - Config.SQUARE_SIZE, square.y - (Config.SQUARE_SIZE * 2), Config.SQUARE_SIZE * 3, Config.SQUARE_SIZE * 2
    elseif square.lastDirection == "down" then
        attackOriginX, attackOriginY, attackWidth, attackHeight = square.x - Config.SQUARE_SIZE, square.y + Config.SQUARE_SIZE, Config.SQUARE_SIZE * 3, Config.SQUARE_SIZE * 2
    elseif square.lastDirection == "left" then
        attackOriginX, attackOriginY, attackWidth, attackHeight = square.x - (Config.SQUARE_SIZE * 2), square.y - Config.SQUARE_SIZE, Config.SQUARE_SIZE * 2, Config.SQUARE_SIZE * 3
    elseif square.lastDirection == "right" then
        attackOriginX, attackOriginY, attackWidth, attackHeight = square.x + Config.SQUARE_SIZE, square.y - Config.SQUARE_SIZE, Config.SQUARE_SIZE * 2, Config.SQUARE_SIZE * 3
    end
    return {{shape = {type = "rect", x = attackOriginX, y = attackOriginY, w = attackWidth, h = attackHeight}, delay = 0}}
end

AttackPatterns.mend = AttackPatterns.viscous_strike  

function AttackPatterns.shockwave(square, world)
    local effects = {}
    if not world then return effects end -- Guard against calls without world context
    for _, enemy in ipairs(world.enemies) do
        if enemy.hp > 0 then
            table.insert(effects, {shape = {type = "rect", x = enemy.x, y = enemy.y, w = enemy.size, h = enemy.size}, delay = 0})
        end
    end
    return effects
end

AttackPatterns.fireball = AttackPatterns.line_of_sight -- Alias for projectile attack

function AttackPatterns.hookshot(entity, world)
    local attackData = AttackBlueprints.hookshot
    local range = attackData.range or 7 -- Default to 7 if not in blueprint
    local effects = {}
    local dir = entity.lastDirection

    local dx, dy = 0, 0
    if dir == "up" then dy = -1
    elseif dir == "down" then dy = 1
    elseif dir == "left" then dx = -1
    elseif dir == "right" then dx = 1
    end

    for i = 1, range do
        local tileX = entity.tileX + dx * i
        local tileY = entity.tileY + dy * i

        -- Stop if out of map bounds
        if tileX < 0 or tileX >= Config.MAP_WIDTH_TILES or tileY < 0 or tileY >= Config.MAP_HEIGHT_TILES then break end

        local pixelX, pixelY = Grid.toPixels(tileX, tileY)
        table.insert(effects, {shape = {type = "rect", x = pixelX, y = pixelY, w = Config.SQUARE_SIZE, h = Config.SQUARE_SIZE}, delay = 0})

        -- Check for a blocking entity (any entity with weight, or the flag)
        local isBlocked = false
        for _, e in ipairs(world.all_entities) do if e ~= entity and e.tileX == tileX and e.tileY == tileY and e.weight and e.weight ~= 0 then isBlocked = true; break end end
        if not isBlocked and world.flag and world.flag.tileX == tileX and world.flag.tileY == tileY then isBlocked = true end
        if isBlocked then break end
    end
    return effects
end

function AttackPatterns.aetherfall(square, world)
    local effects = {}
    if not world then return effects end -- Guard against calls without world context
    for _, enemy in ipairs(world.enemies) do
        if enemy.hp > 0 and enemy.statusEffects.airborne then
            table.insert(effects, {shape = {type = "rect", x = enemy.x, y = enemy.y, w = enemy.size, h = enemy.size}, delay = 0})
        end
    end
    return effects
end

return AttackPatterns