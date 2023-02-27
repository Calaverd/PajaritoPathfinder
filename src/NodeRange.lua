---@module "Node"
local Node = require "Node"
---@module "NodePath"
local NodePath = require "NodePath"

local Directions = require "directions"

--- Contains a set of nodes that represent the
--- maximum extend of movement within a given range
--- from a start node.
---@class NodeRange
---@field start_id number id of the node from were the range starts
---@field range number max allowed weight for traversal
---@field node_traversal_weights {number: number} map of Node id to their corresponding weight in the range
---@field type_movement string what movement is used to build the range
---@field private graphGetNode fun(id:number): Node|nil
---@field private map_type string
---@field private width number width from the graph map
---@field private height number height from the graph map
---@field private depth number depth from the graph map
local NodeRange = {}

---@diagnostic disable-next-line: deprecated
local unpack = unpack or table.unpack

--- Defines a new node range.
---@param settings table
---@return NodeRange
function NodeRange:new(settings)
    local obj = settings

    setmetatable(obj, self)
    self.__index = self
    return obj
end

--- Checks if a given point is contained
--- whitin the NodeRange, if is contained
--- returns the id of the point, otherwise
--- returns false
---@param point number[]
---@return number|boolean
function NodeRange:hasPoint(point)
    local x,y,z = unpack(point)
    local id = Node.getPointId(x or 0, y or 0, z or 0, self.width, self.height, self.depth)
    if self.node_traversal_weights[id] ~= nil then
        return id
    end
    return false
end

--- Makes use of the method getNode from the
--- graph that creates the node range so it
--- can return the node
---@param node_id number
---@return Node|nil
function NodeRange:getNode(node_id)
    return self.graphGetNode(node_id)
end

--- Search if there is a path from the start node
--- of the range to the destination.\
--- Returns a NodePath that contains the nodes that form
--- the path. The NodePath is empty if the path does not exist.
---@param destination number[] position of the destination
---@return NodePath path
function NodeRange:getPathTo(destination)
    local destination_id = self:hasPoint(destination)

    local path = NodePath:new({width = self.width, height = self.height, depth = self.depth})
    if not destination_id then
        return path
    end

    local start_node_id = self.start_id
    local traversal_weights = self.node_traversal_weights
    local current = self:getNode(destination_id --[[@as number]]) --[[@as Node]]
    local allowed_directions = Directions[self.map_type][self.type_movement]

    path:addNode(current)
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
            return {}
        end
        current = best_node
        path:addNode(current)
    end
    return path
end

return NodeRange