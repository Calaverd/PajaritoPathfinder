local PajaritoGraph = require 'Graph'

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

--Define a table of weights and the default weights cost
--note, values equal or less than 0, are considered impassable terrain
local table_of_weights = {}
table_of_weights[1] = 1  --grass    tile 1 -> 1
table_of_weights[2] = 3  --woods    tile 2 -> 3
table_of_weights[3] = 0  --mountain tile 3 -> 0  

--set the map
local pajarito = PajaritoGraph:new({type = '2D', map = tile_map, weights = table_of_weights})
pajarito:build()

local range = pajarito:constructNodeRange({4,4},15)
local found_path = range:getPathTo({1,1})

-- Print the Output 
local x = 1
local y = 1
while y <= tile_map_height do
  x=1
  while x <= tile_map_width do
    if range:hasPoint({x,y}) then --is inside the area
        if found_path:hasPoint({x,y}) then
            if x ==4 and y == 4 then
                io.write(" @") --start point
            else
                io.write(" 0")
            end
        else
            io.write(' +')
        end
    elseif range:borderHasPoint({x,y}) then
        local id = range:borderHasPoint({x,y}) or 0
        local border_weight = range:getBorderWeight(id)
        if border_weight and border_weight > 0 then
            io.write(' *') -- is pasable
        else
            io.write(' !') -- is impassable
        end
    else
        io.write(' _')
    end
    x=x+1
  end
  print()
  y=y+1
end


local path_details = ('(x: %2d, y: %2d) | Seep %2d | Movement: %2d | Grid value Cost: %2d ')
local unpack = unpack or table.unpack
for steep,node in found_path:getNodes()  do
    local x, y = unpack(node.position)
    print(path_details:format(x, y, steep, range:getReachCostAt(node.id), pajarito:getNodeWeight(node) ))
end