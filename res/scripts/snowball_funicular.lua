local colliderutil = require "colliderutil"
local constructionutil = require "constructionutil"
local vec2 = require "snowball_funicular_vec2"
local vec3 = require "snowball_funicular_vec3"
local mat3 = require "snowball_funicular_mat3"
local polygon = require "snowball_funicular_polygon"
local spline = require "snowball_funicular_spline"
local segment = require "snowball_funicular_segment"
local build = require "snowball_funicular_build"
local vec4 = require "vec4"
local transf = require "transf"

local funicular = {}

funicular.segmentLength = 2
funicular.segmentWidth = 4
funicular.segmentHeight = 0.3 + 0.08 + 0.15
funicular.slopePositive = 0
funicular.slopeNegative = 1
funicular.slopeAuto = 2
funicular.stationStore = {}
funicular.trackTypeWood = 0
funicular.trackTypeConcrete = 1
funicular.trackPositions = {
    {0},
    {-2.5, 2.5},
    {-5, 5}
}
funicular.lengths = {20, 40, 60, 80, 160}
funicular.radius = 100

funicular.trackParams = nil

local commonapiok = false
if (commonapi ~= nil and commonapi.uiparameter ~= nil) then
    funicular.trackParams = commonapi.uiparameter.createTrackCatenary()	   
	commonapiok = true	
end

function funicular.makeCentered(segments)

    local center = {0, 0, 0}

    for i = 1, #segments do
        center = vec3.add(center, segments[i].p1)
        center = vec3.add(center, segments[i].p2)        
    end

    center = vec3.mul(1.0 / (#segments * 2), center)
      
    for i = 1, #segments do
        segments[i].p1 = vec3.sub(segments[i].p1, center)
        segments[i].p2 = vec3.sub(segments[i].p2, center)
    end

    return center
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

function funicular.getTrackType(params)
    
    local trackType
    
    if funicular.trackParams then
        return funicular.trackParams:getSelection(params).filename
    else
        local trackTypesDef = { "standard.lua", "high_speed.lua" }
        local trackIdx = (params.snowball_funicular_type or 0) + 1
        return trackTypesDef[trackIdx] or "standard.lua"
    end
end

function funicular.getCatenary(params)
	if funicular.trackParams  then
		return funicular.trackParams:getCatenarySelection(params)
	else
		return ((params.catenary or 0) == 1)
	end
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
            build.affine(
                {p1[1], p1[2], p1[3] + funicular.segmentHeight},
                {p2[1], p2[2], p2[3] + funicular.segmentHeight},
                "asset/snowball_funicular_lane.mdl",
                {1, 1, 1},
                result
            )
        end

        if rack then
            build.affine(
                {p1[1], p1[2], p1[3]},
                {p2[1], p2[2], p2[3]},
                "asset/tracks/snowball_track_rack.mdl",
                {1, funicular.segmentLength, 1},
                result
            )
        end

        local trackConfig = "standard"

        if asEdge then
            if not result.edgeLists then
                result.edgeLists = {}
            end

            local snapNodes = {}
            if snap and i == 1 then
                snapNodes = {0}
            elseif snap and i == #points - 1 then
                snapNodes = {1}
            end

            result.edgeLists[#result.edgeLists + 1] = {
                type = "TRACK",
                params = {
                    catenary = false,
                    type = type
                },
                edges = {
                    {p1, vec3.mul(length, d1)},
                    {p2, vec3.mul(length, d2)}
                },
                snapNodes = snapNodes
            }
        else
            build.affineWide(
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

function funicular.updateStations()
    local position = game.gui.getTerrainPos()
    local constructions =
        game.interface.getEntities(
        {pos = position, radius = 50},
        {type = "CONSTRUCTION", includeData = true, fileName = "station/rail/snowball_funicular_planner.con"}
    )

    for id, data in pairs(constructions) do
        local exists = false

        for i = 1, #funicular.stationStore do
            if (funicular.stationStore[i].id == id) then
                exists = true
            end
        end

        if not exists then
            funicular.stationStore[#funicular.stationStore + 1] = data
        end
    end

    local removedIndices = {}

    for i = 1, #funicular.stationStore do
        local data = game.interface.getEntity(funicular.stationStore[i].id)
        if not data or data.fileName ~= "station/rail/snowball_funicular_planner.con" then
            removedIndices[#removedIndices + 1] = i
        else
            funicular.stationStore[i] = data
        end
    end

    for i = 1, #removedIndices do
        table.remove(funicular.stationStore, removedIndices[i] - i + 1)
    end

    return funicular.stationStore
end

function funicular.getSlopeFromStation(station)
    local slope = station.params.snowball_funicular_slope_10 * 10 + station.params.snowball_funicular_slope_1
    if station.params.snowball_funicular_slope_sign > 0 then
        slope = slope * -1
    end
    return slope
end

function funicular.getSegments(stations)
    if #stations < 2 then
        return nil
    end

    local result = {}

    for i = 1, #stations - 1 do
        local s1 = funicular.lengths[stations[i].params.snowball_funicular_length + 1]
        local s2 = funicular.lengths[stations[i + 1].params.snowball_funicular_length + 1]

        local m1 = mat3.fromView(stations[i].transf)
        local m2 = mat3.fromView(stations[i + 1].transf)

        local p1 = {stations[i].transf[13], stations[i].transf[14], stations[i].transf[15]}
        local slope1 = funicular.getSlopeFromStation(stations[i])

        local p2 = {stations[i + 1].transf[13], stations[i + 1].transf[14], stations[i + 1].transf[15]}
        local slope2 = funicular.getSlopeFromStation(stations[i + 1])

        local a0 = vec3.add(p1, mat3.transform(m1, {0, -0.5 * s1, -0.5 * s1 * slope1 / 100}))
        local a1 = vec3.add(p1, mat3.transform(m1, {0, 0.5 * s1, 0.5 * s1 * slope1 / 100}))
        local a2 = vec3.add(p2, mat3.transform(m2, {0, -0.5 * s2, -0.5 * s2 * slope2 / 100}))
        local a3 = vec3.add(p2, mat3.transform(m2, {0, 0.5 * s2, 0.5 * s2 * slope2 / 100}))

        local en = vec3.length(vec3.sub(a2, a1))

        local d1 = vec3.normalize(mat3.transform(m1, {0, 1, 1 * slope1 / 100}))
        local d2 = vec3.normalize(mat3.transform(m2, {0, 1, 1 * slope2 / 100}))
       
        if i == 1 then
            result[#result + 1] =
                Segment:Create(
                a0,
                a1,
                vec3.normalize(vec3.sub(a1, a0)),
                vec3.normalize(vec3.sub(a1, a0)),                
                funicular.getTrackType(stations[i].params),
                funicular.trackPositions[stations[i].params.snowball_funicular_tracks + 1],
                funicular.trackPositions[stations[i].params.snowball_funicular_tracks + 1],
                funicular.getCatenary(stations[i].params),
                true,
                false,
                stations[i].params.snowball_funicular_rack == 1
            )
        end

        result[#result + 1] =
            Segment:Create(
            a1,
            a2,
            d1,
            d2,            
            funicular.getTrackType(stations[i + 1].params),
            funicular.trackPositions[stations[i].params.snowball_funicular_tracks + 1],
            funicular.trackPositions[stations[i + 1].params.snowball_funicular_tracks + 1],
            funicular.getCatenary(stations[i + 1].params),
            false,
            false,
            stations[i + 1].params.snowball_funicular_rack == 1
        )

        result[#result + 1] =
            Segment:Create(
            a2,
            a3,
            vec3.normalize(vec3.sub(a3, a2)),
            vec3.normalize(vec3.sub(a3, a2)),            
            funicular.getTrackType(stations[i + 1].params),
            funicular.trackPositions[stations[i + 1].params.snowball_funicular_tracks + 1],
            funicular.trackPositions[stations[i + 1].params.snowball_funicular_tracks + 1],
            funicular.getCatenary(stations[i + 1].params),
            false,
            i == #stations - 1,
            stations[i + 1].params.snowball_funicular_rack == 1
        )
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
        local a = vec2.sub(points[i + 1], points[i])
        local b = vec2.sub(points[i + 2], points[i + 1])
        local la = vec2.length(a)
        local lb = vec2.length(b)
        local cos = vec2.dot(a, b) / (la * lb)

        if cos < 1 and cos > -1 then
            local angle = math.acos(cos)
            local d = math.sin(angle) * funicular.segmentWidth

            if d > la or d > lb then                
                return false
            end
        end
    end

    return true
end

function funicular.updateAutomaticSlope(station, params)
    local s = funicular.lengths[station.params.snowball_funicular_length + 1]
    local m = mat3.fromView(station.transf)
    local p = {station.transf[13], station.transf[14], station.transf[15]}
    local a = vec3.add(p, mat3.transform(m, {0, -0.5 * s, 0}))
    local b = vec3.add(p, mat3.transform(m, {0, 0.5 * s, 0}))

    a[3] = game.interface.getHeight(a)
    b[3] = game.interface.getHeight(b)

    local sign = 0
    if a[3] > b[3] then
        sign = 1
    end

    local slope = math.floor(math.min(99, math.abs((b[3] - a[3]) * 5)))

    params.snowball_funicular_slope_sign = sign
    params.snowball_funicular_slope_10 = slope / 10
    params.snowball_funicular_slope_1 = slope % 10
    params.snowball_funicular_upgrade = 1
end

function funicular.upgradeStations(helper)
    local stations = funicular.stationStore
    for i = 1, #stations do
        local station = stations[i]
        local changed = false
       
        local params = {
            snowball_funicular_mode = 0,
            snowball_funicular_helper = station.params.snowball_funicular_helper,
            snowball_funicular_type = station.params.snowball_funicular_type,
            trackType = station.params.trackType,
            catenary = station.params.catenary,
            snowball_funicular_length = station.params.snowball_funicular_length,
            snowball_funicular_tracks = station.params.snowball_funicular_tracks,
            snowball_funicular_rack = station.params.snowball_funicular_rack,
            snowball_funicular_slope_sign = station.params.snowball_funicular_slope_sign,
            snowball_funicular_slope_10 = station.params.snowball_funicular_slope_10,
            snowball_funicular_slope_1 = station.params.snowball_funicular_slope_1
        }

        if station.params.snowball_funicular_slope_sign == funicular.slopeAuto then
            funicular.updateAutomaticSlope(station, params)
            changed = true
        end

        if changed then
            game.interface.upgradeConstruction(station.id, "station/rail/snowball_funicular_planner.con", params)
        end
    end
end

function funicular.plan(slope, length, tracks, type, rack, helper, result)
    local slopeTrans = transf.rotZYXTransl({x = 0, y = 0, z = math.atan((slope or 0) / 100)}, {x = 0, y = 0, z = 0})

    --[[
        nil: automatic slope
        8: max slope to snap        
        30: arbitary high slope
    ]]
    local arrowId = nil

    if not slope then
        arrowId = "snowball_funicular/snowball_funicular_arrow_blue.mdl"
    elseif math.abs(slope) <= 8 then
        arrowId = "snowball_funicular/snowball_funicular_arrow_green.mdl"
    elseif math.abs(slope) <= 30 then
        arrowId = "snowball_funicular/snowball_funicular_arrow_yellow.mdl"
    else
        arrowId = "snowball_funicular/snowball_funicular_arrow_red.mdl"
    end

    if arrowId then
        for i = 1, #tracks do
            local arrowtrans = transf.mul(transf.transl({x = tracks[i], y = 0, z = 5}), slopeTrans)
            result.models[#result.models + 1] = {
                id = arrowId,
                transf = arrowtrans
            }
        end
    end

    if slope then
        for i = 1, #tracks do
            local modelPoints =
                spline.linearByLength(
                {tracks[i], -0.5 * length, -0.5 * length * slope / 100},
                {tracks[i], 0.5 * length, 0.5 * length * slope / 100},
                funicular.segmentLength
            )
            funicular.buildTrack(
                modelPoints,
                {0.0, 1, 0.0},
                {0.0, 1, 0.0},
                math.abs(slope) <= 8,
                type,
                rack,
                true,
                result
            )
        end
    end

    if helper and helper > 0 then
        local scale = math.pow(2, helper - 1)
        local helperTrans = transf.mul(slopeTrans, transf.scale({x = 100 * scale, y = 100 * scale, z = 100 * scale}))
        result.models[#result.models + 1] = {
            id = "snowball_funicular/snowball_funicular_helper.mdl",
            transf = helperTrans
        }
    end

    local stations = funicular.stationStore
    local segments = funicular.getSegments(stations)
    if not segments then
        return
    end

    local points = {}

    for i = 1, #segments do
        local segmentPoints = segments[i]:GetPoints()
        for j = 1, #segmentPoints - 1 do
            points[#points + 1] = segmentPoints[j]
        end
        if i == #segments then
            points[#points + 1] = segmentPoints[#segmentPoints]
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

    local stations = funicular.stationStore
    local segments = funicular.getSegments(stations)
    if not segments then
        return
    end

    for i = 1, #stations do
        game.interface.bulldoze(stations[i].id)
    end

    game.interface.setZone("snowball_funicular_zone", nil)

    local points = {}

    for i = 1, #segments do
        local segmentPoints = segments[i]:GetPoints()
        for j = 1, #segmentPoints - 1 do
            points[#points + 1] = segmentPoints[j]
        end
        if i == #segments then
            points[#points + 1] = segmentPoints[#segmentPoints]
        end
    end

    local anglesOk = funicular.checkAngles(points)
    if not anglesOk then
        return
    end

    local center = funicular.makeCentered(segments)

    local player = game.interface.getPlayer()
    local id =
        game.interface.buildConstruction(
        "station/rail/snowball_funicular_track.con",
        {
            forReal = false,
            segments = segments
        },
        {1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, center[1], center[2], center[3], 1}
    )

    game.interface.setPlayer(id, player)

    game.interface.upgradeConstruction(
        id,
        "station/rail/snowball_funicular_track.con",
        {
            forReal = true,
            segments = segments
        }
    )
end

function funicular.reset(result)
    result.models[#result.models + 1] = {
        id = "asset/snowball_funicular_suspensor.mdl",
        transf = {1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1}
    }

    local stations = funicular.stationStore
    for i = 1, #stations do
        game.interface.bulldoze(stations[i].id)
    end

    game.interface.setZone("snowball_funicular_zone", nil)
end

return funicular
