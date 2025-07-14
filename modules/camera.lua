-- camera.lua
-- Manages the position and movement of the game's camera.

local Grid = require("modules.grid")

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

    -- 2. Check if the cursor is pushing the edges of the screen and update the target accordingly.
    -- This creates the "edge-scrolling" behavior.
    if cursorPixelX < Camera.x then
        targetX = cursorPixelX
    elseif cursorPixelX + cursorSize > Camera.x + Config.VIRTUAL_WIDTH then
        targetX = cursorPixelX + cursorSize - Config.VIRTUAL_WIDTH
    end

    if cursorPixelY < Camera.y then
        targetY = cursorPixelY
    elseif cursorPixelY + cursorSize > Camera.y + Config.VIRTUAL_HEIGHT then
        targetY = cursorPixelY + cursorSize - Config.VIRTUAL_HEIGHT
    end

    -- 3. Clamp the target position to the map boundaries to prevent showing the void.
    local mapPixelWidth = world.map.width * world.map.tilewidth
    local mapPixelHeight = world.map.height * world.map.tileheight
    targetX = math.max(0, math.min(targetX, mapPixelWidth - Config.VIRTUAL_WIDTH))
    targetY = math.max(0, math.min(targetY, mapPixelHeight - Config.VIRTUAL_HEIGHT))

    -- 4. Smoothly move the camera towards the final target position.
    local lerpFactor = 0.2 -- A higher value makes the camera "snappier".
    Camera.x = Camera.x + (targetX - Camera.x) * lerpFactor
    Camera.y = Camera.y + (targetY - Camera.y) * lerpFactor
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