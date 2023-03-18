--- Node test
---@diagnostic disable: undefined-global
require 'busted.runner'()
package.path = package.path .. ";../src/?.lua"

describe("Node test", function()
  local node_a
  local node_b
  local DOWN_RIGHT = 32
  local UP_LEFT = 2

  before_each( function()
    local Node = require("pajarito.Node")
    node_a = Node:new(1,{1,1})
    node_b = Node:new(2,{2,2})
  end )
  after_each(function()
    node_a = nil
    node_b = nil
  end)

  it("Node values are properly initilized", function()
    assert.are.equal(node_a.id, 1)
    assert.are.same(node_a.position, {1,1})
    assert.are.equal(node_b.id, 2)
    assert.are.same(node_b.position, {2,2})
  end)

  it("Node setTile with number returns yes isTileNumber", function()
    assert.are.equal(node_a.tile, 0)
    node_a:setTile(55)
    assert.are.equal(node_a.tile, 55)
    assert.is_true(node_a:isTileNumber())
  end)

  it("Node setTile with string returns not isTileNumber", function()
    assert.are.equal(node_a.tile, 0)
    node_a:setTile('5')
    assert.are.equal(node_a.tile, '5')
    assert.is_false(node_a:isTileNumber())
  end)

  it("Node makeOneWayLinkWith adds note to the given direction", function()
    node_a:makeOneWayLinkWith(node_b, DOWN_RIGHT)
    assert.are.equal(node_a.conections[DOWN_RIGHT], node_b )
  end)

  it("Node makeTwoWayLinkWith connets two nodes in oposite directions", function()
    node_a:makeTwoWayLinkWith(node_b, DOWN_RIGHT)
    assert.are.equal(node_a.conections[DOWN_RIGHT], node_b )
    assert.are.equal(node_b.conections[UP_LEFT], node_a )
  end)

  it("Node clearOneWayLinkWith disconnets node but keeps the conection in the other", function()
    node_a:makeTwoWayLinkWith(node_b, DOWN_RIGHT)
    node_a:clearOneWayLinkWith(node_b);
    assert.is.falsy(node_a.conections[DOWN_RIGHT])
    assert.are.equal(node_b.conections[UP_LEFT], node_a )
  end)

  it("Node add and remove objects", function()
    assert.are.equal(node_a:objectsSize(), 0 )
    assert.is_false(node_a:hasObjects())

    node_a:addObject(1)
    node_a:addObject(2)
    node_a:addObject(3)

    assert.is_true(node_a.objects[1])
    assert.is_true(node_a.objects[2])
    assert.is_true(node_a.objects[3])
    assert.are.equal(node_a:objectsSize(), 3 )
    assert.is_true(node_a:hasObjects())

    node_a:removeObject(1)

    assert.is.falsy(node_a.objects[1])
    assert.are.equal(node_a:objectsSize(), 2 )

    node_a:removeObject(1)

    assert.is.falsy(node_a.objects[1])
    assert.are.equal(node_a:objectsSize(), 2 )


    node_a:removeObject(2)
    node_a:removeObject(3)

    assert.is.falsy(node_a.objects[2])
    assert.is.falsy(node_a.objects[3])
    assert.are.equal(node_a:objectsSize(), 0 )
    assert.is.falsy(node_a:hasObjects())
  end)

end)