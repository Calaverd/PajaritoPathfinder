---@diagnostic disable: undefined-global
local maps = require('spec.support.maps')

describe('constructNodeRange', function()
    local field

    before_each(function()
        field = maps.graphOf(maps.open(9, 9))
    end)

    it('holds the start node', function()
        local range = field:constructNodeRange({5,5}, 3)
        assert.is_truthy(range:hasPoint({5,5}))
        assert.is_true(range:isStartNodePosition({5,5}))
        assert.are.same({5,5}, range:getStartNodePosition())
    end)

    it('reaches as far as the cost allows and no further', function()
        local range = field:constructNodeRange({5,5}, 3)
        assert.is_truthy(range:hasPoint({8,5}), '3 tiles away is within reach')
        assert.is_falsy(range:hasPoint({9,5}), '4 tiles away is out of reach')
    end)

    it('tells what it costs to reach a tile', function()
        local range = field:constructNodeRange({5,5}, 3)
        local id = range:getIdFromPoint({7,5})
        assert.are.equal(2, range:getReachCostAt(id))
    end)

    it('gives -1 for a tile it knows nothing about', function()
        local range = field:constructNodeRange({5,5}, 1)
        assert.are.equal(-1, range:getReachCostAt(range:getIdFromPoint({9,9})))
    end)

    it('counts every tile it reached', function()
        -- A cost of 2 over open ground reaches the diamond of tiles
        -- at a manhattan distance of 2, which is 13 tiles with the start
        local range = field:constructNodeRange({5,5}, 2)
        assert.are.equal(13, #range:getAllNodes())
    end)

    it('does not spill over impassable terrain', function()
        local walled = maps.graphOf(maps.WALL_WITH_A_GAP)
        local range = walled:constructNodeRange({1,1}, 3)
        assert.is_falsy(range:hasPoint({4,1}), 'the wall is not walkable')
        assert.is_falsy(range:hasPoint({5,1}), 'and nothing behind it is in reach')
    end)

    it('keeps what it could not reach on the border', function()
        local range = field:constructNodeRange({5,5}, 1)
        assert.is_truthy(range:borderHasPoint({7,5}), 'just out of reach is border')
        assert.is_falsy(range:hasPoint({7,5}), 'and not part of the range')
    end)

    it('marks the border it can not walk over with -1', function()
        local walled = maps.graphOf(maps.WALL_WITH_A_GAP)
        local range = walled:constructNodeRange({1,1}, 9)
        local wall_id = range:borderHasPoint({4,1})
        assert.is_truthy(wall_id, 'the wall tile should sit on the border')
        assert.are.equal(-1, range:getBorderWeight(wall_id))
    end)

    it('is empty when it starts outside the map', function()
        local range = field:constructNodeRange({99,99}, 3)
        assert.are.equal(0, #range:getAllNodes())
        assert.is_nil(range:getStartNodePosition())
    end)
end)

describe('getPathTo over a range', function()
    local field

    before_each(function()
        field = maps.graphOf(maps.open(16, 16))
    end)

    it('walks back to the start of the range', function()
        local range = field:constructNodeRange({1,1}, 30)
        local path = range:getPathTo({6,4})
        assert.are.equal(field:positionToMapId({1,1}), path:getStart().id)
        assert.are.equal(field:positionToMapId({6,4}), path:getLast().id)
        assert.are.equal(8, path.weight)
    end)

    it('gives an empty path for a tile outside the range', function()
        local range = field:constructNodeRange({1,1}, 2)
        assert.is_true(range:getPathTo({16,16}):isEmpty())
    end)

    -- Every tile of an open field ties with its neighbours, so the
    -- warranty has a bifurcation at every step of the way back. Solving
    -- each branch once keeps this cheap, rebuilding them never finishes.
    it('does not blow up when asked for the warranted shortest path', function()
        local range = field:constructNodeRange({1,1}, 30)
        local started = os.clock()
        local path = range:getPathTo({16,16}, true)
        assert.is_true(os.clock() - started < 1, 'the branches are being rebuilt again')
        assert.are.equal(30, path.weight)
        assert.are.equal(31, path:getLen())
    end)

    it('costs the same with the warranty as without it', function()
        local range = field:constructNodeRange({1,1}, 30)
        assert.are.equal(range:getPathTo({12,9}).weight,
                         range:getPathTo({12,9}, true).weight)
    end)

    it('holds the same path on the example map, warranty or not', function()
        local graph = maps.graphOf(maps.PATHFINDER)
        local range = graph:constructNodeRange(maps.KNIGHT, 25)
        assert.are.equal(range:getPathTo(maps.BANNER).weight,
                         range:getPathTo(maps.BANNER, true).weight)
    end)
end)

describe('a path', function()
    local path, field

    setup(function()
        field = maps.graphOf(maps.open(9, 9))
        path = field:findPath({1,1}, {4,1})
    end)

    it('knows its own length', function()
        assert.are.equal(4, path:getLen())
        assert.is_false(path:isEmpty())
    end)

    it('gives the node at a step', function()
        assert.are.same({1,1}, path:getNodeAtSteep(1).position)
        assert.are.same({4,1}, path:getNodeAtSteep(4).position)
        assert.is_nil(path:getNodeAtSteep(99))
    end)

    it('counts the steps of getStepAtNode from the start, like getNodeAtSteep', function()
        assert.are.equal(1, path:getStepAtNode(path:getStart()))
        assert.are.equal(path:getLen(), path:getStepAtNode(path:getLast()))
        for steep, node in path:iterNodes() do
            assert.are.equal(steep, path:getStepAtNode(node))
            assert.are.equal(node, path:getNodeAtSteep(path:getStepAtNode(node)))
        end
    end)

    it('measures a branch merged at one of its nodes', function()
        -- {4,1}..{4,3} going down, then the path from {4,1} on: 3 + 1
        local branch = field:findPath({4,3}, {4,1})
        assert.are.equal(4, path:getIfMergedBranchLen(branch, path:getLast()))
        assert.are.equal(3 + 4, path:getIfMergedBranchLen(branch, path:getStart()))
        assert.is_nil(path:getIfMergedBranchLen(branch, field:getNodeAt({9,9})))
    end)

    it('knows which points it covers', function()
        assert.is_truthy(path:hasPoint({2,1}))
        assert.is_falsy(path:hasPoint({9,9}))
    end)
end)
