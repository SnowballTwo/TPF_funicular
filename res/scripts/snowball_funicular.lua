local vec2 = require "snowball_funicular_vec2"
local vec3 = require "snowball_funicular_vec3"
local mat3 = require "snowball_funicular_mat3"
local polygon = require "snowball_funicular_polygon"
local vec4 = require "vec4"
local transf = require "transf"

local funicular = {}

local function compareByCount(a, b)
    return a.count < b.count
end

local function compareByDistance(a, b)
    return a.distance < b.distance
end

funicular.segmentLength = 2

funicular.radius = 100

funicular.trackTrans = {
    0,                            1,                            0,                            0,
    1,                            0,                            0,                            0,
    0,                            0,                            1,                            0,
    0.5 * funicular.segmentLength,                            0,                            0,                            1
}

function funicular.dump(o)
    if type(o) == "table" then
        local s = "{ "
        for k, v in pairs(o) do
            if type(k) ~= "number" then
                k = '"' .. k .. '"'
            end
            s = s .. "[" .. k .. "] = " .. funicular.dump(v) .. ","
        end
        return s .. "} "
    else
        return tostring(o)
    end
end

function funicular.getObjects()
    local entities =
        game.interface.getEntities({pos = {0, 0}, radius = 900000}, {type = "ASSET_GROUP", includeData = true})

    local finishers = {}
    local markers = {}

    if entities then
        for id, data in pairs(entities) do           
            local markercount = data.models["asset/snowball_funicular_marker.mdl"] or 0

            if markercount > 0 then
                markers[#markers + 1] = data
                markers[#markers].count = markercount
            end

            local finishercount = data.models["asset/snowball_funicular_finisher.mdl"] or 0
            if finishercount > 0 then
                finishers[#finishers + 1] = data
            end
        end
    end

    table.sort(markers, compareByCount)

    return {markers = markers, finishers = finishers}
end

function funicular.getBuildingConnectionPoints(point)
    local entities =
        game.interface.getEntities({pos = point, radius = 200}, {type = "CONSTRUCTION", includeData = true})
    local connectionPoints = {}

    if entities then
        for id, data in pairs(entities) do
            
            if (data.fileName and (data.fileName == "depot/snowball_funicular_depot.con")) or
                (data.fileName and (data.fileName == "station/street/snowball_funicular_station.con"))
             then              
                connectionPoints[#connectionPoints + 1] = data
                connectionPoints[#connectionPoints].position = {data.transf[13], data.transf[14], data.transf[15]}
                connectionPoints[#connectionPoints].distance = vec2.length(vec2.sub(data.position, point))               
            end
        end
    end

    table.sort(connectionPoints, compareByDistance)

    return connectionPoints
end

local function normalizeAngle(angle)
    local result = angle
    while result > math.pi do
        result = result - math.pi
    end

    while result < -math.pi do
        result = result + math.pi
    end
    return result
end

function funicular.getPoints(markers)
    local result = {}

    for i = 1, #markers do
        result[#result + 1] = markers[i].position
    end

    return result
end

function funicular.getNormals(points)
    local result = {}

    for i = 1, #points do
        local normal = {0, 0}

        if i > 1 then
            local ortho =
                vec2.normalize {
                points[i][2] - points[i - 1][2],
                points[i][1] - points[i - 1][1]
            }

            normal[1] = normal[1] + ortho[1]
            normal[2] = normal[2] - ortho[2]
        end
        if i < #points then
            local ortho =
                vec2.normalize {
                points[i + 1][2] - points[i][2],
                points[i + 1][1] - points[i][1]
            }

            normal[1] = normal[1] + ortho[1]
            normal[2] = normal[2] - ortho[2]
        end

        local normal = vec2.normalize(normal)

        if i > 1 and i < #points then
            local a = vec2.sub(points[i], points[i - 1])
            local b = vec2.sub(points[i + 1], points[i])
            local cosa = vec2.dot(a, b) / (vec2.length(a) * vec2.length(b))

            if (cosa > -1 and cosa < 1) then
                local an = math.acos(cosa)
                local angle = 0.5 * math.abs(normalizeAngle(an))

                normal[1] = normal[1] / math.cos(angle)
                normal[2] = normal[2] / math.cos(angle)
            end
        end

        result[#result + 1] = normal
    end

    return result
end

function funicular.getOutline(points, normals, width)
    local polygon = {}
    local right = {}
    local left = {}

    for i = 1, #points do
        local normal = normals[i]

        right[#right + 1] = {
            points[i][1] + 0.5 * width * normal[1],
            points[i][2] + 0.5 * width * normal[2],
            points[i][3]
        }
        left[#left + 1] = {
            points[i][1] - 0.5 * width * normal[1],
            points[i][2] - 0.5 * width * normal[2],
            points[i][3]
        }
    end

    if #left < 2 or #right < 2 then
        return nil
    end

    for i = 1, #right do
        polygon[#polygon + 1] = right[i]
    end

    for i = 1, #left do
        polygon[#polygon + 1] = left[#left - i + 1]
    end

    return polygon
end

function funicular.buildLane(point1, point2, result)
   
    local segment = vec3.sub(point2, point1)
    local scalex = vec2.length(segment) * 0.01
    local scalez = point2[3] - point1[3]
    local rotz = math.atan2(segment[2], segment[1])
    
    local scale = transf.scale({x = scalex, y = 1, z = scalez})   
    local rotTrans = transf.rotZTransl(rotz, {x = point1[1], y = point1[2], z = point1[3]})

    result.models[#result.models + 1] = {
        id = "asset/snowball_funicular_lane.mdl",
        transf = transf.mul(rotTrans, scale)
    }
end

function funicular.buildSegment(p1, p2, model, modelSize, result)
    
    local b1 = vec2.ortho(vec2.sub(p2, p1))  
    local b2 = vec3.sub(p2, p1)
    b1[3] = 0
   
    local affine = mat3.affine({1,0,0}, {0,1 * modelSize[2],0}, {0,0,1}, b1, b2, {0,0,1})

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
   
    local affine = mat3.affine({1,0,0}, {0,1 * modelSize[2],0}, {0,0,1}, b1, b2, {0,0,1})

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
   
    affine = mat3.affine({1,0,0}, {0,1 * modelSize[2],0}, {0,0,1}, b1, b2, {0,0,1})

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

function funicular.buildConnectionPoint(point, result)
    result.models[#result.models + 1] = {
        id = "asset/snowball_funicular_connection.mdl",
        transf = {1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, point[1], point[2], point[3], 1}
    }
end

function funicular.buildPylon(point, normal, model, result)
    local rotz = math.atan2(normal[2], normal[1])
    result.models[#result.models + 1] = {
        id = model,
        transf = transf.scaleRotZTransl(1, rotz, {x = point[1], y = point[2], z = point[3]})
    }
end

function funicular.connectToBuilding(point, result)
end

function funicular.buildGround(point, normal, result)
    local n = vec3.normalize({normal[1], normal[2], 0})

    local p1 = vec3.add(point, vec3.add(vec3.mul(2, {n[2], -n[1], 0}), vec3.mul(2, n)))
    local p2 = vec3.add(point, vec3.add(vec3.mul(2, {n[2], -n[1], 0}), vec3.mul(-2, n)))
    local p3 = vec3.add(point, vec3.add(vec3.mul(-2, {n[2], -n[1], 0}), vec3.mul(-2, n)))
    local p4 = vec3.add(point, vec3.add(vec3.mul(-2, {n[2], -n[1], 0}), vec3.mul(2, n)))

    result.groundFaces[#result.groundFaces + 1] = {
        face = {p1, p2, p3, p4},
        modes = {
            {
                type = "FILL",
                key = "town_concrete"
            },
            {
                type = "STROKE_OUTER",
                key = "town_concrete_border"
            }
        }
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
              t * t * t * (p0[1] * -1 + p1[1] *  3 + p2[1] * -3 + p3[1])
            + t * t *     (p0[1] *  3 + p1[1] * -6 + p2[1] *  3)
            + t *         (p0[1] * -3 + p1[1] *  3)
            +              p0[1]   
 
          
        local y =
              t * t * t * (p0[2] * -1 + p1[2] *  3 + p2[2] * -3 + p3[2])
            + t * t *     (p0[2] *  3 + p1[2] * -6 + p2[2] *  3)
            + t *         (p0[2] * -3 + p1[2] *  3)
            +              p0[2] 
      
        result[#result + 1] = {x,y}
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


function funicular.getCurveSegment(segment, tension, partLength, result)
    local length = vec2.length(vec2.sub(segment[2], segment[3]))

    local m1x = (1 - tension) * (segment[3][1] - segment[1][1]) / 2
    local m2x = (1 - tension) * (segment[4][1] - segment[2][1]) / 2

    local m1y = (1 - tension) * (segment[3][2] - segment[1][2]) / 2
    local m2y = (1 - tension) * (segment[4][2] - segment[2][2]) / 2

    local parts = math.round(length / partLength)

    for i = 1, parts - 1 do
        local t = 1.0 / parts * i

        local x =
            (2 * t * t * t - 3 * t * t + 1) * segment[2][1] + (t * t * t - 2 * t * t + t) * m1x +
            (-2 * t * t * t + 3 * t * t) * segment[3][1] +
            (t * t * t - t * t) * m2x
        local y =
            (2 * t * t * t - 3 * t * t + 1) * segment[2][2] + (t * t * t - 2 * t * t + t) * m1y +
            (-2 * t * t * t + 3 * t * t) * segment[3][2] +
            (t * t * t - t * t) * m2y

        result[#result + 1] = {x, y}
    end
end
function funicular.getBezierCurve(points, tension, width)
    local result = {}

    if #points < 2 then
        return {points[1]}
    elseif #points == 2 then
        result[#result + 1] = points[1]
        local parts = math.round(length / width * 1.5)
        for i = 1, parts - 1 do
            result[#result + 1] = vec2.add(points[1], vec2.mul(i / parts, vec2.sub(points[2], points[1])))
        end
    else
        local n = #points - 1

        for i = 0, n - 1 do
            result[#result + 1] = points[i + 1]

            if i == 0 then
                funicular.getCurveSegment({points[1], points[1], points[2], points[3]}, tension, width, result)
            elseif (i == n - 1) then
                funicular.getCurveSegment({points[n - 1], points[n], points[n + 1], points[n + 1]}, tension, width, result)
            else
                funicular.getCurveSegment({points[i], points[i + 1], points[i + 2], points[i + 3]}, tension, width, result)
            end
        end
    end

    result[#result + 1] = points[#points]

    for i = 1, #result do
        if (not result[i][3]) or (not result[i].snapped) then
            result[i][3] = game.interface.getHeight({result[i][1], result[i][2]})
        end
    end

    return result
end

return funicular
