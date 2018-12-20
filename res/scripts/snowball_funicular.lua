local colliderutil = require "colliderutil"
local constructionutil = require "constructionutil"
local vec2 = require "snowball_funicular_vec2"
local vec3 = require "snowball_funicular_vec3"
local mat3 = require "snowball_funicular_mat3"
local polygon = require "snowball_funicular_polygon"
local spline = require "snowball_funicular_spline"
local vec4 = require "vec4"
local transf = require "transf"

local funicular = {}

funicular.segmentLength = 2
funicular.segmentWidth = 4
funicular.segmentHeight = 0.3 + 0.08 + 0.15

funicular.trackTypeWood = 0
funicular.trackTypeConcrete = 1

funicular.radius = 100

function funicular.buildSegment(p1, p2, model, modelSize, result)
    local b1 = vec2.ortho(vec2.sub(p2, p1))
    local b2 = vec3.sub(p2, p1)
    b1[3] = 0

    local affine = mat3.affine({1, 0, 0}, {0, 1 * modelSize[2], 0}, {0, 0, 1}, b1, b2, {0, 0, 1})

    local localTransform =
        transf.new(
        vec4.new(affine[1][1], affine[2][1], affine[3][1], .0),
        vec4.new(affine[1][2], affine[2][2], affine[3][2], .0),
        vec4.new(affine[1][3], affine[2][3], affine[3][3], .0),
        vec4.new(p1[1], p1[2], p1[3], 1.0)
    )

    result.models[#result.models + 1] = {
        id = model,
        transf = localTransform
    }
end

function funicular.buildWideSegment(p1, p2, n1, n2, leftModel, rightModel, modelSize, result)
    local left1 = vec3.add(p1, vec3.mul(-0.5 * modelSize[1], n1))
    local right1 = vec3.add(p1, vec3.mul(0.5 * modelSize[1], n1))

    local left2 = vec3.add(p2, vec3.mul(-0.5 * modelSize[1], n2))
    local right2 = vec3.add(p2, vec3.mul(0.5 * modelSize[1], n2))

    -- model with right angle in the lower left corner

    local b1 = n1
    local b2 = vec3.sub(left2, left1)
    b1[3] = 0

    local affine = mat3.affine({1, 0, 0}, {0, 1 * modelSize[2], 0}, {0, 0, 1}, b1, b2, {0, 0, 1})

    local transform =
        transf.new(
        vec4.new(affine[1][1], affine[2][1], affine[3][1], .0),
        vec4.new(affine[1][2], affine[2][2], affine[3][2], .0),
        vec4.new(affine[1][3], affine[2][3], affine[3][3], .0),
        vec4.new(left1[1], left1[2], left1[3], 1.0)
    )

    result.models[#result.models + 1] = {
        id = leftModel,
        transf = transform
    }

    -- model with right angle in the lower left corner

    b1 = vec3.mul(-1, n2)
    b2 = vec3.sub(right1, right2)
    b1[3] = 0

    affine = mat3.affine({1, 0, 0}, {0, 1 * modelSize[2], 0}, {0, 0, 1}, b1, b2, {0, 0, 1})

    transform =
        transf.new(
        vec4.new(affine[1][1], affine[2][1], affine[3][1], .0),
        vec4.new(affine[1][2], affine[2][2], affine[3][2], .0),
        vec4.new(affine[1][3], affine[2][3], affine[3][3], .0),
        vec4.new(right2[1], right2[2], right2[3], 1.0)
    )

    result.models[#result.models + 1] = {
        id = leftModel,
        transf = transform
    }
end

function funicular.getNormal(point, previous, next)
    local normal = {0, 0}

    if previous then
        local ortho =
            vec2.normalize {
            point[2] - previous[2],
            point[1] - previous[1]
        }

        normal[1] = normal[1] + ortho[1]
        normal[2] = normal[2] - ortho[2]
    end
    if next then
        local ortho =
            vec2.normalize {
            next[2] - point[2],
            next[1] - point[1]
        }

        normal[1] = normal[1] + ortho[1]
        normal[2] = normal[2] - ortho[2]
    end

    normal = vec2.normalize(normal)
    return normal
end

function funicular.deCasteljau(p0, p1, p2, p3, parts)
    local result = {}

    for i = 0, parts do
        local t = 1.0 / parts * i

        local x =
            t * t * t * (p0[1] * -1 + p1[1] * 3 + p2[1] * -3 + p3[1]) + t * t * (p0[1] * 3 + p1[1] * -6 + p2[1] * 3) +
            t * (p0[1] * -3 + p1[1] * 3) +
            p0[1]

        local y =
            t * t * t * (p0[2] * -1 + p1[2] * 3 + p2[2] * -3 + p3[2]) + t * t * (p0[2] * 3 + p1[2] * -6 + p2[2] * 3) +
            t * (p0[2] * -3 + p1[2] * 3) +
            p0[2]

        result[#result + 1] = {x, y}
    end

    return result
end

function funicular.arcSegment(radius, center, angle, direction, parts)
    local da = angle / parts
    local result = {}

    for i = 0, parts do
        local a = i * da
        result[#result + 1] = {math.cos(a) * radius * direction + center[1], math.sin(a) * radius + center[2]}
    end

    return result
end

function funicular.lineSegment(p1, p2, parts)
    local result = {}

    local x = p1[1]
    local y = p1[2]
    local z = p1[3]

    local p = 1.0 / parts
    local dx = (p2[1] - p1[1]) * p
    local dy = (p2[2] - p1[2]) * p
    local dz = (p2[3] - p1[3]) * p

    for i = 0, parts do
        result[#result + 1] = {x + i * dx, y + i * dy, z + i * dz}
    end

    return result
end

function funicular.trackTypeToConfig(type)
    if type == funicular.trackTypeWood then
        return "standard"
    elseif type == funicular.trackTypeConcrete then
        return "high_speed"
    end

    return "standard"
end

function funicular.buildTrack(points, startDirection, endDirection, asEdge, type, rack, snap, result)
    local terrainFaces = {}
    local colliderFaces = {}
    local groundFaces = {}
    local left = {}
    local right = {}

    for i = 1, #points - 1 do
        local p1 = points[i]
        local p2 = points[i + 1]

        local n1 = nil
        local d1 = nil
        local length = vec3.length(vec3.sub(p2, p1))

        if i == 1 then
            d1 = vec3.normalize(startDirection)
            n1 = vec2.normalize(vec2.ortho(d1))
        else
            d1 = vec3.normalize(vec3.sub(points[i + 1], points[i - 1]))
            n1 = funicular.getNormal(p1, points[i - 1], points[i + 1])
        end
        local n2 = nil
        if i == #points - 1 then
            d2 = vec3.normalize(endDirection)
            n2 = vec2.normalize(vec2.ortho(endDirection))
        else
            d2 = vec3.normalize(vec3.sub(points[i + 2], points[i]))
            n2 = funicular.getNormal(p2, p1, points[i + 2])
        end

        n1[3] = 0
        n2[3] = 0

        left[#left + 1] = vec3.add(p1, vec3.mul(-0.5 * funicular.segmentWidth, n1))
        right[#right + 1] = vec3.add(p1, vec3.mul(0.5 * funicular.segmentWidth, n1))

        if i == #points - 1 then
            left[#left + 1] = vec3.add(p2, vec3.mul(-0.5 * funicular.segmentWidth, n2))
            right[#right + 1] = vec3.add(p2, vec3.mul(0.5 * funicular.segmentWidth, n2))
        end

        if not asEdge then
            funicular.buildSegment(
                {p1[1], p1[2], p1[3] + funicular.segmentHeight},
                {p2[1], p2[2], p2[3] + funicular.segmentHeight},
                "asset/snowball_funicular_lane.mdl",
                {1, 1, 1},
                result
            )
        end

        if rack then
            funicular.buildSegment(
                {p1[1], p1[2], p1[3]},
                {p2[1], p2[2], p2[3]},
                "asset/tracks/snowball_track_rack.mdl",
                {1, funicular.segmentLength, 1},
                result
            )
        end

        local trackConfig = funicular.trackTypeToConfig(type)

        if asEdge then
            if not result.edgeLists then
                result.edgeLists = {}
            end

            local snapNodes = {}
            if snap and i == 1 then
                snapNodes = {0}
            elseif snap and i ==  #points - 1 then
                snapNodes = {1}
            end

            result.edgeLists[#result.edgeLists + 1] = {
                type = "TRACK",
                params = {
                    catenary = false,
                    type = trackConfig .. ".lua"
                },
                edges = {
                    {p1, vec3.mul(length, d1)},
                    {p2, vec3.mul(length, d2)}
                },
                snapNodes = snapNodes
            }
        else
            funicular.buildWideSegment(
                {p1[1], p1[2], p1[3]},
                {p2[1], p2[2], p2[3]},
                n1,
                n2,
                "asset/tracks/snowball_track_" .. trackConfig .. "_a.mdl",
                "asset/tracks/snowball_track_" .. trackConfig .. "_b.mdl",
                {funicular.segmentWidth, funicular.segmentLength, 1},
                result
            )
        end
        terrainFaces[#terrainFaces + 1] = {
            vec3.add(p1, vec3.mul(-funicular.segmentWidth, n1)),
            vec3.add(p2, vec3.mul(-funicular.segmentWidth, n2)),
            vec3.add(p2, vec3.mul(funicular.segmentWidth, n2)),
            vec3.add(p1, vec3.mul(funicular.segmentWidth, n1))
        }

        colliderFaces[#colliderFaces + 1] = {
            vec3.add(p1, vec3.mul(-0.8 * funicular.segmentWidth, n1)),
            vec3.add(p2, vec3.mul(-0.8 * funicular.segmentWidth, n2)),
            vec3.add(p2, vec3.mul(0.8 * funicular.segmentWidth, n2)),
            vec3.add(p1, vec3.mul(0.8 * funicular.segmentWidth, n1))
        }
    end

    for i = 1, #right do
        groundFaces[#groundFaces + 1] = right[i]
    end

    for i = 1, #left do
        groundFaces[#groundFaces + 1] = left[#left - i + 1]
    end

    if not result.terrainAlignmentLists then
        result.terrainAlignmentLists = {}
    end
    if not asEdge then
        result.terrainAlignmentLists[#result.terrainAlignmentLists + 1] = {
            type = "EQUAL",
            faces = terrainFaces,
            slopeLow = 1,
            slopeHigh = 1
        }

        if not result.colliders then
            result.colliders = {}
        end

        for i = 1, #colliderFaces do
            result.colliders[#result.colliders + 1] = colliderutil.createPointCloud(colliderFaces[i])
        end

        if not result.groundFaces then
            result.groundFaces = {}
        end

        result.groundFaces[#result.groundFaces + 1] = {
            face = groundFaces,
            modes = {{type = "STROKE_OUTER", key = "ballast"}}
        }
        result.groundFaces[#result.groundFaces + 1] = {
            face = constructionutil.reverseFace(groundFaces),
            modes = {{type = "STROKE_OUTER", key = "ballast"}}
        }
    end
end

local function compareBySeed(a, b)
    return tonumber(a.params.seed) < tonumber(b.params.seed)
end

function funicular.getStations()
    local constructions =
        game.interface.getEntities(
        {pos = {0, 0}, radius = 900000},
        {type = "CONSTRUCTION", includeData = true, fileName = "station/rail/snowball_funicular_planner.con"}
    )
    local stations = {}
    for id, data in pairs(constructions) do        
        stations[#stations + 1] = data        
    end
    table.sort(stations, compareBySeed)

    return stations
end

function funicular.getValuesFromStations(stations)
    if #stations < 2 then
        return nil
    end

    local result = {
        segments = {},
        edges = {}
    }

    for i = 1, #stations - 1 do
        local s1 = 20
        local s2 = 20

        local m1 = mat3.fromView(stations[i].transf)
        local m2 = mat3.fromView(stations[i + 1].transf)

        local p1 = {stations[i].transf[13], stations[i].transf[14], stations[i].transf[15]}
        local slope1 =
            stations[i].params.snowball_funicular_slope_10 * 10 + stations[i].params.snowball_funicular_slope_1
        if stations[i].params.snowball_funicular_slope_sign > 0 then
            slope1 = slope1 * -1
        end

        local p2 = {stations[i + 1].transf[13], stations[i + 1].transf[14], stations[i + 1].transf[15]}
        local slope2 =
            stations[i + 1].params.snowball_funicular_slope_10 * 10 + stations[i + 1].params.snowball_funicular_slope_1
        if stations[i + 1].params.snowball_funicular_slope_sign > 0 then
            slope2 = slope2 * -1
        end

        local a0 = vec3.add(p1, mat3.transform(m1, {0, -0.5 * s1, -0.5 * s1 * slope1 / 100}))
        local a1 = vec3.add(p1, mat3.transform(m1, {0, 0.5 * s1, 0.5 * s1 * slope1 / 100}))
        local a2 = vec3.add(p2, mat3.transform(m2, {0, -0.5 * s2, -0.5 * s2 * slope2 / 100}))
        local a3 = vec3.add(p2, mat3.transform(m2, {0, 0.5 * s2, 0.5 * s2 * slope2 / 100}))

        local n = vec3.length(vec3.sub(a2, a1)) * 0.333

        local c1 = vec3.add(p1, mat3.transform(m1, {0, 0.5 * s1 + n, (0.5 * s1 + n) * slope1 / 100}))
        local c2 = vec3.add(p2, mat3.transform(m2, {0, -0.5 * s2 - n, (-0.5 * s2 - n) * slope2 / 100}))

        local spline = spline.cubicBezierCurveByLength(a1, c1, c2, a2, funicular.segmentLength, 0.05)

        if i == 1 then
            result.edges[#result.edges + 1] = {
                a0,
                a1,
                rack = stations[i].params.snowball_funicular_rack == 1,
                type = stations[i].params.snowball_funicular_type
            }
        end
        result.edges[#result.edges + 1] = {
            a2,
            a3,
            rack = stations[i].params.snowball_funicular_rack == 1,
            type = stations[i].params.snowball_funicular_type
        }
        result.segments[#result.segments + 1] = {
            points = spline,
            rack = stations[i].params.snowball_funicular_rack == 1,
            type = stations[i].params.snowball_funicular_type,
            p1 = p1,
            p2 = p2,
            m1 = m1,
            m2 = m2
        }
    end

    return result
end

function funicular.getPolygon(points)
    if #points < 1 then
        return nil
    elseif #points == 1 then
        return {points[1]}
    end

    local result = {}

    --right side
    for i = 1, #points - 1 do
        result[#result + 1] = points[i]
    end

    --left side
    for i = #points, 2, -1 do
        result[#result + 1] = points[i]
    end

    if #result == 0 then
        return nil
    end

    return result
end

function funicular.checkAngles(points)
    
    for i = 1, #points - 2 do

        local a = vec2.sub(points[i+1], points[i])
        local b = vec2.sub(points[i+2], points[i+1])
        local la = vec2.length(a)
        local lb = vec2.length(b)
        local angle = math.acos(vec2.dot(a,b) / ( la * lb))
        local d = math.sin(angle) * funicular.segmentWidth
        
        if d > la or d > lb then
            return false
        end        
    end

    return true
end

function funicular.plan(slope, type, rack, result)
    local modelPoints =
        spline.linearByLength({0.0, -10, -10 * slope / 100}, {0.0, 10, 10 * slope / 100}, funicular.segmentLength)

    
    local arrowtrans = transf.rotZYXTransl({x = 0, y = 0, z = math.asin( slope / 100 )}, {x = 0, y = 0, z=5 })

    --[[
        8: max slope to build
        11: max slope to snap
        30: arbitary high slope
    ]]

    if math.abs( slope ) <= 11 then
        result.models[#result.models + 1] = {
            id = "snowball_funicular/snowball_funicular_arrow_green.mdl",
            transf = arrowtrans
        }
    elseif math.abs( slope ) <= 30 then
        result.models[#result.models + 1] = {
            id = "snowball_funicular/snowball_funicular_arrow_yellow.mdl",
            transf = arrowtrans
        }
    else
        result.models[#result.models + 1] = {
            id = "snowball_funicular/snowball_funicular_arrow_red.mdl",
            transf = arrowtrans
        }
    end

    funicular.buildTrack(modelPoints, {0.0, 1, 0.0}, {0.0, 1, 0.0}, math.abs( slope ) <= 8, type, rack, true, result)
    local stations = funicular.getStations()
    local values = funicular.getValuesFromStations(stations)
    if not values then
        return
    end

    local points = {}

    for i = 1, #values.segments do
        for j = 1, #values.segments[i].points do
            points[#points + 1] = values.segments[i].points[j]
        end
    end

    local anglesOk = funicular.checkAngles(points)
    
    local color = {0.9, 0.7, 0.3, 1}
    if not anglesOk then
        color = {1.0, 0.2, 0.1, 1}
    end
    local polygon = funicular.getPolygon(points)
    local zone = {polygon = polygon, draw = true, drawColor = color}

    game.interface.setZone("snowball_funicular_zone", zone)
end

function funicular.build(result)
    result.models[#result.models + 1] = {
        id = "asset/snowball_funicular_suspensor.mdl",
        transf = {1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1}
    }

    local stations = funicular.getStations()
    local values = funicular.getValuesFromStations(stations)
    if not values then
        return
    end

    

    for i = 1, #stations do
        game.interface.bulldoze(stations[i].id)
    end

    game.interface.setZone("snowball_funicular_zone", nil)

    local points = {}

    for i = 1, #values.segments do
        for j = 1, #values.segments[i].points do
            points[#points + 1] = values.segments[i].points[j]
        end
    end

    local anglesOk = funicular.checkAngles(points)
    if not anglesOk then
        return
    end

    local player = game.interface.getPlayer()
    local id =
        game.interface.buildConstruction(
        "station/rail/snowball_funicular_track.con",
        {
            forReal = false,
            values = values
        },
        {1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1}
    )

    game.interface.setPlayer(id, player)

    game.interface.upgradeConstruction(
        id,
        "station/rail/snowball_funicular_track.con",
        {
            forReal = true,
            values = values
        }
    )
end

function funicular.reset(result)
    result.models[#result.models + 1] = {
        id = "asset/snowball_funicular_suspensor.mdl",
        transf = {1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1}
    }

    local stations = funicular.getStations()
    local values = funicular.getValuesFromStations(stations)
    if not values then
        return
    end

    for i = 1, #stations do
        game.interface.bulldoze(stations[i].id)
    end

    game.interface.setZone("snowball_funicular_zone", nil)
end

return funicular
