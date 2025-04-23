-- Grabber.lua

local Vector = require("vector")

local Grabber = {}
Grabber.__index = Grabber

function Grabber:new(game)
    local grabber = {}
    setmetatable(grabber, Grabber)
    
    grabber.game = game
    grabber.selectedCard = nil
    grabber.selectedPile = nil
    grabber.dragOffset = Vector:new(0, 0)
    grabber.draggingCards = {}
    
    return grabber
end

function Grabber:handlePress(x, y)
    -- Check if stock pile was clicked
    if Vector:new(50, 50):contains(x, y, self.game.cardWidth, self.game.cardHeight) then
        -- Draw 3 cards from stock to waste
        if #self.game.stock > 0 then
            -- Draw up to 3 cards at once
            local cardsToMove = math.min(3, #self.game.stock)
            for i = 1, cardsToMove do
                local card = table.remove(self.game.stock)
                card.faceUp = true
                table.insert(self.game.waste, card)
            end
            self.game:updateCardPositions()
            print("Moved " .. cardsToMove .. " cards from stock to waste. Stock: " .. #self.game.stock .. ", Waste: " .. #self.game.waste)
        else 
            -- If stock is empty, recycle waste pile back to stock
            while #self.game.waste > 0 do
                local card = table.remove(self.game.waste)
                card.faceUp = false
                table.insert(self.game.stock, card)
            end
            self.game:updateCardPositions()
            print("Recycled waste back to stock. Stock: " .. #self.game.stock)
        end
        return
    end
    
    -- Check if clicked on a card in the tableau columns
    for col=1, 7 do
        if #self.game.tableau[col] > 0 then
            for i=#self.game.tableau[col], 1, -1 do
                local card = self.game.tableau[col][i]
                if card.faceUp and Vector:new(card.x, card.y):contains(x, y, self.game.cardWidth, self.game.cardHeight) then
                    -- Start dragging this card and any cards below it
                    self.selectedCard = card
                    self.selectedPile = {type = "tableau", index = col}
                    self.dragOffset = Vector:new(card.x - x, card.y - y)
                    
                    -- Collect cards to drag
                    self.draggingCards = {}
                    for j=i, #self.game.tableau[col] do
                        table.insert(self.draggingCards, self.game.tableau[col][j])
                    end
                    break
                end
            end
            if self.selectedCard then break end
        end
    end
    
    -- If no tableau card was selected, check if clicked on waste pile
    if not self.selectedCard and #self.game.waste > 0 then
        local topCard = self.game.waste[#self.game.waste]
        if Vector:new(topCard.x, topCard.y):contains(x, y, self.game.cardWidth, self.game.cardHeight) then
            self.selectedCard = topCard
            self.selectedPile = {type = "waste"}
            self.dragOffset = Vector:new(topCard.x - x, topCard.y - y)
            self.draggingCards = {topCard}
        end
    end
    
    -- If still no card selected, check if clicked on foundation piles
    if not self.selectedCard then
        for pile=1, 4 do
            if #self.game.foundation[pile] > 0 then
                local topCard = self.game.foundation[pile][#self.game.foundation[pile]]
                if Vector:new(topCard.x, topCard.y):contains(x, y, self.game.cardWidth, self.game.cardHeight) then
                    self.selectedCard = topCard
                    self.selectedPile = {type = "foundation", index = pile}
                    self.dragOffset = Vector:new(topCard.x - x, topCard.y - y)
                    self.draggingCards = {topCard}
                    break
                end
            end
        end
    end
end

-- splitting up this logic into smaller functions made it so much easier
function Grabber:handleMove(x, y)
    if self.selectedCard then
        -- Update positions of dragging cards
        local baseX = x + self.dragOffset.x
        local baseY = y + self.dragOffset.y
        
        for i, card in ipairs(self.draggingCards) do
            card.x = baseX
            card.y = baseY + (i-1) * 25
        end
    end
end

-- Main function - now acts as a coordinator for smaller functions
function Grabber:handleRelease(x, y)
    if self.selectedCard then
        local targetFound = self:tryDropOnFoundation(x, y) or self:tryDropOnTableau(x, y)
        
        -- Reset positions if no valid target
        if not targetFound then
            self.draggingCards = {}
        end
        
        self.game:updateCardPositions()
        
        -- Check for win after successful move
        if self.game:checkForWin() then
            print("Congratulations! You win!")
        end
        
        -- Clear selection state
        self:resetDragState()
    end
end

-- Try to drop card(s) on foundation piles
function Grabber:tryDropOnFoundation(x, y)
    -- Check foundation piles as drop target
    for pile=1, 4 do
        local pileX = 320 + (pile-1) * 100
        local pileY = 50
        
        if Vector:new(pileX, pileY):contains(x, y, self.game.cardWidth, self.game.cardHeight) then
            -- Can only move one card to foundation
            if #self.draggingCards == 1 then
                local card = self.draggingCards[1]
                if card:canAddToFoundation(self.game.foundation[pile]) then
                    self:removeCardsFromSource()
                    table.insert(self.game.foundation[pile], card)
                    return true
                end
            end
            break
        end
    end
    return false
end

-- Try to drop card(s) on tableau columns
function Grabber:tryDropOnTableau(x, y)
    for col=1, 7 do
        local colX = 50 + (col-1) * 100
        local colY = 150
        local colHeight = self.game.cardHeight + (#self.game.tableau[col] * 25)
        
        if Vector:new(colX, colY):contains(x, y, self.game.cardWidth, colHeight) then
            if self:canDropOnTableauColumn(col) then
                self:removeCardsFromSource()
                self:addCardsToTableau(col)
                return true
            end
            break
        end
    end
    return false
end

-- Check if cards can be dropped on specific tableau column
function Grabber:canDropOnTableauColumn(col)
    local firstDragCard = self.draggingCards[1]
    
    -- Empty column case
    if #self.game.tableau[col] == 0 then
        return firstDragCard.rank == "king"
    end
    
    -- Non-empty column case
    local topCard = self.game.tableau[col][#self.game.tableau[col]]
    return firstDragCard:canStackOnTableau(topCard)
end

-- Add cards to tableau column
function Grabber:addCardsToTableau(col)
    for _, card in ipairs(self.draggingCards) do
        table.insert(self.game.tableau[col], card)
    end
end

-- Reset drag state after a move
function Grabber:resetDragState()
    self.selectedCard = nil
    self.selectedPile = nil
    self.draggingCards = {}
end

-- Remove cards from their original location
function Grabber:removeCardsFromSource()
    if self.selectedPile then
        if self.selectedPile.type == "tableau" then
            self:removeCardsFromTableau()
        elseif self.selectedPile.type == "waste" then
            table.remove(self.game.waste)
        elseif self.selectedPile.type == "foundation" then
            local pile = self.selectedPile.index
            table.remove(self.game.foundation[pile])
        end
    end
end

-- Handle removing cards from tableau specifically
function Grabber:removeCardsFromTableau()
    local col = self.selectedPile.index
    local startIdx = self:findCardIndexInTableau(col)
    
    -- Remove cards from tableau
    if startIdx > 0 then
        for i=#self.game.tableau[col], startIdx, -1 do
            table.remove(self.game.tableau[col], i)
        end
    end
    
    -- Flip the new top card if needed
    self:flipTopCardIfNeeded(col)
end

-- Find index of first dragging card in tableau column
function Grabber:findCardIndexInTableau(col)
    for i, card in ipairs(self.game.tableau[col]) do
        if card == self.draggingCards[1] then
            return i
        end
    end
    return 0
end

-- Flip top card in tableau column if needed
function Grabber:flipTopCardIfNeeded(col)
    if #self.game.tableau[col] > 0 and not self.game.tableau[col][#self.game.tableau[col]].faceUp then
        self.game.tableau[col][#self.game.tableau[col]].faceUp = true
    end
end

function Grabber:drawDraggingCards()
    for _, card in ipairs(self.draggingCards) do
        card:draw(self.game.cardImages, self.game.defaultCardBack)
    end
end

return Grabber