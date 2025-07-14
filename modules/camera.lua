-- camera.lua
-- Manages the position and movement of the game's camera.

local Grid = require("modules.grid")
local Config = require("config")

local Camera = {}

-- Initialize the camera's state
Camera.x = 0
Camera.y = 0

-- The update function is called every frame to move the camera smoothly.
function Camera.update(dt, world)
    -- Get cursor position in pixels.
    local cursorPixelX, cursorPixelY = Grid.toPixels(world.mapCursorTile.x, world.mapCursorTile.y)
    local cursorSize = Config.SQUARE_SIZE

    -- 1. By default, the camera's target is its current position (it doesn't move).
    local targetX, targetY = Camera.x, Camera.y

    -- 2. Define a margin for edge-scrolling. The camera will move when the cursor enters this area.
    local scrollMargin = 3 * Config.SQUARE_SIZE -- 3 tiles from the edge

    -- Get map dimensions in pixels to check against boundaries.
    local mapPixelWidth = world.map.width * world.map.tilewidth
    local mapPixelHeight = world.map.height * world.map.tileheight

    -- 3. Check if the cursor is in the margin and update the camera's target position.
    -- This creates a "dead zone" in the center of the screen where the camera doesn't move.

    -- Horizontal Scrolling
    if cursorPixelX < Camera.x + scrollMargin then
        -- Cursor is in the left margin, move camera left.
        targetX = cursorPixelX - scrollMargin
    elseif cursorPixelX + cursorSize > Camera.x + Config.VIRTUAL_WIDTH - scrollMargin then
        -- Cursor is in the right margin, move camera right.
        targetX = cursorPixelX + cursorSize - (Config.VIRTUAL_WIDTH - scrollMargin)
    end

    -- Vertical Scrolling
    if cursorPixelY < Camera.y + scrollMargin then
        -- Cursor is in the top margin, move camera up.
        targetY = cursorPixelY - scrollMargin
    elseif cursorPixelY + cursorSize > Camera.y + Config.VIRTUAL_HEIGHT - scrollMargin then
        -- Cursor is in the bottom margin, move camera down.
        targetY = cursorPixelY + cursorSize - (Config.VIRTUAL_HEIGHT - scrollMargin)
    end

    -- 4. Smoothly move the camera towards the target position.
    local lerpFactor = 0.2 -- A higher value makes the camera "snappier".
    Camera.x = Camera.x + (targetX - Camera.x) * lerpFactor
    Camera.y = Camera.y + (targetY - Camera.y) * lerpFactor

    -- 5. Clamp the camera's final position to the map boundaries to prevent showing the void.
    Camera.x = math.max(0, math.min(Camera.x, mapPixelWidth - Config.VIRTUAL_WIDTH))
    Camera.y = math.max(0, math.min(Camera.y, mapPixelHeight - Config.VIRTUAL_HEIGHT))
end

-- Applies the camera's transformation to the graphics stack.
function Camera.apply()
    love.graphics.push()
    love.graphics.translate(-math.floor(Camera.x), -math.floor(Camera.y))
end

-- Reverts the camera's transformation.
function Camera.revert()
    love.graphics.pop()
end

return Camera