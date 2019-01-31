local vec2 = require "snowball_funicular_vec2"
local vec3 = require "snowball_funicular_vec3"
local mat3 = require "snowball_funicular_mat3"
local spline = require "snowball_funicular_spline"
local build = require "snowball_funicular_build"

Segment = {}
Segment.__index = Segment

function Segment:Create(
    p1,
    p2,
    d1,
    d2,
    type,
    tracksStart,
    tracksEnd,
    catenary,
    snapStart,
    snapEnd,
    rack,
    transition,
    station)
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
        rack = rack or false,
        transition = transition,
        station = station or false
    }
    setmetatable(segment, Segment)
    return segment
end

local function to4x4(m, p)
    return {
        m[1][1],
        m[2][1],
        m[3][1],
        0,
        m[1][2],
        m[2][2],
        m[3][2],
        0,
        m[1][3],
        m[2][3],
        m[3][3],
        0,
        p[1],
        p[2],
        p[3],
        1
    }
end

function Segment:BuildStation(result)
    if not self:IsLinear() then
        error("Nonlinear stations are not supported yet")
    end

    if #self.tracksStart ~= #self.tracksEnd then
        error("Stations must have a constant number of tracks")
    end

    local l = vec2.length(vec2.sub(self.p2, self.p1))

    --if l < 40 then
    --    error("Stations must have at least 40 meter length, yours is only "..l.." meters")
    --end

    --constants
    local terminalLength = 20
    local terminalOffset = 2.5
    local terminalWidth = 1.5
    local connectorWidth = 1

    local d = vec3.mul(0.5, vec3.sub(self.p2, self.p1))
    local dn = vec3.normalize(d)
    local n = vec2.normalize(vec2.ortho(self.d1))
    n[3] = 0
    local f = vec2.normalize(d)[1] / dn[1]
    local s = vec3.add(self.p1, d)
    
    local terminalSegments = math.round(l / terminalLength)

    for i, x in pairs(self.tracksStart) do
        local p1 = vec3.add(self.p1, vec3.mul(x, n))
        local ps = vec3.add(s, vec3.mul(x, n))
        local p2 = vec3.add(self.p2, vec3.mul(x, n))

        self:BuildTrack({{p1, d}, {ps, d}, {ps, d}, {p2, d}}, {0, 3}, nil, result)
        self:BuildStreetConnection(
            vec3.add(ps, vec3.mul(terminalOffset + terminalWidth + connectorWidth, n)),
            vec3.mul(5, n),
            result
        )
        local nd = vec2.normalize(d)
        local terminalTransform =
            mat3.affine(
            {1, 0, 0},
            {0, 1, 0},
            {0, 0, 1},
            {nd[2], -nd[1], 0},
            {0.1 * d[1], 0.1 * d[2], 0.1 * d[3]},
            {0, 0, 1}
        )

        local terminals = {}

        for ns = 1, terminalSegments do
            local pplatform = vec3.add(self.p1, vec3.mul( (ns - 0.5) *  f * terminalLength, dn))
            local terminalPosition = vec3.add(pplatform, vec3.mul(terminalOffset + x, n))

            result.models[#result.models + 1] = {
                id = "station/train/passenger/1850/platform_single_open_first.mdl",
                transf = to4x4(terminalTransform, terminalPosition)
            }

            terminals[#terminals + 1] = {#result.models - 1, 0}

        end

        --[[local terminalPosition = vec3.add(ps, vec3.mul(terminalOffset, n))

        
        terminals[#terminals + 1] = {#result.models, 0}

        result.models[#result.models + 1] = {
            id = "station/train/passenger/1850/platform_single_open_first.mdl", --"snowball_funicular/snowball_funicular_terminal.mdl",
            transf = to4x4(terminalTransform, terminalPosition)
        }]]--

        result.terminalGroups[#result.terminalGroups + 1] = {terminals = terminals, vehicleNodeOverride = 1}

        
        local connectorTransform =
            mat3.affine({1, 0, 0}, {0, 1, 0}, {0, 0, 1}, {nd[2], -nd[1], 0}, {nd[1], nd[2], 0}, {0, 0, 1})
        local connectorPosition = vec3.add(ps, vec3.mul(terminalOffset + terminalWidth, n))

        result.models[#result.models + 1] = {
            id = "snowball_funicular/snowball_funicular_terminal_connector.mdl",
            transf = to4x4(connectorTransform, connectorPosition)
        }
    end
end

function Segment:BuildEdges(result)
    if self.station then
        self:BuildStation(result)
    end

    if not result.edgeLists then
        result.edgeLists = {}
    end

    if self.station then
        return
    else
        local snapNodes = {}

        if self.snapStart then
            snapNodes[#snapNodes + 1] = 0
        end
        if self.snapEnd then
            snapNodes[#snapNodes + 1] = 1
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
                    self:BuildTrack({{p1, d1}, {p2, d2}}, snapNodes, {0, 1}, result)
                end
            end
        end
    end
end

function Segment:BuildStreetConnection(p, d, result)
    result.edgeLists[#result.edgeLists + 1] = {
        type = "STREET",
        params = {
            type = "new_small.lua",
            tramTrackType = "NO"
        },
        edges = {
            {p, d},
            {vec3.add(p, d), d}
        },
        snapNodes = {1}
    }
end

function Segment:BuildTrack(edges, snapNodes, freeNodes, result)
    local edge = {
        type = "TRACK",
        params = {
            catenary = self.catenary,
            type = self.type
        },
        edges = edges,
        freeNodes = freeNodes,
        snapNodes = snapNodes
    }

    if self.transition and self.transition.type and self.transition.config then
        edge.edgeType = self.transition.type
        edge.edgeTypeName = self.transition.config
    end

    result.edgeLists[#result.edgeLists + 1] = edge

    if self.rack and (#self.tracksEnd == #self.tracksStart or self:IsFlat()) then
        for i = 0, #edges / 2 - 1 do
            local p1 = edges[i * 2 + 1][1]
            local d1 = edges[i * 2 + 1][2]
            local p2 = edges[i * 2 + 2][1]
            local d2 = edges[i * 2 + 2][2]

            self:BuildRack(p1, p2, d1, d2, result)
        end
    end
end

function Segment:BuildRack(p1, p2, d1, d2, result)
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

function Segment:IsFlat()
    local n = vec3.cross(self.d1, {self.d1[2], -self.d1[1], 0})
    local p = self.p1
    local dot = vec3.dot(n, p)
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
        if s and math.abs(si - s) > 1e-8 then
            return false
        end
        if d and math.abs(di - d) > 1e-8 then
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
