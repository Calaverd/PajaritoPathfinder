--- A simple data agnostic Heap implementation.
-- This heap is build to be data agnostic, so it can work
-- comparing arbitrary data types. Is used for the priority queue
---@class Heap
---@author Calaverd
---@license MIT
local Heap = {}

-- Define the math functions for some small speed bonus
local FMOD = math.fmod
local MMAX = math.max
local FLOOR = math.floor
if not FMOD then -- Why are you usign lua < 5.1 ?
    FMOD = function(a, b) return a - FLOOR(a / b) * b end
end

--- Internal function, gets the parent of a node.
---@param id number of a node in the heap.
---@return number id of parent node.
local function getParentOf(id)
    if FMOD(id, 2) == 0 then return id / 2 end
    return (id - 1) / 2
end

--- Constructs a new Heap instance
---@return Heap
function Heap:new()
    local obj = {
        -- index of the last inserted item
        last = 0,
        -- body of the heap, contains items
        container = {},
        -- An internal function used for comparisions
        compareFun = function (a,b) return a <= b end
    }

    setmetatable(obj, self)
    self.__index = self
    return obj
end

--- A internal function that compares two things.
--  This function is used to handle the internally comparisions
-- between items. You can overrride it with your own function
-- as long it returns a boolean true if object_a has more
-- priority than object_b, False otherwise.
---@see setCompare
---@param object_a any
---@param object_b any
---@return boolean
function Heap:compare(object_a, object_b)
    return self.compareFun( object_a, object_b )
end

--- Takes a new function to use to compare.
---@param newCompare fun(object_a:any, object_b:any): boolean
function Heap:setCompare(newCompare)
    self.compareFun = newCompare or self.compareFun
end

--- Clears the contents of the heap.
-- Clears from any content, so it can be reused.
function Heap:clear()
    self.container = {}
    self.last = 0
end

--- Adds a new item into the Heap.
--  Use this function to insert new items into the heap
-- and sort it according to their priority.
--  As long as the item can get compared with the ones
-- already on the heap, anything goes.
---@param data any
function Heap:push(data)
    --is first element.
    if self.last <= 1 then
        self.container[1] = data
        self.last = 2
        return
    end

    local heap_property = false
    local current = self.last
    local parent = 0
    self.container[current] = data

    while not heap_property do
        parent = getParentOf(current)
        if self:compare(self.container[current], self.container[parent]) then
            --swap current and parent
            self.container[current] = self.container[parent]
            self.container[parent] = data
            current = parent
        else
            heap_property = true
        end
        if current <= 1 then
            heap_property = true
        end
    end
    self.last = self.last + 1
end

--- Remove and retrive the higher priority item.
--  This function takes the item with higher priority on
-- the heap, removes it, and then returns it.
-- returns nil if the heap is empty
--- @return any item
function Heap:pop()
    --sawp first and last value
    local top = self.container[1]
    self.container[1] = self.container[self.last - 1]
    self.container[self.last - 1] = nil
    local current = 1
    local heap_property = false
    while not heap_property do
        local left = 2 * current
        local right = 2 * current + 1
        local choosed = current
        -- Exist the right node?
        if self.container[right] then
            if self:compare(self.container[left], self.container[right]) then
                choosed = left
            else
                choosed = right
            end
            if self:compare(self.container[choosed], self.container[current]) then
                --swap the value
                local temp = self.container[choosed]
                self.container[choosed] = self.container[current]
                self.container[current] = temp
                current = choosed
            else
                heap_property = true
            end
            -- Exist the left node?
        elseif self.container[left] then
            if self:compare(self.container[left], self.container[current]) then
                --swap the value
                choosed = left
                local temp = self.container[choosed]
                self.container[choosed] = self.container[current]
                self.container[current] = temp
                current = choosed
            else
                heap_property = true
            end
        else
            heap_property = true
        end
    end

    self.last = MMAX(self.last - 1, 0)
    return top
end

-- Returns the higher priority item and keeps it on the heap.
---@return any
function Heap:peek()
    return self.container[1]
end

--- Gets the number of items in the heap.
---@return integer
function Heap:getSize()
    return MMAX(self.last - 1, 0)
end

return Heap