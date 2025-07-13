-- grid.lua
-- A helper module for converting between tile coordinates and pixel coordinates.

local Grid = {}

-- Converts tile coordinates (e.g., 5, 3) to pixel coordinates (e.g., 160, 96).
function Grid.toPixels(tileX, tileY)
    local pixelX = tileX * Config.MOVE_STEP
    local pixelY = tileY * Config.MOVE_STEP
    return pixelX, pixelY
end

-- Converts pixel coordinates to the tile coordinates they fall within.
function Grid.toTile(pixelX, pixelY)
    local tileX = math.floor(pixelX / Config.MOVE_STEP)
    local tileY = math.floor(pixelY / Config.MOVE_STEP)
    return tileX, tileY
end

return Grid