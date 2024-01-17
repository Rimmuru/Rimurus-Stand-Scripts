local snakeGame = {}
snakeGame.__index = snakeGame

require("natives-1627063482")

local function drawText(text, pos, size, scale, colour, flags, font)
    -- Transform position from -1 to 1 range to 0.0 to 1.0 range
    local transformedPosX = (pos.x + 1) / 2
    local transformedPosY = (pos.y + 1) / 2

    return directx.draw_text(transformedPosX, transformedPosY, text, flags, scale, colour, false, font)
end

--void directx.draw_rect(number x, number y, number width, number height, Colour colour)
local function drawRect(pos, size, colour)
    -- Transform position from -1 to 1 range to 0.0 to 1.0 range
    local transformedPosX = (pos.x + 1) / 2
    local transformedPosY = (pos.y + 1) / 2

    -- Transform size as well, considering the coordinate system change
    local transformedSizeX = size.x / 2
    local transformedSizeY = size.y / 2

    return directx.draw_rect(transformedPosX, transformedPosY, transformedSizeX, transformedSizeY, colour)
end

local function v2(x, y)
    return {x = x, y = y}
end

local create_thread = util.create_thread
local draw_rect = drawRect
local draw_text = drawText

function snakeGame.new(x, y, width, height)
    local self = setmetatable({}, snakeGame)
    self.x = x
    self.y = y
    self.width = width
    self.height = height
    return self
end

function snakeGame:getPosition()
    return self.x, self.y
end

function snakeGame:getSize()
    return self.width, self.height
end

function snakeGame:setPosition(x, y)
    self.x = x
    self.y = y
end

function snakeGame:setSize(width, height)
    self.width = width
    self.height = height
end

local function randomPosition(objectSize)
    local min = -1 + objectSize / 2
    local max = 1 - objectSize / 2
    return math.random() * (max - min) + min, math.random() * (max - min) + min
end

-- Initialisers
local halfWidth, halfHeight = 0.25 / 2, 0.25 / 2
local snakeChar = snakeGame.new(-halfWidth, -halfHeight, 0.07, 0.1)
local foodSize, foodX, foodY = 0.1, randomPosition(0.1)
local snakeFood = snakeGame.new(foodX, foodY, foodSize - 0.03, foodSize)

snakeGame.snakeColour = {r = 0.435, g = 0.858, b = 0.286, a = 1.0}
snakeGame.snakeLength = 1
snakeGame.direction = 'right'  
snakeGame.snakeParts = {snakeChar}
snakeGame.foodColour = {r = 1.0, g = 0.0, b = 0.0, a = 1.0}
snakeGame.gameScore = 0
snakeGame.gameStarted = false
snakeGame.bestScore = 99999
snakeGame.gameTimer = 0

function snakeGame.hasGameStarted()
    return snakeGame.gameStarted
end

function snakeGame.growSnake(gapSize)
    local lastPart = snakeGame.snakeParts[#snakeGame.snakeParts]
    local newPartX, newPartY = lastPart.x, lastPart.y
    gapSize = gapSize or 0.02  -- Adjust this value for testing

    -- Calculate the total move amount including the size of the part and the gap
    local moveX = lastPart.width + gapSize
    local moveY = lastPart.height + gapSize

    if snakeGame.direction == 'up' then
        newPartY = newPartY - moveY
    elseif snakeGame.direction == 'down' then
        newPartY = newPartY + moveY
    elseif snakeGame.direction == 'left' then
        newPartX = newPartX - moveX
    elseif snakeGame.direction == 'right' then
        newPartX = newPartX + moveX
    end

    local newPart = snakeGame.new(newPartX, newPartY, lastPart.width, lastPart.height)
    table.insert(snakeGame.snakeParts, newPart)
end


local function isSnakeNearFood(snake, food, range)
    range = range or 0.11
    local snakeX, snakeY = snake:getPosition()
    local foodX, foodY = food:getPosition()

    local distance = math.sqrt((foodX - snakeX)^2 + (foodY - snakeY)^2)

    return distance <= range
end

local directionMappings = {
    [187] = {dy = 0.1, direction = "up"},
    [188] = {dy = -0.1, direction = "down"},
    [190] = {dx = 0.1, direction = "right"},
    [189] = {dx = -0.1, direction = "left"}
}

function snakeGame.updateSnakePosition()
    -- Update direction based on player input
    for control, mapping in pairs(directionMappings) do
        if PAD.IS_CONTROL_PRESSED(2, control) then
            snakeGame.direction = mapping.direction
            break
        end
    end

    -- Move the head in the current direction
    local head = snakeGame.snakeParts[1]
    local x, y = head:getPosition()
    local movementSpeed = 0.006

    -- Check for boundaries
    local minX, maxX = -1 + head.width / 2, 1 - head.width / 2
    local minY, maxY = -1 + head.height / 2, 1 - head.height / 2

    if snakeGame.direction == 'up' and y < maxY then
        y = y + movementSpeed
    elseif snakeGame.direction == 'down' and y > minY then
        y = y - movementSpeed
    elseif snakeGame.direction == 'left' and x > minX then
        x = x - movementSpeed
    elseif snakeGame.direction == 'right' and x < maxX then
        x = x + movementSpeed
    end

    -- Update the position only if within boundaries
    if x >= minX and x <= maxX and y >= minY and y <= maxY then
        head:setPosition(x, y)

        -- Move the other parts
        for i = #snakeGame.snakeParts, 2, -1 do
            local part = snakeGame.snakeParts[i]
            local prevPart = snakeGame.snakeParts[i - 1]
            part:setPosition(prevPart.x, prevPart.y)
        end
    end

    local newPositionValid = true
    for i = 2, #snakeGame.snakeParts do
        local part = snakeGame.snakeParts[i]
        if x == part.x and y == part.y then
            newPositionValid = false
            break
        end
    end

    -- Only update position if it's valid and within boundaries
    if newPositionValid and x >= minX and x <= maxX and y >= minY and y <= maxY then
        head:setPosition(x, y)

        -- Move the other parts
        for i = #snakeGame.snakeParts, 2, -1 do
            local part = snakeGame.snakeParts[i]
            local prevPart = snakeGame.snakeParts[i - 1]
            part:setPosition(prevPart.x, prevPart.y)
        end
    end
end

function snakeGame.updateUI()
    if PAD.IS_CONTROL_PRESSED(2, 288) and not snakeGame.hasGameStarted() then
        snakeGame.gameStarted = true
    end
end

local whiteTextColour = {r = 1.0, g = 1.0, b = 1.0, a = 1.0}

function snakeGame.gameUI()
    draw_text("Score: "..snakeGame.gameScore, v2(-0.65, -0.8), v2(0.2, 0.2), 0.8, whiteTextColour, ALIGN_TOP_CENTRE) 

    draw_text("Best Score: "..snakeGame.bestScore, v2(-0.65, -0.9), v2(0.2, 0.2), 0.8, whiteTextColour, ALIGN_TOP_CENTRE) 

    local elapsedTime = math.floor(snakeGame.gameTimer)
    local minutes = math.floor(elapsedTime / 60)
    local seconds = elapsedTime % 60
    local timeDisplay = (minutes > 0) and string.format("%d:%02d", minutes, seconds) or string.format("%d", seconds)

    draw_text("Timer: "..timeDisplay, v2(0.65, -0.9), v2(0.2, 0.2), 0.8, whiteTextColour, ALIGN_TOP_CENTRE)
end

function snakeGame.helpTextUI()
    draw_text("Snake By Rimuru", v2(-0.25, 0.7), v2(1, 1), 1.7, whiteTextColour, ALIGN_CENTRE) 
    draw_text("Press F1 to start.", v2(-0.25, 0.45), v2(1, 1), 1.7, whiteTextColour, ALIGN_CENTRE) 
    draw_text("Use the arrow keys to play.", v2(-0.25, 0.3), v2(1, 1), 1.7, whiteTextColour, ALIGN_CENTRE) 
end

function snakeGame.gameEnded()
    snakeGame.gameStarted = false
end

-- Game Loop
local currentTime = os.time()
create_thread(function()
    while true do
        if snakeGame.hasGameStarted() then
            snakeGame.snakeLength = #snakeGame.snakeParts -- Keep track of length for UI
            
            -- Draw foodie
            local foodX, foodY = snakeFood:getPosition()
            local foodW, foodH = snakeFood:getSize()
            draw_rect(v2(foodX, foodY), v2(foodW, foodH), snakeGame.foodColour)
            
            -- Draw each part of the snake
            for _, part in ipairs(snakeGame.snakeParts) do
                local x, y = part:getPosition()
                local w, h = part:getSize()
                draw_rect(v2(x, y), v2(w, h), snakeGame.snakeColour)
            end
            
            if isSnakeNearFood(snakeGame.snakeParts[1], snakeFood, range) then
                local newFoodX, newFoodY = randomPosition(foodSize)
                snakeFood:setPosition(newFoodX, newFoodY)

                snakeGame.growSnake()
                snakeGame.gameScore = snakeGame.gameScore + 1
            end        
            
            snakeGame.gameUI()
            snakeGame.updateSnakePosition()  -- Update the position of the snake
            
            snakeGame.gameTimer = os.difftime(os.time(), currentTime)
        else
            snakeGame.helpTextUI()
            snakeGame.updateUI()
        end
        coroutine.yield()
    end
end)