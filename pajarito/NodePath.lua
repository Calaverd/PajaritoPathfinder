local Node = require (__PAJARITO_MODULE_PATH..'Node')

--- A class that contains the necessary nodes to follow
--- to traverse from one node to another.
---@class NodePath
---@field node_list Node[] A list of the nodes in the path
---@field weight number The cost of traversing this path in the range.
---@field contains table<NodeID, number> A map to check if the path has a node and its steep number.
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

--- Adds a node at the front of the path.\
--- Paths are built from the end backwards, so each new
--- node goes before the ones already in it.
---@param node Node
function NodePath:addNode(node)
    -- read as: "contains this node, it was the n-th to arrive".
    -- The steep counted from the start is worked out in getStepAtNode
    self.contains[node.id] = #self.node_list+1
    table.insert(self.node_list, 1, node)
end

--- Give the number of nodes on the path.
---@return integer length
function NodePath:getLen()
    return #self.node_list
end

--- A function that checks if the
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

--- Returns in what steep this node is, counted from the start
--- of the path, so `getNodeAtSteep(getStepAtNode(node))` gives
--- back the node.\
--- If there is no node in the path, return nil.
---@param node Node
---@return number|nil
function NodePath:getStepAtNode(node)
    local arrival = self.contains[node.id]
    if not arrival then
        return nil
    end
    -- the first node to arrive ends up the last one of the path
    return #self.node_list + 1 - arrival
end

--- Returns the length of the path if it follows the given branch:
--- the branch, and then this path from the bifurcation point on.\
--- Returns nil if the branch is empty or the
--- bifurcation point is not on this path.
---@param branch NodePath
---@param bifurcation_point Node
---@return number|nil len
function NodePath:getIfMergedBranchLen(branch, bifurcation_point)
    local step = self:getStepAtNode(bifurcation_point)
    if branch:isEmpty() or not step then
        return nil
    end
    local len_from_bifurcation = self:getLen() - step + 1
    return branch:getLen() + len_from_bifurcation
end

--- Adds the nodes of the branch to itself.
--- Is based on the presumption that the branch
--- starts where this path ends.
---@param branch NodePath
---@return NodePath
function NodePath:Merge(branch)
    -- weights are accumulated costs, so the total is the biggest one
    self.weight = math.max(self.weight, branch.weight)
    local node_list = branch.node_list
    local num = #node_list
    while node_list[num] do
        self:addNode(node_list[num])
        num = num - 1
    end
    return self
end

--- Custom iterator for the NodePath
---@return fun(): number|nil, Node|nil iterator
function NodePath:iterNodes()
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

--- Checks if a given point is contained within the NodeRange.
---@param point number[]
---@return boolean
function NodePath:hasPoint(point)
    local x,y,z = unpack(point)
    local id = Node.getPointId(x or 0, y or 0, z or 0, self.width, self.height, self.depth)
    return self.contains[id] ~= nil
end

return NodePath