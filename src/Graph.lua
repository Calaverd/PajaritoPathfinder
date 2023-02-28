local Directions = require "directions"
local Heap = require "heap";
local Node = require "Node";
local NodeRange = require "NodeRange";


---@diagnostic disable-next-line: deprecated
local unpack = unpack or table.unpack

--- A class for the representation of
--- maps as Graph. \
--- Is composed of nodes and allows for
--- operations on them.
---@class Graph
---@field node_map {numeber:Node} A list of all the nodes on this graph
---@field weight_map table<number,number> A map for the weight of tiles
---@field walls table<number, number> A map for node id and wall
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
        local neighbour_id = Node.getPointId(n_x, n_y, n_z, width, height, deep)
        local neighbour = self:getNode(neighbour_id)
        if neighbour then
            new_node:makeTwoWayLinkWith(neighbour, direction)
        end
    end
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
            local node_id = Node.getPointId(x, y, 0, width, height, 0)
            local node = Node:new(node_id, {x,y})
            node.tile = map_2d[y][x]
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
        local weight_a = self.weight_map[node_a.tile] or node_a.tile
        local weight_b = self.weight_map[node_b.tile] or node_b.tile
        return weight_a < weight_b
    end )
    return heap
end

--- Converts a position given as a list the corresponding 
--- node ID in the map. 
--- The ID is constructed based on the graph's settings
--- (dimensions of the map). Returns the node ID.
---@param position number[] The position with the x, y, and z coordinates packed.
---@return number id corresponding to the given position in the graph's map.
function Graph:listTableToMapId(position)
    local width = 0
    local height = 0
    local depth = 0
    if self.settings.type == '2D' then
        height = #self.settings.map
        width = #self.settings.map[1]
    end
    local x,y,z = unpack(position)
    return Node.getPointId(x or 0, y or 0, z or 0, width, height, depth)
end

--- Check if there is posible to go from a connected
--- node to another. It returs false if the destiny
--- node is impassable terrain, or exist a wall in
--- between nodes.
---@param start Node
---@param destiny Node
---@param direction number
---@return boolean way_is_posible
function Graph:isWayPosible(start, destiny, direction)
    -- check if the destiny is impassable terrain.
    if self.weight_map[destiny.tile] == 0 or destiny.tile == 0 then
        return false
    end
    -- chek if there is a wall from start to destiny
    local wall_in_start = self.walls[start.id]
    if Directions.isWallFacingDirection(wall_in_start, direction) then
        return false
    end
    local wall_in_destiny = self.walls[destiny.id]
    -- get the direction from destiny to start
    local direction_2 = Directions.flip(direction)
    -- chek if there is a wall from destiny to start
    if Directions.isWallFacingDirection(wall_in_destiny, direction_2) then
        return false
    end
    return true
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
---@return NodeRange range
function Graph:constructNodeRange(start, max_cost, type_movement)
    local start_node = self:getNode( self:listTableToMapId(start) )
    if not start_node then
        return {}
    end
    local start_weight = self.weight_map[start_node.tile] or start_node.tile

    local nodes_explored = {}
    local nodes_in_queue = {}
    local nodes_in_border = {}
    local node_queue = self:newNodeHeap()
    local allowed_directions = Directions[self.settings.type][type_movement or 'manhattan']

    nodes_explored[start_node.id] = start_weight;
    node_queue:push(start_node);
    while node_queue:getSize() > 0 do

        local current = node_queue:pop() --[[@as Node]]
        local weight = nodes_in_queue[current.id] or start_weight
        nodes_in_queue[current.id] = nil;

        for _,direction in ipairs( allowed_directions ) do
            local node = current.conections[direction]

            if not node then
                goto continue
            end

            local node_weight = self.weight_map[node.tile] or node.tile
            local total_weight = node_weight+weight
            local is_way_posible = self:isWayPosible(current, node, direction)
            if  nodes_explored[node.id] == nil -- is not yet explored
                and nodes_in_queue[node.id] == nil -- is not yet in queue
                then
                if is_way_posible and not (total_weight > max_cost)  then -- is not beyond range
                    nodes_in_queue[node.id] = total_weight
                    node_queue:push(node)
                else
                    local border_weight = total_weight
                    if not is_way_posible then
                        border_weight = -1
                    end
                    nodes_in_border[node.id] = border_weight
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
        graphGetNode = function (id) return self:getNode(id) end
    })
    return range
end
--[[
local graph1 = Graph:new({
    type = '2D',
    map = {
        {1,1,0},
        {1,0,1},
        {1,1,1}
      },
});
graph1:build();
print('Number of created nodes '..tostring(#graph1.node_map))
local center_node = graph1:getNode(5);
print('Center node conects to: ')
if center_node then
    for direction, node in pairs(center_node.conections) do
        print(' node '..node.id..' at '..Directions.names[direction])
    end
end
local node_range = graph1:constructNodeRange({1,1},5)
print('Nodes in range strating at x:1,y:1 = ')
print(' start node id: '..node_range.start_id)
print(' traverse type: '..node_range.type_movement)
for node_id,weight in pairs(node_range.node_traversal_weights) do
    local x,y = unpack(graph1:getNode(node_id).position)
    print(' node '..' ('..x..', '..y..')'..' -> weight: '..weight)
end
print('find path from [1,1] to [3,3]')
local path = node_range:getPathTo({3,3})
for steep, node in ipairs(path.node_list) do
    local x,y = unpack(node.position)
    print(''..steep..' , ('..x..', '..y..')')
end

print('Using a custom iterator')
print('Path weight is: '..path.weight)
for steep, node in path:getNodes() do
    local x,y = unpack(node.position)
    print(''..steep..' , ('..x..', '..y..')')
end
--]]
return Graph