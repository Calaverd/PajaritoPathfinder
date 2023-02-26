-- @module Point
local Point = {}

--- Constructs a new Point instance.
-- @number x The x coordinate of the point.
-- @number y The y coordinate of the point.
function Point:new(x, y)
  local obj = { x = x, y = y }
  setmetatable(obj, self)
  self.__index = self
  return obj
end

--- Returns the x coordinate of the point.
-- @treturn number The x coordinate of the point.
function Point:getX()
  return self.x
end

--- Returns the y coordinate of the point.
-- @treturn number The y coordinate of the point.
function Point:getY()
  return self.y
end

return Point