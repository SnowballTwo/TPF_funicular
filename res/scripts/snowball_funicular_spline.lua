local vec3 = require "snowball_funicular_vec3"

local spline3 = {}

function spline3.cubicBezierPoint(b0, b1, b2, b3, t)
    local result = {}
    for c = 1, 3 do
        result[c] =
            t * t * t * (-1 * b0[c] + 3 * b1[c] - 3 * b2[c] + b3[c]) + t * t * (3 * b0[c] - 6 * b1[c] + 3 * b2[c]) +
            t * (-3 * b0[c] + 3 * b1[c]) +
            b0[c]
    end

    return result
end

function spline3.approximateParamter(b0, b1, b2, b3, length, tolerance)
   
    local dt = 0.5
    
    local b = spline3.cubicBezierPoint(b0, b1, b2, b3, dt)
    local l = vec3.length(vec3.sub(b,b0))
    local ratio = l / length
    local quitCounter = 0
    
    while math.abs(ratio - 1) > tolerance and quitCounter < 15 do
        dt = dt / ratio       
        quitCounter = quitCounter + 1

        b = spline3.cubicBezierPoint(b0, b1, b2, b3, dt)
        l = vec3.length(vec3.sub(b,b0))
        ratio = l / length
    end

    print("Approximated 'dt' to "..dt.." with a remaining deviation of "..math.abs(ratio - 1) * 100 .. "%.")

    return dt

end

function spline3.linearByLength(a,b,length)

    
    local v = vec3.sub(b,a)
    local s = math.max(1, math.round(vec3.length(v) / length))
    local d = vec3.mul(1 / s, v)

    local result = {a}

    for i = 1, s - 1 do
        result[#result + 1] = vec3.add(a, vec3.mul(i, d))
    end

    result[#result + 1] = b

    return result
end

function spline3.cubicBezierCurveByLength(b0, b1, b2, b3, length, tolerance)
    local result = {b0}

    local t = 0
    local dt = spline3.approximateParamter(b0, b1, b2, b3, length, tolerance)
    local count = math.round(1.0 / dt)
    local dt = 1.0 / count

    for i = 1, count - 1 do
        t = i * dt
        result[#result + 1] = spline3.cubicBezierPoint(b0, b1, b2, b3, t)
        local segmentLength = vec3.length(vec3.sub(result[#result], result[#result - 1]))
        print("Added segment with length "..segmentLength.." to point ["..result[#result][1]..","..result[#result][2]..","..result[#result][3].."] which means a deviation of "..math.abs(segmentLength / length - 1) * 100 .. "%")
    end
    
    result[#result + 1] = b3

    return result
end

return spline3
