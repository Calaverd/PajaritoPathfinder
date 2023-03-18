# Pajarito Pathfinder

Pajarito Pathfinder is a library written on Lua for weighted pathfinder, in mind to be used primarily on turn based tactics games on a grid like _Advance Wars_ or _Fire Emblem_.

Pajarito main features are:

* Get a list of all the possible position points with a given movement range, and their path cost.
* Terrain weight constraints.
* Working with walls on edges.
* Get _any_ possible path inside a movement range upon request.
* Also a standard A* Pathfinder (Aka, a straight request of a path from point A to point B) 

Pajarito is *not framework related*, and can be used on any Lua project. Although if your main goal is speed on a uniform cost grid, try [Jumper](https://github.com/Yonaba/Jumper)

- [Example](#Example)
- [Basic API and Usage](#basic-api-and-usage)
   * [Requiring the library](#requiring-the-library)
   * [Initializing a new map](#initializing-a-new-map)
   * [Set a cost-weight table](#set-a-cost-weight-table)
   * [Build a movement range](#build-a-movement-range)
   * [The path inside a movement range](#the-paht-inside-a-movement-range)
   * [Using Diagonal](#using-diagonal)
   * [Using Pajarito as a simple pathfinder](#using-pajarito-as-a-simple-pathfinder)
   * [Requesting point info](#requesting-point-info)
       + [Node structure](#requesting-point-info)
       + [Is Point in the found path](#is-point-in-the-found-path)
       + [Is point inside the range](#is-point-inside-the-range)
       + [Is point in the border of the range](#is-point-in-the-border-of-the-range)
       + [Get the weight of a point on the grid](#get-the-weight-of-a-point-on-the-grid)
- [License](#License)
<!--      + [Sub-sub-heading](#sub-sub-heading)-->

## Example

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


-- Build a range of nodes. It will be the set of all possible
-- movements starting from the point (x:4,y:4) within
-- the range cost of 15
-- We can use this range to get all possible paths from
-- the starting point to any other node in it.
local range = map_graph:constructNodeRange({4,4},15)


-- From the nodes in the range, now can be build a list
-- of nodes for the path from the starting point of the
-- range in (x:4, y:4) to (x:1, y:1)
local found_path = range:getPathTo({1,1})

-- Print the Output
local x = 1
local y = 1
while y <= tile_map_height do
  x=1
  while x <= tile_map_width do
    -- Check if this point is in the range.
    if range:hasPoint({x,y}) then
        if found_path:hasPoint({x,y}) then
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
    elseif range:borderHasPoint({x,y}) then
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
for steep,node in found_path:getNodes()  do
    x, y = unpack(node.position)
    print(detail:format(steep, x, y, range:getReachCostAt(node.id), map_graph:getNodeWeight(node) ))
end
```

The above code generates the following output

```
 X # - # - - -
 o # - - - - -
 o o o o - - -
 - - # @ - # #
 - - - - - # ?
 - - - # # ? ?
 - - - - * ? ?
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

## Basic API and Usage

### Requiring the library

```lua
local pajarito = require 'pajarito'
```

That's all. Let's now explain the basic methods and their function on detail, so you can get the most of Pajarito as well.

### Initializing a new map

```lua
pajarito.init(map, map_width, map_height, diagonal)
```

To start, Pajarito needs to get a map to work. The map can be a table of one or two dimensions, with consecutive indices/keys starting at 1. Map width is the number of columns, and Map height the number of rows of the given map. Diagonal is a _boolean_ flag to set to allow the movement on diagonal tiles, by default is __false__, more details in [diagonal bellow](#using-diagonal).

So then

```lua
map = { 
        1, 3, 2, 3, 1, 1, 1, 
        1, 3, 2, 2, 2, 1, 1, 
        2, 1, 1, 2, 2, 1, 1, 
        1, 2, 3, 1, 1, 3, 3, 
        1, 2, 2, 2, 1, 3, 2,
        1, 1, 1, 3, 3, 3, 2,
        1, 1, 2, 2, 2, 3, 2 
        }
```

and 

```lua
map = { 
      { 1, 3, 2, 3, 1, 1, 1 }, 
      { 1, 3, 2, 2, 2, 1, 1 }, 
      { 2, 1, 1, 2, 2, 1, 1 }, 
      { 1, 2, 3, 1, 1, 3, 3 }, 
      { 1, 2, 2, 2, 1, 3, 2 },
      { 1, 1, 1, 3, 3, 3, 2 },
      { 1, 1, 2, 2, 2, 3, 2 }
      }
```

Are both valid map inputs.


### Set a cost-weight table

```lua
pajarito.setWeigthTable(table_of_weights)
```

This function make an association of a grid value to a table of weights. The table can be build on the following form:

```lua
table_of_weights[grid value] = weight  
```

All weights less or equal than 0 are treated as walls or impassable terrain. 

Is necessary set a weight table, at least only with the weights bigger than 1 of each corresponding grid value. If is not defined a weight for a grid value on the table, ***by default, all grid values _greater than 0_ are treated with a weight of __1__***. You can call this function swap between different weight tables on the same map before building a new movement range. 

### Build a movement range

```lua
pajarito.buildRange(start_x,start_y,movement_range_value)
```

Generates a hash table containing all possible nodes of the given movement range, at the position start_x,start_y taking into account the weight of the map. This function for itself do not generate a path. All request of `pajarito.buildPathInRange` will be made on a previously builded range.

### The path inside a movement range

```lua
pajarito.buildInRangePathTo(goal_x,goal_y) 
```

First is need to know if a path to the point is possible inside the range. For that we call first `pajarito.buildInRangePathTo(goal_x,goal_y)`. This function checks the existence of a path from the defined as start point on `pajarito.buildRange()`. If the path exists, then returns __true__, otherwise, __false__.

Later we can request the path using:

```lua
path = pajarito.getFoundPath()
```

If the path exist, returns a __list of _nodes___, where the first is the starting point, and the last is the goal point. Otherwise, returns a __empty list__.

### Using diagonal

![Diagonal example](/img/diagonal.png)

Diagonal is a flag that indicates to pajarito to use also the diagonal nodes of grid. It can be set as a optional parameter of `pajarito.init`, or using

```lua
pajarito.useDiagonal(diagonal_flag)
```

Where `diagonal_flag` is a _boolean_ type.

Diagonal can be set any time, and affects the following calls to `pajarito.buildRange` and  `pajarito.pathfinder`.

### Using Pajarito as a simple pathfinder

```lua
path = pajarito.pathfinder(start_x, start_y, goal_x, goal_y)
```
Pajarito offers a simple implementation of the A* pathfinder algorithm. It requires the same setup as `pajarito.buildPathInRange`, in other words, to be set the map and a table of weights. After that, can be called to find a path from the position start_x,start_y to the goal_x,goal_y.

Returns a __list of *nodes*__, where the first is the starting point, and the last is the goal point. Otherwise, returns a __empty list__.

Because of being a more straightforward function build on top, `pajarito.isPointInRangeBorder(x,y)` do not generate borders, `node.d` shows not the distance, but _the heuristic value_ of the distance, and `pajarito.isPointInRange(x,y)` shows all the explored points in the grid before finding the goal.

***Avoid use it at the same time that  `pajarito.buildPathInRange` or vise versa*** both functions clear the data of the grid to build their paths. Calling one will overwrite the data of the other. 


### Requesting point info

Because is common to want to know the status of a point often (is in range, is path, is border range) to draw to screen, Pajarito stores the nodes on a hash table to quick access avoiding comparison of the requested point against every node on the grid. This info do not change until `pajarito.buildRange()` is called on a new start position.

#### Node structure

Pajarito is build around a __node__ type with the following attributes:
* `node.x` The _x_ position of the node on the grid.
* `node.y` The _y_ position of the node on the grid.
* `node.d` The deep or distance of this node in relative to the start point.
* `node.father` A hash table id of the preceding node.

#### Is point inside the range 

```lua
pajarito.isPointInRange(x,y)
```
Request if a point is inside of a range, if is the case, then returns __true__, otherwise, __false__.

#### Is Point in the found path

```lua
pajarito.isPointInFoundPath(x,y)
```

Request if a point is inside of the found path, if is the case, then returns __true__, otherwise, __false__. If not path exist always returns __false__.

#### Is point in the border of the range

```lua
pajarito.isPointInRangeBorder(x,y) 
```

Request if a point is part of the border of the range, understanding the border as the set of _nodes_ with at least a neighbor _node_ that is inside the range. If this is the case, then returns __true__, otherwise, __false__.

#### Get the weight of a point on the grid

```lua
pajarito.getWeightAt(x,y)
```

Compare the grid value on the grid at that position against their given value on the weighted table, and returns that value. If the point is outside the grid returns __0__, if there is not defined a weight for the grid value on the table, then all values _greater than 0_ are returned with a weight of __1__


## License

pajarito.lua is licensed under the MIT license.
