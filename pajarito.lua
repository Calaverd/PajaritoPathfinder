-- define the math functions for some small speed bonus
local FMOD = math.fmod
local MMAX = math.max
local MMIN = math.min
local FLOOR = math.floor
if not FMOD then -- Why are you usign lua < 5.1 ? 
    FMOD = function(a,b) return a - FLOOR(a/b)*b end 
end

--- The Pajarito class.
-- Implementation of the `pajarito` class.
-- Pajarito is a set of functions to handle a very basic pathfinder
-- with a support for weighted nodes. 
-- @usage
  -- to call 
  -- local pajarito = require("pajarito")


-- A simple Heap implementation.
-- Is build to be data agnostic, so it can work comparing
-- arbitrary data types.
-- Is used for the priority queue

function PajaritoHeap()
    local self = {}
    
    local last = 0 --the id of the last inserted item
    local container = {}
    
    function self.compare(a,b)
        return a <= b
    end
    
    function self.clear()
        container = {}
        last = 0
    end
    
    local function getParentOf(id)
        if FMOD(id,2) == 0 then return id/2 end
        return (id-1)/2 
    end
    
    function self.push(data)
        --is first element.
        if last <= 1 then
            container[1] = data
            last = 2
            return nil
        end
        
        local heap_property = false
        local current = last
        local parent = 0
        container[current] = data
        
        while not heap_property do
            parent = getParentOf(current)
            if self.compare( container[current], container[parent] ) then
                --swap current and parent
                container[current] = container[parent]
                container[parent] = data
                current = parent
            else
                heap_property = true
            end
            if current <= 1 then
                heap_property = true
            end        
        end
        last = last+1
        
    end
    
    function self.pop()
        --sawp first and last value
        local top = container[1]
        container[1] = container[last-1]
        container[last-1] = nil
        
        local current = 1
        local heap_property = false
        ---- -- print('*** START ***')
        while not heap_property do
            local left = 2*current
            local right = 2*current + 1
            local choosed = current
            -- Exist the right node?
            if container[right] then
                if self.compare(container[left], container[right]) then
                    choosed = left
                else
                    choosed = right
                end
                
                if self.compare(container[choosed],container[current]) then
                    --swap the value
                    local temp = container[choosed]
                    container[choosed] = container[current]
                    container[current] = temp
                    current = choosed   
                else
                    heap_property = true
                end
            -- Exist the left node?
            elseif container[left] then
                if self.compare(container[left],container[current]) then
                    --swap the value
                    choosed = left
                    local temp = container[choosed]
                    container[choosed] = container[current]
                    container[current] = temp
                    current = choosed   
                else
                    heap_property = true
                end
            else
                heap_property = true
            end
        end

        last = MMAX(last-1,0)
        
        return top
    end
    
    function self.peek()
        return container[1]
    end
    
    function self.getSize()
        return last
    end
    
    return self
end



-- for working with walls, we need to do bitwise operations
-- in this case just `and` and `or`
-- Check lua version to use the best aviable.

local band = nil
local bor = nil
-- we are Lua jit?
local v_number = tonumber(_VERSION:match '(%d%.%d)')
if type(jit) == 'table' then
    -- print('Using Lua Jit Bitwise')
    -- import Lua jit bit operations
    bit = require("bit")
    band = bit.band
    bor = bit.bor
elseif v_number >= 5.3 then
    -- print('Using Lua Built-in Bitwise')
    -- use lua build-in bitwise operators
    -- this ugly thing here is to avoid the script from raise an error
    -- on lower versions of Lua while is parsing
    band = load("local function band(a,b) return (a & b) end return band")()
    bor =  load("local function bor(a,b) return (a | b) end return bor")()
else
    -- no Lua jit nor lua 5.3 >:( 
    -- try import bit32
    local status, bit = pcall(require, "bit32")
    if(status) then
        -- print('Using Lua bit32 Bitwise')
        band = bit.band
        bor = bit.bor
    else
        -- print('Using Pure Lua Bitwise')
        -- Why are you doing this to yourself? 
        -- this should "in theory" work even on Lua 5.0 
        -- from https://stackoverflow.com/questions/5977654/how-do-i-use-the-bitwise-operator-xor-in-lua
        band = function(a,b)
            local p,c=1,0
            while a>0 and b>0 do
                local ra,rb= FMOD(a,2), FMOD(b,2)
                if ra+rb>1 then c=c+p end
                a,b,p=(a-ra)/2,(b-rb)/2,p*2
            end
            return c
        end
        bor = function(a,b)
            local p,c=1,0
            while a+b>0 do
                local ra,rb= FMOD(a,2),FMOD(b,2)
                if ra+rb>0 then c=c+p end
                a,b,p=(a-ra)/2,(b-rb)/2,p*2
            end
            return c
        end
    end
end


--- The `PajaritoNode` node class.<br/>
--  Inits a new `pajarito node`
  -- @class function
  
  -- @param x an integer that references the position x of the node on the map
  -- @param y an integer that references the position y of the node on the map
  -- @param[opt] d a number used to mark the deep or weight of this node
    -- Defaults to zero when omitted.
  -- @param[opt] father an integer used to reference the father of this node on
    -- the list of the marked nodes.
    -- Defaults to nil when omitted.
    
  -- @return itself, a new node
  
  -- @usage
  -- -- A simple node on the position x: 15 y: 1 
  -- local node = pajaritoNode(15,1)
  --
local function pajaritoNode(x,y,d,father)
    local self = {}
    self.x = x
    self.y = y
    self.d = d or 0 --the deep of the node
    self.father = father
    return self
end

--- The `Pajarito` class.<br/>
-- @type Pajarito
local pajarito = {}

-- The grid that refrences the tile map / navigation map
local reference_grid = nil

-- List that contains a correlation key -> val
-- in this case, the key begin the tile number, and the val is the referenced weight
-- we are taking advantage that lua tables works as hash tables or dictionaries.
local lst_weight_ref = nil

-- Number of walls
local num_walls = 0
-- A list of walls 
local lst_of_walls = {}

-- A list of the nodes already visited
-- in this case, the key begin the node id number, and the val is the node itself
-- we are taking advantage that lua tables works as hash tables or dictionaries.
local lst_marked_nodes = {}

-- A queue of the nodes to be visited
local queue_of_nodes = PajaritoHeap()
queue_of_nodes.compare = function(a, b)
    return a.d < b.d  
end

-- A list of the nodes to be visited
-- this one is just to not search on the queue on a value by value
-- in this case, the key begin the node id number, and the val is __true__
-- we are taking advantage that lua tables works as hash tables or dictionaries.
local lst_nodes_on_queue = {} 

-- A list of the nodes on the border, aka, 
-- the nodes determined to be beyond range and/or obstacles
-- in this case, the key begin the node id number, and the val is __true__
-- we are taking advantage that lua tables works as hash tables or dictionaries.  
local lst_border_nodes = {}

-- A table to insert the nodes of a path in a sequential manner
local path_of_nodes = {}

-- A list of the nodes on the path
-- in this case, the key begin the node id number, and the val is __true__
-- we are taking advantage that lua tables works as hash tables or dictionaries.
local lst_nodes_on_path = {}

--the size of the map
local map_width = nil
local map_height = nil

-- A value to store if we should allow diagonal movement
local p_allow_diagonal = false

-- A value to check if we should treat the grid as a hexagonal one
local p_is_hexagonal = false


-- A function to be called each time want a weight value from a 
-- point in the grid, mean to be overryde by the user
-- by default calls to pajarito.getWeightFromTableOf()
local function weightFunctionCall(grid_value)
    return pajarito.getWeightFromTableOf(grid_value)
end

-- Define the type of the grid to use. 
-- we accept the grid
local ARRAY_1D = 1
local ARRAY_2D = 2
local grid_is_type = ARRAY_2D

--  Inits a new `pajarito class`
  -- @class function
  
  -- @param grid a table (2D array) with consecutive indices starting at 1
  -- @param w an integer value, the width of the map
  -- @param h an integer value, the height of the map
  -- @param[opt] diagonal a boolean value, used to tell pajarito that 
    -- we are allowing  diagonal movement
    -- Defaults to false when omitted.
  -- @param[opt] hexagonal a boolean value, used to tell pajarito that
    -- must treat the given grid as a hexagonal node grid
    -- if given __true__ then turn off the diagonal value 
    -- Defaults to false when omitted.
    
  -- @return none
  
  -- @usage
  -- -- Use to initialize the pajarito lib
  
  -- -- To init a map with not diagonal movement
  --  pajarito.init(map,map_size_width,map_size_height)
  
  -- -- To init a map with diagonal movement
  --  pajarito.init(map,map_size_width,map_size_height,true)
  
  -- -- To init a map with hexagonal grid
  --  pajarito.init(map,map_size_width,map_size_height,false,true)
  
function pajarito.init(grid,w,h,diagonal,hexagonal)
    p_allow_diagonal = diagonal or false 
    p_is_hexagonal = hexagonal or false
    if p_is_hexagonal then
        p_allow_diagonal = false
    end
    map_height = h
    map_width = w
    if type(grid[1]) == 'table' then 
        grid_is_type = ARRAY_2D
        if #grid ~= map_height or #grid[1] ~= map_width then
            if map_height == nil or map_width == nil then
                io.write('Pajarito Warning! Not given Grid size.\n')
            else
                io.write('Pajarito Warning! Grid size disparity.\n')
                io.write(
                    ('Given a grid size as %s x %s But grid size is %d x %d\n'):format(
                        tostring(w),tostring(h),#grid[1],#grid)
                    )
                io.write('Using grid size instead.\n')
            end
            map_height = #grid
            map_width = #grid[1]
        end
    end
    if type(grid[1]) == 'number' then
        grid_is_type = ARRAY_1D
        if (map_height == nil and map_width == nil) or 
           (type(map_height)~='number' and type(map_width)~='number') then
            assert(nil,
[[Pajarito Error!
Expected size 'w' and 'h' for one dimension grid.
But are not numbers, or none was given!!!]])
        else
            if map_height == nil then
                if FMOD(#grid,map_width) == 0 and (map_width < #grid) then
                    io.write('Pajarito Warning! Not given valid height for one dimension array.\n')
                    map_height = FLOOR((#grid)/map_width)
                else
                    assert(nil,
("Pajarito Error!\nOne dimension grid of %d elements can not have a width of %s!!!"):format(
    #grid,
    tostring(map_width)))
                end
            else
                if FMOD(#grid,map_height) == 0 and (map_height < #grid) then
                    io.write('Pajarito Warning! Not given valid width for one dimension array.\n')
                    map_width = FLOOR((#grid)/map_height)
                else
                    assert(nil,
("Pajarito Error!\nOne dimension grid of %d elements can not have a height of %s!!!"):format(
    #grid,
    tostring(map_height)))
                end
            end
            io.write(('Usign grid size of %d x %d as placeholder\n'):format(map_width,map_height))
        end
    end
    reference_grid = grid
end


--  Tells `pajarito` to use or not the diagonal movement
  -- @class function
  -- @param diagonal a boolean value
  -- @return none
  
  -- @usage
  -- -- Use to allow/disallow diagonal movement
  -- -- Note that if the grid is already marked as hexagonal
  -- -- this function ignores any value and defaults to false
  -- 
  --  pajarito.useDiagonal(true)

function pajarito.useDiagonal(diagonal)
    p_allow_diagonal = diagonal or false 
    if p_is_hexagonal then
        p_allow_diagonal = false
    end
end

--  Returns if the diagonal movement is allowed
  -- @class function
  -- @param none
  -- @return boolean
  
  -- @usage
  -- -- Use show if the diagonal movement is allowed/disallowed 
  --  val = pajarito.getDiagonal()
  
function pajarito.getDiagonal()
    return p_allow_diagonal
end


--  Tells `pajarito` to treat the given grid as a hexagonal one
  -- @class function
  -- @param hexagonal a boolean value
  -- @return none
  
  -- @usage
  -- -- Use to start or stop treating the grid as a hexagonal one
  --  pajarito.setHexagonal(true)

function pajarito.setHexagonal(hexagonal)
    p_is_hexagonal = hexagonal
end

--  Returns if the grid is treated as a hexagonal one.
  -- @class function
  -- @param none
  -- @return boolean
  
  -- @usage
  -- -- Use show if the grid is treated as a hexagonal one
  --  val = pajarito.getDiagonal()
  
function pajarito.getHexagonal()
    return p_is_hexagonal
end


--  Set a table containing a list of the weights for the values
--  on the grid
  -- @class function
  -- @param w_table a table that contains a set of the values 
    -- where each key refrences a value on the grid.  
  -- @return none
  
  -- @usage
  -- -- Use to set a table containing a list of the weights for the values
  -- -- in this example, we used a table to treat the values of the grid 
  -- -- 1 with a weight of 3; 2,3 with weight 1; and 4 with weight 0.
  -- -- note that all weights bellow or equal to zero are impassable terrain. 
  
  --  my_weigth_table = {[1]=3,[2]=1,[3]=1,[4]=0} 
  --  pajarito.setWeigthTable(my_weigth_table)

function pajarito.setWeigthTable(w_table)
    lst_weight_ref = w_table
end

--  Set a funtion to be called to know the weight of the node 
--  This function should get as argument the stored value on the grid
--  and return the weight for the value as a number
  -- @class function
  -- @param w_function a function to be called to know the weight of the node
  -- @return none
  
  -- @usage
  -- -- Use to set a funtion to be called by the pathfinder to know the weight of the node 
  -- -- in this example, we used a function that returs all odd values as 0 
  -- -- note that all weights bellow or equal to zero are impassable terrain. 
  
  --  function my_function(value_on_grid)
  --    if (value_on_grid % 2 == 0) then
  --      return 1
  --    else
  --      return 0
  --    end
  --  end
  --
  --  pajarito.setWeigthFunction(my_function)

function pajarito.setWeigthFunction(w_function)
    weightFunctionCall = w_function
end

--  Get the weight from the weight table of a value on grid
  -- @class function
  -- @param A value stored on the grid
  -- @return the weight of the value on the weight table if exist,
  -- otherwise, returns the default weigth
  
  -- @usage
  -- -- Used internally to get the weight from the weight table
  -- weight = pajarito.getWeightFromTableOf(value_on_grid)
  
function pajarito.getWeightFromTableOf(value_on_grid)
    if lst_weight_ref then
        return lst_weight_ref[value_on_grid]
    end
    if value_on_grid <= 0 then
        return 0
    end
    return 1
end


--  Get a index for a point on position (x,y)
  -- @class function
  -- @param node_x an integer the x pos of the point on the grid
  -- @param node_y an integer the y pos of the point on the grid  
  -- @return an integer index
  
  -- @usage
  -- -- Use to get the corresponding index for a node position 
  -- -- on the grid map
  -- index = getIndexOfNode(25,10)

function pajarito.getIndexOfNode(node_x,node_y)
    node_y = MMIN(map_height,MMAX(node_y,1))
    node_x = MMIN(map_width,MMAX(node_x,1))
    return ( ( node_y * map_width ) + node_x )
end
local getIndexOfNode = pajarito.getIndexOfNode


local function getIndexOfGrid1D(node_x,node_y)
    node_y = MMIN(map_height,MMAX(node_y,1))-1
    node_x = MMIN(map_width,MMAX(node_x,1))-1
    return ( ((node_y * map_width) + node_x) + 1)
end

--  Get a node x and y position from their index value
  -- @class function
  -- @param index an integer corresponding with a position
     -- of a node on the grid
  -- @return integer position x
  -- @return integer position y
  
  -- @usage
  -- -- Use to get the position of a node 
  -- -- on the grid map from their index
  --  x, y = pajarito.getNodeOfIndex(2510)
  
function pajarito.getNodeOfIndex(index)
    local a = FMOD(index,map_width)
    return FMOD(index,map_width), FLOOR(index/map_width)
end

--  Get if a given point x,y exist on the grid
  -- @class function
  -- @param x an integer, the x pos of the point on the grid
  -- @param y an integer, the y pos of the point on the grid  
  -- @return boolean __true__ if the point exist __false__ otherwise 
  
  -- @usage
  -- -- Use to know if a point x,y exist on the grid
  --  is_on_grid = pajarito.isNodeOnGrid(20,50)
  
function pajarito.isNodeOnGrid(x,y)
    if grid_is_type == ARRAY_2D then
        if reference_grid[y] then
            if reference_grid[y][x] then
                return true
            end
        end
        return false
    end
    if grid_is_type == ARRAY_1D then
        local id = getIndexOfGrid1D(x,y)
        if reference_grid[id] then
            return true
        end
        return false
    end
    return false
end

--  Get the weight of a point on the grid
  -- @class function
  -- @param x an integer, the x pos of the point on the grid
  -- @param y an integer, the y pos of the point on the grid  
  -- @return w integer equal to the weight of the point be this
     --  the value of the tile if not a weight table was set
     --  defaults to 1
  
  -- @usage
  -- -- Use to get the weight of a point on the grid
  --  weight_on_point = getGridWeight(40,12)

local function getGridWeight(x,y)
    local w = 0
    if grid_is_type == ARRAY_2D then
        if reference_grid[y] then
            if reference_grid[y][x] then
                w = reference_grid[y][x]
                return weightFunctionCall(w)
            end
        end
    end
    if grid_is_type == ARRAY_1D then
        local id = getIndexOfGrid1D(x,y)
        if reference_grid[id] then
            w = reference_grid[id]
            return weightFunctionCall(w)
        end
    end
    if w <= 0 then
        return 0
    end
    return 1 --the default weight
end


--  Get if a given point x,y is a obstacle
  -- @class function
  -- @param x an integer, the x pos of the point on the grid
  -- @param y an integer, the y pos of the point on the grid  
  -- @return boolean __true__ if the point weight is minor or equal 
     --  than zero and __false__ otherwise 
  
  -- @usage
  -- -- Use to know if a given point x,y is a obstacle
  --  is_obstacle = pajarito.isNodeObstacle(20,10)

function pajarito.isNodeObstacle(x,y)
    return ( getGridWeight(x,y) <= 0)
end

--  Returns if the point is on the queue to be visited nodes
  -- @class function
  -- @param x an integer, the x pos of the point on the grid
  -- @param y an integer, the y pos of the point on the grid  
  -- @return boolean
  
  -- @usage
  -- -- Use to know if the point is on the queue to be visited
  --  is_on_queue = pajarito.isNodeOnQueue(x,y)
  
function pajarito.isNodeOnQueue(x,y)
    return (lst_nodes_on_queue[getIndexOfNode(x,y)] ~= nil)
end

--  Returns if the point is marked as visited
  -- @class function
  -- @param x an integer, the x pos of the point on the grid
  -- @param y an integer, the y pos of the point on the grid  
  -- @return boolean
  
  -- @usage
  -- -- Use know if the point is marked as visited
  --  is_visited = isNodeMarked(x,y)
  
local function isNodeMarked(x,y)
    return (lst_marked_nodes[getIndexOfNode(x,y)] ~= nil)
end

--  Returns if the point is on the border
  -- @class function
  -- @param x an integer, the x pos of the point on the grid
  -- @param y an integer, the y pos of the point on the grid  
  -- @return boolean
  
  -- @usage
  -- -- Use know if the point is on the queue 
  --  is_on_border = isNodeBorder(x,y)
  
local function isNodeBorder(x,y)
    return (lst_border_nodes[getIndexOfNode(x,y)] ~= nil)
end

--  Gets the node on the list of visited nodes
  -- @class function
  -- @param x an integer, the x pos of the point on the grid
  -- @param y an integer, the y pos of the point on the grid  
  -- @return a pajaritoNode
  
  -- @usage
  -- -- get the node on the list of visited nodes
  --  node = pajarito.getNodeMarkedValue(x,y)
  
function pajarito.getNodeMarkedValue(x,y)
    return lst_marked_nodes[getIndexOfNode(x,y)]
end

--  Checks if a node is valid to be added to the queue
  -- @class function
  -- @param node_x an integer, the x pos of the point on the grid
  -- @param node_y an integer, the y pos of the point on the grid  
  -- @return integer flags

  
  -- @usage
  -- -- Checks if a node is valid to be added to the queue
  -- -- returns a flag 
  -- -- 0 if the node no exist
  -- -- 1 if the node is a obstacle
  -- -- 2 if the node is already on the queue
  -- -- 3 if the node is already marked
  -- -- 4 the node is valid to add to the queue
  --  flag = pajarito.isNodeCompilant(node_x,node_y)

--check if the node is valid
function pajarito.isNodeCompilant(node_x,node_y)
    if pajarito.isNodeOnGrid(node_x,node_y) then
        ---- -- print('exist!!')
        if not pajarito.isNodeObstacle(node_x,node_y) then
            ---- -- print('is not a obstacle!!!')
            if not pajarito.isNodeOnQueue(node_x,node_y) then
                ---- -- print('is not on the queue!!!')
                if not isNodeMarked(node_x,node_y) then
                    --add anyway
                    return 4
                end
                return 3 --'node is marked'
            end
            return 2 --'node is on queue '
        end
        --
        return 1 --'node is a obstacle'
    end
    return 0 --'node no exist'
end


--  Takes two nodes ids and checks if is a wall between
  -- @class function
  -- @param father an integer, the id of the starting node.
  -- @param son an integer, the id of the destiny node. 
  -- @return boolean, true if there is a wall, false otherwise

  -- @usage
  -- -- Takes two nodes id and checks if there is a wall
  -- -- between the two. 
  -- -- returns a boolean flag 
  -- -- false if there is no wall
  -- -- true if there is a wall
  --  is_wall = isWallBetween(father,son)

local function isWallBetween(father,son)
    -- first, is there any walls? 
    if num_walls == 0 then return false end
    -- if father == son then return false end -- you can not collide with yourself...
    
    -- only on a non diagonal, the wall list should have the father or the son on the wall list
    -- if that is not the case, then thre is no walls between they.
    if not p_allow_diagonal and not ( lst_of_walls[father] or lst_of_walls[son] ) then return false end
    
    -- for the diagonals, we need to do more checks for each posible point
    if p_allow_diagonal then
        local front = father+1
        local back  = father-1
        local down  = father+map_width
        local up    = father-map_width
        
        if son == up+1 then -- aka corner E
            if lst_of_walls[father] and band(lst_of_walls[father],64) == 64  then return true end
            if lst_of_walls[son]    and band(lst_of_walls[son],16) == 16     then return true end
            if lst_of_walls[front]  and band(lst_of_walls[front],128) == 128 then return true end
            if lst_of_walls[up]     and band(lst_of_walls[up],32) == 32      then return true end
            return false
        end
        
        if son == up-1 then -- aka corner Q
            if lst_of_walls[father] and band(lst_of_walls[father],128) == 128 then return true end
            if lst_of_walls[son]    and band(lst_of_walls[son],32) == 32      then return true end
            if lst_of_walls[back]   and band(lst_of_walls[back],64) == 64     then return true end
            if lst_of_walls[up]     and band(lst_of_walls[up],16) == 16       then return true end
            return false
        end
        
        if son == down-1 then -- aka corner Z
            if lst_of_walls[father] and band(lst_of_walls[father],16) == 16 then return true end
            if lst_of_walls[son]    and band(lst_of_walls[son],64) == 64    then return true end
            if lst_of_walls[back]   and band(lst_of_walls[back],32) == 32   then return true end
            if lst_of_walls[down]   and band(lst_of_walls[down],128) == 128 then return true end
            return false
        end
        
        if son == down+1 then -- aka corner C
            if lst_of_walls[father] and band(lst_of_walls[father],32) == 32 then return true end
            if lst_of_walls[son]    and band(lst_of_walls[son],128) == 128  then return true end
            if lst_of_walls[front]  and band(lst_of_walls[front],16) == 16  then return true end
            if lst_of_walls[down]   and band(lst_of_walls[down],64) == 64   then return true end
            return false
        end
    end
    
    if father == son-1 then
        if lst_of_walls[father] and band(lst_of_walls[father],4) == 4 then return true end
        if lst_of_walls[son]    and band(lst_of_walls[son],2) == 2    then return true end
        return false
    end
    
    if father == son+1 then
        if lst_of_walls[father] and band(lst_of_walls[father],2) == 2 then return true end
        if lst_of_walls[son]    and band(lst_of_walls[son],4) == 4    then return true end
        return false
    end
    
    if father == son-map_width then 
        if lst_of_walls[father] and band(lst_of_walls[father],1) == 1 then return true end
        if lst_of_walls[son]    and band(lst_of_walls[son],8) == 8    then return true end
        return false
    end
    
    if father == son+map_width then 
        if lst_of_walls[father] and band(lst_of_walls[father],8) == 8 then return true end
        if lst_of_walls[son]    and band(lst_of_walls[son],1) == 1    then return true end
        return false
    end
    
    return false
end


--  Adds the node to the queue by priority.
  -- @class function
  -- @param node_x an integer, the x pos of the point on the grid
  -- @param node_y an integer, the y pos of the point on the grid  
  -- @param d an number of the weight of the node
  -- @param father an integer, the index of the father of this node
  -- @return none
  
  -- @usage
  -- -- this function adds a node to the queue, giving more
  -- -- priority to the nodes with a lower d value to be inserted 
  -- -- to the front.
  --  pajarito.addNodeByPriority(node_x,node_y,d,father)
  
function pajarito.addNodeByPriority(node_x, node_y, d, father_index)
    -- print(' Check node ',node_x,',',node_y,' for father ', pajarito.getNodeOfIndex(father_index))
    local son_index = getIndexOfNode(node_x,node_y)
    local val = pajarito.isNodeCompilant(node_x,node_y)
    if val == 4 then
        if not isWallBetween(father_index, son_index) then
            -- print('    Node compilant!!!')
            queue_of_nodes.push(pajaritoNode(node_x,node_y,d,father_index))
            lst_nodes_on_queue[son_index] = d
        else
            -- print('    Discarted by walls')
        end
    elseif val == 1 then
        pajarito.markBorderNode(node_x,node_y,pajaritoNode(node_x,node_y,-1,father_index))
        --local node = getIndexOfNode(node_x,node_y)
        ---- -- print('Error -> ',val, getGridWeight(node_x,node_y))
        -- print('    marked as -1')
    elseif val == 2 then
        -- print('     is already on queue')
    elseif val == 3  then
        -- print('     was already marked')
    end
end


--  Adds a node to the marked nodes list. 
  -- @class function
  -- @param x an integer, the x pos of the node on the grid
  -- @param y an integer, the y pos of the node on the grid
  -- @param node a pajaritoNode, the node on that point  
  -- @return none
  
  -- @usage
  -- -- add a node using their pos to the marked nodes
  --  pajarito.markNode(x,y,node)
  
function pajarito.markNode(x,y,node)
    lst_marked_nodes[getIndexOfNode(x,y)] = node
end

--  Adds a node to the border nodes list. 
  -- @class function
  -- @param x an integer, the x pos of the node on the grid
  -- @param y an integer, the y pos of the node on the grid
  -- @param node a pajaritoNode, the node on that point  
  -- @return none
  
  -- @usage
  -- -- add a node using their pos to the border nodes
  --  pajarito.markBorderNode(x,y,node)

function pajarito.markBorderNode(x,y,node)
    lst_border_nodes[getIndexOfNode(x,y)] = node
end


--  Check if a node had a better possible father among their already listed neighbors
  -- @class function
  -- @param father a integer index of the father of this node.  
  -- @param x an integer, the x pos of the node on the grid
  -- @param y an integer, the y pos of the node on the grid
  -- @return nf a pajaritoNode as new father if fund, otherwise nil
  -- @return fd an integer as new father distance value, otherwise -1
  
  -- @usage
  -- -- Check if a node had a better possible father on one 
  -- -- of their neighbors. We undestand a 'better possible father'
  -- -- as a node with a lower weight cost
  --  pajarito.findABestFatherNode(father,node_x,node_y)
  
function pajarito.findABestFatherNode(father,node_x,node_y)
    local fd = -1
    local nf = nil
    local son_index = getIndexOfNode(node_x,node_y)
    if lst_marked_nodes[father] then
        fd = lst_marked_nodes[father].d
    else
        return nil
    end
    local tmp_node = nil
    
    if p_is_hexagonal then
        local dir = -1
        if FMOD(node_y,2) == 0 then dir = 1 end
        tmp_node = nil
        if lst_marked_nodes[getIndexOfNode(node_x+dir,node_y-1)] then
            temp_node = lst_marked_nodes[getIndexOfNode(node_x+dir,node_y-1)]
            if temp_node.d < fd then
                fd = temp_node.d
                nf = temp_node
            end
        end
        
        tmp_node = nil
        if lst_marked_nodes[getIndexOfNode(node_x+dir,node_y+1)] then
            temp_node = lst_marked_nodes[getIndexOfNode(node_x+dir,node_y+1)]
            if temp_node.d < fd then
                fd = temp_node.d
                nf = temp_node
            end
        end
        
    end

    if p_allow_diagonal then
        tmp_node = nil
        if lst_marked_nodes[getIndexOfNode(node_x+1,node_y-1)] 
            and not isWallBetween(getIndexOfNode(node_x+1,node_y-1), son_index) 
            then
            temp_node = lst_marked_nodes[getIndexOfNode(node_x+1,node_y-1)]
            if temp_node.d < fd then
                fd = temp_node.d
                nf = temp_node
            end
        end
        temp_node = nil
        if lst_marked_nodes[getIndexOfNode(node_x+1,node_y+1)] 
            and not isWallBetween(getIndexOfNode(node_x+1,node_y+1), son_index) 
            then
            temp_node = lst_marked_nodes[getIndexOfNode(node_x+1,node_y+1)]
            if temp_node.d < fd then
                fd = temp_node.d
                nf = temp_node
            end
        end
        temp_node = nil
        if lst_marked_nodes[getIndexOfNode(node_x-1,node_y+1)] 
            and not isWallBetween(getIndexOfNode(node_x-1,node_y+1), son_index) 
            then
            temp_node = lst_marked_nodes[getIndexOfNode(node_x-1,node_y+1)]
            if temp_node.d < fd then
                fd = temp_node.d
                nf = temp_node
            end
        end
        temp_node = nil
        if lst_marked_nodes[getIndexOfNode(node_x-1,node_y-1)] 
            and not isWallBetween(getIndexOfNode(node_x-1,node_y-1), son_index) 
            then
            temp_node = lst_marked_nodes[getIndexOfNode(node_x-1,node_y-1)]
            if temp_node.d < fd then
                fd = temp_node.d
                nf = temp_node
            end
        end
    end
    
    
    if lst_marked_nodes[getIndexOfNode(node_x,node_y-1)] 
        and not isWallBetween(getIndexOfNode(node_x,node_y-1), son_index) 
        then
        temp_node = lst_marked_nodes[getIndexOfNode(node_x,node_y-1)]
        if temp_node.d < fd then
            fd = temp_node.d
            nf = temp_node
        end
    end
    temp_node = nil
    if lst_marked_nodes[getIndexOfNode(node_x,node_y+1)] 
        and not isWallBetween(getIndexOfNode(node_x,node_y+1), son_index) 
        then
        temp_node = lst_marked_nodes[getIndexOfNode(node_x,node_y+1)]
        if temp_node.d < fd then
            fd = temp_node.d
            nf = temp_node
        end
    end
    temp_node = nil
    if lst_marked_nodes[getIndexOfNode(node_x-1,node_y)] 
        and not isWallBetween(getIndexOfNode(node_x-1,node_y), son_index) 
        then
        temp_node = lst_marked_nodes[getIndexOfNode(node_x-1,node_y)]
        if temp_node.d < fd then
            fd = temp_node.d
            nf = temp_node
        end
    end
    temp_node = nil
    if lst_marked_nodes[getIndexOfNode(node_x+1,node_y)] 
        and not isWallBetween(getIndexOfNode(node_x+1,node_y), son_index) 
        then
        temp_node = lst_marked_nodes[getIndexOfNode(node_x+1,node_y)]
        if temp_node.d < fd then
            fd = temp_node.d
            nf = temp_node
        end
    end
    
    
    return nf,fd
end

--  Get and add a new father node to the requesting node.
  -- @class function
  -- @param father a integer index of the father of this node.  
  -- @param x an integer, the x pos of the node on the grid
  -- @param y an integer, the y pos of the node on the grid
  -- @return boolean __true__ if find, __false__ otherwise
  -- if is found a fahter the node is re-added to the queue
  
  -- @usage
  -- -- Check if a node had a better possible father on one 
  -- -- of their neighbors. We undestand a 'better possible father'
  -- -- as a node with a lower weight cost
  --  pajarito.getNewFatherNode(father,node_x,node_y)
  
function pajarito.getNewFatherNode(father,node_x,node_y)
    -- print('Check node for best possible father')
    local nf,fd = pajarito.findABestFatherNode(father,node_x,node_y)
    if nf then
        pajarito.addNodeByPriority(node_x,node_y,fd,getIndexOfNode(nf.x,nf.y))
        return true
    end
    return false
end


--  Generate a list of all the possible nodes on a given range 
  -- @class function  
  -- @param node_x an integer, the x pos of the starting point
  -- @param node_y an integer, the y pos of the starting point
  -- @param range an number, the max range we can get 
  -- @return none
  
  -- @usage
  -- -- Generates a list containing all possible nodes on a
  -- -- range of movement taking into account the weight
  -- -- this function for itself do not generate a path.
  -- -- if you need a path, use getAndBuildPathInRange
  -- -- afterwards 
  --  getNodesOnRange(node_x,node_y,range)

local function getNodesOnRange(node_x,node_y,range)
    --we add the first node to the queue, we trust the user
    if node_x == nil or node_y == nil then return end --NOPE NOPE NOPE
    ---- -- print('start:',node_x,node_y)
        
    if pajarito.isNodeOnGrid(node_x,node_y) then
        queue_of_nodes.push(pajaritoNode(FLOOR(node_x),FLOOR(node_y)))
        lst_nodes_on_queue[getIndexOfNode(node_x,node_y)] = range
    end
    
    local node = queue_of_nodes.pop()
    -- first node gets also the wheight of the point where it is standing
    -- node.d = node.d + getGridWeight(node.x,node.y)
    while node do
        local index = getIndexOfNode(node.x,node.y)
        local w = node.d --+ getGridWeight(node.x,node.y)
        -- node.d = w
        lst_nodes_on_queue[index] = nil
        -- print()
        -- print('On node ',node.x,',',node.y)
        if not pajarito.getNewFatherNode(node.father,node.x,node.y) then
            if w <= range then
                pajarito.markNode(node.x,node.y,node)
                -- print()
                -- print('~cheking hood~')
                
                -- print(' Node ->')
                pajarito.addNodeByPriority(node.x+1,node.y,w+getGridWeight(node.x+1,node.y),index)
                -- print(' Node ^')
                pajarito.addNodeByPriority(node.x,node.y-1,w+getGridWeight(node.x,node.y-1),index)
                -- print(' Node <-')
                pajarito.addNodeByPriority(node.x-1,node.y,w+getGridWeight(node.x-1,node.y),index)
                -- print(' Node v')
                pajarito.addNodeByPriority(node.x,node.y+1,w+getGridWeight(node.x,node.y+1),index)
                
                if p_allow_diagonal then
                    -- print('  Diagonals')
                    pajarito.addNodeByPriority(node.x+1,node.y+1,w+getGridWeight(node.x+1,node.y+1),index)
                    pajarito.addNodeByPriority(node.x-1,node.y-1,w+getGridWeight(node.x-1,node.y-1),index)
                    pajarito.addNodeByPriority(node.x+1,node.y-1,w+getGridWeight(node.x+1,node.y-1),index)
                    pajarito.addNodeByPriority(node.x-1,node.y+1,w+getGridWeight(node.x-1,node.y+1),index)
                end
                
                if p_is_hexagonal then
                    -- print('   Hexagonals')
                    local dir = -1
                    if FMOD(node.y,2) == 0 then dir = 1 end
                    pajarito.addNodeByPriority(node.x+dir,node.y-1,w,index)
                    pajarito.addNodeByPriority(node.x+dir,node.y+1,w,index)
                end
            else
                pajarito.markBorderNode(node.x,node.y,node)
                --check if it is sourronded
            end
        end
        
        node = queue_of_nodes.pop() 
    end
    
    for k,v in pairs(lst_border_nodes) do
        if lst_marked_nodes[k] then
            lst_border_nodes[k] = nil
        end
    end
end

--  Generate a path of nodes inside a precalculated range
  -- @class function  
  -- @param x an integer, the x pos of the destination point
  -- @param y an integer, the y pos of the destination point
  -- @return boolean true if exist the path, false if failure.
  
  -- @usage
  -- -- Generates a path of nodes between the starting point of 
  -- -- the range and the destination point.
  -- -- Use this function afterwards 
  -- -- of getNodesOnRange
  
  --  buildPathInRange(x,y)
local function buildPathInRange(x,y)
    path_of_nodes = {}
    lst_nodes_on_path = {}
    
    local index = getIndexOfNode(x,y)
    
    if not lst_marked_nodes[index] then
        ---- -- print('Point is not in range',2)
        return false
    end
    --exits the point on the marked ones...
    while lst_marked_nodes[index] or index ~= nil do
        local node = lst_marked_nodes[index]
        lst_nodes_on_path[index] = true
        ---- -- print(node.x,node.y) 
        index = nil
        if node then
            table.insert(path_of_nodes,1,node)
            local father = node.father
            local node_x = node.x
            local node_y = node.y
            index = father
            local nf,fd = pajarito.findABestFatherNode(father,node_x,node_y)
            if nf then
                index = getIndexOfNode(nf.x,nf.y) 
            end
        end
    end
    
    return (#path_of_nodes > 0)
end


--  Generate a path of nodes inside a precalculated range
  -- @class function  
  -- @param x an integer, the x pos of the destination point
  -- @param y an integer, the y pos of the destination point
  -- @return table containing pajaritoNodes on a sequential order
  
  -- @usage
  -- -- Generates a path of nodes between the starting point of 
  -- -- the range and the destination point.
  -- -- Use this function afterwards 
  -- -- of getNodesOnRange
  
  --  getAndBuildPathInRange(x,y)
local function getAndBuildPathInRange(x,y)
    path_of_nodes = {}
    lst_nodes_on_path = {}
    
    local index = getIndexOfNode(x,y)
    
    if not lst_marked_nodes[index] then
        ---- -- print('Point is not in range',2)
        return path_of_nodes 
    end
    --exits the point on the marked ones...
    while lst_marked_nodes[index] or index ~= nil do
        local node = lst_marked_nodes[index]
        lst_nodes_on_path[index] = true
        ---- -- print(node.x,node.y) 
        index = nil
        if node then
            table.insert(path_of_nodes,1,node)
            local father = node.father
            local node_x = node.x
            local node_y = node.y
            index = father
            local nf,fd = pajarito.findABestFatherNode(father,node_x,node_y)
            if nf then
                index = getIndexOfNode(nf.x,nf.y) 
            end
        end
    end
    
    return path_of_nodes
end

-- Get the Manhattan distance between a node "a" and a node "b"  
  -- @class function  
  -- @param a a pajaritoNode 
  -- @param b a pajaritoNode
  -- @return integer distance 
  
  -- @usage
  -- -- Get the Manhattan distance between a node "a" and a node "b"
  -- -- used for the pathfinder. 
  --  distance = pajarito.heuristic(a,b)
  
function pajarito.heuristic(a,b)
    return math.abs(a.x - b.x) + math.abs(a.y - b.y)
    --return (a.x-b.x)*(a.x-b.x) + (a.y-b.y)*(a.y-b.y)
end


--  Generate a path of nodes using A* algorithm  
  -- @class function  
  -- @param node_x an integer, the x pos of the starting point
  -- @param node_y an integer, the y pos of the starting point
  -- @param dest_x an integer, the x pos of the destiny point
  -- @param dest_y an integer, the y pos of the destiny point
  -- @return table containing pajaritoNodes on a sequential order
  
  -- @usage
  -- -- Generates a path of nodes between the starting point and the
  -- -- destination point.  
  --  path = pajarito.pathfinder(node_x,node_y,dest_x,dest_y)
  
function pajarito.pathfinder(node_x,node_y,dest_x,dest_y)
    pajarito.clearNodeInfo()
    --we add the first node to the queue, we trust the user
    if node_x == nil or node_y == nil then return end --NOPE NOPE NOPE
    if dest_x == nil or dest_y == nil then return end --NOPE NOPE NOPE
    ---- -- print('start:',node_x,node_y)
        
    local node_dest =  nil
    local dest_index = 1
    if pajarito.isNodeOnGrid(node_x,node_y) and pajarito.isNodeOnGrid(dest_x,dest_y) then
        queue_of_nodes.push(pajaritoNode(FLOOR(node_x),FLOOR(node_y)))
        lst_nodes_on_queue[getIndexOfNode(node_x,node_y)] = range
        node_dest = pajaritoNode(FLOOR(dest_x),FLOOR(dest_y))
        dest_index = getIndexOfNode(dest_x,dest_y)
    else
        return {}
    end
    
    local break_bucle = nil
    local node = queue_of_nodes.pop()
    while node do
        local index = getIndexOfNode(node.x,node.y)
        local w = node.d
        w = w+MMAX(getGridWeight(node.x,node.y),1)*pajarito.heuristic(node_dest,node)
        node.d = w
        lst_nodes_on_queue[index] = nil

        if not pajarito.getNewFatherNode(node.father,node.x,node.y) then
            
            pajarito.markNode(node.x,node.y,node)
            if dest_index == index then
                break
            end

            pajarito.addNodeByPriority(node.x+1,node.y,w+getGridWeight(node.x+1,node.y),index)
            pajarito.addNodeByPriority(node.x,node.y-1,w+getGridWeight(node.x,node.y-1),index)
            pajarito.addNodeByPriority(node.x-1,node.y,w+getGridWeight(node.x-1,node.y),index)
            pajarito.addNodeByPriority(node.x,node.y+1,w+getGridWeight(node.x,node.y+1),index)
            
            if p_allow_diagonal then
                pajarito.addNodeByPriority(node.x+1,node.y+1,w+getGridWeight(node.x+1,node.y+1),index)
                pajarito.addNodeByPriority(node.x-1,node.y-1,w+getGridWeight(node.x-1,node.y-1),index)
                pajarito.addNodeByPriority(node.x+1,node.y-1,w+getGridWeight(node.x+1,node.y-1),index)
                pajarito.addNodeByPriority(node.x-1,node.y+1,w+getGridWeight(node.x-1,node.y+1),index)
            end
            
            if p_is_hexagonal then
                local dir = -1
                if FMOD(node.y,2) == 0 then dir = 1 end
                pajarito.addNodeByPriority(node.x+dir,node.y-1,w,index)
                pajarito.addNodeByPriority(node.x+dir,node.y+1,w,index)
            end
            
        else
            
            --check if it is sourronded
        end
        node = queue_of_nodes.pop()
    end
    
    --clear the queue
    --sometimes, a better path is
    --still on the to be processed
    --nodes of the queue
    while node do
        local index = getIndexOfNode(node.x,node.y)
        local w = node.d
        w = w+MMAX(getGridWeight(node.x,node.y),1)*pajarito.heuristic(node_dest,node)
        node.d = w
        lst_nodes_on_queue[index] = nil
        
        
        if not pajarito.getNewFatherNode(node.father,node.x,node.y) then
            pajarito.markNode(node.x,node.y,node)
        else
            --pajarito.markBorderNode(node.x,node.y,node)
        end
        node = queue_of_nodes.pop()
    end
    
    lst_border_nodes = lst_nodes_on_queue
    return getAndBuildPathInRange(dest_x,dest_y)
end


-- Get the list of the marked nodes
  -- @class function  
  -- @param none
  -- @return a table containing a dictionaries of the marked nodes 
  
  -- @usage
  -- -- Get the list of the marked nodes
  --  marked_nodes = pajarito.getMarkedNodes()
function pajarito.getMarkedNodes()
    return lst_marked_nodes
end

-- Get the nodes on the border.
  -- @class function  
  -- @param none
  -- @return a table containing a dictionaries of the border nodes 
  
  -- @usage
  -- -- Get the list of the marked nodes
  --  border_nodes = pajarito.getBorderNodes()
function pajarito.getBorderNodes()
    return lst_border_nodes
end


-- Clear all the info generated.
  -- @class function  
  -- @param none
  -- @return none
  
  -- @usage
  -- -- Clear the info generated for the functions
  -- -- getNodesOnRange, getAndBuildPathInRange,
  -- -- and pajarito.pathfinder
  -- -- call this function any time you change the starting point of 
  -- -- getNodesOnRange, or before calling
  -- -- pajarito.pathfinder with new parameters. 
  --  pajarito.clearNodeInfo()
  
function pajarito.clearNodeInfo()
    path_of_nodes = {}
    lst_nodes_on_path = {}
    lst_marked_nodes = {}
    queue_of_nodes.clear()
    lst_nodes_on_queue = {}
    lst_border_nodes = {}
end

-- Transfors a string to an integger for walls
  -- @class function  
  -- @param string to parse.
  -- @return int, wall flags
  
  -- @usage
  -- -- Transfors a string to an integger for walls
  -- -- Wall are given as a string, were each char means a
  -- -- direction were there is a wall
  -- -- [Q][W][E] 
  -- -- [A]   [D]
  -- -- [Z][X][C]
  -- -- Pajarito uses integer to understand the walls, where each bit is a flag
  -- -- each bit must be arrange like this
  -- -- QECZ WDXA
  -- -- So a string like 'WX' or 'XW' is translated to binary as
  -- -- 0000 1010 
  -- -- and that is transformet to the integer "10" on decimal
  -- -- note that S is also equivalent to X
  -- wall = wallStrToInt(string)

local function wallStrToInt(string)
    local str = string.upper(string)
    local int = 0
    if string.find(str, "W") then
        int = bor(int,8)
    end
    if string.find(str, "D") then
        int = bor(int,4)
    end
    if string.find(str, "A") then
        int = bor(int,2)
    end
    if string.find(str, "S") or  string.find(str, "X") then
        int = bor(int,1)
    end
    -- Diagonal walls
    if string.find(str, "Q") then
        int = bor(int,128)
    end
    if string.find(str, "E") then
        int = bor(int,64)
    end
    if string.find(str, "C") then
        int = bor(int,32)
    end
    if string.find(str, "Z") then
        int = bor(int,16)
    end
    return int
end

-- Adds a wall into the wall list
  -- @class function  
  -- @param x position of the wall
  -- @param y position of the wall
  -- @param val of the wall, can be an string or a integger
  -- @return success int.
  
  -- @usage
  -- -- Adds a wall into the wall list
  -- -- it can recive the value as a integger or parse the string
  -- -- using `wallStrToInt`
  -- -- if the value given goes against an already exiting value
  -- -- on the wall list, they will be merged, so use `pajarito.setWall`
  -- -- to replace the value of a wall 
  -- -- if the value given is nil, `pajarito.addWall` does nothing, so 
  -- -- use `pajarito.removeWall` instead
  -- -- returns 1 if success
  -- -- returns 0 if failure
  -- -- returns 2 if collision and merge.
  --  pajarito.addWall(x,y,val)

function pajarito.addWall(x,y,val)
    local int = val
    if type(val) == 'string' then
        int = wallStrToInt(val)
    end
    if int and int ~= 0 then
        local index = getIndexOfNode(x,y)
        if not lst_of_walls[ index ] then
            num_walls = num_walls+1
            lst_of_walls[ index ] = FLOOR(int)
            -- print('Adding wall on ',x,y,'str value:',val,' Bit value:',int)
            return 1
        else
            local merged = bor(lst_of_walls[ index ],int)
            -- print('Collision of wall on ',x,y)
            -- print('Merge old value of',lst_of_walls[ index ],'with',int,'as',merged)
            lst_of_walls[ index ] = merged
            return 2
        end
        
    end
    return 0
end

-- Sets a new type for an already existing wall on the wall list
  -- @class function  
  -- @param x position of the wall
  -- @param y position of the wall
  -- @param val of the wall, can be an string or a integger
  -- @return none
  
  -- @usage
  -- -- Sets a new type for an already existing wall on the wall list
  -- -- it can recive the value as a integger or parse the string
  -- -- using `wallStrToInt`
  -- -- if the wall not exist on the wall list, does nothing.
  -- -- if the value given is nil, acts equal than `pajarito.removeWall`
  --  pajarito.setWall(x,y,val)
  
function pajarito.setWall(x,y,val)
    local index = getIndexOfNode(x,y)
    if lst_of_walls[index] then
        local int = val
        if type(val) == 'string' then
            int = wallStrToInt(val)
        end
        if int and int ~= 0 then
            lst_of_walls[ index ] = int
        else
            -- remvoe the wall
            num_walls = num_walls-1
            lst_of_walls[ index ] = nil
        end
    end
end

-- Removes a wall from the wall list
  -- @class function  
  -- @param x position of the wall
  -- @param y position of the wall
  -- @return none
  
  -- @usage
  -- -- Removes a specific wall from the list
  --  pajarito.removeWall(x,y)
  
function pajarito.removeWall(x,y)
    if lst_of_walls[ getIndexOfNode(x,y) ] then
        num_walls = num_walls-1
        lst_of_walls[ getIndexOfNode(x,y) ] = nil
    end
end


-- Clear all the walls. 
  -- @class function  
  -- @param none
  -- @return none
  
  -- @usage
  -- -- Clear all the walls from the list. 
  --  pajarito.clearWalls()

function pajarito.clearWalls()
    lst_of_walls = {}
end

--this functions are just a wrap for more user friendly api

--  Get if a given point x,y exist on the calculated path
  -- @class function
  -- @param x an integer, the x pos of the point on the grid
  -- @param y an integer, the y pos of the point on the grid  
  -- @return boolean __true__ if the point exist __false__ otherwise 
  
  -- @usage
  -- -- Use to get if a point x,y exist on the calculated path
  --  is_on_path = pajarito.isNodeOnGrid(20,50)
  
function pajarito.isPointInFoundPath(x,y)
    return (lst_nodes_on_path[getIndexOfNode(x,y)] ~= nil)
end


function pajarito.buildRange(node_x,node_y,range)
    pajarito.clearNodeInfo()
    getNodesOnRange(node_x,node_y,range)
end

function pajarito.buildInRangePathTo(x,y)
    return buildPathInRange(x,y)
end

function pajarito.getFoundPath()
    return path_of_nodes
end

function pajarito.isPointInRange(x,y)
    return isNodeMarked(x,y)
end

function pajarito.isPointInRangeBorder(x,y)
    return isNodeBorder(x,y)
end

function pajarito.getWeightAt(x,y)
    if pajarito.isNodeOnGrid(x,y) then
        return getGridWeight(x,y)
    end
    return 0
end

function pajarito.getInRangeNodes()
    return pajarito.getMarkedNodes()
end

function pajarito.setWallsByList(wall_list)
    local layer = {}
    for _, wall_pos in ipairs(wall_list) do
        pajarito.addWall(wall_pos[1], wall_pos[2], wall_pos[3])
    end
end

return pajarito

