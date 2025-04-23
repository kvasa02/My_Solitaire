-- Main.lua
-- Klondike Solitaire in LÖVE 2D

io.stdout:setvbuf("no")

-- Import modules
local Card = require("card")
local Vector = require("vector")
local Grabber = require("grabber")

-- Game class
local Game = {}
Game.__index = Game

function Game:new()
    local game = {}
    setmetatable(game, Game)
    
    game.deck = {}        -- Full deck before distribution
    game.stock = {}       -- Cards available to draw from (face down)
    game.waste = {}       -- Cards turned over from stock (face up)
    game.foundation = {{}, {}, {}, {}}  -- The 4 foundation piles (by suit)
    game.tableau = {{}, {}, {}, {}, {}, {}, {}}  -- The 7 tableau columns
    game.cardWidth = 71
    game.cardHeight = 96
    game.cardImages = {}
    game.cardBacks = {}
    game.defaultCardBack = nil
    
    return game
end

function Game:loadCardAssets()
    -- Initialize tables for individual card images
    self.cardImages = {}
    
    -- Load the cards from assets 
    for _, suit in ipairs(Card.SUITS) do
        self.cardImages[suit] = {}
        for _, rank in ipairs(Card.RANKS) do
            local filename = "assets/card_" .. suit .. "_" .. rank .. ".png"
            self.cardImages[suit][rank] = love.graphics.newImage(filename)
            print("Loaded card: " .. filename)
        end
    end
    
    -- All card back images are the same
    self.cardBacks = {
        red = love.graphics.newImage("assets/card_back.png"),
        green = love.graphics.newImage("assets/card_back.png"),
        blue = love.graphics.newImage("assets/card_back.png"),
        purple = love.graphics.newImage("assets/card_back.png")
    }
    
    -- Set the default card back color
    self.defaultCardBack = self.cardBacks.red
    
    local sampleCard = self.cardImages["clubs"]["ace"]
    self.cardWidth = sampleCard:getWidth()
    self.cardHeight = sampleCard:getHeight()
    
    print("Card dimensions: " .. self.cardWidth .. "x" .. self.cardHeight)
end

function Game:createDeck()
    -- Create a full deck of cards
    self.deck = {}
    
    for _, suit in ipairs(Card.SUITS) do
        for _, rank in ipairs(Card.RANKS) do
            table.insert(self.deck, Card:new(suit, rank))
        end
    end
    
    print("Created deck with " .. #self.deck .. " cards")
end

function Game:shuffleDeck()
    -- Fisher-Yates shuffle algorithm
    for i = #self.deck, 2, -1 do
        local j = math.random(i)
        self.deck[i], self.deck[j] = self.deck[j], self.deck[i]
    end
    print("Shuffled the deck")
end

function Game:dealCards()
    -- Deal cards to tableau (7 columns)
    self.tableau = {{}, {}, {}, {}, {}, {}, {}}
    
    for col=1, 7 do
        for row=1, col do
            if #self.deck > 0 then
                local card = table.remove(self.deck)
                -- Only the top card in each column starts face up
                card.faceUp = (row == col)
                table.insert(self.tableau[col], card)
            end
        end
    end
    
    -- Remaining cards form the stock pile
    self.stock = self.deck
    self.deck = {}
    self.waste = {}
    self.foundation = {{}, {}, {}, {}}
    
    print("Dealt cards to tableau. Stock has " .. #self.stock .. " cards")
end

function Game:updateCardPositions()
    -- Update positions of all cards for drawing
    
    -- Position cards in the tableau columns
    local tableauStartX = 50
    local tableauStartY = 150
    local colSpacing = 100  -- Horizontal spacing between columns
    local rowSpacing = 25   -- Vertical spacing for overlapping cards
    
    for col=1, 7 do
        for row=1, #self.tableau[col] do
            local card = self.tableau[col][row]
            card.x = tableauStartX + (col-1) * colSpacing
            card.y = tableauStartY + (row-1) * rowSpacing
        end
    end
    
    -- Position cards in the stock pile (all cards in same position)
    local stockX = 50
    local stockY = 50
    for i, card in ipairs(self.stock) do
        card.x = stockX
        card.y = stockY
    end
    
    -- Position cards in the waste pile with more clear offset for 3-card draw
    local wasteX = 140
    local wasteY = 50
    
    -- Only show up to 3 waste cards with a clearer offset
    local visibleCount = math.min(3, #self.waste)
    local startIndex = #self.waste - visibleCount + 1
    
    for i = startIndex, #self.waste do
        local card = self.waste[i]
        local offset = (i - startIndex) * 20  -- Offset each visible waste card by 20px
        card.x = wasteX + offset
        card.y = wasteY
        card.faceUp = true -- Make sure waste cards are face up
    end
    
    -- Position cards in foundation piles
    local foundationStartX = 320
    local foundationY = 50
    for pile=1, 4 do
        for i, card in ipairs(self.foundation[pile]) do
            card.x = foundationStartX + (pile-1) * colSpacing
            card.y = foundationY
            card.faceUp = true -- Foundation cards are always face up
        end
    end
end

function Game:checkForWin()
    -- Check if all cards are in foundation piles
    local totalFoundationCards = 0
    for i=1, 4 do
        totalFoundationCards = totalFoundationCards + #self.foundation[i]
    end
    
    return totalFoundationCards == 52
end

function Game:draw()
    -- Draw placeholders for empty spaces
    love.graphics.setColor(0.1, 0.4, 0.1)
    
    -- Draw tableau placeholders
    for col=1, 7 do
        love.graphics.rectangle("line", 50 + (col-1) * 100, 150, self.cardWidth, self.cardHeight)
    end
    
    -- Draw stock placeholder
    love.graphics.rectangle("line", 50, 50, self.cardWidth, self.cardHeight)
    
    -- Draw waste placeholder
    love.graphics.rectangle("line", 140, 50, self.cardWidth, self.cardHeight)
    
    -- Draw foundation placeholders
    for pile=1, 4 do
        love.graphics.rectangle("line", 320 + (pile-1) * 100, 50, self.cardWidth, self.cardHeight)
    end
    
    -- Draw text labels
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("Stock", 50, 30)
    love.graphics.print("Waste", 140, 30)
    love.graphics.print("Foundation", 320, 30)
    love.graphics.print("Tableau", 50, 130)
    
    -- Draw cards in tableau
    for col=1, 7 do
        for row=1, #self.tableau[col] do
            -- Skip cards that are being dragged
            local isDragging = false
            for _, dragCard in ipairs(self.grabber.draggingCards) do
                if dragCard == self.tableau[col][row] then
                    isDragging = true
                    break
                end
            end
            
            if not isDragging then
                self.tableau[col][row]:draw(self.cardImages, self.defaultCardBack)
            end
        end
    end
    
    -- Draw stock pile (just the top card)
    if #self.stock > 0 then
        self.stock[#self.stock]:draw(self.cardImages, self.defaultCardBack)
    end
    
    -- Draw waste pile (showing up to 3 cards)
    if #self.waste > 0 then
        -- Calculate how many cards to display (up to 3)
        local visibleCount = math.min(3, #self.waste)
        local startIndex = #self.waste - visibleCount + 1
        
        for i = startIndex, #self.waste do
            local card = self.waste[i]
            -- Skip card if it's being dragged
            local isDragging = false
            for _, dragCard in ipairs(self.grabber.draggingCards) do
                if dragCard == card then
                    isDragging = true
                    break
                end
            end
            
            if not isDragging then
                card:draw(self.cardImages, self.defaultCardBack)
            end
        end
    end
    
    -- Draw foundation piles (just the top card)
    for pile=1, 4 do
        if #self.foundation[pile] > 0 then
            local topCard = self.foundation[pile][#self.foundation[pile]]
            
            -- Skip card if it's being dragged
            local isDragging = false
            for _, dragCard in ipairs(self.grabber.draggingCards) do
                if dragCard == topCard then
                    isDragging = true
                    break
                end
            end
            
            if not isDragging then
                topCard:draw(self.cardImages, self.defaultCardBack)
            end
        end
    end
    
    -- Draw dragging cards
    self.grabber:drawDraggingCards()
    
    -- Debug: Print card distribution info
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("Stock: " .. #self.stock .. " cards", 50, 600)
    love.graphics.print("Waste: " .. #self.waste .. " cards", 200, 600)
    
    local totalTableauCards = 0
    for i=1, 7 do
        totalTableauCards = totalTableauCards + #self.tableau[i]
    end
    love.graphics.print("Tableau: " .. totalTableauCards .. " cards", 350, 600)
    
    local totalFoundationCards = 0
    for i=1, 4 do
        totalFoundationCards = totalFoundationCards + #self.foundation[i]
    end
    love.graphics.print("Foundation: " .. totalFoundationCards .. " cards", 500, 600)
end

-- Global game instance
local game = Game:new()

function love.load()
    -- Set random seed for shuffling
    math.randomseed(os.time())
    
    -- Window setup
    screenWidth = 800
    screenHeight = 640
    love.window.setMode(screenWidth, screenHeight)
    love.window.setTitle("Klondike Solitaire")
    love.graphics.setBackgroundColor(0.2, 0.7, 0.2, 1) -- Green table
    
    -- Load card images
    game:loadCardAssets()
    
    -- Create the grabber for drag and drop functionality
    game.grabber = Grabber:new(game)
    
    -- Initialize the game
    game:createDeck()
    game:shuffleDeck()
    game:dealCards()
    game:updateCardPositions()
end

function love.update(dt)
    -- Game logic updates here (if needed for animations later)
end

function love.draw()
    game:draw()
end

function love.mousepressed(x, y, button)
    if button == 1 then -- Left mouse button
        game.grabber:handlePress(x, y)
    end
end

function love.mousemoved(x, y)
    game.grabber:handleMove(x, y)
end

function love.mousereleased(x, y, button)
    if button == 1 then -- Left mouse button
        game.grabber:handleRelease(x, y)
    end
end