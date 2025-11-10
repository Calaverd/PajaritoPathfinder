local Directions = require(__PAJARITO_MODULE_PATH..'directions')
local Heap = require(__PAJARITO_MODULE_PATH..'heap')
local Node = require(__PAJARITO_MODULE_PATH..'Node')
local NodeRange = require(__PAJARITO_MODULE_PATH..'NodeRange')
local mathops = require(__PAJARITO_MODULE_PATH..'mathops')
local pow = mathops.pow
local band = mathops.band
local isSamePosition = mathops.isSamePosition

---@diagnostic disable-next-line: deprecated
local unpack = unpack or table.unpack

--- takes an object an returns a number to
--- use as id.
---@param object table
---@return ObjectID
local function getObjectID(object)
    return tonumber( tostring(object):gsub('table: 0x',''), 16)
end

local Node_getPointId = Node.getPointId

--- A class for the representation of
--- maps as a Graph. Is composed of nodes and allows for
--- operations on them.
---@class Graph
---@field node_map {number:Node} A list of all the nodes on this graph
---@field weight_map table<number,number> A map for the weight of tiles
---@field walls table<number, number> A map for node id and wall.
---@field portals table<number,NodeID[]> A list of the active portals with the nodes it connects.
---@field objects { ObjectID:NodeID } A map to keep track of the position of objects useful to handle entities that move around the map.
---@field objects_ref {ObjectID:table} A map to get the object referenced by the object_id.
---@field object_groups { string:{ObjectID:boolean} } to store the groups of the objects.
---@field settings table A map that contains contextual info to build the graph.
local Graph = {}


--- Graph object constructor
---@param settings table instructions about how to create this graph
---@return Graph
function Graph:new(settings)
    local obj = {}
    obj.node_map = {} --- A list with all the nodes
    obj.weight_map = {}
    obj.walls = {}
    obj.settings = settings
    obj.portals = {}
    obj.objects = {}
    obj.objects_ref = {}
    obj.object_groups = {}
    setmetatable(obj, self)
    self.__index = self
    return obj
end

--- Returns the node with that id if exists
--- in the graph, otherwise nil.
---@param id_node integer
---@return Node | nil
function Graph:getNode(id_node)
    return self.node_map[id_node]
end

--- Returns the node at the given position if it exists
--- in the graph, otherwise nil.
---@param position number[]
---@return Node | nil
function Graph:getNodeAt(position)
    local id = self:positionToMapId(position)
    return self.node_map[id]
end

---Adds a node to this graph.
---@param node Node
function Graph:addNode(node)
    self.node_map[node.id] = node;
end

--- Takes the position of a node in the graph
--- and updates the contained tile value.
---@param position number[]
---@param tile number|string
function Graph:updateNodeTile(position, tile)
    local id = self:positionToMapId(position)
    local node = self:getNode(id)
    if node then
        node:setTile(tile)
    end
end

--- Adds a node to the graph to connect it to its neighbors
--- if they exist or there is no wall between them.\
--- Needs some contextual info about node position
--- and the graph dimensions.
---@param new_node Node
---@param x number
---@param y number
---@param z number
---@param width number
---@param height number
---@param deep number
function Graph:connectNodeToNeighbors(new_node, x,y,z,width,height,deep)
    -- Connect the node to their neighbourds
    local all_2d_directions = Directions["2D"].diagonal;
    for _, direction in pairs( all_2d_directions ) do
        local neighbour = nil
        if direction ~= 0 then
            local move = Directions.movements[direction]
            local n_x, n_y, n_z = x+move.x, y+move.y, z+move.z
            if band(self.settings.wrap or 0, 1) == 1 then
                if n_x == 0 then n_x = width end
                if n_x > width then n_x = 1 end
            end
            if band(self.settings.wrap or 0, 2) == 2 then
                if n_y == 0 then n_y = height end
                if n_y > height then n_y = 1 end
            end
            local neighbour_id = Node_getPointId(n_x, n_y, n_z, width, height, deep)
            neighbour = self:getNode(neighbour_id)
        end
        if neighbour then
            new_node:makeTwoWayLinkWith(neighbour, direction)
        end
    end
end

--- This function connects to points if they exist inside the map
--- to each other, so the pathfinder can work between them.
--- If one point is outside the map or has already a portal,
--- the operation is aborted
---@param point_a number[]
---@param point_b number[]
---@return boolean success
function Graph:createPortalBetween(point_a, point_b)
    local n1 = self:getNode(self:positionToMapId(point_a))
    local n2 = self:getNode(self:positionToMapId(point_b))
    if n1 and n2 then
        if not n1:hasPortal() and not n2:hasPortal() then
            n1:makeTwoWayLinkWith(n2,0) -- direction 0, portal
            self.portals[mathops.bxor(n1.id, n2.id)] = {n1.id, n2.id}
            return true
        end
    end
    return false
end

--- This function removes a connection between nodes
--- if one point is outside the map or the points are
--- not connected, then the operation is aborted.
---@param point_a number[]
---@param point_b number[]
---@return boolean success
function Graph:removePortalBetween(point_a, point_b)
    local n1 = self:getNode(self:positionToMapId(point_a))
    local n2 = self:getNode(self:positionToMapId(point_b))
    if n1 and n2 then
        -- check if exists the portal
        local portal_id = mathops.bxor(n1.id, n2.id)
        if self.portals[portal_id] then
            n1:clearTwoWayLinkWith(n2)
            self.portals[portal_id] = nil
            return true
        end
    end
    return false
end

--- Sets the given table as the weight_map
---@param new_weight_map table<number,number> 
function Graph:setWeightMap(new_weight_map)
    self.weight_map = new_weight_map
end

---@param point number[]
---@return boolean
function Graph:hasPoint(point)
    local node_id = self:positionToMapId(point)
    return self.node_map[node_id] ~= nil
end


local createWall = Directions.mergeDirections

--- Adds a new wall in the given position with the
--- given facing orientations. If no directions are provided,
--- removes all walls at that position.
---@param position number[]
---@param ... number|string
function Graph:setWall(position, ...)
    local id = self:positionToMapId(position)
    local arg_count = select('#', ...)
    if arg_count == 0 then
        -- No directions provided, remove walls at this position
        self.walls[id] = nil
    else
        -- Create wall with provided directions
        self.walls[id] = createWall(...)
    end
end

--- Returns the wall value at the given position.\
--- If there is no wall, returns a nil value
---@param position number[]
---@return number|nil
function Graph:getWallAt(position)
    local node_id = self:positionToMapId(position)
    return self.walls[node_id]
end

---A helper function that sets the walls from a
--- given list in the format { {position}, direction_a, direction_b, ... }
---@param list_of_walls any[]
function Graph:buildWalls(list_of_walls)
    for _, wall in pairs(list_of_walls) do
        local position = table.remove(wall,1)
        self:setWall(position, unpack(wall) )
    end
end

--- Deletes all the walls in the graph
function Graph:clearWalls()
    self.walls = {}
end
--- Custom iterator for the graph walls, it
--- returns the position and the value.
-- If the wall position is outside the graph,
-- return a list fill with -1
---@return fun(): number[]|nil, number|nil iterator
function Graph:iterWalls()
    local node_id = nil
    return function()
        local wall_value
        node_id, wall_value = next(self.walls, node_id)
        if node_id then
            local position = {-1,-1,-1}
            local node = self:getNode(node_id)
            if node then
                position = node.position
            end
            return position, wall_value
        end
    end
end

--- Adds a new object.\
--- Objects are entities that
--- can move around the map\
--- Retruns an `object_id` to handle the object.
--- **This function does not care to check
--- if the new position is a valid one.**
---@param object table And object to add.
---@param position number[] Position of the node where this object will be added.
---@param groups ?string[] A set of custom groups to the ones this object bellows see Graph:setObjectRules
---@return ObjectID object_id
function Graph:addObject(object, position, groups)
    local object_id = getObjectID(object)
    local node_id = self:positionToMapId(position)
    local node = self:getNode(node_id)
    if node then
        node:addObject(object_id)
    end
    self.objects[object_id] = node_id
    self.objects_ref[object_id] = object
    if groups then
        for _, group in ipairs(groups) do
            if not self.object_groups[group] then
                self.object_groups[group] = {}
            end
            self.object_groups[group][object_id] = true;
        end
    end
    return object_id
end

--- Moves an object from its current position
--- on the graph to a new one.\
---@param object_to_move ObjectID|table The object to move itself or its id.
---@param new_position number[]
---@return boolean result if the translation could be fulfilled
function Graph:translateObject(object_to_move, new_position)
    local old_node = nil
    local object_id = object_to_move --[[@as ObjectID]]
    if self.objects[object_to_move] then
        old_node = self:getNode(self.objects[object_to_move])
    else
        object_id = getObjectID(object_to_move --[[@as table]])
        if self.objects[object_id] then
            old_node = self:getNode(self.objects[object_id])
        else
            return false
        end
    end
    local new_node = self:getNode(self:positionToMapId(new_position))
    if old_node then
        old_node:removeObject(object_id)
    end
    if new_node then
        new_node:addObject(object_id)
        self.objects[object_id] = new_node.id
        return true
    end
    return false
end

--- If exists one or more objects in a position
--- return a list with the objects, otherwise nil.
---@param position number[]
---@return table[] | nil
function Graph:getObjectsAt(position)
    local node = self:getNode(self:positionToMapId(position))
    if node and node:hasObjects() then
        local objects = {}
        for object_id,_ in pairs(node.objects) do
            objects[#objects+1] = self.objects_ref[object_id]
        end
        return objects
    end
    return nil
end


---Removes the object references in the graph
---@param object_to_remove ObjectID|any The object to delete itself or its id.
function Graph:removeObject(object_to_remove)
    local old_node = nil
    local object_id = object_to_remove --[[@as ObjectID]]
    if self.objects[object_to_remove] then
        old_node = self:getNode(self.objects[object_to_remove])
    else
        object_id = getObjectID(object_to_remove --[[@as table]])
        if self.objects[object_id] then
            old_node = self:getNode(self.objects[object_to_remove])
        end
    end
    if old_node then
        old_node:removeObject(object_id)
    end
    for _, group in pairs(self.object_groups) do
        if self.object_groups[group][object_id] then
            self.object_groups[group][object_id] = nil
        end
    end
    self.objects[object_id] = nil
    self.objects_ref[object_id] = nil
end

---Fills the node_map of the graph using the 
---2D map given by the user in the settings.
---@param map_2d table The 2D map to start building the graph.
function Graph:buildFrom2DMap(map_2d)
    local y = 1
    local height = #map_2d
    local width = #map_2d[y]
    while map_2d[y] do
        local x = 1
        while map_2d[y][x] do
            local node_id = Node_getPointId(x, y, 0, width, height, 0)
            local node = Node:new(node_id, {x,y})
            node:setTile(map_2d[y][x])
            self:addNode(node)
            self:connectNodeToNeighbors(node,x,y,0,width,height,0)
            x = x+1
        end
        y = y+1
    end
end

--- Starts building the Graph from the
--- instructions given in the settings
function Graph:build()
    if self.settings.type == '2D' then
        self:buildFrom2DMap(self.settings.map)
    end
    self.weight_map = self.settings.weights or {}
end

--- Creates a new priority heap that will contain
--- Nodes and stores them based on their weight.
---@return Heap
function Graph:newNodeHeap()
    ---@type Heap
    local heap = Heap:new();
    heap:setCompare( function (node_a, node_b)
        -- vale 1 is the Node, value 2 is the accumulated_weight!
        return node_a[2] < node_b[2]
    end )
    return heap
end

--- Creates a new priority heap that will contain
--- Nodes and stores them based on their weight and distance.
---@param position number[] position of the destiny node
---@return Heap
function Graph:newNodeHeapDistance(position)
    ---@type Heap
    local heap = Heap:new();

    local function compareByWeightDistance(start_x, start_y, start_z)
        return (function (a, b)
            local node_a = a[1]
            local node_b = b[1]
            local w_a = a[2]
            local w_b = b[2]
            local ax,ay,az = unpack(node_a.position)
            local bx,by,bz = unpack(node_b.position)
            local cost_a = w_a * (pow(ax-start_x,2) + pow(ay-start_y,2) + pow((az or 0)-(start_z or 0),2))
            local cost_b = w_b * (pow(bx-start_x,2) + pow(by-start_y,2) + pow((bz or 0)-(start_z or 0),2))
            return cost_a < cost_b
        end)
    end

    heap:setCompare(compareByWeightDistance(position[1], position[2], position[3]))
    return heap
end


--- Converts a position given as a list to the
--- corresponding node ID in the map.
--- The ID is constructed based on the graph's settings
--- (dimensions of the map). Returns the node ID.
---@param position number[] The position with the x, y, and z coordinates packed.
---@return NodeID id corresponds to the given position in the graph's map.
function Graph:positionToMapId(position)
    local width = 0
    local height = 0
    local depth = 0
    if self.settings.type == '2D' then
        height = #self.settings.map
        width = #self.settings.map[1]
    end
    local x,y,z = unpack(position)
    return Node_getPointId(x or 0, y or 0, z or 0, width, height, depth)
end

--- Returns the weight of this node in the current weight_map.\
--- If the node is not in the weight_map,
--- return the tile of the node if is a number.\
--- If the tile of the node is not a number, returns
--- the weight as impassable
---@param node Node
---@return number
function Graph:getNodeWeight(node)
    if self.weight_map[node.tile] then
        return self.weight_map[node.tile]
    end
    if node:isTileNumber() then
        return node.tile --[[@as number]]
    end
    return 0
end

--- Do a check against the objects in the node.
--- and if one is on the collision groups, then
--- the node is considered blocked.
---@param node Node
---@param collition_groups ?string[]
---@return boolean
function Graph:isBlockedByObject(node, collition_groups)
    if not collition_groups or not node:hasObjects() then
        return false
    end
    for object_id,_ in pairs(node.objects) do
        for _, group in ipairs(collition_groups) do
            -- the object in the node is in the group?
            if self.object_groups[group] and
                self.object_groups[group][object_id] then
                return true
            end
        end
    end
    return false
end

--- Check if there is possible to go
--- from one connected node to another.\
--- It returns false if the destiny node is
--- impassable terrain, or exists a wall in
--- between nodes.
---@param start Node
---@param destiny Node
---@param direction number
---@return boolean way_is_posible
function Graph:isWallInTheWay(start, destiny, direction)
    -- chek if there is a wall from start to destiny
    local wall_in_start = self.walls[start.id]
    local wall_in_destiny = self.walls[destiny.id]
    local direction_2 = Directions.flip(direction) -- to the direction from destiny to start
    return Directions.isWallFacingDirection(wall_in_start, direction)
        or Directions.isWallFacingDirection(wall_in_destiny, direction_2)
end

--- Check if there is a wall blocking movement between two positions.
--- User-friendly wrapper that takes positions instead of nodes.
---@param start_pos number[]
---@param destiny_pos number[]
---@param direction number
---@return boolean way_is_blocked
function Graph:isWallBetween(start_pos, destiny_pos, direction)
    local start_node = self:getNodeAt(start_pos)
    local destiny_node = self:getNodeAt(destiny_pos)
    
    if not start_node or not destiny_node then
        return true  -- Consider invalid positions as blocked
    end
    
    return self:isWallInTheWay(start_node, destiny_node, direction)
end

--- Check if there is a wall blocking movement between two adjacent positions.
--- Automatically detects the direction based on position difference.
--- Only works for adjacent positions (1 tile apart in cardinal/diagonal directions).
---@param start_pos number[]
---@param destiny_pos number[]
---@return boolean way_is_blocked
function Graph:hasWallBetween(start_pos, destiny_pos)
    local start_node = self:getNodeAt(start_pos)
    local destiny_node = self:getNodeAt(destiny_pos)
    
    if not start_node or not destiny_node then
        return true  -- Consider invalid positions as blocked
    end
    
    -- Calculate position difference
    local dx = destiny_pos[1] - start_pos[1]
    local dy = destiny_pos[2] - start_pos[2]
    local dz = (destiny_pos[3] or 0) - (start_pos[3] or 0)
    
    -- Find matching direction based on movement delta
    for direction, movement in pairs(Directions.movements) do
        if movement.x == dx and movement.y == dy and movement.z == dz then
            return self:isWallInTheWay(start_node, destiny_node, direction)
        end
    end
    
    -- Positions are not adjacent in any valid direction
    return true
end


function Graph:isImpassable(destiny)
    -- check if the destiny is impassable terrain.
    return self:getNodeWeight(destiny) == 0
end

--- Helper function to process a neighbor node during range construction
---@private
---@param node Node The neighbor node to process
---@param current Node The current node
---@param direction string The direction of the neighbor
---@param weight number The accumulated weight to current node
---@param max_cost? number Optional maximum cost limit
---@param collition_groups ?string[] Optional collision groups
---@param nodes_explored table Table of explored nodes
---@param nodes_in_queue table Table of nodes in queue
---@param nodes_in_border table Table of border nodes
---@param node_queue table The priority queue
function Graph:processNeighborNode(node, current, direction, weight, max_cost, collition_groups, nodes_explored, nodes_in_queue, nodes_in_border, node_queue)
    if not node then
        return
    end

    local node_id = node.id
    local node_weight = self:getNodeWeight(node)
    local accumulated_weight = node_weight + weight
    local is_beyond_range = max_cost and (accumulated_weight > max_cost)
    local is_way_possible =
         not self:isImpassable(node) and
         not self:isWallInTheWay(current, node, direction) and
         not self:isBlockedByObject(node, collition_groups)

    if not nodes_explored[node_id] and not nodes_in_queue[node_id] then
        if is_way_possible and not is_beyond_range then
            nodes_in_queue[node_id] = accumulated_weight
            node_queue:push({node, accumulated_weight})
            -- clean the border if we marked it before
            nodes_in_border[node_id] = nil
        else
            local border_weight = accumulated_weight
            if not is_way_possible then
                border_weight = -1
            end
            nodes_in_border[node_id] = border_weight
        end
    end
end

--- Creates a range of nodes that contains all
--- possible paths with the specified maximum
--- movement cost from the starting point.
---
---```lua
--- local start = {2,2}
--- local max_cost = 5
--- local node_range_a = my_graph:constructNodeRange(start, max_cost, 'manhattan')
---```
---
---@param start number[] Starting point
---@param max_cost number max cost of the paths contained
---@param type_movement? string manhattan or diagonal
---@param collition_groups ?string[] a list of object groups to consider as impassable terrain
---@return NodeRange range
function Graph:constructNodeRange(start, max_cost, type_movement, collition_groups)
    local start_node = self:getNode( self:positionToMapId(start) )
    if not start_node then
        return {}
    end
    local start_weight =  0 -- self:getNodeWeight(start_node)
    local nodes_explored = {}
    local nodes_in_queue = {}
    local nodes_in_border = {}
    local node_queue = self:newNodeHeap()
    local allowed_directions = Directions[self.settings.type][type_movement or 'manhattan']

    nodes_explored[start_node.id] = start_weight;
    node_queue:push({start_node, start_weight});
    while node_queue:getSize() > 0 do

        local poped = node_queue:pop()
        local current = poped[1] --[[@as Node]]
        local weight = nodes_in_queue[current.id] or start_weight
        nodes_in_queue[current.id] = nil;

        for _,direction in ipairs( allowed_directions ) do
            local node = current.conections[direction] --[[@as Node]]
            self:processNeighborNode(node, current, direction, weight, max_cost, collition_groups, nodes_explored, nodes_in_queue, nodes_in_border, node_queue)
        end
        nodes_explored[current.id] = weight
    end

    local width = 0
    local height = 0
    local depth = 0
    if self.settings.type == '2D' then
        height = #self.settings.map
        width = #self.settings.map[1]
    end

    local range = NodeRange:new({
        range = max_cost,
        start_id = start_node.id,
        node_traversal_weights = nodes_explored,
        border = nodes_in_border,
        type_movement  = type_movement or "manhattan",
        width = width, height = height, depth = depth,
        map_type = self.settings.type,
        graphGetNode = function (id) return self:getNode(id) end,
        graphIsWallInTheWay = function (origin, destiny, direction)
            return self:isWallInTheWay(origin, destiny, direction) end
    })
    return range
end

--- Returns a range of the explored nodes to reach a certain path
---
---```lua
--- local start = {2,2}
--- local target = {10,10}
--- local node_range_a = my_graph:findPath(start, target, 'manhattan')
---```
---
---@private
---@param use_dikstra boolean 
---@param start number[] Starting point
---@param target number[] Target point
---@param type_movement? string manhattan or diagonal
---@param collition_groups ?string[] a list of object groups to consider as impassable terrain
---@return NodeRange range
function Graph:rangeForDirectPath(use_dikstra, start, target, type_movement, collition_groups)
    local start_node = self:getNode( self:positionToMapId(start) )
    local target_node = self:getNode( self:positionToMapId(target) )
    local range_to_target = 0
    if not start_node or not target_node then
        return NodeRange:new({})
    end
    local start_weight =  0 -- self:getNodeWeight(start_node)
    local nodes_explored = {}
    local nodes_in_queue = {}
    local nodes_in_border = {}
    --- We use a nodeheap that gives priority to closer ones
    local node_queue = self:newNodeHeapDistance(target)
    if use_dikstra then -- we use the normal heap
        node_queue = self:newNodeHeap();
    end
    local allowed_directions = Directions[self.settings.type][type_movement or 'manhattan']
    local found_target = false

    nodes_explored[start_node.id] = start_weight;
    node_queue:push({start_node, start_weight});
    while not found_target do

        local poped = node_queue:pop()
        if not poped then -- no more nodes to search
            break
        end
        local current = poped[1] --[[@as Node]]
        local weight = nodes_in_queue[current.id] or start_weight
        nodes_in_queue[current.id] = nil;

        for _,direction in ipairs( allowed_directions ) do
            local node = current.conections[direction] --[[@as Node]]
            self:processNeighborNode(node, current, direction, weight, nil, collition_groups, nodes_explored, nodes_in_queue, nodes_in_border, node_queue)
        end
        nodes_explored[current.id] = weight
        if isSamePosition(current.position, target) then
            found_target = true
            range_to_target = weight
            -- nodes_explored[node_id] = node_weight
            break
        end
    end

    local width = 0
    local height = 0
    local depth = 0
    if self.settings.type == '2D' then
        height = #self.settings.map
        width = #self.settings.map[1]
    end

    local range = NodeRange:new({
        range = range_to_target,
        start_id = start_node.id,
        node_traversal_weights = nodes_explored,
        border = nodes_in_border,
        type_movement  = type_movement or "manhattan",
        width = width, height = height, depth = depth,
        map_type = self.settings.type,
        graphGetNode = function (id) return self:getNode(id) end,
        graphIsWallInTheWay = function (origin, destiny, direction)
            return self:isWallInTheWay(origin, destiny, direction) end
    })
    return range
end

--- This function uses the A* algorithm to return the
--- node range and the path to get to the point.
--- if no path is found, it returns nothing.
---@param start number[] position of the start point in the grid.
---@param target number[] position of the target point in the grid.
---@param type_movement? string manhattan or diagonal
---@param collition_groups ?string[] a list of object groups to consider as impassable terrain
---@return NodePath | nil, NodeRange | nil
function Graph:findPath(start, target, type_movement, collition_groups)
    local range = self:rangeForDirectPath(false, start, target, type_movement, collition_groups)
    local path = range:getPathTo(target, true)
    return path, range
end

--- This function uses the Dijkstra algorithm to return the
--- node range and the path to get to the point.
--- if no path is found, it returns nothing
---@param start number[] position of the start point
---@param target number[]
---@param type_movement? string manhattan or diagonal
---@param collition_groups ?string[] a list of object groups to consider as impassable terrain
---@return NodePath | nil, NodeRange | nil
function Graph:findPathDijkstra(start, target, type_movement, collition_groups)
    local range = self:rangeForDirectPath(true, start, target, type_movement, collition_groups)
    local path = range:getPathTo(target)
    if path:isEmpty() then
        return nil, nil
    end
    return path, range
end

return Graph