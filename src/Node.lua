local Directions = require "directions"

---@class Node
---@field id integer
---@field tile number|string
---@field position number[]
---@field conections table
local Node = {}

local FLOOR = math.floor

---Check if a number is between other 2
---@param num number to check
---@param min number bottom boundary
---@param max number top boundary
---@return boolean
local function isInRange(num,min,max)
    return num >= min and num <= max;
end

--- Static helper function that takes the 
--- value of a position on the map and their
--- dimentions to create an id for that point
---@param x_pos number
---@param y_pos number
---@param z_pos number
---@param width number
---@param height number
---@param depth number
---@return integer
function Node.getPointId(x_pos, y_pos, z_pos, width, height, depth)
    if not isInRange(y_pos,1,height)
        or not isInRange(x_pos,1,width) then
        return -1
    end
    if depth ~= 0 then
        if not isInRange(z_pos,1,depth) then
            return -1
        end
    end
    return FLOOR( (z_pos* depth * width ) + ((y_pos-1) * width) + (x_pos-1) )+1
end


--- Node constructor
---@param id number unique to this node on the graph
---@param position number[]
---@return Node
function Node:new(id, position)
    local obj = {}
    obj.id = id
    obj.tile = 0
    obj.position = position
    obj.conections = {}

    setmetatable(obj, self)
    self.__index = self
    return obj
end

--- Conenct this node to another.
---@param node Node
---@param direction integer
function Node:makeOneWayLinkWith(node, direction)
    self.conections[direction] = node
end

--- Connect this node to another and
--- that another node to this one.
---@param node Node
---@param direction integer
function Node:makeTwoWayLinkWith(node, direction)
    self:makeOneWayLinkWith(node, direction)
    node:makeOneWayLinkWith(self, Directions.flip(direction))
end

--- Delete the link if the conection exist
---@param node_to_clear Node
function Node:clearOneWayLinkWith(node_to_clear)
    for direction, conected_node in pairs(self.conections) do
        if conected_node.id == node_to_clear.id then
            self.conections[direction] = nil
            return
        end
    end
end

--- Deletes the link connecting this
--- and the other node if exist
---@param node Node
function Node:clearTwoWayLinkWith(node)
    self:clearOneWayLinkWith(node)
    node:clearOneWayLinkWith(self)
end

return Node