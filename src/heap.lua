--- A simple data agnostic Heap implementation.
-- This heap is build to be data agnostic, so it can work
-- comparing arbitrary data types. Is used for the priority queue
-- @classmod Heap
-- @author Calaverd
-- @license MIT

-- Define the math functions for some small speed bonus
local FMOD = math.fmod
local MMAX = math.max
local FLOOR = math.floor
if not FMOD then -- Why are you usign lua < 5.1 ?
    FMOD = function(a, b) return a - FLOOR(a / b) * b end
end

--- Returns a new Heap instance
-- @return Heap instance
return function()
    local self = {}

    local last = 0 -- id of the last inserted item
    local container = {} -- body of the heap

    --- A internal function that compares two things.
    --  This function is used to handle the internally comparisions
    -- between items. You can overrride it with your own function
    -- as long it returns a boolean
    -- @param object_a
    -- @param object_b
    -- @return bool True if object_a has more priority than object_b, False otherwise.
    function self.compare(object_a, object_b)
        return object_a <= object_b
    end

    --- Clears the contents of the heap.
    -- Clears the heap from any content, so it can be reused.
    function self.clear()
        container = {}
        last = 0
    end

    --- Intenral function, gets the parent of a node.
    -- @int id the id of a node in the heap.
    -- @return int id of parent node.
    local function getParentOf(id)
        if FMOD(id, 2) == 0 then return id / 2 end
        return (id - 1) / 2
    end

    --- Adds a new item into the Heap.
    --  Use this function to insert new items into the heap
    -- and sort it according to their priority.
    --  As long as the item can get compared with the ones
    -- already on the heap, anything goes.
    -- @param data anything to be added.
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
            if self.compare(container[current], container[parent]) then
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
        last = last + 1
    end

    --- Remove and retrive the higher priority item.
    --  This function takes the item with higher priority on
    -- the heap, removes it, and then returns it.
    -- @return data, nil if heap is empty
    function self.pop()
        --sawp first and last value
        local top = container[1]
        container[1] = container[last - 1]
        container[last - 1] = nil
        local current = 1
        local heap_property = false
        while not heap_property do
            local left = 2 * current
            local right = 2 * current + 1
            local choosed = current
            -- Exist the right node?
            if container[right] then
                if self.compare(container[left], container[right]) then
                    choosed = left
                else
                    choosed = right
                end
                if self.compare(container[choosed], container[current]) then
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
                if self.compare(container[left], container[current]) then
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

        last = MMAX(last - 1, 0)
        return top
    end

    -- Returns the higher priority item and keeps it on the heap.
    -- @return data the higer priority element on the heap.
    function self.peek()
        return container[1]
    end

    --- Gets the number of items in the heap.
    -- @return int the number of items in the heap.
    function self.getSize()
        return MMAX(last - 1, 0)
    end

    return self
end