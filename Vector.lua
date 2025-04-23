-- Vector.lua

local Vector = {}
Vector.__index = Vector

function Vector:new(x, y)
    local vector = {}
    setmetatable(vector, Vector)
    vector.x = x or 0
    vector.y = y or 0
    return vector
end

function Vector:add(other)
    return Vector:new(self.x + other.x, self.y + other.y)
end

function Vector:subtract(other)
    return Vector:new(self.x - other.x, self.y - other.y)
end

function Vector:multiply(scalar)
    return Vector:new(self.x * scalar, self.y * scalar)
end

function Vector:distanceTo(other)
    local dx = self.x - other.x
    local dy = self.y - other.y
    return math.sqrt(dx * dx + dy * dy)
end

function Vector:contains(x, y, width, height)
    return x >= self.x and x <= self.x + width and 
           y >= self.y and y <= self.y + height
end

return Vector