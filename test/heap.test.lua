--- Heap test
---@diagnostic disable: undefined-global
require 'busted.runner'()
package.path = package.path .. ";../src/?.lua"

describe("Heap test", function()
  local myHeap

  setup( function()
    local newHeap = require("heap")
    myHeap = newHeap();
  end )
  after_each(function()
    myHeap.clear()
  end)
  teardown(function()
    myHeap = nil
  end)

  it("Starting size must be 0", function()
    assert.are.equal(myHeap.getSize(), 0)
  end)

  it("Push changes the size of heap", function()
    assert.are.equal(myHeap.getSize(), 0)
    myHeap.push(1);
    assert.are.equal(myHeap.getSize(), 1)
    myHeap.push(2)
    myHeap.push(3);
    myHeap.push(4);
    myHeap.push(5);
    assert.are.equal(myHeap.getSize(),5);
  end)

  it("Pop changes the size of heap", function()
    assert.are.equal(myHeap.getSize(), 0)
    myHeap.push(1);
    myHeap.push(2)
    myHeap.push(3);
    myHeap.push(4);
    myHeap.push(5);
    
    assert.are.equal(myHeap.getSize(), 5)
    myHeap.pop();
    assert.are.equal(myHeap.getSize(), 4);
    
    myHeap.pop();
    myHeap.pop();
    myHeap.pop();
    myHeap.pop();
    assert.are.equal(myHeap.getSize(), 0);
  end)

  it("Pop returns items in acording priority", function()
    myHeap.push(2)
    myHeap.push(500);
    myHeap.push(1);
    myHeap.push(-1);
    myHeap.push(3);
    
    assert.are.equal(myHeap.pop(), -1)
    assert.are.equal(myHeap.pop(), 1)
    assert.are.equal(myHeap.pop(), 2)
    assert.are.equal(myHeap.pop(), 3)
    assert.are.equal(myHeap.pop(), 500)
  end)

  it("Peek returns item of higger priority, does not change size.", function()
    myHeap.push(2)
    myHeap.push(500);
    myHeap.push(1);
    myHeap.push(-1);
    myHeap.push(3);
    
    assert.are.equal(myHeap.getSize(), 5)
    assert.are.equal(myHeap.peek(), -1)
    assert.are.equal(myHeap.getSize(), 5)
  end)

  it("Custom compare function", function()
    myHeap.compare = function (b,a)
      return b >= a
    end
    myHeap.push(2)
    myHeap.push(500);
    myHeap.push(1);
    myHeap.push(-1);
    myHeap.push(3);
    
    assert.are.equal(myHeap.pop(), 500)
    assert.are.equal(myHeap.pop(), 3)
    assert.are.equal(myHeap.pop(), 2)
    assert.are.equal(myHeap.pop(), 1)
    assert.are.equal(myHeap.pop(), -1)
  end)

  it("Push and compare objects", function()
    myHeap.compare = function (obj_a,obj_b)
      return obj_a.p <= obj_b.p
    end
    myHeap.push( {p=2 })
    myHeap.push( {p=500} );
    myHeap.push( {p=1} );
    myHeap.push( {p=-1} );
    myHeap.push( {p=3} );

    assert.are.equal( myHeap.pop().p, -1 )
    assert.are.equal( myHeap.pop().p, 1 )
    assert.are.equal( myHeap.pop().p, 2 )
    assert.are.equal( myHeap.pop().p, 3 )
    assert.are.equal( myHeap.pop().p, 500 )
  end)
end)