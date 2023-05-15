# Pajarito Pathfinder

![Main graphical](/img/sample.gif)

Pajarito Pathfinder is a library written on Lua for weighted pathfinder, thought to be used primarily as in turn-based tactics games on a grid (think **Advance Wars** or **Fire Emblem**) or as a solution for terrains of variable movement cost.

Pajarito's main features are:

* Get a list of all the possible position points with a given movement range, and their path cost.
* Terrain weight constraints.
* Working with walls.
* Get **any** possible path inside a movement range upon request.
* Dijkstra or A* pathfinder from point a to b.

Pajarito is *independent of the framework* and can include in any Lua project. Although if your main goal is speed on a uniform cost grid, try [Jumper](https://github.com/Yonaba/Jumper)

## Table of Contents

* [Installation](#installation)
* [Basic Example](#basic-example)
* [Documentation and Examples](#documentation-and-examples)
* [License](#license)

## Installation

To install, just download the `pajarito` directory into your project, and afterward just require it using the path.

```lua
local pajarito = require 'pajarito'
```

## Basic Example

Consider the following map:

![map](/img/map.png)

And this sample code to find a path.

```lua
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
```

The above code generates the following output:

```code
 X # ? ? ? ? ?
 o # ? ? ? ? ?
 o o o o ? ? ?
 ? ? # @ - # ?
 ? ? ? ? ? ? ?
 ? ? ? ? ? ? ?
 ? ? ? ? ? ? ?
 Steep |    Position    | Cost of Movement | Grid Weight
   1   | (x:  4, y:  4) |         0        |      1
   2   | (x:  4, y:  3) |         3        |      3
   3   | (x:  3, y:  3) |         4        |      1
   4   | (x:  2, y:  3) |         5        |      1
   5   | (x:  1, y:  3) |         8        |      3
   6   | (x:  1, y:  2) |         9        |      1
   7   | (x:  1, y:  1) |        10        |      1

```

On a graphical form:

![Main graphical](/img/main_graphical.png)

## Documentation and Examples

For the documentation in detail of the modules of pajarito, visit the [project wiki page](https://github.com/Calaverd/PajaritoPathfinder/wiki).

For the examples, at the moment, go for [our graphical ones made in love2d](https://github.com/Calaverd/Pajarito-Exampes)

## License

Pajarito is licensed under the MIT license.
