---@diagnostic disable: undefined-global
local maps = require('spec.support.maps')

describe('a graph', function()
    local field

    before_each(function()
        field = maps.graphOf(maps.open(5, 5))
    end)

    it('knows which points it holds', function()
        assert.is_true(field:hasPoint({1,1}))
        assert.is_true(field:hasPoint({5,5}))
        assert.is_false(field:hasPoint({0,1}))
        assert.is_false(field:hasPoint({6,1}))
    end)

    it('gives the node sitting at a position', function()
        local node = field:getNodeAt({3,4})
        assert.are.same({3,4}, node.position)
        assert.is_nil(field:getNodeAt({99,99}))
    end)

    it('reports the size of the map', function()
        local width, height, deep = field:getDimensions()
        assert.are.equal(5, width)
        assert.are.equal(5, height)
        assert.are.equal(0, deep)
    end)

    it('takes the weight of a tile from the weight map', function()
        assert.are.equal(1, field:getNodeWeight(field:getNodeAt({1,1})))
    end)

    it('falls back to the tile itself when it is a number', function()
        local bare = maps.graphOf(maps.open(3, 3))
        bare:setWeightMap({})
        assert.are.equal(1, bare:getNodeWeight(bare:getNodeAt({1,1})))
    end)

    it('refuses a negative weight', function()
        local bare = maps.graphOf(maps.open(3, 3))
        bare:setWeightMap({[1] = -1})
        assert.has_error(function() bare:getNodeWeight(bare:getNodeAt({1,1})) end)
    end)

    it('treats a tile that is not a number as impassable', function()
        field:updateNodeTile({3,3}, 'a rock')
        assert.is_true(field:isImpassable(field:getNodeAt({3,3})))
    end)
end)

describe('changing a tile', function()
    it('changes where the path can go', function()
        local field = maps.graphOf(maps.open(3, 3))
        assert.are.equal(2, field:findPath({1,2}, {3,2}).weight)

        -- Drop a piramid in the middle, now the path has to go around
        field:updateNodeTile({2,2}, 5)
        local around = field:findPath({1,2}, {3,2})
        assert.are.equal(4, around.weight)
        assert.is_falsy(around:hasPoint({2,2}))
    end)
end)

describe('walls', function()
    local field

    before_each(function()
        -- The Elemental Walls example is open ground, everything
        -- that blocks the way there is a wall
        field = maps.graphOf(maps.ELEMENTAL_WALLS)
    end)

    it('are stored at the position they are set on', function()
        field:setWall({5,5}, 'UP')
        assert.is_truthy(field:getWallAt({5,5}))
        assert.is_nil(field:getWallAt({5,6}))
    end)

    -- setWall takes the names, the checks want the numbers behind them
    local dir = require('pajarito').directions.values

    it('block the way through the side they face', function()
        assert.is_false(field:isWallBetween({5,5}, {5,4}, dir.UP))
        field:setWall({5,5}, 'UP')
        assert.is_true(field:isWallBetween({5,5}, {5,4}, dir.UP))
    end)

    it('block the way from the other side too', function()
        field:setWall({5,5}, 'UP')
        assert.is_true(field:isWallBetween({5,4}, {5,5}, dir.DOWN))
    end)

    it('leave the other sides open', function()
        field:setWall({5,5}, 'UP')
        assert.is_false(field:isWallBetween({5,5}, {5,6}, dir.DOWN))
        assert.is_false(field:isWallBetween({5,5}, {4,5}, dir.LEFT))
    end)

    it('are found without naming the direction', function()
        assert.is_false(field:hasWallBetween({5,5}, {5,4}))
        field:setWall({5,5}, 'UP')
        assert.is_true(field:hasWallBetween({5,5}, {5,4}))
        assert.is_true(field:hasWallBetween({5,4}, {5,5}), 'and from the other side')
        assert.is_false(field:hasWallBetween({5,5}, {4,5}))
    end)

    it('take the numbers and the names alike', function()
        field:setWall({5,5}, dir.UP)
        assert.are.equal(field:getWallAt({5,5}), (function()
            local other = maps.graphOf(maps.ELEMENTAL_WALLS)
            other:setWall({5,5}, 'UP')
            return other:getWallAt({5,5})
        end)())
    end)

    it('send the path around them', function()
        local straight = field:findPath({4,5}, {6,5})
        assert.are.equal(2, straight.weight)

        -- Box the tile in the middle on both sides
        field:setWall({5,5}, 'LEFT', 'RIGHT')
        local around = field:findPath({4,5}, {6,5})
        assert.is_truthy(around)
        assert.are.equal(4, around.weight, 'has to go around the wall')
        assert.is_falsy(around:hasPoint({5,5}))
    end)

    it('can shut a tile in completely', function()
        field:setWall({5,5}, 'UP', 'DOWN', 'LEFT', 'RIGHT')
        assert.is_nil(field:findPath({1,1}, {5,5}))
    end)

    it('are taken down one by one', function()
        field:setWall({5,5}, 'UP', 'DOWN', 'LEFT', 'RIGHT')
        field:setWall({5,5})
        assert.is_nil(field:getWallAt({5,5}))
        assert.is_truthy(field:findPath({1,1}, {5,5}))
    end)

    it('are taken down all at once', function()
        field:buildWalls({
            { {5,5}, 'UP', 'DOWN', 'LEFT', 'RIGHT' },
            { {7,7}, 'UP' },
        })
        assert.is_truthy(field:getWallAt({7,7}))
        field:clearWalls()
        assert.is_nil(field:getWallAt({5,5}))
        assert.is_nil(field:getWallAt({7,7}))
    end)

    it('are listed by the iterator', function()
        field:buildWalls({ { {5,5}, 'UP' }, { {7,7}, 'DOWN' } })
        local found = 0
        for position, value in field:iterWalls() do
            assert.is_truthy(value)
            assert.is_truthy(field:hasPoint(position))
            found = found + 1
        end
        assert.are.equal(2, found)
    end)
end)

describe('portals', function()
    local field

    before_each(function()
        field = maps.graphOf(maps.PORTALS)
    end)

    it('join two far away tiles', function()
        local far = field:findPath({2,2}, {23,13}).weight
        assert.is_true(field:createPortalBetween({2,2}, {23,13}))
        assert.are.equal(1, field:findPath({2,2}, {23,13}).weight,
            'the portal should be one step')
        assert.is_true(far > 1)
    end)

    it('refuse a tile outside the map', function()
        assert.is_false(field:createPortalBetween({2,2}, {99,99}))
    end)

    it('refuse a tile that already has one', function()
        assert.is_true(field:createPortalBetween({2,2}, {23,13}))
        assert.is_false(field:createPortalBetween({2,2}, {5,5}))
    end)

    it('are taken down again', function()
        field:createPortalBetween({2,2}, {23,13})
        assert.is_true(field:removePortalBetween({2,2}, {23,13}))
        assert.is_true(field:findPath({2,2}, {23,13}).weight > 1)
    end)

    it('say when there was nothing to take down', function()
        assert.is_false(field:removePortalBetween({2,2}, {23,13}))
    end)
end)

describe('objects', function()
    local field, knight

    before_each(function()
        field = maps.graphOf(maps.ENTITIES)
        knight = {name = 'knight'}
    end)

    it('are found where they were put', function()
        field:addObject(knight, {4,4})
        assert.are.same({knight}, field:getObjectsAt({4,4}))
        assert.is_nil(field:getObjectsAt({5,4}))
    end)

    it('move to another tile', function()
        field:addObject(knight, {4,4})
        assert.is_true(field:translateObject(knight, {6,4}))
        assert.is_nil(field:getObjectsAt({4,4}))
        assert.are.same({knight}, field:getObjectsAt({6,4}))
    end)

    it('do not move outside the map', function()
        field:addObject(knight, {4,4})
        assert.is_false(field:translateObject(knight, {99,99}))
        assert.are.same({knight}, field:getObjectsAt({4,4}))
    end)

    it('are removed', function()
        field:addObject(knight, {4,4})
        field:removeObject(knight)
        assert.is_nil(field:getObjectsAt({4,4}))
    end)

    it('are ignored by a search that names no groups', function()
        field:addObject(knight, {4,4}, {'Knights'})
        assert.is_truthy(field:findPath({3,4}, {5,4}):hasPoint({4,4}))
    end)

    it('block a search that collides with their group', function()
        field:addObject(knight, {4,4}, {'Knights'})
        local path = field:findPath({3,4}, {5,4}, nil, {'Knights'})
        assert.is_truthy(path)
        assert.is_falsy(path:hasPoint({4,4}), 'should have walked around the knight')
    end)

    it('do not block a search that collides with another group', function()
        field:addObject(knight, {4,4}, {'Knights'})
        local path = field:findPath({3,4}, {5,4}, nil, {'Demons'})
        assert.is_truthy(path:hasPoint({4,4}))
    end)
end)

describe('a wrapping map', function()
    it('lets the path cross the left and right edges', function()
        local flat = maps.graphOf(maps.MAP_WRAP)
        local wrapped = maps.graphOf(maps.MAP_WRAP, {wrap = 1})
        -- Two tiles on the same row, one at each end of the map
        local west, east = {2,1}, {29,1}
        assert.is_true(wrapped:findPath(west, east).weight
                     < flat:findPath(west, east).weight,
            'wrapping around the edge is the short way')
    end)

    it('lets the path cross the top and bottom edges', function()
        local flat = maps.graphOf(maps.MAP_WRAP)
        local wrapped = maps.graphOf(maps.MAP_WRAP, {wrap = 2})
        local north, south = {1,1}, {1,15}
        assert.is_true(wrapped:findPath(north, south).weight
                     < flat:findPath(north, south).weight)
    end)

    it('wraps both ways when asked for both', function()
        local wrapped = maps.graphOf(maps.MAP_WRAP, {wrap = 3})
        assert.are.equal(2, wrapped:findPath({1,1}, {30,15}).weight,
            'opposite corners are two steps apart when both edges wrap')
    end)
end)
