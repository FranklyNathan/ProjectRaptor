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

AttackPatterns.fireball = AttackPatterns.line_of_sight -- Alias for projectile attack

return AttackPatterns