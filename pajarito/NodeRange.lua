local Heap = require (__PAJARITO_MODULE_PATH..'heap')
local Node = require (__PAJARITO_MODULE_PATH..'Node')
local NodePath = require (__PAJARITO_MODULE_PATH..'NodePath')
local Directions = require (__PAJARITO_MODULE_PATH..'directions')
local mathops = require (__PAJARITO_MODULE_PATH..'mathops')
local pow = mathops.pow

--- Contains a set of nodes that represent the
--- maximum extent of movement within a given range
--- from a start node.
---@class NodeRange
---@field start_id number id of the node from where the range starts
---@field range number max allowed weight for traversal
---@field node_traversal_weights table<NodeID, number> map of Node id to their corresponding weight in the range
---@field type_movement string The kind of movement is used to build the range.
---@field border table<NodeID, number> map of Node id that contains the border nodes to this range.
---@field private graphGetNode fun(id:NodeID): Node|nil
---@field private graphIsWallInTheWay fun(origin:Node,destiny:Node, direction:integer): boolean
---@field private map_type string
---@field private width number width from the graph map
---@field private height number height from the graph map
---@field private depth number depth from the graph map
local NodeRange = {}

---@diagnostic disable-next-line: deprecated
local unpack = unpack or table.unpack
local max = math.max

--- Marks a node whose branch is still being solved further up the
--- recursion of getPathTo, see getBranchTo. Running into it means the
--- way back has walked in a circle.
local BEING_SOLVED = {}

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
--- If the node is not contained in the range or their border, returns -1
---@param id NodeID
---@return number
function NodeRange:getReachCostAt(id)
    local weight = self.node_traversal_weights[id]
    if weight then
        return weight
    end
    -- then return the border weight
    return self.border[id] or -1
end

--- Custom iterator that contains the nodes
--- that form the `NodeRange`
---@return fun(): number|nil, Node|nil iterator
function NodeRange:iterNodes()
    local node_t = self.node_traversal_weights
    local k = nil
    local count = 0
    return function()
        k = next(node_t, k)
        count = count +1
        if k == nil then
            return nil, nil
        end
        return count, self.graphGetNode(k)
    end
end

--- Custom iterator that contains the nodes
--- that form the border of the `NodeRange`
---@return fun(): number|nil, Node|nil iterator
function NodeRange:iterBorderNodes()
    local node_t = self.border
    local k = nil
    local count = 0
    return function()
        k = next(node_t, k)
        count = count +1
        if k == nil then
            return nil, nil
        end
        return count, self.graphGetNode(k)
    end
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
---@param direction integer
---@return boolean way_is_posible
function NodeRange:isWallInTheWay(origin, destiny, direction)
    return self.graphIsWallInTheWay(origin, destiny, direction)
end

--- Finds the neighbours this node can step back to: the ones
--- that are cheapest to reach from the start of the range.\
--- Several neighbours can tie, so they come in a heap that
--- pops first the one closest to the start.\
--- Returns nil if there is no neighbour to step back to.
---@package
---@param node Node
---@param closestToStart fun(a:Node, b:Node): boolean
---@return Heap|nil cheapest_neighbors, number|nil their_weight
function NodeRange:getCheapestNeighbors(node, closestToStart)
    local traversal_weights = self.node_traversal_weights
    local cheapest_neighbors = nil
    local cheapest_weight = math.huge

    for _, direction in ipairs(Directions[self.map_type][self.type_movement]) do
        local neighbor = node.conections[direction]
        local weight = neighbor and traversal_weights[neighbor.id]

        if weight and not self:isWallInTheWay(node, neighbor, direction) then
            if weight < cheapest_weight then
                -- a cheaper one, forget the ones found so far
                cheapest_weight = weight
                cheapest_neighbors = Heap:new()
                cheapest_neighbors:setCompare(closestToStart)
            end
            if weight == cheapest_weight and cheapest_neighbors then
                cheapest_neighbors:push(neighbor)
            end
        end
    end
    return cheapest_neighbors, cheapest_neighbors and cheapest_weight
end

--- Gives the path from the start of the range to this node.\
--- This is the memoization that keeps the warranty of `getPathTo` fast.
--- Every tie on the way back opens a new branch, and every branch meets
--- more ties, so solving each branch from scratch doubles the work at
--- every tie. But the path to a node is the same no matter which branch
--- asks for it, so each node is solved once and remembered in `solved_branches`.\
--- Returns nil if the node is still being solved further up the
--- recursion: going back through it would walk in a circle.
---@package
---@param node Node
---@param solved_branches table<NodeID,NodePath|table> the branches solved so far
---@return NodePath|nil branch
function NodeRange:getBranchTo(node, solved_branches)
    local branch = solved_branches[node.id]
    if branch == BEING_SOLVED then
        return nil
    end
    if not branch then
        solved_branches[node.id] = BEING_SOLVED
        branch = self:getPathTo(node.position, true, solved_branches)
        solved_branches[node.id] = branch
    end
    return branch --[[@as NodePath]]
end

--- Solves the branch behind each of the candidates and returns
--- the one with fewest steps. On a tie, the candidate closest to
--- the start wins, as it is the first to come out of the heap.\
--- Returns nil if every candidate is still being solved.
---@package
---@param candidates Heap the tied neighbours, see getCheapestNeighbors
---@param solved_branches table<NodeID,NodePath|table>
---@return NodePath|nil shortest
function NodeRange:getShortestBranch(candidates, solved_branches)
    local shortest = nil
    while candidates:getSize() > 0 do
        local branch = self:getBranchTo(candidates:pop(), solved_branches)
        if branch and (not shortest or branch:getLen() < shortest:getLen()) then
            shortest = branch
        end
    end
    return shortest
end

--- Search if there is a path from the start node
--- of the range to the destination.\
--- Returns a NodePath that contains the nodes.\
--- Unless the warranty_shortest option is active, will
--- return the first path that finds the point.\
--- The NodePath is empty if the path does not exist.
---@param destination number[] position of the destination
---@param warranty_shortest_path? boolean Use only if you *absolutely* need the shortest, Can be slower on large maps.
---@param solved_branches? table<NodeID,NodePath|table> internal, shared by the recursive calls, see getBranchTo
---@return NodePath path
function NodeRange:getPathTo(destination, warranty_shortest_path, solved_branches)
    local path = NodePath:new(0, {self.width, self.height, self.depth})
    local destination_id = self:hasPoint(destination)
    if not destination_id then
        return path
    end

    -- The range already knows what it costs to reach each of its nodes.
    -- So the path is built backwards: start at the destination and keep
    -- stepping to the cheapest neighbour, until arriving at the start.
    local sx, sy, sz = unpack(self:getStartNodePosition() --[[@as number[] ]])
    local closestToStart = buildClosestDistanceCompareFunction(sx, sy, sz)
    local current_node = self:getNode(destination_id --[[@as number]]) --[[@as Node]]
    path:addNode(current_node)
    path.weight = self.node_traversal_weights[destination_id]

    while current_node.id ~= self.start_id do
        local candidates, weight = self:getCheapestNeighbors(current_node, closestToStart)
        if not candidates then
            print('Error, can not build path')
            return path
        end
        if warranty_shortest_path and candidates:getSize() > 1 then
            -- The tied neighbours cost the same, but the ways back through
            -- them can take a different number of steps. Solve them all and
            -- keep the shortest. It already reaches the start, so we are done.
            solved_branches = solved_branches or {}
            local shortest = self:getShortestBranch(candidates, solved_branches)
            if not shortest then
                -- Every way back walks in a circle. Each step back is
                -- cheaper than the last, so this should never happen.
                print('Error, can not build path')
                return path
            end
            return path:Merge(shortest)
        end

        -- Without the warranty, step to the one closest to the start
        -- (special thanks to zet23t for sugesting it in the love2d discord.)
        current_node = candidates:pop()
        path.weight = max(path.weight, weight)
        path:addNode(current_node)
    end
    return path
end

return NodeRange