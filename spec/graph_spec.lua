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

    -- The checks take the numbers behind the names too
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

    it('are checked by name and by alias too, the same as they are set', function()
        local Directions = require('pajarito').directions
        Directions.setDirectionAlias('north_wall', 'UP')
        field:setWall({5,5}, 'UP')
        assert.is_true(field:isWallBetween({5,5}, {5,4}, 'UP'))
        assert.is_true(field:isWallBetween({5,4}, {5,5}, 'DOWN'), 'and from the other side')
        assert.is_true(field:isWallBetween({5,5}, {5,4}, 'north_wall'))
        assert.is_false(field:isWallBetween({5,5}, {5,6}, 'DOWN'))
        Directions.clearAllAlias()
    end)

    it('refuse to check a direction that does not exist', function()
        field:setWall({5,5}, 'UP')
        assert.has_error(function() field:isWallBetween({5,5}, {5,4}, 'UPP') end)
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

    it('take a type in a table, next to plain directions', function()
        local WINDOW = require('pajarito').WINDOW
        field:setWall({5,5}, {'UP', WINDOW}, 'DOWN')
        assert.is_true(field:hasWallBetween({5,5}, {5,4}))
        assert.is_true(field:hasWallBetween({5,5}, {5,6}))
        assert.are.same({ {dir.UP, WINDOW}, {dir.DOWN} }, field:getWallTypesAt({5,5}))
    end)

    it('give back each face with its type', function()
        local WINDOW = require('pajarito').WINDOW
        assert.is_nil(field:getWallTypesAt({5,5}))
        field:setWall({5,5}, 'DOWN', {'UP', WINDOW}, {'LEFT', 'fence'})
        assert.are.same({
            {dir.LEFT, 'fence'},
            {dir.UP, WINDOW},
            {dir.DOWN},
        }, field:getWallTypesAt({5,5}))
    end)

    it('refuse a table with no type, a misspelt constant is nil', function()
        assert.has_error(function() field:setWall({5,5}, {'UP', nil}) end)
    end)

    it('forget their types when replaced', function()
        local WINDOW = require('pajarito').WINDOW
        field:setWall({5,5}, {'UP', WINDOW})
        field:setWall({5,5}, 'UP')
        assert.are.same({ {dir.UP} }, field:getWallTypesAt({5,5}))
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

    -- They used to be kept under the xor of both ids, where two
    -- unrelated portals can land on the same key. On the first row
    -- the id is x, and 1 xor 2 is 3, same as 4 xor 7.
    it('keep track of each portal on its own', function()
        local a1, a2, b1, b2 = {1,1}, {2,1}, {4,1}, {7,1}
        assert.is_true(field:createPortalBetween(a1, a2))
        assert.is_true(field:createPortalBetween(b1, b2))
        assert.is_false(field:removePortalBetween(a1, b2), 'those are not joined')
        assert.is_true(field:removePortalBetween(a1, a2))
        assert.is_true(field:removePortalBetween(b1, b2))
    end)

    it('leave the side link of neighbours alone when taken down', function()
        field:createPortalBetween({2,2}, {3,2})
        field:removePortalBetween({2,2}, {3,2})
        local here, there = field:getNodeAt({2,2}), field:getNodeAt({3,2})
        assert.is_false(here:hasPortal())
        assert.are.equal(there, here.conections[16], 'the step to the right is gone')
        assert.are.equal(here, there.conections[1], 'the step to the left is gone')
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

    -- The id used to be parsed out of tostring(object).
    it('take objects that print themselves', function()
        local named = setmetatable({}, {__tostring = function() return 'Knight' end})
        field:addObject(named, {4,4}, {'Knights'})
        assert.are.same({named}, field:getObjectsAt({4,4}))
        assert.is_true(field:translateObject(named, {6,4}))
        field:removeObject(named)
        assert.is_nil(field:getObjectsAt({6,4}))
    end)

    it('do not block a search that collides with another group', function()
        field:addObject(knight, {4,4}, {'Knights'})
        local path = field:findPath({3,4}, {5,4}, nil, {'Demons'})
        assert.is_truthy(path:hasPoint({4,4}))
    end)
end)

describe('an object position', function()
    it('is where the object stands', function()
        local field = maps.graphOf(maps.ENTITIES)
        local knight = {}
        field:addObject(knight, {4,4})
        assert.are.same({4,4}, field:getObjectPosition(knight))
        field:translateObject(knight, {6,4})
        assert.are.same({6,4}, field:getObjectPosition(knight))
        field:removeObject(knight)
        assert.is_nil(field:getObjectPosition(knight))
    end)
end)

describe('the line of sight', function()
    local MOUNTAIN, WOODS = 3, 4
    local field

    before_each(function()
        field = maps.graphOf(maps.open(5, 5))
    end)

    it('crosses open ground', function()
        assert.is_true(field:hasLineOfSight({1,1}, {5,4}))
        assert.is_true(field:hasLineOfSight({3,3}, {3,3}), 'a tile sees itself')
    end)

    it('does not leave the map', function()
        assert.is_false(field:hasLineOfSight({1,1}, {9,9}))
    end)

    it('is stopped by impassable terrain unless told otherwise', function()
        field:updateNodeTile({3,3}, MOUNTAIN)
        assert.is_false(field:hasLineOfSight({1,3}, {5,3}))
        field:setSightMap({[MOUNTAIN] = true})
        assert.is_true(field:hasLineOfSight({1,3}, {5,3}))
    end)

    it('is stopped by a walkable tile marked as blocking', function()
        field:updateNodeTile({3,3}, WOODS)
        assert.is_true(field:hasLineOfSight({1,3}, {5,3}))
        field:setSightMap({[WOODS] = false})
        assert.is_false(field:hasLineOfSight({1,3}, {5,3}))
    end)

    it('is never stopped by its own ends', function()
        field:updateNodeTile({1,3}, MOUNTAIN)
        field:updateNodeTile({5,3}, MOUNTAIN)
        assert.is_true(field:hasLineOfSight({1,3}, {5,3}))
    end)

    it('is stopped by walls', function()
        field:setWall({3,3}, 'LEFT')
        assert.is_false(field:hasLineOfSight({1,3}, {5,3}))
        assert.is_false(field:hasLineOfSight({5,3}, {1,3}), 'from the other side too')
        assert.is_true(field:hasLineOfSight({1,2}, {5,2}))
    end)

    it('goes through a window, but walking does not', function()
        local WINDOW = require('pajarito').WINDOW
        field:setWall({3,3}, {'LEFT', WINDOW}, 'UP')
        assert.is_true(field:hasLineOfSight({1,3}, {5,3}))
        assert.is_true(field:hasWallBetween({2,3}, {3,3}), 'still a wall to walk')
        assert.is_false(field:hasLineOfSight({3,1}, {3,5}), 'the other face is solid')
    end)

    it('is stopped by a window when the sight map says so', function()
        local WINDOW = require('pajarito').WINDOW
        field:setWall({3,3}, {'LEFT', WINDOW})
        field:setSightMap({[WINDOW] = false}) -- an arrow, not a spell
        assert.is_false(field:hasLineOfSight({1,3}, {5,3}))
    end)

    it('is stopped by a typed wall unless the sight map lets it through', function()
        local FENCE = 'fence'
        field:setWall({3,3}, {'LEFT', FENCE})
        assert.is_false(field:hasLineOfSight({1,3}, {5,3}))
        field:setSightMap({[FENCE] = true})
        assert.is_true(field:hasLineOfSight({1,3}, {5,3}))
    end)

    it('needs both faces of the same edge to let it through', function()
        local WINDOW = require('pajarito').WINDOW
        field:setWall({3,3}, {'LEFT', WINDOW})
        field:setWall({2,3}, 'RIGHT')
        assert.is_false(field:hasLineOfSight({1,3}, {5,3}))
    end)

    it('is stopped by objects of the blocking groups only', function()
        field:addObject({}, {3,3}, {'Knights'})
        assert.is_true(field:hasLineOfSight({1,3}, {5,3}))
        assert.is_true(field:hasLineOfSight({1,3}, {5,3}, {'Demons'}))
        assert.is_false(field:hasLineOfSight({1,3}, {5,3}, {'Knights'}))
    end)

    it('slips through a corner if one tile beside it is open', function()
        field:updateNodeTile({2,1}, MOUNTAIN)
        assert.is_true(field:hasLineOfSight({1,1}, {3,3}))
        field:updateNodeTile({1,2}, MOUNTAIN)
        assert.is_false(field:hasLineOfSight({1,1}, {3,3}), 'both sides are shut')
    end)

    -- Pinned in KNOWN_ISSUES.md, the line stays inside the map.
    it('does not go around the edges of a wrapping map', function()
        local ring = maps.graphOf(maps.open(5, 1), {wrap = 1})
        ring:updateNodeTile({3,1}, MOUNTAIN)
        assert.is_truthy(ring:findPath({1,1}, {5,1}), 'walking goes around')
        assert.is_false(ring:hasLineOfSight({2,1}, {4,1}), 'the sight does not')
    end)

    it('is the same both ways', function()
        field:updateNodeTile({3,2}, MOUNTAIN)
        field:updateNodeTile({2,4}, MOUNTAIN)
        for _, pair in ipairs({ {{1,1},{5,3}}, {{1,5},{4,1}}, {{2,1},{3,5}} }) do
            local a, b = pair[1], pair[2]
            assert.are.equal(field:hasLineOfSight(a, b), field:hasLineOfSight(b, a))
        end
    end)
end)

describe('point ids', function()
    it('are unique across the layers of a 3d map', function()
        local Node = require('pajarito').Node
        local seen, count = {}, 0
        for z = 1, 3 do for y = 1, 4 do for x = 1, 5 do
            local id = Node.getPointId(x, y, z, 5, 4, 3)
            assert.is_nil(seen[id], ('(%d,%d,%d) reuses id %d'):format(x, y, z, id))
            seen[id] = true
            count = count + 1
        end end end
        assert.are.equal(5 * 4 * 3, count)
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
