local Pajarito = require 'pajarito'

local tile_map = {
    { 1, 3, 2, 3, 1, 1, 1 },
    { 1, 3, 2, 2, 2, 1, 1 },
    { 2, 1, 1, 2, 2, 1, 1 },
    { 1, 2, 3, 1, 1, 3, 3 },
    { 1, 2, 2, 2, 1, 3, 2 },
    { 1, 1, 1, 3, 3, 3, 2 },
    { 1, 1, 2, 2, 2, 3, 2 }
  }

local tile_map_width = #tile_map[1]
local tile_map_height = #tile_map

-- Define a table of weights and the default weights cost
-- Note: values equal or less than 0, are considered impassable terrain
local table_of_weights = {}
table_of_weights[1] = 1  --grass    tile 1 -> 1
table_of_weights[2] = 3  --sand     tile 2 -> 3
table_of_weights[3] = 0  --mountain tile 3 -> 0  

-- Set the map using a table with the settings...
local map_graph = Pajarito.Graph:new{ type= '2D', map= tile_map, weights= table_of_weights}

-- ...and construct a node structure using the settings.
map_graph:build()

--- We can get the path with the steps to go from point A to B
--- And also the range with the explored nodes
local found_path, range = map_graph:findPath({4,4}, {1,1})

-- Print the Output, and get info about the map and path.

local x = 1
local y = 1
while y <= tile_map_height do
  x=1
  while x <= tile_map_width do
    -- Check if this point is in the range.
    if range and range:hasPoint({x,y}) then
        if found_path and found_path:hasPoint({x,y}) then
            if x == 4 and y == 4 then
                io.write(" @") -- start point
            elseif x == 1 and y == 1 then
                io.write(" X") -- destiny point
            else
                io.write(" o") -- is path
            end
        else -- is whitin the range but not in the path
            io.write(' -') 
        end
    elseif range and range:borderHasPoint({x,y}) then
        local id = range:borderHasPoint({x,y}) or 0 --[[@as integer]]
        local border_weight = range:getBorderWeight(id)
        if border_weight and border_weight > 0 then
            io.write(' *') -- is pasable
        else
            io.write(' #') -- is impassable
        end
    else -- Is outside the range, aka unexplored.
        io.write(' ?')
    end
    x=x+1
  end
  print()
  y=y+1
end

-- Get more info about the path.
print(' Steep |    Position    | Cost of Movement | Grid Weight ')
local detail = '  %2d   | (x: %2d, y: %2d) |        %2d        |     %2d'
local unpack = unpack or table.unpack
for steep,node in found_path:iterNodes() do
    x, y = unpack(node.position)
    print(detail:format(steep, x, y, range:getReachCostAt(node.id), map_graph:getNodeWeight(node) ))
end