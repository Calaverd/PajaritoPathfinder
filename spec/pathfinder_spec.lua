---@diagnostic disable: undefined-global
local maps = require('spec.support.maps')

--- Walks the path and complains if two nodes in a row are not neighbours.
local function assertStepsAreContiguous(path)
    local previous = nil
    for _, node in path:iterNodes() do
        if previous then
            local dx = math.abs(node.position[1] - previous.position[1])
            local dy = math.abs(node.position[2] - previous.position[2])
            assert.is_true(dx <= 1 and dy <= 1 and (dx + dy) > 0,
                ('jumped from (%d,%d) to (%d,%d)'):format(
                    previous.position[1], previous.position[2],
                    node.position[1], node.position[2]))
        end
        previous = node
    end
end

describe('findPath', function()
    local graph

    before_each(function()
        graph = maps.graphOf(maps.WALL_WITH_A_GAP)
    end)

    it('reaches the target', function()
        local path = graph:findPath({1,1}, {7,7})
        assert.are.equal(graph:positionToMapId({1,1}), path:getStart().id)
        assert.are.equal(graph:positionToMapId({7,7}), path:getLast().id)
    end)

    it('only takes steps between neighbours', function()
        assertStepsAreContiguous(graph:findPath({1,1}, {7,7}))
    end)

    it('goes through the only gap in the wall', function()
        assert.is_truthy(graph:findPath({1,1}, {7,7}):hasPoint({4,4}))
    end)

    it('costs the same as the dijkstra search', function()
        local by_astar = graph:findPath({1,1}, {7,7})
        local by_dijkstra = graph:findPathDijkstra({1,1}, {7,7})
        assert.are.equal(by_dijkstra.weight, by_astar.weight)
        assert.are.equal(12, by_astar.weight)
    end)

    it('gives nothing when the target can not be walked over', function()
        assert.is_nil(graph:findPath({1,1}, {4,2}))
    end)

    it('gives nothing when the target is outside the map', function()
        assert.is_nil(graph:findPath({1,1}, {99,99}))
    end)

    it('gives nothing when the start is outside the map', function()
        assert.is_nil(graph:findPath({-5,-5}, {1,1}))
    end)

    it('gives nothing when there is no way around', function()
        local walled = maps.graphOf({
            {1,5,1},
            {1,5,1},
            {1,5,1},
        })
        assert.is_nil(walled:findPath({1,1}, {3,3}))
    end)

    it('walks around terrain that costs more than the way around', function()
        -- Crossing the sand costs 13, the grass corridor on the right 11
        local band = maps.graphOf(maps.EXPENSIVE_BAND)
        local path = band:findPath({1,1}, {1,6})
        assert.are.equal(11, path.weight)
        assert.is_truthy(path:hasPoint({4,3}), 'should have gone down the corridor')
        assert.is_falsy(path:hasPoint({2,3}), 'should not have crossed the sand')
        assert.are.equal(band:findPathDijkstra({1,1}, {1,6}).weight, path.weight)
    end)
end)

describe('findPath on the example map', function()
    local graph

    setup(function()
        graph = maps.graphOf(maps.PATHFINDER)
    end)

    -- This is the search of the Standar Pathfinder example. Rebuilding
    -- the branches of the shortest path warranty used to make it run
    -- forever here, while the smaller maps stayed under the threshold.
    it('finishes', function()
        local started = os.clock()
        local path = graph:findPath(maps.KNIGHT, maps.BANNER)
        assert.is_truthy(path)
        assert.is_true(os.clock() - started < 1,
            'the branches of the warranty are being rebuilt again')
    end)

    it('agrees with the dijkstra search, both ways around', function()
        for _, pair in ipairs({{maps.KNIGHT, maps.BANNER}, {maps.BANNER, maps.KNIGHT}}) do
            local by_astar = graph:findPath(pair[1], pair[2])
            local by_dijkstra = graph:findPathDijkstra(pair[1], pair[2])
            assert.are.equal(by_dijkstra.weight, by_astar.weight)
            assert.are.equal(by_dijkstra:getLen(), by_astar:getLen())
        end
    end)

    it('looks at less of the map than the dijkstra search', function()
        local function explored(use_dijkstra)
            local range = graph:rangeForDirectPath(use_dijkstra, maps.KNIGHT, maps.BANNER)
            local count = 0
            for _ in pairs(range.node_traversal_weights) do count = count + 1 end
            return count
        end
        assert.is_true(explored(false) < explored(true),
            'the estimate is not steering the search anywhere')
    end)

    it('only takes steps between neighbours', function()
        assertStepsAreContiguous(graph:findPath(maps.KNIGHT, maps.BANNER))
    end)

    it('never walks over a tile it can not pass', function()
        for _, node in graph:findPath(maps.KNIGHT, maps.BANNER):iterNodes() do
            assert.is_false(graph:isImpassable(node),
                ('stepped on the impassable tile %s'):format(tostring(node.tile)))
        end
    end)
end)

describe('diagonal movement', function()
    local field

    setup(function()
        field = maps.graphOf(maps.open(16, 16))
    end)

    it('walks a straight run straight', function()
        -- Going sideways and back costs the same as going straight, the
        -- corner nudge is what keeps the path from wandering off.
        for _, node in field:findPath({1,1}, {6,1}, 'diagonal'):iterNodes() do
            assert.are.equal(1, node.position[2])
        end
    end)

    it('still cuts the corner when that is the shorter way', function()
        local across = field:findPath({1,1}, {6,6}, 'diagonal')
        assert.are.equal(6, across:getLen())
        assert.is_true(across.weight < field:findPath({1,1}, {6,6}).weight,
            'corners must stay cheaper than going around by the sides')
    end)

    it('takes more steps without corners than with them', function()
        local by_corners = field:findPath({1,1}, {6,6}, 'diagonal')
        local by_sides = field:findPath({1,1}, {6,6}, 'manhattan')
        assert.is_true(by_corners:getLen() < by_sides:getLen())
    end)

    it('agrees with the dijkstra search on the example map', function()
        local graph = maps.graphOf(maps.PATHFINDER)
        local by_astar = graph:findPath(maps.KNIGHT, maps.BANNER, 'diagonal')
        local by_dijkstra = graph:findPathDijkstra(maps.KNIGHT, maps.BANNER, 'diagonal')
        assert.are.equal(by_dijkstra.weight, by_astar.weight)
    end)
end)
