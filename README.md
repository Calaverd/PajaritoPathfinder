# Pajarito Pathfinder

Pajarito Pathfinder is a library written on Lua for weighted pathfinder, in mind to be used primarily on turn based tactics games on a grid like _Advance Wars_ or _Fire Emblem_.

Pajarito main features are:

* Get a list of all the possible position points with a given movement range, and their path cost.
* Terrain weight constraints.
* Get _any_ possible path inside a movement range upon request.
* Also a standard A* Pathfinder (Aka, a straight request of a path from point A to point B) 

Pajarito is *not framework related*,  and can be used on any Lua project. Although if your main goal is speed on a uniform cost grid, try [Jumper](https://github.com/Yonaba/Jumper)

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


```lua
local pajarito = require 'pajarito'

tile_map = { { 1, 3, 2, 3, 1, 1, 1 }, 
             { 1, 3, 2, 2, 2, 1, 1 }, 
             { 2, 1, 1, 2, 2, 1, 1 }, 
             { 1, 2, 3, 1, 1, 3, 3 }, 
             { 1, 2, 2, 2, 1, 3, 2 },
             { 1, 1, 1, 3, 3, 3, 2 },
             { 1, 1, 2, 2, 2, 3, 2 } }

tile_map_width = #tile_map[1]
tile_map_height = #tile_map

--Define a table of weights and the default weights cost
--note, values equal or less than 0, are considered impassable terrain
local table_of_weights = {}
table_of_weights[1] = 1  --grass    tile 1 -> 1
table_of_weights[2] = 3  --dessert  tile 2 -> 3
table_of_weights[3] = 0  --mountain tile 3 -> 0  

--set the map
pajarito.init(tile_map, tile_map_width, tile_map_height)

--set the weights
pajarito.setWeigthTable(table_of_weights)

--[[
build a set of nodes that comprend the set of all the posible
movement range of  starting from the point (x:4,y:4)
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
```

The above code generates the following output

```
 0 ? + ? + + +
 0 ? + + + + +
 0 0 0 0 + + +
 + + ? @ + ? ?
 + + + + + ? _
 + + + ? ? _ _
 + + + + ? _ _
(x:  4, y:  4) | Seep  1 | Movement:  1 | Grid value Cost:  1 
(x:  4, y:  3) | Seep  2 | Movement:  4 | Grid value Cost:  3 
(x:  3, y:  3) | Seep  3 | Movement:  5 | Grid value Cost:  1 
(x:  2, y:  3) | Seep  4 | Movement:  6 | Grid value Cost:  1 
(x:  1, y:  3) | Seep  5 | Movement:  9 | Grid value Cost:  3 
(x:  1, y:  2) | Seep  6 | Movement: 10 | Grid value Cost:  1 
(x:  1, y:  1) | Seep  7 | Movement: 11 | Grid value Cost:  1 

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
