--- Heap test
---@diagnostic disable: undefined-global
require 'busted.runner'()
package.path = package.path .. ";../src/?.lua"

describe("Heap test", function()
    local Heap

    setup( function()
      Heap = require("heap")()
    end )
    after_each(function()
      Heap.clear()
    end)
    teardown(function()
      Heap = nil
    end)

  it("Starting size must be 0", function()
    assert.are.equal(Heap.getSize(), 0)
  end)

  it("Push changes the size of heap", function()
    assert.are.equal(Heap.getSize(), 0)
    Heap.push(1);
    assert.are.equal(Heap.getSize(), 1)
    Heap.push(2)
    Heap.push(3);
    Heap.push(4);
    Heap.push(5);
    assert.are.equal(Heap.getSize(),5);
  end)

  it("Pop changes the size of heap", function()
    assert.are.equal(Heap.getSize(), 0)
    Heap.push(1);
    Heap.push(2)
    Heap.push(3);
    Heap.push(4);
    Heap.push(5);
    
    assert.are.equal(Heap.getSize(), 5)
    Heap.pop();
    assert.are.equal(Heap.getSize(), 4);
    
    Heap.pop();
    Heap.pop();
    Heap.pop();
    Heap.pop();
    assert.are.equal(Heap.getSize(), 0);
  end)

  it("Pop returns items in acording priority", function()
    Heap.push(2)
    Heap.push(500);
    Heap.push(1);
    Heap.push(-1);
    Heap.push(3);
    
    assert.are.equal(Heap.pop(), -1)
    assert.are.equal(Heap.pop(), 1)
    assert.are.equal(Heap.pop(), 2)
    assert.are.equal(Heap.pop(), 3)
    assert.are.equal(Heap.pop(), 500)
  end)

  it("Peek returns item of higger priority, does not change size.", function()
    Heap.push(2)
    Heap.push(500);
    Heap.push(1);
    Heap.push(-1);
    Heap.push(3);
    
    assert.are.equal(Heap.getSize(), 5)
    assert.are.equal(Heap.peek(), -1)
    assert.are.equal(Heap.getSize(), 5)
  end)

  it("Custom compare function", function()
    Heap.compare = function (b,a)
      return b >= a
    end
    Heap.push(2)
    Heap.push(500);
    Heap.push(1);
    Heap.push(-1);
    Heap.push(3);
    
    assert.are.equal(Heap.pop(), 500)
    assert.are.equal(Heap.pop(), 3)
    assert.are.equal(Heap.pop(), 2)
    assert.are.equal(Heap.pop(), 1)
    assert.are.equal(Heap.pop(), -1)
  end)

  it("Push and compare objects", function()
    Heap.compare = function (obj_a,obj_b)
      return obj_a.p <= obj_b.p
    end
    Heap.push( {p=2 })
    Heap.push( {p=500} );
    Heap.push( {p=1} );
    Heap.push( {p=-1} );
    Heap.push( {p=3} );

    assert.are.equal( Heap.pop().p, -1 )
    assert.are.equal( Heap.pop().p, 1 )
    assert.are.equal( Heap.pop().p, 2 )
    assert.are.equal( Heap.pop().p, 3 )
    assert.are.equal( Heap.pop().p, 500 )
  end)
end)