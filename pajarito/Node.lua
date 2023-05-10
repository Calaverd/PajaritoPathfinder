local Directions = require "pajarito.directions"

---@alias NodeID integer
---@alias ObjectID integer

--- A Node is an object that can be conected to
--- other Nodes (neighbours). 
---@class Node
---@field id NodeID To identify the node in the grid.
---@field tile number|string The tile value on the equivalent map
---@field position number[] A list for the position on [x,y,z]
---@field conections table The nodes that are neighbours to this one.
---@field objects {ObjectID:boolean} a list of the objecs in this node.
---@field private is_tile_number boolean a value that stores the type of the tile
---@field private num_objects number the number of objecs in this node.
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
--- value of a position on the map\
--- and their dimentions to create an id for that point
---@param x_pos number
---@param y_pos number
---@param z_pos number
---@param width number
---@param height number
---@param depth number
---@return NodeID
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

---Returns the direction a node is connected to another
---nil if the node is not connected
---@param node any
---@return number|nil direction
function Node:directionToConnected(node)
    for direction,snode in pairs(self.conections) do
        if snode.id == node.id then
            return direction
        end
    end
    return nil
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
    obj.objects = {}
    obj.num_objects = 0

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

--- Sets the value of the node tile and also
--- check the type of it.
---@param tile number|string
function Node:setTile(tile)
    self.tile = tile
    self.is_tile_number = type(tile) == "number"
end

---Returns if the tile is of type number
---@return boolean
function Node:isTileNumber()
    return self.is_tile_number
end

--- This function cheeks if the node has an active portal.
---@return boolean
function Node:hasPortal()
    return self.conections[0] ~= nil
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

---Adds a object as belogin to this node
---@param object_id ObjectID
function Node:addObject(object_id)
    self.objects[object_id] = true
    self.num_objects = self.num_objects + 1
end

---Removes an object from this node
---@param object_id ObjectID
function Node:removeObject(object_id)
    if self.objects[object_id] then
        self.objects[object_id] = nil
        self.num_objects = self.num_objects - 1
    end
end

--- Returns the number of objects in this node
---@return number
function Node:objectsSize()
    return self.num_objects;
end

--- Returns if the objects list of this
--- node is empty.
---@return boolean true if empty
function Node:hasObjects()
    return self.num_objects > 0;
end

return Node