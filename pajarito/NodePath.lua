local Node = require "pajarito.Node"

--- A class that contains the necessary nodes
--- to follow in order to traverse from a node to another.
---@class NodePath
---@field node_list Node[] A list of the nodes in the path
---@field weight number The cost of traversing this path in the range.
---@field contains {NodeID:boolean} A map to check if the path has a node
---@field private width number width from the graph map
---@field private height number height from the graph map
---@field private depth number depth from the graph map
local NodePath = {}

---@diagnostic disable-next-line: deprecated
local unpack = unpack or table.unpack

--- Defines a new node range.
---@param weight number
---@param map_size number[]
---@return NodePath
function NodePath:new(weight, map_size)
    local width, height, depth = unpack(map_size)
    local obj = {
        weight = weight,
        node_list     = {},
        ---@protected
        width = width or 0,
        ---@protected
        height = height or 0,
        ---@protected
        depth = depth or 0,
        contains = {}
    }
    setmetatable(obj, self)
    self.__index = self
    return obj
end

---Adds a node
---@param node Node
function NodePath:addNode(node)
    self.contains[node.id] = true
    table.insert(self.node_list, 1, node)
end

--- Give the number of nodes on the path.
---@return integer len
function NodePath:getLen()
    return #self.node_list
end

--- A function that chek if the
--- path contains nodes
---@return boolean
function NodePath:isEmpty()
    return #self.node_list == 0
end

--- Gets the starting node of the path.\
--- If the path is empty returns nil
---@return Node|nil
function NodePath:getStart()
    return self.node_list[1]
end


--- Gets the last node of the path.\
--- If the path is empty returns nil
---@return Node|nil
function NodePath:getLast()
    return self.node_list[#self.node_list]
end

--- Gets the node at a given steep.
--- If there is no node in that steep, returns nil.
---@param steep number
---@return Node|nil
function NodePath:getNodeAtSteep(steep)
    return self.node_list[steep]
end

--- Custom iterator for the NodePath
---@return fun(): number|nil, Node|nil iterator
function NodePath:getNodes()
    local i = 0
    local n = #self.node_list
    return function ()
        i = i + 1
        if i <= n then
            return i, self.node_list[i]
        end
        return nil, nil
    end
end

---Checks if a given point is contained
---whitin the NodeRange
---@param point number[]
---@return boolean
function NodePath:hasPoint(point)
    local x,y,z = unpack(point)
    local id = Node.getPointId(x or 0, y or 0, z or 0, self.width, self.height, self.depth)
    return self.contains[id] ~= nil
end

return NodePath