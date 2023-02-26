---@module "Node"
local Node = require "Node"

---@class NodePath
---@field node_list Node[] A list of the nodes in the path
---@field map_size number[]
local NodePath = {}

---@diagnostic disable-next-line: deprecated
local unpack = unpack or table.unpack

--- Defines a new node range.
---@param map_size number[]
---@return NodePath
function NodePath:new(map_size)
    local obj = {
        node_list     = {},
        map_size = map_size
    }
    setmetatable(obj, self)
    self.__index = self
    return obj
end

---Adds a node
---@param node Node
function NodePath:addNode(node)
    table.insert(self.node_list, 1, node)
end

---Checks if a given point is contained
---whitin the NodeRange
---@param x number
---@param y number
---@param z ?number
---@return boolean
function NodePath:hasPoint(x,y,z)
    local width, height, depth = unpack(self.map_size)
    local id = Node.getPointId(x or 0, y or 0, z or 0, width, height, depth)
    return self.node_list[id] ~= nil
end

return NodePath