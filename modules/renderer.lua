-- renderer.lua
-- Contains all drawing logic for the game.

local Grid = require("modules.grid")
local Camera = require("modules.camera")
local Assets = require("modules.assets")
local CharacterBlueprints = require("data.character_blueprints")
local AttackBlueprints = require("data.attack_blueprints")
local WorldQueries = require("modules.world_queries")
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

-- Calculates the final Y position and rotation for an entity, accounting for airborne and bobbing effects.
-- Also draws the shadow for airborne units.
local function calculate_visual_offsets(entity, currentAnim, drawX, baseDrawY)
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
    return finalDrawY, rotation
end

-- Draws shader-based overlays for status effects like poison, paralysis, and stun.
local function draw_status_overlays(entity, currentAnim, spriteSheet, w, h, drawX, finalDrawY, rotation)
    if not Assets.shaders.solid_color then return end

    -- If poisoned, draw a semi-transparent pulsating overlay on top.
    if entity.statusEffects.poison then
        love.graphics.setShader(Assets.shaders.solid_color)
        local pulse = (math.sin(love.timer.getTime() * 8) + 1) / 2
        local alpha = 0.2 + pulse * 0.3
        Assets.shaders.solid_color:send("solid_color", {0.6, 0.2, 0.8, alpha})
        currentAnim:draw(spriteSheet, drawX, finalDrawY, rotation, 1, 1, w / 2, h)
    end

    -- If paralyzed, draw a semi-transparent pulsating overlay on top.
    if entity.statusEffects.paralyzed then
        love.graphics.setShader(Assets.shaders.solid_color)
        local pulse = (math.sin(love.timer.getTime() * 6) + 1) / 2
        local alpha = 0.1 + pulse * 0.3
        Assets.shaders.solid_color:send("solid_color", {1.0, 1.0, 0.2, alpha})
        currentAnim:draw(spriteSheet, drawX, finalDrawY, rotation, 1, 1, w / 2, h)
    end

    -- If stunned, draw a static purple overlay.
    if entity.statusEffects.stunned then
        love.graphics.setShader(Assets.shaders.solid_color)
        Assets.shaders.solid_color:send("solid_color", {0.5, 0, 0.5, 0.5})
        currentAnim:draw(spriteSheet, drawX, finalDrawY, rotation, 1, 1, w / 2, h)
    end
end

-- Draws shader-based overlays for game states, like "has acted" or "is selected".
local function draw_state_overlays(entity, is_active_player, currentAnim, spriteSheet, w, h, drawX, finalDrawY, rotation)
    -- If the unit has acted, draw a greyscale version on top of everything else.
    if entity.hasActed and Assets.shaders.greyscale then
        love.graphics.setShader(Assets.shaders.greyscale)
        Assets.shaders.greyscale:send("strength", 1.0)
        currentAnim:draw(spriteSheet, drawX, finalDrawY, rotation, 1, 1, w / 2, h)
    end

    -- If this is the active player, draw the outline on top as an overlay.
    if is_active_player and Assets.shaders.outline then
        love.graphics.setShader(Assets.shaders.outline)
        Assets.shaders.outline:send("outline_color", {1.0, 1.0, 1.0, 1.0})
        Assets.shaders.outline:send("texture_size", {spriteSheet:getWidth(), spriteSheet:getHeight()})
        Assets.shaders.outline:send("outline_only", true)
        currentAnim:draw(spriteSheet, drawX, finalDrawY, rotation, 1, 1, w / 2, h)
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

    if entity.components.animation then
        -- 1. Get animation data
        local animComponent = entity.components.animation
        local currentAnim = animComponent.animations[animComponent.current]
        local spriteSheet = animComponent.spriteSheet
        local w, h = currentAnim:getDimensions()

        -- 2. Calculate drawing position and offsets
        local drawX = entity.x + entity.size / 2
        local baseDrawY = entity.y + entity.size
        local finalDrawY, rotation = calculate_visual_offsets(entity, currentAnim, drawX, baseDrawY)

        -- 3. Draw the base sprite
        love.graphics.setShader()
        love.graphics.setColor(1, 1, 1, 1)
        currentAnim:draw(spriteSheet, drawX, finalDrawY, rotation, 1, 1, w / 2, h)

        -- 4. Draw overlays for status effects (poison, paralysis, etc.)
        draw_status_overlays(entity, currentAnim, spriteSheet, w, h, drawX, finalDrawY, rotation)

        -- 5. Draw overlays for game state (acted, selected)
        draw_state_overlays(entity, is_active_player, currentAnim, spriteSheet, w, h, drawX, finalDrawY, rotation)

        -- 6. Reset shader state
        love.graphics.setShader()
    end

    -- 7. Draw the health bar on top of everything
    drawHealthBar(entity)

    love.graphics.pop()
end

local function draw_all_entities_and_effects(world)
    -- Draw Sceptile's Flag and Zone
    if world.flag then
        -- Draw the flag sprite
        local flagSprite = world.flag.sprite
        if flagSprite then
            love.graphics.setColor(1, 1, 1, 1) -- Reset to white
            local w, h = flagSprite:getDimensions()
            -- Anchor to bottom-center of its tile for consistency with characters
            local drawX = world.flag.x + world.flag.size / 2
            local drawY = world.flag.y + world.flag.size
            love.graphics.draw(flagSprite, drawX, drawY, 0, 1, 1, w / 2, h)
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

    -- Create a single list of all units to be drawn.
    local drawOrder = {}
    for _, p in ipairs(world.players) do
        table.insert(drawOrder, p)
    end
    for _, e in ipairs(world.enemies) do
        table.insert(drawOrder, e)
    end

    -- Sort the list by Y-coordinate. Entities lower on the screen (higher y) are drawn later (on top).
    table.sort(drawOrder, function(a, b)
        return a.y < b.y
    end)

    -- Draw all units in the correct Z-order.
    for _, entity in ipairs(drawOrder) do
        local is_active = (entity.type == "player" and entity == world.selectedUnit)
        draw_entity(entity, world, is_active)
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
end

local function draw_world_space_ui(world)
    -- Draw Turn-Based UI Elements (Ranges, Path, Cursor)
    local BORDER_WIDTH = 1
    local INSET_SIZE = Config.SQUARE_SIZE - (BORDER_WIDTH * 2)

    if world.gameState == "gameplay" and world.turn == "player" then
        -- 1. Draw the full attack range for the selected unit (the "danger zone").
        -- This is drawn first so that the blue movement range tiles can draw over it.
        if world.playerTurnState == "unit_selected" and world.attackableTiles then
            love.graphics.setColor(1, 0.2, 0.2, 0.3) -- Faint, transparent red
            for posKey, _ in pairs(world.attackableTiles) do
                local tileX = tonumber(string.match(posKey, "(-?%d+)"))
                local tileY = tonumber(string.match(posKey, ",(-?%d+)"))
                if tileX and tileY then
                    local pixelX, pixelY = Grid.toPixels(tileX, tileY)
                    love.graphics.rectangle("fill", pixelX + BORDER_WIDTH, pixelY + BORDER_WIDTH, INSET_SIZE, INSET_SIZE)
                end
            end
        end

        -- 2. Draw the movement range for the selected unit. This is drawn on top of the attack range.
        if world.playerTurnState == "unit_selected" and world.reachableTiles then
            love.graphics.setColor(0.2, 0.4, 1, 0.6) -- Semi-transparent blue
            for posKey, _ in pairs(world.reachableTiles) do
                local tileX = tonumber(string.match(posKey, "(-?%d+)"))
                local tileY = tonumber(string.match(posKey, ",(-?%d+)"))
                if tileX and tileY then
                    local pixelX, pixelY = Grid.toPixels(tileX, tileY)
                    love.graphics.rectangle("fill", pixelX + BORDER_WIDTH, pixelY + BORDER_WIDTH, INSET_SIZE, INSET_SIZE)
                end
            end
        end

        -- 3. Draw the movement path arrow.
        if world.playerTurnState == "unit_selected" and world.movementPath and #world.movementPath > 0 then
            love.graphics.setColor(1, 1, 0, 0.8) -- Bright yellow
            love.graphics.setLineWidth(3)
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
                love.graphics.rectangle("fill", pixelX + BORDER_WIDTH, pixelY + BORDER_WIDTH, INSET_SIZE, INSET_SIZE)
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
                        -- For phantom_step, shade the target red and the warp destination blue.
                        local dx, dy = 0, 0
                        if target.lastDirection == "up" then dy = 1
                        elseif target.lastDirection == "down" then dy = -1
                        elseif target.lastDirection == "left" then dx = 1
                        elseif target.lastDirection == "right" then dx = -1
                        end
                        -- Shade the target tile red.
                        love.graphics.setColor(1, 0.2, 0.2, 0.3) -- Semi-transparent red
                        love.graphics.rectangle("fill", target.x + BORDER_WIDTH, target.y + BORDER_WIDTH, INSET_SIZE, INSET_SIZE)

                        local behindTileX, behindTileY = target.tileX + dx, target.tileY + dy
                        local behindPixelX, behindPixelY = Grid.toPixels(behindTileX, behindTileY)

                        -- Shade the destination tile blue.
                        love.graphics.setColor(0.2, 0.4, 1, 0.3) -- Semi-transparent blue
                        love.graphics.rectangle("fill", behindPixelX + BORDER_WIDTH, behindPixelY + BORDER_WIDTH, INSET_SIZE, INSET_SIZE)
                    elseif world.selectedAttackName == "hookshot" then

                        -- Draw a red line preview for hookshot
                        love.graphics.setColor(1, 0.2, 0.2, 0.3) -- Semi-transparent red
                        local dist = math.abs(attacker.tileX - target.tileX) + math.abs(attacker.tileY - target.tileY)

                        if attacker.tileX == target.tileX then -- Vertical line
                            local dirY = (target.tileY > attacker.tileY) and 1 or -1
                            for i = 1, dist do
                                local pixelX, pixelY = Grid.toPixels(attacker.tileX, attacker.tileY + i * dirY)
                                love.graphics.rectangle("fill", pixelX + BORDER_WIDTH, pixelY + BORDER_WIDTH, INSET_SIZE, INSET_SIZE)
                            end
                        elseif attacker.tileY == target.tileY then -- Horizontal line
                            local dirX = (target.tileX > attacker.tileX) and 1 or -1
                            for i = 1, dist do
                                local pixelX, pixelY = Grid.toPixels(attacker.tileX + i * dirX, attacker.tileY)
                                love.graphics.rectangle("fill", pixelX + BORDER_WIDTH, pixelY + BORDER_WIDTH, INSET_SIZE, INSET_SIZE)
                            end
                        end
                    end
                end
            end
        end
    end
end

local function draw_party_select_ui(world)
    -- Draw a semi-transparent background overlay to dim the game world
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.rectangle("fill", 0, 0, Config.VIRTUAL_WIDTH, Config.VIRTUAL_HEIGHT)

    -- Define grid properties
    local gridCols, gridRows = 3, 3
    local boxSize = 80
    local spacing = 10
    local totalWidth = gridCols * boxSize + (gridCols - 1) * spacing
    local totalHeight = gridRows * boxSize + (gridRows - 1) * spacing
    local startX = (Config.VIRTUAL_WIDTH - totalWidth) / 2
    local startY = (Config.VIRTUAL_HEIGHT - totalHeight) / 2

    -- A local mapping from player type to asset name, mirroring entities.lua
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

    -- Draw the grid boxes and character sprites
    for y = 1, gridRows do
        for x = 1, gridCols do
            local charType = world.characterGrid[y] and world.characterGrid[y][x]
            local boxX = startX + (x - 1) * (boxSize + spacing)
            local boxY = startY + (y - 1) * (boxSize + spacing)

            -- Draw the box background
            love.graphics.setColor(0.1, 0.1, 0.2, 0.8)
            love.graphics.rectangle("fill", boxX, boxY, boxSize, boxSize)

            -- Draw the character sprite if one exists in this slot
            if charType then
                local entity = world.roster[charType] -- Get the entity from the roster to check HP
                local spriteName = playerSpriteMap[charType]
                local spriteSheet = spriteName and Assets.images[spriteName]
                local anim = spriteName and Assets.animations[spriteName].down -- Use 'down' as the default portrait

                if entity and spriteSheet and anim then
                    -- If the character is dead, draw them greyed out
                    if entity.hp <= 0 then
                        love.graphics.setColor(0.5, 0.5, 0.5, 1)
                    else
                        love.graphics.setColor(1, 1, 1, 1)
                    end
                    -- Draw the CURRENT frame of the animation, which is updated in main.lua.
                    local w, h = anim:getDimensions()
                    local scale = (boxSize - 10) / math.max(w, h) -- Scale to fit inside the box
                    -- Use the animation's own draw method to handle animated frames correctly.
                    anim:draw(spriteSheet, boxX + boxSize / 2, boxY + boxSize / 2, 0, scale, scale, w / 2, h / 2)
                end
            end

            -- Draw selection highlight if a square is selected
            if world.selectedSquare and world.selectedSquare.x == x and world.selectedSquare.y == y then
                love.graphics.setColor(1, 1, 0, 1) -- Yellow for selected
                love.graphics.setLineWidth(3)
                love.graphics.rectangle("line", boxX, boxY, boxSize, boxSize)
            else
                -- Draw standard box outline
                love.graphics.setColor(0.8, 0.8, 0.9, 1)
                love.graphics.setLineWidth(2)
                love.graphics.rectangle("line", boxX, boxY, boxSize, boxSize)
            end

            -- Draw cursor on top
            if world.cursorPos.x == x and world.cursorPos.y == y then
                local alpha = 0.6 + (math.sin(love.timer.getTime() * 5) + 1) / 2 * 0.4
                love.graphics.setColor(1, 1, 1, alpha)
                love.graphics.setLineWidth(3)
                love.graphics.rectangle("line", boxX - 2, boxY - 2, boxSize + 4, boxSize + 4)
            end
        end
    end
end

-- Draws debug and status information that is not part of a specific menu.
-- This restores the info text that was present in the old renderer.
local function draw_debug_info(world)
    love.graphics.setColor(1, 1, 1, 1) -- Reset color to white for text

    -- Instructions (Top-Left, below the action menu)
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
end

local function draw_screen_space_ui(world)
    -- Draw Action Menu
    if world.actionMenu.active then
        local menu = world.actionMenu
        local unit = menu.unit
        if not unit then return end -- Can't draw without a unit

        -- Convert world coordinates to screen coordinates for UI positioning
        local screenUnitX = unit.x - Camera.x
        local screenUnitY = unit.y - Camera.y
        local font = love.graphics.getFont()

        -- Dynamically calculate menu width based on the longest option text
        local maxTextWidth = font:getWidth("Actions") -- Start with title width
        for _, option in ipairs(menu.options) do
            maxTextWidth = math.max(maxTextWidth, font:getWidth(option.text))
        end
        local menuWidth = maxTextWidth + 20 -- 10px padding on each side
        local menuHeight = 25 + #menu.options * 20
        local menuX = screenUnitX + unit.size + 5 -- Position it to the right of the unit
        local menuY = screenUnitY

        -- Clamp menu position to stay on screen
        if menuX + menuWidth > Config.VIRTUAL_WIDTH then menuX = screenUnitX - menuWidth - 5 end
        if menuY + menuHeight > Config.VIRTUAL_HEIGHT then menuY = Config.VIRTUAL_HEIGHT - menuHeight end
        menuX = math.max(0, menuX)
        menuY = math.max(0, menuY)

        -- Draw menu background
        love.graphics.setColor(0.1, 0.1, 0.2, 0.8)
        love.graphics.rectangle("fill", menuX, menuY, menuWidth, menuHeight)
        love.graphics.setColor(0.8, 0.8, 0.9, 1)
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", menuX, menuY, menuWidth, menuHeight)
        love.graphics.setLineWidth(1)

        -- Draw menu title
        love.graphics.printf("Actions", menuX, menuY + 5, menuWidth, "center")

        -- Draw menu options
        for i, option in ipairs(menu.options) do
            local yPos = menuY + 25 + (i - 1) * 20
            local attackData = AttackBlueprints[option.key]

            -- Check if an attack option is invalid (has no valid targets)
            local is_valid = true
            if attackData and attackData.targeting_style == "cycle_target" then
                local validTargets = WorldQueries.findValidTargetsForAttack(menu.unit, option.key, world)
                if #validTargets == 0 then
                    is_valid = false
                end
            end

            if i == menu.selectedIndex then
                love.graphics.setColor(1, 1, 0, 1) -- Yellow for selected
            elseif not is_valid then
                love.graphics.setColor(0.5, 0.5, 0.5, 1) -- Grey for invalid
            else
                love.graphics.setColor(1, 1, 1, 1) -- White for others
            end
            love.graphics.print(option.text, menuX + 10, yPos)
        end
    end

    -- Draw Map Menu
    if world.mapMenu.active then
        local menu = world.mapMenu
        local cursorTile = world.mapCursorTile
        local worldCursorX, worldCursorY = Grid.toPixels(cursorTile.x, cursorTile.y)
        local font = love.graphics.getFont()

        -- Convert world coordinates to screen coordinates for UI positioning
        local screenCursorX = worldCursorX - Camera.x
        local screenCursorY = worldCursorY - Camera.y

        -- Dynamically calculate menu width based on the longest option text
        local maxTextWidth = 0
        for _, option in ipairs(menu.options) do
            maxTextWidth = math.max(maxTextWidth, font:getWidth(option.text))
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

        -- Draw menu background
        love.graphics.setColor(0.1, 0.1, 0.2, 0.8)
        love.graphics.rectangle("fill", menuX, menuY, menuWidth, menuHeight)
        love.graphics.setColor(0.8, 0.8, 0.9, 1)
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", menuX, menuY, menuWidth, menuHeight)
        love.graphics.setLineWidth(1)

        -- Draw menu options
        for i, option in ipairs(menu.options) do
            local yPos = menuY + 5 + (i - 1) * 20
            if i == menu.selectedIndex then
                love.graphics.setColor(1, 1, 0, 1) -- Yellow for selected
            else
                love.graphics.setColor(1, 1, 1, 1) -- White for others
            end
            love.graphics.print(option.text, menuX + 10, yPos)
        end
    end
end

--------------------------------------------------------------------------------
-- MAIN DRAW FUNCTION
--------------------------------------------------------------------------------

function Renderer.draw(world)
    -- 1. Clear the screen with a background color
    love.graphics.clear(0.1, 0.1, 0.1, 1)

    -- 2. Apply camera for world-space drawing
    Camera.apply()
    -- Draw UI elements like range indicators first, so they appear under units.
    draw_world_space_ui(world)
    draw_all_entities_and_effects(world)
    Camera.revert()

    -- 3. Draw screen-space UI based on the current game state
    if world.gameState == "gameplay" then
        draw_screen_space_ui(world)
        draw_debug_info(world)
    elseif world.gameState == "party_select" then
        draw_party_select_ui(world)
    end

    -- 4. Reset graphics state to be safe
    love.graphics.setColor(1, 1, 1, 1)
end

return Renderer