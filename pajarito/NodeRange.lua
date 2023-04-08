local Node = require "pajarito.Node"
local NodePath = require "pajarito.NodePath"
local Directions = require "pajarito.directions"

--- Contains a set of nodes that represent the
--- maximum extend of movement within a given range
--- from a start node.
---@class NodeRange
---@field start_id number id of the node from were the range starts
---@field range number max allowed weight for traversal
---@field node_traversal_weights {NodeID: number} map of Node id to their corresponding weight in the range
---@field type_movement string what movement is used to build the range
---@field border {NodeID: number} map of Node id that contains the border nodes to this range.
---@field private graphGetNode fun(id:NodeID): Node|nil
---@field private map_type string
---@field private width number width from the graph map
---@field private height number height from the graph map
---@field private depth number depth from the graph map
local NodeRange = {}

---@diagnostic disable-next-line: deprecated
local unpack = unpack or table.unpack
local max = math.max

--- Defines a new node range.
---@param settings table
---@return NodeRange
function NodeRange:new(settings)
    local obj = settings

    setmetatable(obj, self)
    self.__index = self
    return obj
end

---@private
---@param point number[]
---@return NodeID
function NodeRange:getIdFromPoint(point)
    local x,y,z = unpack(point)
    return Node.getPointId(x or 0, y or 0, z or 0, self.width, self.height, self.depth)
end

--- Checks if a given point is contained
--- whitin the NodeRange, if is contained
--- returns the id of the point, otherwise
--- returns false
---@param point number[]
---@return NodeID|boolean
function NodeRange:hasPoint(point)
    local id = self:getIdFromPoint(point)
    if self.node_traversal_weights[id] ~= nil then
        return id
    end
    return false
end

--- Returns the sum of all the weights from the tiles
--- traveled to reach this point in the range.\
--- If the node is not contained, returns -1
---@param id NodeID
---@return number
function NodeRange:getReachCostAt(id)
    local weight = self.node_traversal_weights[id]
    if weight then
        return weight
    end
    return -1
end

--- Checks if a given point is contained
--- whitin the border of this NodeRange.\
--- If is contained returns the id of
--- the point, otherwise returns false
---@param point number[]
---@return NodeID|boolean
function NodeRange:borderHasPoint(point)
    local id = self:getIdFromPoint(point)
    if self.border[id] ~= nil then
        return id
    end
    return false
end

--- Returns the weight of the border node.\
--- If is a negative number, the node can not
--- be reached by their neighbours.\
--- If nil, the node does not exist on the border.
---@param id NodeID
---@return number|nil
function NodeRange:getBorderWeight(id)
    return self.border[id]
end


--- Makes use of the method getNode from the
--- graph that creates the node range so it
--- can return the node
---@param node_id NodeID
---@return Node|nil
function NodeRange:getNode(node_id)
    return self.graphGetNode(node_id)
end

function NodeRange:getStartNode()
    return self.graphGetNode(self.start_id)
end

--- Returns a list of all the nodes in the range
---@return table<number,Node>
function NodeRange:getAllNodes()
    local nodes = {}
    for node_id,_ in pairs(self.node_traversal_weights) do
        nodes[#nodes+1] = self:getNode(node_id)
    end
    return nodes
end

--- Returns a list with the nodes on the border.
---@return table<number,Node>
function NodeRange:getAllBoderNodes()
    local nodes = {}
    for _,node_id in pairs(self.border) do
        nodes[#nodes+1] = self:getNode(node_id)
    end
    return nodes
end


--- Search if there is a path from the start node
--- of the range to the destination.\
--- Returns a NodePath that contains the nodes that form
--- the path. The NodePath is empty if the path does not exist.
---@param destination number[] position of the destination
---@return NodePath path
function NodeRange:getPathTo(destination)
    local destination_id = self:hasPoint(destination)

    local path = NodePath:new( 0, {self.width, self.height, self.depth})
    if not destination_id then
        return path
    end

    local start_node_id = self.start_id
    local traversal_weights = self.node_traversal_weights
    local current = self:getNode(destination_id --[[@as number]]) --[[@as Node]]
    local allowed_directions = Directions[self.map_type][self.type_movement] --[=[@as number[]]=]

    path:addNode(current)
    path.weight = traversal_weights[destination_id]
    while current.id ~= start_node_id do
        local best_node = nil
        local best_node_weight = 1000000
        for _,direction in ipairs( allowed_directions ) do
            local node = current.conections[direction]

            if not node or not traversal_weights[node.id] then
                goto continue
            end

            if traversal_weights[node.id] < best_node_weight then
                best_node = self:getNode(node.id)
                best_node_weight = traversal_weights[node.id]
            end

            ::continue::
        end
        if not best_node then
            print('Error, can not build path')
            return path
        end
        current = best_node
        path.weight = max(path.weight, best_node_weight)
        path:addNode(current)
    end
    return path
end

return NodeRange