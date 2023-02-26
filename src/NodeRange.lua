---@module "Node"
local Node = require "Node"

---@class NodeRange
---@field start_id number id of the node from were the range starts
---@field range {number: number} map of Node id to weight in that part of the range
---@field type_movement string what movement is used to build the range
---@field map_size number[]
local NodeRange = {}

---@diagnostic disable-next-line: deprecated
local unpack = unpack or table.unpack

--- Defines a new node range.
---@param start_id number 
---@param range {number: number}
---@param type_movement string|nil
---@param map_size number[]
---@return NodeRange
function NodeRange:new(start_id, range, type_movement, map_size)
    local obj = {
        start_id = start_id,
        range    = range,
        type_movement = type_movement or "manhattan",
        map_size = map_size
    }

    setmetatable(obj, self)
    self.__index = self
    return obj
end

---Checks if a given point is contained
---whitin the NodeRange
---@param x number
---@param y number
---@param z ?number
---@return boolean
function NodeRange:hasPoint(x,y,z)
    local width, height, depth = unpack(self.map_size)
    local id = Node.getPointId(x or 0, y or 0, z or 0, width, height, depth)
    return self.range[id] ~= nil
end

return NodeRange