local Heap = require "pajarito.heap"
local Node = require "pajarito.Node"
local NodePath = require "pajarito.NodePath"
local Directions = require "pajarito.directions"
local mathops = require "pajarito.mathops"
local pow = mathops.pow

--- Contains a set of nodes that represent the
--- maximum extent of movement within a given range
--- from a start node.
---@class NodeRange
---@field start_id number id of the node from where the range starts
---@field range number max allowed weight for traversal
---@field node_traversal_weights {NodeID: number} map of Node id to their corresponding weight in the range
---@field type_movement string The kind of movement is used to build the range.
---@field border {NodeID: number} map of Node id that contains the border nodes to this range.
---@field private graphGetNode fun(id:NodeID): Node|nil
---@field private graphIsWallInTheWay fun(origin:Node,destiny:Node, direction:number): boolean
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
--- within the NodeRange, if is contained
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
--- within the border of this NodeRange.\
--- If it is contained returns the id of
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
--- be reached by its neighbours.
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
    ---@package
    return self.graphGetNode(node_id)
end

--- Gets the initial node from where this
--- range started
---@return Node|nil
function NodeRange:getStartNode()
    ---@package
    return self.graphGetNode(self.start_id)
end

--- If this Range is not empty, return the staring
--- node position.
---@return number[]|nil position
function NodeRange:getStartNodePosition()
    local node = self.graphGetNode(self.start_id)
    if node then
        return node.position
    end
    return nil
end

--- Check if a given array for the position is equal
--- to the position of the start node.
---@param position number[]
---@return boolean
function NodeRange:isStartNodePosition(position)
    return (self.start_id == self:getIdFromPoint(position))
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
    for node_id,_ in pairs(self.border) do
        nodes[#nodes+1] = self:getNode(node_id)
    end
    return nodes
end


--- Contruct a function specific to get the shortest
--- distance for this use case.0
---@param start_x number
---@param start_y number
---@param start_z? number
---@return fun(a:Node, b:Node): boolean
local function buildClosestDistanceCompareFunction(start_x, start_y, start_z)
    return (function (node_a, node_b)
        local ax,ay,az = unpack(node_a.position)
        local bx,by,bz = unpack(node_b.position)
        local distance_a = pow(ax-start_x,2) + pow(ay-start_y,2) + pow((az or 0)-(start_z or 0),2)
        local distance_b = pow(bx-start_x,2) + pow(by-start_y,2) + pow((bz or 0)-(start_z or 0),2)
        return distance_a < distance_b
    end)
end

--- Check if there is possible to go
--- from one connected node to another.\
--- It returns false if the destiny node is
--- impassable terrain, or exists a wall in
--- between nodes.
---@package
---@param origin Node
---@param destiny Node
---@param direction number
---@return boolean way_is_posible
function NodeRange:isWallInTheWay(origin, destiny, direction)
    return self.graphIsWallInTheWay(origin, destiny, direction)
end

--- Search if there is a path from the start node
--- of the range to the destination.\
--- Returns a NodePath that contains the nodes.\
--- Unless the warranty_shortest option is active, will
--- return the first path that finds the point.\
--- The NodePath is empty if the path does not exist.
---@param destination number[] position of the destination
---@param warranty_shortest_path? boolean Use only if you *absolutely* need the shortest, Can be slower on large maps.
---@return NodePath path
function NodeRange:getPathTo(destination, warranty_shortest_path)
    local destination_id = self:hasPoint(destination)

    local path = NodePath:new( 0, {self.width, self.height, self.depth})
    if not destination_id then
        return path
    end

    local start_node_id = self.start_id
    local traversal_weights = self.node_traversal_weights
    local current_node = self:getNode(destination_id --[[@as number]]) --[[@as Node]]
    local allowed_directions = Directions[self.map_type][self.type_movement] --[=[@as number[]]=]
    local sx,sy,sz = unpack(self:getStartNodePosition() --[[@as number[] ]] )
    local compareFun = buildClosestDistanceCompareFunction(sx, sy, sz)

    path:addNode(current_node)
    path.weight = traversal_weights[destination_id]
    while current_node.id ~= start_node_id do
        local best_node = nil
        local best_node_weight = 10000000
        ---@type {number:Heap}
        local nodes_by_weight = {}
        for _,direction in ipairs( allowed_directions ) do
            local node = current_node.conections[direction]

            if not node or not traversal_weights[node.id]
                or self:isWallInTheWay(current_node, node, direction) then
                goto continue
            end

            local node_weight = traversal_weights[node.id]
            if node_weight < best_node_weight then
                best_node_weight = node_weight
                best_node = node
            end

            -- We create a space to store the nodes that
            -- are of the same weight
            if not nodes_by_weight[node_weight] then
                nodes_by_weight[node_weight] = Heap:new()
                nodes_by_weight[node_weight]:setCompare(compareFun)
            end

            nodes_by_weight[node_weight]:push(node)

            ::continue::
        end

        if not best_node then
            print('Error, can not build path')
            return path
        end

        -- There is more than one nodes that are a good option...
        local heap_closest_nodes = nodes_by_weight[best_node_weight]
        if heap_closest_nodes:getSize() > 1 then
            if warranty_shortest_path then
                -- You want to be ABSOLUTELY sure to get the shortest path.
                -- We are going to take the recursive rute, and check
                -- which node leads to the path that is trully the shortest.
                local bifurcation_point = current_node
                local minimun_branch = path
                local minimun_branch_len = 100000
                while heap_closest_nodes:getSize() > 0 do
                    local node = heap_closest_nodes:pop()
                    local branch = self:getPathTo(node.position, warranty_shortest_path);
                    local branch_len = path:getIfMergedBranchLen(branch, bifurcation_point) or minimun_branch_len
                    if minimun_branch_len > branch_len then
                        minimun_branch_len = branch_len
                        minimun_branch = branch
                    end
                end
                return path:Merge(minimun_branch)
            end
            -- Or we can only use the closest to the starting point
            -- (special thanks to zet23t for sugesting it in the love2d discord.)
            best_node = heap_closest_nodes:pop()
        end

        current_node = best_node
        path.weight = max(path.weight, best_node_weight)
        path:addNode(current_node)
    end
    return path
end

return NodeRange