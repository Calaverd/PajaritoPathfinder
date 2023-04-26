local Directions = require "pajarito.directions"
local Heap = require "pajarito.heap";
local Node = require "pajarito.Node";
local NodeRange = require "pajarito.NodeRange";


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
--- maps as a Graph. \
--- Is composed of nodes and allows for
--- operations on them
---@class Graph
---@field node_map {numeber:Node} A list of all the nodes on this graph
---@field weight_map table<number,number> A map for the weight of tiles
---@field walls table<number, number> A map for node id and wall
---@field objects { ObjectID:NodeID } A map to keep track of the position of objects usefull to handle entities that move around the map.
---@field objects_ref {ObjectID:table} A map to get the object refrenced by the object_id
---@field object_groups { string:{ObjectID:boolean} } to store the groups of the objects
---@field settings table A map for that contains contextual info to build the graph
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
    obj.objects = {}
    obj.objects_ref = {}
    obj.object_groups = {}

    setmetatable(obj, self)
    self.__index = self
    return obj
end

--- Returns the node with that id if exist
--- in the graph, otherwise nil.
---@param id_node integer
---@return Node | nil
function Graph:getNode(id_node)
    return self.node_map[id_node]
end

---Adds a node to this graph.
---@param node Node
function Graph:addNode(node)
    self.node_map[node.id] = node;
end

--- Takes the postion of a node in the graph
--- and updates their contained tile value.
---@param position number[]
---@param tile number|string
function Graph:updateNodeTile(position, tile)
    local id = self:positionToMapId(position)
    local node = self:getNode(id)
    if node then
        node:setTile(tile)
    end
end

--- Adds a node to the graph and conects
--- it to their neighbourds if they exist
--- or there is no wall between.\
--- Needs some contextual info about node position
--- and the graph dimentions.
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
        local move = Directions.movements[direction]
        local n_x, n_y, n_z = x+move.x, y+move.y, z+move.z
        local neighbour_id = Node_getPointId(n_x, n_y, n_z, width, height, deep)
        local neighbour = self:getNode(neighbour_id)
        if neighbour then
            new_node:makeTwoWayLinkWith(neighbour, direction)
        end
    end
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
--- given facing orientations.
---@param position number[]
---@param ... number|string
function Graph:setWall(position, ...)
    local id = self:positionToMapId(position)
    self.walls[id] = createWall(...)
end

--- Returns the wall value at the given position.\
--- Of there is no wall, returns nil
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
-- returns a list fill with -1
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
--- Retruns a object_id to handle the object
--- **This function does not cares to check
--- if the new position is a valid one.**
---@param object table And object to add.
---@param position number[] Position of the node were this object will be added.
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

--- Moves an object from their current position
--- on the graph to a new one.\
---@param object_to_move ObjectID|table -- the object to move itself or their id.
---@param new_position number[]
---@return boolean result if the translation could be fullfiled
function Graph:translasteObject(object_to_move, new_position)
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

--- If exist one or more objects in a position
--- returns a list with the objects, otherwise nil.
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
---@param object_to_remove ObjectID|any -- the object to delete itself or their id.
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
---@param map_2d table The 2D map to build the graph from
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
--- Nodes and store them based on their weight.
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

--- Converts a position given as a list the corresponding 
--- node ID in the map. 
--- The ID is constructed based on the graph's settings
--- (dimensions of the map). Returns the node ID.
---@param position number[] The position with the x, y, and z coordinates packed.
---@return NodeID id corresponding to the given position in the graph's map.
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
--- returns the tile of the node if is a number.\
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
--- and if one is on the collition groups, then
--- the node is considered bloked.
---@param node Node
---@param collition_groups ?string[]
---@return boolean
function Graph:isBlokedByObject(node, collition_groups)
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

--- Check if there is posible to go
--- from a connected node to another.\
--- It returs false if the destiny node is
--- impassable terrain, or exist a wall in
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


function Graph:isImpassable(destiny)
    -- check if the destiny is impassable terrain.
    return self:getNodeWeight(destiny) == 0
end

--- Creates a range of nodes that contains all
--- possible paths with the specified maximum
--- movement cost from the starting point. 
---
---Example:
---> local start = {2,2}\
---> local max_cost = 5\
---> local node_range_a = my_graph:constructNodeRange(start, max_cost, 'manhattan')
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

            if not node then
                goto continue
            end

            local node_id = node.id
            local node_weight = self:getNodeWeight(node)
            local accumulated_weight = node_weight+weight
            local is_beyond_range = (accumulated_weight > max_cost)
            local is_way_possible =
                 not self:isImpassable(node) and
                 not self:isWallInTheWay(current, node, direction) and
                 not self:isBlokedByObject(node, collition_groups)
            if not nodes_explored[node_id] -- is not yet explored
                and not nodes_in_queue[node_id] -- is not yet in queue
                then
                if is_way_possible and not is_beyond_range then
                    nodes_in_queue[node_id] = accumulated_weight
                    --- We save to the queue the node and their acumulated weight
                    node_queue:push({node, accumulated_weight})
                    
                    -- clean the border if we marked it before
                    -- (this case only happens if node was behind a wall)
                    nodes_in_border[node_id] = nil
                else
                    local border_weight = accumulated_weight
                    if not is_way_possible then
                        border_weight = -1
                    end
                    nodes_in_border[node_id] = border_weight
                end
            end

            ::continue::
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

return Graph