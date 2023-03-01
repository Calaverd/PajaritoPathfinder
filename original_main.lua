local pajarito = require 'pajarito'

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
pajarito.init(tile_map, tile_map_width, tile_map_height)

--set the weights
pajarito.setWeigthTable(table_of_weights)

--[[
build a set of nodes that comprend the set of all the posible
movement range of  starting from the point (x:4,y:14)
]]
pajarito.buildRange(4,4,15)

--[[
Build a list of nodes that form the path.
this build list will be used for pajarito to look up other
requests on the path
]]
local found_path = nil
if pajarito.buildInRangePathTo(1,1) then
    found_path = pajarito.getFoundPath()
end

-- Print the Output 
local x = 1
local y = 1
while y <= tile_map_height do
  x=1
  while x <= tile_map_width do
    if pajarito.isPointInRange(x,y) then --is inside the area
        if pajarito.isPointInFoundPath(x,y) then
            if x ==4 and y == 4 then
                io.write(" @") --start point
            else
                io.write(" 0")
            end
        else
            io.write(' +')
        end
    elseif pajarito.isPointInRangeBorder(x,y) then
            io.write(' ?')
    else
        io.write(' _')
    end
    x=x+1
  end
  print()
  y=y+1
end

if found_path then
    local path_details = ('(x: %2d, y: %2d) | Seep %2d | Movement: %2d | Grid value Cost: %2d ')
    for key,node in ipairs(found_path) do
        print(path_details:format(node.x, node.y, key, node.d, pajarito.getWeightAt(node.x,node.y)))
    end
end