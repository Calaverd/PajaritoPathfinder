--- The Pajarito class.
-- Implementation of the `pajarito` class.
-- Pajarito is a set of functions to handle a very basic pathfinder
-- with a support for weighted nodes. 
-- @usage
  -- to call 
  -- local pajarito = require("pajarito")

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

-- A list of the nodes already visited
-- in this case, the key begin the node id number, and the val is the node itself
-- we are taking advantage that lua tables works as hash tables or dictionaries.
local lst_marked_nodes = {}

-- A queue of the nodes to be visited
local queue_of_nodes = {}

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

--  Get a index for a point on position (x,y)
  -- @class function
  -- @param node_x an integer the x pos of the point on the grid
  -- @param node_y an integer the y pos of the point on the grid  
  -- @return an integer index
  
  -- @usage
  -- -- Use to get the corresponding index for a node position 
  -- -- on the grid map
  -- index = pajarito.getIndexOfNode(25,10)

function pajarito.getIndexOfNode(node_x,node_y)
    return ( ( node_y * map_width ) + node_x )
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
    local a = math.fmod(index,map_width)
    return math.fmod(index,map_width), math.floor(index/map_width)
end

--  Get if a given point x,y exist on the grid
  -- @class function
  -- @param x an integer, the x pos of the point on the grid
  -- @param y an integer, the y pos of the point on the grid  
  -- @return boolean __true__ if the point exist __false__ otherwise 
  
  -- @usage
  -- -- Use to get if a point x,y exist on the grid
  --  is_on_grid = pajarito.isNodeOnGrid(20,50)
  
function pajarito.isNodeOnGrid(x,y)
    if reference_grid[y] then
        if reference_grid[y][x] then
            return true
        end
    end
    return false
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
    return ( pajarito.getGridWeight(x,y) <= 0)
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
  --  weight_on_point = pajarito.getGridWeight(40,12)

function pajarito.getGridWeight(x,y)
    if reference_grid[y] then
        if reference_grid[y][x] then
            local w = reference_grid[y][x]
            if lst_weight_ref then
                return lst_weight_ref[w]
            end
            return w
        end
    end
    return 1 --the default weight
end

--  Returns if the point is on the queue
  -- @class function
  -- @param x an integer, the x pos of the point on the grid
  -- @param y an integer, the y pos of the point on the grid  
  -- @return boolean
  
  -- @usage
  -- -- Use know if the point is on the queue 
  --  is_on_queue = pajarito.isNodeOnQueue(x,y)
  
function pajarito.isNodeOnQueue(x,y)
    return (lst_nodes_on_queue[pajarito.getIndexOfNode(x,y)] ~= nil)
end

--  Returns if the point is marked as visited
  -- @class function
  -- @param x an integer, the x pos of the point on the grid
  -- @param y an integer, the y pos of the point on the grid  
  -- @return boolean
  
  -- @usage
  -- -- Use know if the point is marked as visited
  --  is_visited = pajarito.isNodeMarked(x,y)
  
function pajarito.isNodeMarked(x,y)
    return (lst_marked_nodes[pajarito.getIndexOfNode(x,y)] ~= nil)
end

--  Returns if the point is on the border
  -- @class function
  -- @param x an integer, the x pos of the point on the grid
  -- @param y an integer, the y pos of the point on the grid  
  -- @return boolean
  
  -- @usage
  -- -- Use know if the point is on the queue 
  --  is_on_border = pajarito.isNodeBorder(x,y)
  
function pajarito.isNodeBorder(x,y)
    return (lst_border_nodes[pajarito.getIndexOfNode(x,y)] ~= nil)
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
    return lst_marked_nodes[pajarito.getIndexOfNode(x,y)]
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
        --print('exist!!')
        if not pajarito.isNodeObstacle(node_x,node_y) then
            --print('is not a obstacle!!!')
            if not pajarito.isNodeOnQueue(node_x,node_y) then
                --print('is not on the queue!!!')
                if not pajarito.isNodeMarked(node_x,node_y) then
                    --add aniway
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
  
function pajarito.addNodeByPriority(node_x,node_y,d,father)
    local val = pajarito.isNodeCompilant(node_x,node_y)
    if val == 4 then
        
        local i = 1
        while queue_of_nodes[i] do
            local n = queue_of_nodes[i]
            if n.d >= d then
                break
            end
            i=i+1
        end
        
        table.insert(queue_of_nodes,i,pajaritoNode(node_x,node_y,d,father))
        lst_nodes_on_queue[pajarito.getIndexOfNode(node_x,node_y)] = d
    elseif val == 1 then
        pajarito.markBorderNode(node_x,node_y,pajaritoNode(node_x,node_y,-1,father))
        --local node = pajarito.getIndexOfNode(node_x,node_y)
        --print('Error -> ',val, pajarito.getGridWeight(node_x,node_y))
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
    lst_marked_nodes[pajarito.getIndexOfNode(x,y)] = node
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
    lst_border_nodes[pajarito.getIndexOfNode(x,y)] = node
end


--  Check if a node had a better possible father on one of their neighbors
  -- @class function
  -- @param father a integer index of the father of this node.  
  -- @param x an integer, the x pos of the node on the grid
  -- @param y an integer, the y pos of the node on the grid
  -- @return boolean __true__ if find, __false__ otherwise
  -- if find a neighbors the node is re-added to the queue
  
  -- @usage
  -- -- Check if a node had a better possible father on one 
  -- -- of their neighbors. We undestand a 'better possible father'
  -- -- as a node with a lower weight cost
  --  pajarito.findABestFatherNode(father,node_x,node_y)
  
function pajarito.findABestFatherNode(father,node_x,node_y)
    local fd = -1
    local nf = nil
    if lst_marked_nodes[father] then
        fd = lst_marked_nodes[father].d
    else
        return false
    end
    local tmp_node = nil
    if lst_marked_nodes[pajarito.getIndexOfNode(node_x,node_y-1)] then
        temp_node = lst_marked_nodes[pajarito.getIndexOfNode(node_x,node_y-1)]
        if temp_node.d < fd then
            fd = temp_node.d
            nf = temp_node
        end
    end
    temp_node = nil
    if lst_marked_nodes[pajarito.getIndexOfNode(node_x,node_y+1)] then
        temp_node = lst_marked_nodes[pajarito.getIndexOfNode(node_x,node_y+1)]
        if temp_node.d < fd then
            fd = temp_node.d
            nf = temp_node
        end
    end
    temp_node = nil
    if lst_marked_nodes[pajarito.getIndexOfNode(node_x-1,node_y)] then
        temp_node = lst_marked_nodes[pajarito.getIndexOfNode(node_x-1,node_y)]
        if temp_node.d < fd then
            fd = temp_node.d
            nf = temp_node
        end
    end
    temp_node = nil
    if lst_marked_nodes[pajarito.getIndexOfNode(node_x+1,node_y)] then
        temp_node = lst_marked_nodes[pajarito.getIndexOfNode(node_x+1,node_y)]
        if temp_node.d < fd then
            fd = temp_node.d
            nf = temp_node
        end
    end
    --IF WE DO NOT FIND IT, CHEK FOR THE DIAGONALS TO!!!
    if p_allow_diagonal and nf == nil then
        tmp_node = nil
        if lst_marked_nodes[pajarito.getIndexOfNode(node_x+1,node_y-1)] then
            temp_node = lst_marked_nodes[pajarito.getIndexOfNode(node_x+1,node_y-1)]
            if temp_node.d < fd then
                fd = temp_node.d
                nf = temp_node
            end
        end
        temp_node = nil
        if lst_marked_nodes[pajarito.getIndexOfNode(node_x+1,node_y+1)] then
            temp_node = lst_marked_nodes[pajarito.getIndexOfNode(node_x+1,node_y+1)]
            if temp_node.d < fd then
                fd = temp_node.d
                nf = temp_node
            end
        end
        temp_node = nil
        if lst_marked_nodes[pajarito.getIndexOfNode(node_x-1,node_y+1)] then
            temp_node = lst_marked_nodes[pajarito.getIndexOfNode(node_x-1,node_y+1)]
            if temp_node.d < fd then
                fd = temp_node.d
                nf = temp_node
            end
        end
        temp_node = nil
        if lst_marked_nodes[pajarito.getIndexOfNode(node_x-1,node_y-1)] then
            temp_node = lst_marked_nodes[pajarito.getIndexOfNode(node_x-1,node_y-1)]
            if temp_node.d < fd then
                fd = temp_node.d
                nf = temp_node
            end
        end
    end

    if nf then
        pajarito.addNodeByPriority(node_x,node_y,fd,pajarito.getIndexOfNode(nf.x,nf.y))
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
  -- -- if you need a path, use pajarito.getPathInsideRange
  -- -- afterwards 
  --  pajarito.getNodesOnRange(node_x,node_y,range)

function pajarito.getNodesOnRange(node_x,node_y,range)
    --we add the first node to the queue, we trust the user
    if node_x == nil or node_y == nil then return end --NOPE NOPE NOPE
    --print('start:',node_x,node_y)
        
    if pajarito.isNodeOnGrid(node_x,node_y) then
        table.insert(queue_of_nodes,pajaritoNode(math.floor(node_x),math.floor(node_y)))
        lst_nodes_on_queue[pajarito.getIndexOfNode(node_x,node_y)] = range
    end
    
    while queue_of_nodes[1] do
        local node = queue_of_nodes[1]
        local index = pajarito.getIndexOfNode(node.x,node.y)
        local w = node.d+math.max(pajarito.getGridWeight(node.x,node.y),1)
        node.d = w
        table.remove(queue_of_nodes,1)
        lst_nodes_on_queue[index] = nil
        
        if not pajarito.findABestFatherNode(node.father,node.x,node.y) then
            if w <= range then
                pajarito.markNode(node.x,node.y,node)
                
                if not p_is_hexagonal then
                    if p_allow_diagonal then
                        pajarito.addNodeByPriority(node.x+1,node.y+1,w,index)
                        pajarito.addNodeByPriority(node.x-1,node.y-1,w,index)
                        pajarito.addNodeByPriority(node.x+1,node.y-1,w,index)
                        pajarito.addNodeByPriority(node.x-1,node.y+1,w,index)
                    end

                    pajarito.addNodeByPriority(node.x+1,node.y,w,index)
                    pajarito.addNodeByPriority(node.x-1,node.y,w,index)
                    pajarito.addNodeByPriority(node.x,node.y-1,w,index)
                    pajarito.addNodeByPriority(node.x,node.y+1,w,index)
                    
                else
                    local dir = -1
                    if math.fmod(node.y,2) == 0 then dir = 1 end
                    pajarito.addNodeByPriority(node.x+1,node.y,w,index)
                    pajarito.addNodeByPriority(node.x-1,node.y,w,index)
                    pajarito.addNodeByPriority(node.x,node.y-1,w,index)
                    pajarito.addNodeByPriority(node.x,node.y+1,w,index)
                    pajarito.addNodeByPriority(node.x+dir,node.y-1,w,index)
                    pajarito.addNodeByPriority(node.x+dir,node.y+1,w,index)
                end
            else
                pajarito.markBorderNode(node.x,node.y,node)
            end
        end
    end
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
  -- -- of pajarito.getNodesOnRange
  
  --  pajarito.getPathInsideRange(x,y)
function pajarito.getPathInsideRange(x,y)
    path_of_nodes = {}
    lst_nodes_on_path = {}
    
    local index = pajarito.getIndexOfNode(x,y)
    
    if not lst_marked_nodes[index] then
        --print('Point is not on range',2)
        return path_of_nodes 
    end
    --exist the point on the marked ones...
    while lst_marked_nodes[index] or index ~= nil do
        local node = lst_marked_nodes[index]
        table.insert(path_of_nodes,1,node)
        lst_nodes_on_path[index] = true
        --print(node.x,node.y) 
        index = node.father
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
  --  path = pajarito.getPath(node_x,node_y,dest_x,dest_y)
  
function pajarito.getPath(node_x,node_y,dest_x,dest_y)
    --we add the first node to the queue, we trust the user
    if node_x == nil or node_y == nil then return end --NOPE NOPE NOPE
    if dest_x == nil or dest_y == nil then return end --NOPE NOPE NOPE
    --print('start:',node_x,node_y)
        
    local node_dest =  nil
    local dest_index = 1
    if pajarito.isNodeOnGrid(node_x,node_y) and pajarito.isNodeOnGrid(dest_x,dest_y) then
        table.insert(queue_of_nodes,pajaritoNode(math.floor(node_x),math.floor(node_y)))
        lst_nodes_on_queue[pajarito.getIndexOfNode(node_x,node_y)] = range
        node_dest = pajaritoNode(math.floor(dest_x),math.floor(dest_y))
        dest_index = pajarito.getIndexOfNode(dest_x,dest_y)
    else
        return {}
    end
    
    while queue_of_nodes[1] do
        local node = queue_of_nodes[1]
        local index = pajarito.getIndexOfNode(node.x,node.y)
        local w = node.d
        w = w+math.max(pajarito.getGridWeight(node.x,node.y),1)*pajarito.heuristic(node_dest,node)
        node.d = w
        table.remove(queue_of_nodes,1)
        lst_nodes_on_queue[index] = nil
        
        if not pajarito.findABestFatherNode(node.father,node.x,node.y) then
            
            pajarito.markNode(node.x,node.y,node)
            if dest_index == index then
                break
            end
            
            if p_allow_diagonal then
                pajarito.addNodeByPriority(node.x+1,node.y+1,w,index)
                pajarito.addNodeByPriority(node.x-1,node.y-1,w,index)
                pajarito.addNodeByPriority(node.x+1,node.y-1,w,index)
                pajarito.addNodeByPriority(node.x-1,node.y+1,w,index)
            end

            pajarito.addNodeByPriority(node.x+1,node.y,w-0.1,index)
            pajarito.addNodeByPriority(node.x-1,node.y,w-0.1,index)
            pajarito.addNodeByPriority(node.x,node.y-1,w-0.1,index)
            pajarito.addNodeByPriority(node.x,node.y+1,w-0.1,index)
        end
    end
    
    lst_border_nodes = lst_nodes_on_queue
    return pajarito.getPathInsideRange(dest_x,dest_y)
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
  -- -- pajarito.getNodesOnRange, pajarito.getPathInsideRange,
  -- -- and pajarito.getPath
  -- -- call this function any time you change the starting point of 
  -- -- pajarito.getNodesOnRange, or before calling
  -- -- pajarito.getPath with new parameters. 
  --  pajarito.clearNodeInfo()
function pajarito.clearNodeInfo()
    path_of_nodes = {}
    lst_nodes_on_path = {}
    lst_marked_nodes = {}
    queue_of_nodes = {}
    lst_nodes_on_queue = {}
    lst_border_nodes = {}
end

--  Get if a given point x,y exist on the calculated path
  -- @class function
  -- @param x an integer, the x pos of the point on the grid
  -- @param y an integer, the y pos of the point on the grid  
  -- @return boolean __true__ if the point exist __false__ otherwise 
  
  -- @usage
  -- -- Use to get if a point x,y exist on the calculated path
  --  is_on_path = pajarito.isNodeOnGrid(20,50)
function pajarito.isNodeOnPath(x,y)
    return (lst_nodes_on_path[pajarito.getIndexOfNode(x,y)] ~= nil)
end


return pajarito