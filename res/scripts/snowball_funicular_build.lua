local vec2 = require "snowball_funicular_vec2"
local vec3 = require "snowball_funicular_vec3"
local mat3 = require "snowball_funicular_mat3"

local vec4 = require "vec4"
local transf = require "transf"

local build = {}

function build.affine(p1, p2, model, modelSize, result)
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

function build.affineWide(p1, p2, n1, n2, leftModel, rightModel, modelSize, result)
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

return build