-- camera.lua
-- Manages the position and movement of the game's camera.

local Camera = {}

-- Initialize the camera's state
Camera.x = 0
Camera.y = 0
Camera.speed = 300 -- How fast the camera scrolls

-- The update function will be called every frame to move the camera smoothly.
function Camera.update(dt, world)
    local targetX, targetY = world.mapCursorTile.x * Config.MOVE_STEP, world.mapCursorTile.y * Config.MOVE_STEP

    -- Calculate the desired camera position to center the cursor, but clamp it to the map boundaries.
    local desiredX = targetX - Config.VIRTUAL_WIDTH / 2
    local desiredY = targetY - Config.VIRTUAL_HEIGHT / 2

    -- Calculate map boundaries in pixels
    local mapPixelWidth = Config.MAP_WIDTH_TILES * Config.MOVE_STEP
    local mapPixelHeight = Config.MAP_HEIGHT_TILES * Config.MOVE_STEP

    -- Clamp the camera's desired position to ensure it doesn't show areas outside the map.
    desiredX = math.max(0, math.min(desiredX, mapPixelWidth - Config.VIRTUAL_WIDTH))
    desiredY = math.max(0, math.min(desiredY, mapPixelHeight - Config.VIRTUAL_HEIGHT))

    -- Smoothly move the camera towards its desired position (interpolation)
    local moveStep = Camera.speed * dt
    Camera.x = Camera.x + (desiredX - Camera.x) * 0.1 -- Using a fraction creates a smoother, easing effect
    Camera.y = Camera.y + (desiredY - Camera.y) * 0.1
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