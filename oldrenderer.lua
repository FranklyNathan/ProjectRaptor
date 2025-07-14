

-- oldrenderer.lua
-- An outdated, old version of the renderer. Kept here in case it's useful, since some things broke when we swapped to the new renderer.

local Grid = require("modules.grid")
local Camera = require("modules.camera")
local Assets = require("modules.assets")
local Renderer = {}

--------------------------------------------------------------------------------
-- LOCAL DRAWING HELPER FUNCTIONS
-- (Moved from systems.lua)
--------------------------------------------------------------------------------

local function drawHealthBar(square)
    local barWidth, barHeight, barYOffset = square.size, 3, square.size + 2
    love.graphics.setColor(0.2, 0.2, 0.2, 1) -- Dark grey background for clarity
    love.graphics.rectangle("fill", square.x, square.y + barYOffset, barWidth, barHeight)
    local currentHealthWidth = (square.hp / square.maxHp) * barWidth
    if square.type == "enemy" then
        love.graphics.setColor(1, 0, 0, 1) -- Red for enemies
    else
        love.graphics.setColor(0, 1, 0, 1) -- Green for players
    end
    love.graphics.rectangle("fill", square.x, square.y + barYOffset, currentHealthWidth, barHeight)

    -- If shielded, draw an outline around the health bar.
    if square.components.shielded then
        love.graphics.setColor(0.7, 0.7, 1, 0.8) -- Light blue
        love.graphics.setLineWidth(1)
        love.graphics.rectangle("line", square.x - 1, square.y + barYOffset - 1, barWidth + 2, barHeight + 2)
        love.graphics.setLineWidth(1) -- Reset
    end
end

local function draw_entity(entity, world, is_active_player)
    love.graphics.push()
    -- Check for the 'shake' component
    if entity.components.shake then
        local offsetX = math.random(-entity.components.shake.intensity, entity.components.shake.intensity)
        local offsetY = math.random(-entity.components.shake.intensity, entity.components.shake.intensity)
        love.graphics.translate(offsetX, offsetY)
    end

    -- If the entity has a sprite, draw it. Otherwise, draw the old rectangle.
    if entity.components.animation then
        local animComponent = entity.components.animation
        local currentAnim = animComponent.animations[animComponent.current]
        local spriteSheet = animComponent.spriteSheet

        -- Get the native dimensions of the sprite frame.
        local w, h = currentAnim:getDimensions()

        -- The anchor point is the bottom-center of the entity's logical 32x32 tile.
        -- This makes characters of different heights all appear to stand on the same ground plane.
        local drawX = entity.x + entity.size / 2
        local baseDrawY = entity.y + entity.size

        -- Airborne effect calculations
        local visualYOffset = 0
        local rotation = 0
        if entity.statusEffects.airborne then
            local effect = entity.statusEffects.airborne
            local totalDuration = 2 -- The initial duration of the airborne effect
            local timeElapsed = totalDuration - effect.duration
            local progress = math.min(1, timeElapsed / totalDuration)

            -- Draw shadow on the ground. It fades as the entity goes up.
            local shadowAlpha = 0.4 * (1 - math.sin(progress * math.pi))
            love.graphics.setColor(0, 0, 0, shadowAlpha)
            love.graphics.ellipse("fill", drawX, baseDrawY, 12, 6)

            -- Calculate visual offset for the "pop up" and rotation
            visualYOffset = -math.sin(progress * math.pi) * 40 -- Max height of 40px
            rotation = progress * (2 * math.pi) -- Full 360-degree rotation over the duration
        end

-- Add a bobbing effect when idle and not airborne.
        local bobbingOffset = 0
        if currentAnim.status == "paused" and not entity.statusEffects.airborne and not entity.hasActed then
            bobbingOffset = math.sin(love.timer.getTime() * 8) -- Bob up and down 1 pixel
        end

        local finalDrawY = baseDrawY + visualYOffset + bobbingOffset

        -- Step 1: Draw the base sprite in full color. This is the bottom layer.
        love.graphics.setShader() -- Ensure no shader is active for the base draw.
        love.graphics.setColor(1, 1, 1, 1) -- Reset color to white to avoid tinting the sprite.
        currentAnim:draw(spriteSheet, drawX, finalDrawY, rotation, 1, 1, w / 2, h)

        -- Step 2: If poisoned, draw a semi-transparent pulsating overlay on top.
        if entity.statusEffects.poison and Assets.shaders.solid_color then
            love.graphics.setShader(Assets.shaders.solid_color)
            -- Pulsating purple tint for poison
            local pulse = (math.sin(love.timer.getTime() * 8) + 1) / 2 -- Fast pulse (0 to 1)
            local alpha = 0.2 + pulse * 0.3 -- Alpha from 0.2 to 0.5
            Assets.shaders.solid_color:send("solid_color", {0.6, 0.2, 0.8, alpha}) -- Purple
            currentAnim:draw(spriteSheet, drawX, finalDrawY, rotation, 1, 1, w / 2, h)
        end

        -- Step 3: If paralyzed, draw a semi-transparent pulsating overlay on top.
        if entity.statusEffects.paralyzed and Assets.shaders.solid_color then
            love.graphics.setShader(Assets.shaders.solid_color)
            -- Pulsating yellow tint for paralysis
            local pulse = (math.sin(love.timer.getTime() * 6) + 1) / 2 -- Slower pulse (0 to 1)
            local alpha = 0.1 + pulse * 0.3 -- Alpha from 0.1 to 0.4
            Assets.shaders.solid_color:send("solid_color", {1.0, 1.0, 0.2, alpha}) -- Yellow
            currentAnim:draw(spriteSheet, drawX, finalDrawY, rotation, 1, 1, w / 2, h)
        end

        -- Step 3.5: If stunned, draw a static purple overlay.
        if entity.statusEffects.stunned and Assets.shaders.solid_color then
            love.graphics.setShader(Assets.shaders.solid_color)
            Assets.shaders.solid_color:send("solid_color", {0.5, 0, 0.5, 0.5}) -- Semi-transparent purple
            currentAnim:draw(spriteSheet, drawX, finalDrawY, rotation, 1, 1, w / 2, h)
        end

        -- Step 3.7: If the unit has acted, draw a greyscale version on top of everything else.
        -- This ensures the "acted" state is always visible.
        if entity.hasActed and Assets.shaders.greyscale then
            love.graphics.setShader(Assets.shaders.greyscale)
            Assets.shaders.greyscale:send("strength", 1.0) -- Full greyscale effect
            currentAnim:draw(spriteSheet, drawX, finalDrawY, rotation, 1, 1, w / 2, h)
        end

        -- Step 4: If this is the active player, draw the outline on top as an overlay.
        if is_active_player and Assets.shaders.outline then
            love.graphics.setShader(Assets.shaders.outline)
            Assets.shaders.outline:send("outline_color", {1.0, 1.0, 1.0, 1.0}) -- White
            Assets.shaders.outline:send("texture_size", {spriteSheet:getWidth(), spriteSheet:getHeight()})
            Assets.shaders.outline:send("outline_only", true) -- Use the new overlay mode
            currentAnim:draw(spriteSheet, drawX, finalDrawY, rotation, 1, 1, w / 2, h)
        end

        -- Step 5: Reset the shader state after all drawing for this entity is done.
        love.graphics.setShader() 
    end

    drawHealthBar(entity)

    love.graphics.pop()
end

--------------------------------------------------------------------------------
-- MAIN DRAW FUNCTION
--------------------------------------------------------------------------------

-- This single function draws the entire game state.
-- It receives a `gameState` table containing everything it needs to render.
function Renderer.draw_frame(world)
    -- Apply the camera transformation for all world-space objects
    Camera.apply()

    -- Draw Turn-Based UI Elements (Ranges, Path, Cursor)
    if world.gameState == "gameplay" and world.turn == "player" then
        -- 1. Draw the full attack range for the selected unit (the "danger zone").
        -- This is drawn first so that the blue movement range tiles can draw over it.
        if world.playerTurnState == "unit_selected" and world.attackableTiles then
            love.graphics.setColor(1, 0.2, 0.2, 0.6) -- Faint, transparent red
            for posKey, _ in pairs(world.attackableTiles) do
                local tileX = tonumber(string.match(posKey, "(-?%d+)"))
                local tileY = tonumber(string.match(posKey, ",(-?%d+)"))
                if tileX and tileY then
                    local pixelX, pixelY = Grid.toPixels(tileX, tileY)
                    love.graphics.rectangle("fill", pixelX, pixelY, Config.SQUARE_SIZE, Config.SQUARE_SIZE)
                end
            end
        end

        -- 2. Draw the movement range for the selected unit.
        if world.playerTurnState == "unit_selected" and world.reachableTiles then
            love.graphics.setColor(0.2, 0.4, 1, 0.6) -- Semi-transparent blue
            for posKey, _ in pairs(world.reachableTiles) do
                local tileX = tonumber(string.match(posKey, "(-?%d+)"))
                local tileY = tonumber(string.match(posKey, ",(-?%d+)"))
                if tileX and tileY then
                    local pixelX, pixelY = Grid.toPixels(tileX, tileY)
                    love.graphics.rectangle("fill", pixelX, pixelY, Config.SQUARE_SIZE, Config.SQUARE_SIZE)
                end
            end
        end

        -- 3. Draw the movement path arrow.
        if world.playerTurnState == "unit_selected" and world.movementPath and #world.movementPath > 0 then
            love.graphics.setColor(1, 1, 0, 0.8) -- Bright yellow
            love.graphics.setLineWidth(3)

            -- Start the line from the center of the selected unit.
            local prevX = world.selectedUnit.x + world.selectedUnit.size / 2
            local prevY = world.selectedUnit.y + world.selectedUnit.size / 2

            for _, node in ipairs(world.movementPath) do
                local nextX = node.x + Config.SQUARE_SIZE / 2
                local nextY = node.y + Config.SQUARE_SIZE / 2
                love.graphics.line(prevX, prevY, nextX, nextY)
                prevX, prevY = nextX, nextY
            end

            love.graphics.setLineWidth(1) -- Reset line width
        end

        -- 4. Draw the map cursor.
        if world.playerTurnState == "free_roam" or world.playerTurnState == "unit_selected" or
           world.playerTurnState == "cycle_targeting" or world.playerTurnState == "ground_aiming" then
            love.graphics.setColor(1, 1, 1, 1) -- White cursor outline
            love.graphics.setLineWidth(2)
            local cursorPixelX, cursorPixelY
            if world.playerTurnState == "cycle_targeting" and world.cycleTargeting.active and #world.cycleTargeting.targets > 0 then
                local target = world.cycleTargeting.targets[world.cycleTargeting.selectedIndex]
                if target then
                    -- In cycle mode, the cursor is on the target itself.
                    cursorPixelX, cursorPixelY = target.x, target.y
                else
                    cursorPixelX, cursorPixelY = Grid.toPixels(world.mapCursorTile.x, world.mapCursorTile.y)
                end
            else
                cursorPixelX, cursorPixelY = Grid.toPixels(world.mapCursorTile.x, world.mapCursorTile.y)
            end
            love.graphics.rectangle("line", cursorPixelX, cursorPixelY, Config.SQUARE_SIZE, Config.SQUARE_SIZE)
            love.graphics.setLineWidth(1) -- Reset line width
        end

        -- Draw the ground aiming grid (the valid area for ground-targeted attacks)
        if world.playerTurnState == "ground_aiming" and world.groundAimingGrid then
            love.graphics.setColor(0.2, 0.8, 1, 0.4) -- A light, cyan-ish color
            for _, tile in ipairs(world.groundAimingGrid) do
                local pixelX, pixelY = Grid.toPixels(tile.x, tile.y)
                love.graphics.rectangle("fill", pixelX, pixelY, Config.SQUARE_SIZE, Config.SQUARE_SIZE)
            end
        end

        -- 5. Draw the Attack AoE preview
        if world.playerTurnState == "ground_aiming" and world.attackAoETiles then
            love.graphics.setColor(1, 0.2, 0.2, 0.6) -- Semi-transparent red
            for _, effectData in ipairs(world.attackAoETiles) do
                local s = effectData.shape
                if s.type == "rect" then
                    love.graphics.rectangle("fill", s.x, s.y, s.w, s.h)
                elseif s.type == "line_set" then
                    -- Could render lines here in the future if needed for previews
                end
            end
            love.graphics.setColor(1, 1, 1, 1) -- Reset color
        end

        -- 6. Draw Cycle Targeting UI (previews, etc.)
        if world.playerTurnState == "cycle_targeting" and world.cycleTargeting.active then
            local cycle = world.cycleTargeting
            if #cycle.targets > 0 then
                local target = cycle.targets[cycle.selectedIndex]
                local attacker = world.actionMenu.unit

                if target and attacker then
                    if world.selectedAttackName == "phantom_step" then
                        -- For phantom_step, draw a preview of the teleport destination.
                        -- The cursor itself acts as the highlight on the target.
                        local dx, dy = 0, 0
                        if target.lastDirection == "up" then dy = 1
                        elseif target.lastDirection == "down" then dy = -1
                        elseif target.lastDirection == "left" then dx = 1
                        elseif target.lastDirection == "right" then dx = -1
                        end
                        local behindTileX, behindTileY = target.tileX + dx, target.tileY + dy
                        local behindPixelX, behindPixelY = Grid.toPixels(behindTileX, behindTileY)

                        love.graphics.setColor(1, 0, 1, 0.8) -- Magenta
                        love.graphics.setLineWidth(2)
                        love.graphics.line(attacker.x + attacker.size/2, attacker.y + attacker.size/2, behindPixelX + Config.SQUARE_SIZE/2, behindPixelY + Config.SQUARE_SIZE/2)
                        love.graphics.rectangle("line", behindPixelX, behindPixelY, Config.SQUARE_SIZE, Config.SQUARE_SIZE)
                        love.graphics.setLineWidth(1) -- Reset
                    elseif world.selectedAttackName == "hookshot" then
                        -- Draw a red line preview for hookshot
                        love.graphics.setColor(1, 0.2, 0.2, 0.6) -- Semi-transparent red
                        local dist = math.abs(attacker.tileX - target.tileX) + math.abs(attacker.tileY - target.tileY)

                        if attacker.tileX == target.tileX then -- Vertical line
                            local dirY = (target.tileY > attacker.tileY) and 1 or -1
                            for i = 1, dist do
                                local pixelX, pixelY = Grid.toPixels(attacker.tileX, attacker.tileY + i * dirY)
                                love.graphics.rectangle("fill", pixelX, pixelY, Config.SQUARE_SIZE, Config.SQUARE_SIZE)
                            end
                        elseif attacker.tileY == target.tileY then -- Horizontal line
                            local dirX = (target.tileX > attacker.tileX) and 1 or -1
                            for i = 1, dist do
                                local pixelX, pixelY = Grid.toPixels(attacker.tileX + i * dirX, attacker.tileY)
                                love.graphics.rectangle("fill", pixelX, pixelY, Config.SQUARE_SIZE, Config.SQUARE_SIZE)
                            end
                        end
                        love.graphics.setColor(1, 1, 1, 1) -- Reset color
                    end
                end
            end
        end
    end

    -- Draw Sceptile's Tree and Zone
    if world.flag then
        -- Draw the Tree sprite
        local treeSprite = world.flag.sprite
        if treeSprite then
            love.graphics.setColor(1, 1, 1, 1) -- Reset to white
            local w, h = treeSprite:getDimensions()
            -- Anchor to bottom-center of its tile for consistency with characters
            local drawX = world.flag.x + world.flag.size / 2
            local drawY = world.flag.y + world.flag.size
            love.graphics.draw(treeSprite, drawX, drawY, 0, 1, 1, w / 2, h)
        end
    end

    -- Draw afterimage effects
    for _, a in ipairs(world.afterimageEffects) do
        -- If the afterimage has sprite data, draw it as a solid-color sprite.
        if a.frame and a.spriteSheet and Assets.shaders.solid_color then
            love.graphics.setShader(Assets.shaders.solid_color)

            local alpha = (a.lifetime / a.initialLifetime) * 0.5 -- Max 50% transparent
            -- Send the dominant color and alpha to the shader
            Assets.shaders.solid_color:send("solid_color", {a.color[1], a.color[2], a.color[3], alpha})

            -- Anchor the afterimage to the same position as the original sprite
            local drawX = a.x + a.size / 2
            local drawY = a.y + a.size
            local w, h = a.width, a.height

            -- Draw the specific frame that was captured
            love.graphics.draw(a.spriteSheet, a.frame, drawX, drawY, 0, 1, 1, w / 2, h)

            love.graphics.setShader() -- Reset to default shader
        else
            -- Fallback for non-sprite entities or if shaders are unsupported.
            local alpha = (a.lifetime / a.initialLifetime) * 0.5
            love.graphics.setColor(a.color[1], a.color[2], a.color[3], alpha)
            love.graphics.rectangle("fill", a.x, a.y, a.size, a.size)
        end
    end

    -- Draw all players
    for i, p in ipairs(world.players) do
        -- In the turn-based system, the "active" player is the one currently selected.
        local is_active = (p == world.selectedUnit)
        draw_entity(p, world, is_active)
    end

    -- Draw all enemies
    for _, e in ipairs(world.enemies) do
        draw_entity(e, world, false) -- Enemies are never the active player
    end

    -- Draw active attack effects (flashing tiles)
    for _, effect in ipairs(world.attackEffects) do
        -- Only draw if the initial delay has passed
        if effect.initialDelay <= 0 then
            -- Calculate alpha for flashing effect (e.g., fade out)
            local alpha = effect.currentFlashTimer / effect.flashDuration
            love.graphics.setColor(effect.color[1], effect.color[2], effect.color[3], alpha) -- Use effect's color
            love.graphics.rectangle("fill", effect.x, effect.y, effect.width, effect.height)
        end
    end

    -- Draw projectiles
    for _, projectile in ipairs(world.projectiles) do
        love.graphics.setColor(1, 0.5, 0, 1) -- Orange/red color for projectiles
        love.graphics.rectangle("fill", projectile.x, projectile.y, projectile.size, projectile.size)
    end

    -- Draw particle effects
    for _, p in ipairs(world.particleEffects) do
        -- Fade out the particle as its lifetime decreases
        local alpha = (p.lifetime / p.initialLifetime)
        love.graphics.setColor(p.color[1], p.color[2], p.color[3], alpha)
        love.graphics.rectangle("fill", p.x, p.y, p.size, p.size)
    end

    -- Draw damage popups
    love.graphics.setColor(1, 1, 1, 1) -- Reset color
    for _, p in ipairs(world.damagePopups) do
        local alpha = (p.lifetime / p.initialLifetime)
        love.graphics.setColor(p.color[1], p.color[2], p.color[3], alpha)
        love.graphics.print(p.text, p.x, p.y)
    end

    -- Draw new grappling hooks and their lines
    for _, entity in ipairs(world.all_entities) do
        if entity.type == "grapple_hook" and entity.components.grapple_hook then
            local hookComp = entity.components.grapple_hook
            local attacker = hookComp.attacker

            -- Draw the hook itself
            love.graphics.setColor(entity.color)
            love.graphics.rectangle("fill", entity.x, entity.y, entity.size, entity.size)

            -- Draw the line from the attacker to the hook
            if attacker then
                love.graphics.setColor(0.6, 0.3, 0.1, 1) -- Brown color for the grapple line
                love.graphics.setLineWidth(2)
                local x1, y1 = attacker.x + attacker.size / 2, attacker.y + attacker.size / 2
                local x2, y2 = entity.x + entity.size / 2, entity.y + entity.size / 2
                love.graphics.line(x1, y1, x2, y2)
                love.graphics.setLineWidth(1) -- Reset
            end
        end
    end

    -- Revert the camera transformation to draw screen-space UI
    Camera.revert()

    -- Draw Map Menu
    if world.mapMenu.active then
        local menu = world.mapMenu
        local cursorTile = world.mapCursorTile
        local worldCursorX, worldCursorY = Grid.toPixels(cursorTile.x, cursorTile.y)

        -- Convert world coordinates to screen coordinates for UI positioning
        local screenCursorX = worldCursorX - Camera.x
        local screenCursorY = worldCursorY - Camera.y

        -- Dynamically calculate menu width based on the longest option text
        local maxTextWidth = 0
        if GameFont then
            for _, option in ipairs(menu.options) do
                maxTextWidth = math.max(maxTextWidth, GameFont:getWidth(option.text))
            end
        end

        local menuWidth = maxTextWidth + 20 -- 10px padding on each side
        local menuHeight = #menu.options * 20 + 10
        local menuX = screenCursorX + Config.SQUARE_SIZE + 5 -- Position it to the right of the cursor
        local menuY = screenCursorY

        -- Clamp menu position to stay on screen
        if menuX + menuWidth > Config.VIRTUAL_WIDTH then menuX = screenCursorX - menuWidth - 5 end
        if menuY + menuHeight > Config.VIRTUAL_HEIGHT then menuY = Config.VIRTUAL_HEIGHT - menuHeight end
        menuX = math.max(0, menuX)
        menuY = math.max(0, menuY)

        -- Draw background box
        love.graphics.setColor(0.1, 0.1, 0.2, 0.85)
        love.graphics.rectangle("fill", menuX, menuY, menuWidth, menuHeight)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", menuX, menuY, menuWidth, menuHeight)
        love.graphics.setLineWidth(1)

        -- Draw menu options
        for i, option in ipairs(menu.options) do
            if i == menu.selectedIndex then
                love.graphics.setColor(1, 1, 0, 1) -- Yellow for selected
            else
                love.graphics.setColor(1, 1, 1, 1) -- White for others
            end
            love.graphics.print(option.text, menuX + 10, menuY + 5 + (i - 1) * 20)
        end
        love.graphics.setColor(1, 1, 1, 1) -- Reset color
    end

    -- Draw Action Menu
    if world.actionMenu.active then
        local menu = world.actionMenu
        local unit = menu.unit

        -- Convert world coordinates to screen coordinates for UI positioning
        local screenUnitX = unit.x - Camera.x
        local screenUnitY = unit.y - Camera.y

        -- Dynamically calculate menu width based on the longest option text
        local maxTextWidth = 0
        if GameFont then
            for _, option in ipairs(menu.options) do
                maxTextWidth = math.max(maxTextWidth, GameFont:getWidth(option.text))
            end
        end

        local menuWidth = maxTextWidth + 20 -- 10px padding on each side
        local menuHeight = #menu.options * 20 + 10
        local menuX = screenUnitX + unit.size + 5 -- Position it to the right of the unit
        local menuY = screenUnitY

        -- Clamp menu position to stay on screen
        if menuX + menuWidth > Config.VIRTUAL_WIDTH then menuX = screenUnitX - menuWidth - 5 end
        if menuY + menuHeight > Config.VIRTUAL_HEIGHT then menuY = Config.VIRTUAL_HEIGHT - menuHeight end
        menuX = math.max(0, menuX)
        menuY = math.max(0, menuY)

        -- Draw background box
        love.graphics.setColor(0.1, 0.1, 0.2, 0.85)
        love.graphics.rectangle("fill", menuX, menuY, menuWidth, menuHeight)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", menuX, menuY, menuWidth, menuHeight)
        love.graphics.setLineWidth(1)

        -- Draw menu options
        for i, option in ipairs(menu.options) do
            if i == menu.selectedIndex then
                love.graphics.setColor(1, 1, 0, 1) -- Yellow for selected
            else
                love.graphics.setColor(1, 1, 1, 1) -- White for others
            end
            love.graphics.print(option.text, menuX + 10, menuY + 5 + (i - 1) * 20)
        end
        love.graphics.setColor(1, 1, 1, 1) -- Reset color
    end

    -- Set the custom font for all UI text. If GameFont is nil, it uses the default.
    if GameFont then
        love.graphics.setFont(GameFont)
    end

    -- UI Drawing
    love.graphics.setColor(1, 1, 1, 1) -- Set color back to white for text

    -- Instructions (Top-Left)
    local instructions = {
        "CONTROLS:",
        "WASD: Move Cursor",
        "J: Select / Confirm",
        "K: Cancel / Back",
        "Esc: Party Menu"
    }
    local yPos = 10
    for _, line in ipairs(instructions) do
        love.graphics.print(line, 10, yPos)
        yPos = yPos + 20
    end

    -- Player Stats (Below Instructions)
    local yOffset = yPos -- Start right after instructions
    for i, p in ipairs(world.players) do
        local statsText = string.format("P%d (%s): HP=%d/%d Atk=%d Def=%d X=%d Y=%d", i, p.playerType, p.hp, p.maxHp, p.finalAttackStat or 0, p.finalDefenseStat or 0, p.tileX, p.tileY)
        love.graphics.print(statsText, 10, yOffset)
        yOffset = yOffset + 20
    end

    -- Enemy Stats (Below Player Stats)
    yOffset = yOffset + 10 -- Add some space
    love.graphics.print("Enemies:", 10, yOffset)
    yOffset = yOffset + 20
    for i, e in ipairs(world.enemies) do
        local statsText = string.format("E%d (%s): HP=%d/%d X=%d Y=%d", i, e.enemyType, e.hp, e.maxHp, e.tileX, e.tileY)
        love.graphics.print(statsText, 10, yOffset)
        yOffset = yOffset + 20
    end

    -- Reset color to white for the rest of the UI text
    love.graphics.setColor(1, 1, 1, 1)

    -- Display PAUSED message and party select screen if game is paused
    if world.gameState == "party_select" then
        -- Draw a semi-transparent background overlay
        love.graphics.setColor(0, 0, 0, 0.9)
        love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight())

        love.graphics.setColor(1, 1, 1, 1) -- White color
        love.graphics.printf("PARTY SELECT", 0, 40, love.graphics.getWidth(), "center")

        -- Draw the character grid
        local gridSize = 80
        local gridStartX = love.graphics.getWidth() / 2 - (gridSize * 1.5)
        local gridStartY = love.graphics.getHeight() / 2 - (gridSize * 1.5)

        for y = 1, 3 do
            for x = 1, 3 do
                local playerType = world.characterGrid[y][x]
                if playerType then
                    local squareDisplaySize = gridSize * 0.9
                    local squareX = gridStartX + (x - 1) * gridSize
                    local squareY = gridStartY + (y - 1) * gridSize

                    -- Draw the character's sprite instead of a colored square
                    local entity = world.roster[playerType]
                    if entity and entity.components.animation then
                        local animComponent = entity.components.animation
                        local spriteSheet = animComponent.spriteSheet
                        local downAnimation = animComponent.animations.down

                        local w, h = downAnimation:getDimensions()
                        local scale = squareDisplaySize / w -- Scale to fit the grid cell
                        local drawX = squareX + squareDisplaySize / 2
                        local drawY = squareY + squareDisplaySize / 2

                        love.graphics.setColor(1, 1, 1, 1) -- Reset color to white to avoid tinting
                        downAnimation:draw(spriteSheet, drawX, drawY, 0, scale, scale, w / 2, h / 2)
                    else
                        -- Fallback for characters without sprites
                        love.graphics.setColor(CharacterBlueprints[playerType].dominantColor)
                        love.graphics.rectangle("fill", squareX, squareY, squareDisplaySize, squareDisplaySize)
                    end

                    -- Draw selection highlight
                    if world.selectedSquare and world.selectedSquare.x == x and world.selectedSquare.y == y then
                        love.graphics.setColor(0, 1, 0, 1) -- Green highlight
                        love.graphics.setLineWidth(3)
                        love.graphics.rectangle("line", squareX, squareY, squareDisplaySize, squareDisplaySize)
                        love.graphics.setLineWidth(1)
                    end
                end
            end
        end

        -- Draw the cursor
        love.graphics.setColor(1, 1, 0, 1) -- Venusaur cursor
        love.graphics.setLineWidth(3)
        love.graphics.rectangle("line", gridStartX + (world.cursorPos.x - 1) * gridSize, gridStartY + (world.cursorPos.y - 1) * gridSize, gridSize * 0.9, gridSize * 0.9)
        love.graphics.setLineWidth(1)

        -- Reset color to white after drawing the UI to prevent tinting the whole screen
        love.graphics.setColor(1, 1, 1, 1)
    end
end

return Renderer