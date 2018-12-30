local vec2 = require "snowball_funicular_vec2"
local vec3 = require "snowball_funicular_vec3"
local spline = require "snowball_funicular_spline"
local build = require "snowball_funicular_build"

Segment = {}
Segment.__index = Segment

function Segment:Create(p1, p2, d1, d2, type, tracksStart, tracksEnd, catenary, snapStart, snapEnd, rack)
    local segment = {
        p1 = p1,
        p2 = p2,
        d1 = d1,
        d2 = d2,
        type = type or "standard.lua",
        tracksStart = tracksStart or {0},
        tracksEnd = tracksEnd or {0},
        catenary = catenary or false,
        snapStart = snapStart or false,
        snapEnd = snapEnd or false,
        rack = rack or false
    }
    setmetatable(segment, Segment)
    return segment
end

local function buildRack(p1, p2, d1, d2, result)
    local rackLength = 2.0

    local b1 = p1
    local b2 = vec3.add(p1, vec3.mul(0.33333, d1))
    local b3 = vec3.add(p2, vec3.mul(-0.33333, d2))
    local b4 = p2

    local points = spline.cubicBezierCurveByLength(b1, b2, b3, b4, rackLength, 0.05)

    for i = 1, #points - 1 do
        local a = points[i]
        local b = points[i + 1]
        build.affine(
            {a[1], a[2], a[3]},
            {b[1], b[2], b[3]},
            "asset/tracks/snowball_track_rack.mdl",
            {1, rackLength, 1},
            result
        )
    end
end

function Segment:BuildEdges(result)
    local snapNodes = {}

    if self.snapStart then
        snapNodes[#snapNodes + 1] = 0
    end

    if self.snapEnd then
        snapNodes[#snapNodes + 1] = 1
    end

    if not result.edgeLists then
        result.edgeLists = {}
    end

    for i = 1, #self.tracksStart do
        local n1 = vec2.normalize(vec2.ortho(self.d1))
        n1[3] = 0
        local p1 = vec3.add(self.p1, vec3.mul(self.tracksStart[i], n1))

        for j = 1, #self.tracksEnd do
            --avoid crossing edges. it works! but we don't need it.
            if j == i or #self.tracksEnd ~= #self.tracksStart then
                local n2 = vec2.normalize(vec2.ortho(self.d2))
                n2[3] = 0
                local p2 = vec3.add(self.p2, vec3.mul(self.tracksEnd[j], n2))
                local l = vec3.length(vec3.sub(p2, p1))
                local d1 = vec3.mul(l, self.d1)
                local d2 = vec3.mul(l, self.d2)

                result.edgeLists[#result.edgeLists + 1] = {
                    type = "TRACK",
                    params = {
                        catenary = self.catenary,
                        type = self.type
                    },
                    edges = {
                        {p1, d1},
                        {p2, d2}
                    },
                    freeNodes = {0, 1},
                    snapNodes = snapNodes
                }

                if self.rack and ( #self.tracksEnd == #self.tracksStart or self:IsFlat()) then
                    buildRack(p1, p2, d1, d2, result)
                end
            end
        end
    end
end

function Segment:IsFlat()
    local n = vec3.cross(self.d1, {self.d1[2], -self.d1[1], 0})
    local p = self.p1
    local dot = vec3.dot(n,p)
    local n0 = vec3.normalize(n)
    if dot < 0 then
        n0 = vec3.mul(-1, n0)
    end
    local d = vec3.dot(p, n0)

    if math.abs(vec3.dot(self.p2, n0) - d) > 0.1 then
        return false
    end

    if math.abs(vec3.dot(vec3.add(self.p2, self.d2), n0) - d) > 0.1 then
        return false
    end

    return true
end

function Segment:IsLinear()
    local s = nil
    local d = nil
    for i = 1, 3 do
        local si = (self.p2[i] - self.p1[i]) / self.d1[i]
        local d1 = self.d1[i] / self.d2[i]
        if s and si ~= s then
            return false
        end
        if d and di ~= d then
            return false
        end
        d = di
        s = si
    end

    return true
end

function Segment:GetPoints()
    if self:IsLinear() then
        return {
            self.p1,
            self.p2
        }
    end

    local l = vec3.length(vec3.sub(self.p2, self.p1))

    local c1 = vec3.add(self.p1, vec3.mul(0.33333 * l, self.d1))
    local c2 = vec3.add(self.p2, vec3.mul(-0.33333 * l, self.d2))

    return spline.cubicBezierCurveByDistance(self.p1, c1, c2, self.p2, 0.5)
end

return Segment
