-- Card.lua
-- Card class

local Card = {}
Card.__index = Card

function Card:new(suit, rank)
    local card = {}
    setmetatable(card, Card)
    card.suit = suit
    card.rank = rank
    card.faceUp = false
    card.x = 0
    card.y = 0
    return card
end

function Card:draw(cardImages, defaultCardBack)
    -- Draw card using the loaded individual images
    love.graphics.setColor(1, 1, 1)
    
    if self.faceUp then
        -- Face up card - use the appropriate individual card image
        love.graphics.draw(cardImages[self.suit][self.rank], self.x, self.y)
    else
        -- Face down card - use the card back image
        love.graphics.draw(defaultCardBack, self.x, self.y)
    end
end

-- Card constants
Card.SUITS = {"clubs", "diamonds", "hearts", "spades"}
Card.RANKS = {"ace", "2", "3", "4", "5", "6", "7", "8", "9", "10", "jack", "queen", "king"}
Card.RANK_VALUES = {
    ace = 1, ["2"] = 2, ["3"] = 3, ["4"] = 4, ["5"] = 5, ["6"] = 6, ["7"] = 7,
    ["8"] = 8, ["9"] = 9, ["10"] = 10, jack = 11, queen = 12, king = 13
}
Card.RED_SUITS = {diamonds = true, hearts = true}
Card.BLACK_SUITS = {clubs = true, spades = true}

function Card:isRed()
    return Card.RED_SUITS[self.suit] ~= nil
end

function Card:isBlack()
    return Card.BLACK_SUITS[self.suit] ~= nil
end

-- logic for placing the cards
function Card:canStackOnTableau(existingCard)
    -- Cards must alternate colors and be in descending rank
    if self:isRed() == existingCard:isRed() then
        return false -- Cards must be different colors
    end
    
    -- Check ranks (must be in descending order)
    return Card.RANK_VALUES[self.rank] == Card.RANK_VALUES[existingCard.rank] - 1
end

-- logic for foundation cards
function Card:canAddToFoundation(foundationPile)
    if #foundationPile == 0 then
        -- Can only start with ace
        return self.rank == "ace"
    else
        local topCard = foundationPile[#foundationPile]
        
        if self.suit ~= topCard.suit then
            return false
        end
        
        return Card.RANK_VALUES[self.rank] == Card.RANK_VALUES[topCard.rank] + 1
    end
end

return Card