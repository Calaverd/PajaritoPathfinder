--- Defines a bit operations AND & OR
-- This module exist to define the bit operations to work in
-- a large range of lua versions thaking their quirks into account

local FMOD = math.fmod
-- We are using Lua jit?
local v_number = tonumber(_VERSION:match '(%d%.%d)')

--- A simple wraper for the bit operations that
--- are used so can they work in different lua
--- environments
---@class bitops
---@field band fun(a:integer, b:integer):integer
---@field bor fun(a:integer, b:integer):integer
local bitops = {}

---@diagnostic disable-next-line: undefined-global
if type(jit) == 'table' then
    -- 'Using Lua Jit Bitwise'
    -- import Lua jit bit operations
    local bit = require("bit")
    bitops = {band=bit.band, bor=bit.bor}
elseif v_number >= 5.3 then
    -- 'Using Lua Built-in Bitwise'
    -- use lua build-in bitwise operators
    -- this ugly thing here is to avoid the script from raise an error
    -- on lower versions of Lua while is parsing
    local band = load("return function (a,b) return (a & b) end")()
    local bor = load("return function (a,b) return (a | b) end")()
    bitops = {band=band, bor=bor}
else
    -- 'Using the Lua lib "bit32" for Bitwise'
    -- no Lua jit nor lua 5.3 >:(
    -- try import bit32
    local status_ok, bit = pcall(require, "bit32")
    if (status_ok) then
        bitops = {band=bit.band, bor=bit.bor}
    else
        -- 'Using Pure Lua Bitwise'
        -- Why are you doing this to yourself?
        -- this should "in theory" work even on Lua 5.0
        -- from https://stackoverflow.com/questions/5977654/how-do-i-use-the-bitwise-operator-xor-in-lua

        local band = function(a, b)
            local p, c = 1, 0
            while a > 0 and b > 0 do
                local ra, rb = FMOD(a, 2), FMOD(b, 2)
                if ra + rb > 1 then c = c + p end
                a, b, p = (a - ra) / 2, (b - rb) / 2, p * 2
            end
            return c
        end
        local bor = function(a, b)
            local p, c = 1, 0
            while a + b > 0 do
                local ra, rb = FMOD(a, 2), FMOD(b, 2)
                if ra + rb > 0 then c = c + p end
                a, b, p = (a - ra) / 2, (b - rb) / 2, p * 2
            end
            return c
        end
        bitops = {band=band, bor=bor}
    end
end

return bitops