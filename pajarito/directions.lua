local bitops = require 'pajarito.bitops'
local bor = bitops.bor;
local band = bitops.band;

-- An special direction to allow the\
-- conection of nodes separated in space.
local PORTAL = 0

local NORTH = 256 -- Wall
local NORTH_UP = 3
local NORTH_LEFT = 5
local NORTH_RIGHT = 7
local NORTH_DOWN = 9
local NORTH_UP_LEFT = 11
local NORTH_UP_RIGHT = 13
local NORTH_DOWN_LEFT = 15
local NORTH_DOWN_RIGHT = 17

local UP_LEFT = 2 -- Wall
local UP = 4 -- Wall
local UP_RIGHT = 8 -- Wall
local LEFT = 1 -- Wall
local RIGHT = 16 -- Wall
local DOWN_RIGHT = 32 -- Wall
local DOWN = 64 -- Wall
local DOWN_LEFT = 128 -- Wall

local SOUTH = 512 -- Wall
local SOUTH_UP = 19
local SOUTH_LEFT = 21
local SOUTH_RIGHT = 23
local SOUTH_DOWN = 25
local SOUTH_UP_LEFT = 27
local SOUTH_UP_RIGHT = 29
local SOUTH_DOWN_LEFT = 31
local SOUTH_DOWN_RIGHT = 33

---@enum direction_names
local direction_names = {
    [0] = "PORTAL",
    [256] = "NORTH",
    [3] = "NORTH_UP",
    [5] = "NORTH_LEFT",
    [7] = "NORTH_RIGHT",
    [9] = "NORTH_DOWN",
    [11] = "NORTH_UP_LEFT",
    [13] = "NORTH_UP_RIGHT",
    [15] = "NORTH_DOWN_LEFT",
    [17] = "NORTH_DOWN_RIGHT",
    [2] = "UP_LEFT",
    [4] = "UP",
    [8] = "UP_RIGHT",
    [1] = "LEFT",
    [16] = "RIGHT",
    [32] = "DOWN_RIGHT",
    [64] = "DOWN",
    [128] = "DOWN_LEFT",
    [512] = "SOUTH",
    [19] = "SOUTH_UP",
    [21] = "SOUTH_LEFT",
    [23] = "SOUTH_RIGHT",
    [25] = "SOUTH_DOWN",
    [27] = "SOUTH_UP_LEFT",
    [29] = "SOUTH_UP_RIGHT",
    [31] = "SOUTH_DOWN_LEFT",
    [33] = "SOUTH_DOWN_RIGHT"
}

--- A list that contains the only directions valid to use for walls.
---@enum Allowed_Walls
local Allowed_Walls = {
    NORTH = NORTH,
    LEFT = LEFT,
    UP_LEFT = UP_LEFT,
    UP = UP,
    UP_RIGHT = UP_RIGHT,
    RIGHT = RIGHT,
    DOWN_RIGHT = DOWN_RIGHT,
    DOWN = DOWN,
    DOWN_LEFT = DOWN_LEFT,
    SOUTH = SOUTH
}

--- A simple enum for the directions
--- and their flips either using the
--- number or the string name.
---@enum Allowed_Flips
local Allowed_Flips = {
    PORTAL = PORTAL,

    NORTH = SOUTH,
    NORTH_UP = SOUTH_DOWN,
    NORTH_LEFT = SOUTH_RIGHT,
    NORTH_RIGHT = SOUTH_LEFT,
    NORTH_DOWN = SOUTH_UP,
    NORTH_UP_LEFT = SOUTH_DOWN_RIGHT,
    NORTH_UP_RIGHT = SOUTH_DOWN_LEFT,
    NORTH_DOWN_LEFT = SOUTH_UP_RIGHT,
    NORTH_DOWN_RIGHT = SOUTH_UP_LEFT,

    LEFT = RIGHT,
    UP_LEFT = DOWN_RIGHT,
    UP = DOWN,
    UP_RIGHT = DOWN_LEFT,
    RIGHT = LEFT,
    DOWN_RIGHT = UP_LEFT,
    DOWN = UP,
    DOWN_LEFT = UP_RIGHT,

    SOUTH = NORTH,
    SOUTH_DOWN = NORTH_UP,
    SOUTH_RIGHT = NORTH_LEFT,
    SOUTH_LEFT = NORTH_RIGHT,
    SOUTH_UP = NORTH_DOWN,
    SOUTH_DOWN_RIGHT = NORTH_UP_LEFT,
    SOUTH_DOWN_LEFT = NORTH_UP_RIGHT,
    SOUTH_UP_RIGHT = NORTH_DOWN_LEFT,
    SOUTH_UP_LEFT = NORTH_DOWN_RIGHT,

    [NORTH] = SOUTH,
    [NORTH_UP] = SOUTH_DOWN,
    [NORTH_LEFT] = SOUTH_RIGHT,
    [NORTH_RIGHT] = SOUTH_LEFT,
    [NORTH_DOWN] = SOUTH_UP,
    [NORTH_UP_LEFT] = SOUTH_DOWN_RIGHT,
    [NORTH_UP_RIGHT] = SOUTH_DOWN_LEFT,
    [NORTH_DOWN_LEFT] = SOUTH_UP_RIGHT,
    [NORTH_DOWN_RIGHT] = SOUTH_UP_LEFT,

    [LEFT] = RIGHT,
    [UP_LEFT] = DOWN_RIGHT,
    [UP] = DOWN,
    [UP_RIGHT] = DOWN_LEFT,
    [RIGHT] = LEFT,
    [DOWN_RIGHT] = UP_LEFT,
    [DOWN] = UP,
    [DOWN_LEFT] = UP_RIGHT,

    [SOUTH] = NORTH,
    [SOUTH_UP] = NORTH_DOWN,
    [SOUTH_LEFT] = NORTH_RIGHT,
    [SOUTH_RIGHT] = NORTH_LEFT,
    [SOUTH_DOWN] = NORTH_UP,
    [SOUTH_UP_LEFT] = NORTH_DOWN_RIGHT,
    [SOUTH_UP_RIGHT] = NORTH_DOWN_LEFT,
    [SOUTH_DOWN_LEFT] = NORTH_UP_RIGHT,
    [SOUTH_DOWN_RIGHT] = NORTH_UP_LEFT,
}

---@enum VON_NEUMANN_NEIGHBORHOOD
local FULL_VON_NEUMANN_NEIGHBORHOOD = {
--[[ UPPER PART ]]
    [NORTH] = { x =  0, y =  0, z =  1 },
    [NORTH_UP]    = { x =  0, y = -1, z =  1 },
    [NORTH_LEFT]  = { x = -1, y =  0, z =  1 },
    [NORTH_RIGHT] = { x =  1, y =  0, z =  1 },
    [NORTH_DOWN]  = { x =  0, y =  1, z =  1 },
    [NORTH_UP_LEFT] = { x = -1, y = -1, z =  1 },
    [NORTH_UP_RIGHT] = { x = 1, y = -1, z =  1 },
    [NORTH_DOWN_LEFT] = { x = -1, y = 1, z =  1 },
    [NORTH_DOWN_RIGHT] = { x = 1, y = 1, z =  1 },

--[[ CENTER PART ]]
    [UP]    = { x =  0, y = -1, z =  0 },
    [LEFT]  = { x = -1, y =  0, z =  0 },
    [RIGHT] = { x =  1, y =  0, z =  0 },
    [DOWN]  = { x =  0, y =  1, z =  0 },
    [UP_LEFT] = { x = -1, y = -1, z =  0 },
    [UP_RIGHT] = { x = 1, y = -1, z =  0 },
    [DOWN_LEFT] = { x = -1, y = 1, z =  0 },
    [DOWN_RIGHT] = { x = 1, y = 1, z =  0 },

--[[ LOWER PART ]]
    [SOUTH] = { x =  0, y =  0, z = -1 },
    [SOUTH_UP]    = { x =  0, y = -1, z =  -1 },
    [SOUTH_LEFT]  = { x = -1, y =  0, z =  -1 },
    [SOUTH_RIGHT] = { x =  1, y =  0, z =  -1 },
    [SOUTH_DOWN]  = { x =  0, y =  1, z =  -1 },
    [SOUTH_UP_LEFT] = { x = -1, y = -1, z =  -1 },
    [SOUTH_UP_RIGHT] = { x = 1, y = -1, z =  -1 },
    [SOUTH_DOWN_LEFT] = { x = -1, y = 1, z =  -1 },
    [SOUTH_DOWN_RIGHT] = { x = 1, y = 1, z =  -1 },
}

-- Diagonal 3d is all the Von Neumann neighborhood

return {
    --- All possible movements in a grid are defined here.
    movements = FULL_VON_NEUMANN_NEIGHBORHOOD,

    names = direction_names,
    --- The sets of posible allowed directions to move that
    -- can be taken on the grid based on the grid tipe and move
    ["2D"] = {
        ---@type number[]
        manhattan = {UP,LEFT,RIGHT,DOWN},
        ---@type number[]
        diagonal = {UP,LEFT,RIGHT,DOWN,UP_LEFT,UP_RIGHT,DOWN_LEFT,DOWN_RIGHT}
    },
    ["3D"] = {
        ---@type number[]
        manhattan = {UP,LEFT,RIGHT,DOWN,NORTH, SOUTH},
        ---@type number[]
        diagonal = {NORTH,NORTH_UP,NORTH_LEFT,NORTH_RIGHT,NORTH_DOWN,NORTH_UP_LEFT,NORTH_UP_RIGHT,NORTH_DOWN_LEFT,NORTH_DOWN_RIGHT,UP,LEFT,RIGHT,DOWN,UP_LEFT,UP_RIGHT,DOWN_LEFT,DOWN_RIGHT,SOUTH,SOUTH_UP,SOUTH_LEFT,SOUTH_RIGHT,SOUTH_DOWN,SOUTH_UP_LEFT,SOUTH_UP_RIGHT,SOUTH_DOWN_LEFT,SOUTH_DOWN_RIGHT}
    },
    ---Takes any number of argument numbers and creates a
    -- number that is unique to that combination of walls.
    ---@example wall = createWall(UP_LEFT, DOWN_RIGH, ...)
    ---@param ... integer
    ---@return integer
    createWall = function(...)
        local num = 0
        -- chek if all the walls are on the list
        for _,v in ipairs({...}) do
            if type(v) ~= 'string' or Allowed_Walls[v] == nil then
                assert(false,'Invalid wall value. Given "'..tostring(v)..'".')
            end
            num = bor( num, Allowed_Walls[v] )
        end
        return num
    end,
    --- Checks if the wall can block the movement
    --- in the given direction.
    ---@param wall integer
    ---@param direction integer
    ---@return boolean
    isWallFacingDirection = function(wall,direction)
        if not wall or not Allowed_Walls[direction] then
            return false
        end
        return band(wall,Allowed_Walls[direction]) == direction
    end,
    --- Takes the name or the number id of a direction AND
    --- returns the fliped direction number id
    ---@param direction string|integer
    ---@return integer
    flip = function (direction)
        return Allowed_Flips[direction]
    end
}