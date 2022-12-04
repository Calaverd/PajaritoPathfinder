--- Heap test
---@diagnostic disable: undefined-global
require 'busted.runner'()
package.path = package.path .. ";../src/?.lua"

describe("Bit operations test", function()
    local band
    local bor

    setup( function()
      local bitops = require("bitops")
      band = bitops.band
      bor = bitops.bor
    end )
    teardown(function()
      band = nil
      bor = nil
    end)

  it("band & bor are functions", function ()
    assert.is_function(band)
    assert.is_function(bor)
  end)

  it("1010 & 0011 == 0010", function()
    assert.are.equal(band(10,3), 2)
  end)

  it("1010 & 0101 == 0000", function()
    assert.are.equal(band(10,5), 0)
  end)

  it("1010 & 1010 == 1010", function()
    assert.are.equal(band(10,10), 10)
  end)

  it("1111 & 1111 == 1111", function()
    assert.are.equal(band(15,15), 15)
  end)

  -- Now the or test

  it("1010 | 0011 == 1011", function()
    assert.are.equal(bor(10,3), 11)
  end)

  it("1010 | 0101 == 1111", function()
    assert.are.equal(bor(10,5), 15)
  end)

  it("1010 | 1010 == 1010", function()
    assert.are.equal(bor(10,10), 10)
  end)

  it("0000 | 0000 == 0000", function()
    assert.are.equal(bor(0,0),0)
  end)

end)