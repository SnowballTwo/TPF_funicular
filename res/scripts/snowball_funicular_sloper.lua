local vec2 = require "snowball_funicular_vec2"
local vec3 = require "snowball_funicular_vec3"
local vec4 = require "vec4"
local mat3 = require "snowball_funicular_mat3"
local planner = require "snowball_funicular_planner"

local transf = require "transf"
local sloper = {}

sloper.pickMode = 0
sloper.dropMode = 1
sloper.hideMode = 2
sloper.signs = {1, -1}
sloper.subscales = {0.0, 0.2, 0.4, 0.5, 0.6, 0.8}
sloper.slopeRotate = 0
sloper.slopeShear = 1

sloper.model = nil
sloper.pickers = {}
sloper.finishers = {}
sloper.finisherId = "asset/snowball_funicular_finisher.mdl"
sloper.pickerId = "asset/snowball_funicular_picker.mdl"
sloper.whitePickerId = "snowball_funicular/snowball_funicular_picker_white.mdl"
sloper.greenPickerId = "snowball_funicular/snowball_funicular_picker_green.mdl"

function sloper.pick(result, slope, slopeMode, roty, rotz, offsetx, offsety, offsetz, scalex, scaley, scalez)
    local built =
        planner.updateEntityLists(
        {
            [sloper.finisherId] = sloper.finishers,
            [sloper.pickerId] = sloper.pickers
        }
    )

    for i = 1, #sloper.finishers do
        if game.interface.getEntity(sloper.finishers[i].id) then
            game.interface.bulldoze(sloper.finishers[i].id)
        end
    end

    if built then
        sloper.model = sloper.searchModel()

        for i = 1, #sloper.pickers do
            if game.interface.getEntity(sloper.pickers[i].id) then
                game.interface.bulldoze(sloper.pickers[i].id)
            end
        end
    end

    if sloper.model then
        local mat

        if slopeMode == sloper.slopeShear then
            mat =
                mat3.mul( mat3.rotZ(rotz),
                mat3.mul( mat3.rotY(roty),
                mat3.mul(
                    mat3.affine(
                        {1, 0, 0},
                        {0, 1, 0},
                        {0, 0, 1},
                        vec3.normalize({1, 0, -(slope or 0)}),
                        {0, 1, 0},
                        {0, 0, 1}
                    ),
                    mat3.scale(scalex, scaley, scalez)
                )))
        else
            mat =
                mat3.mul( mat3.rotZ(rotz),
                mat3.mul( mat3.rotY(roty),
                mat3.mul( mat3.rotY(math.atan(slope or 0)), mat3.scale(scalex, scaley, scalez)))
            )
        end

        local transform =
            transf.new(
            vec4.new(mat[1][1], mat[2][1], mat[3][1], .0),
            vec4.new(mat[1][2], mat[2][2], mat[3][2], .0),
            vec4.new(mat[1][3], mat[2][3], mat[3][3], .0),
            vec4.new(offsetx, offsety, offsetz, 1.0)
        )

        result.models[#result.models + 1] = {
            id = sloper.model,
            transf = transform
        }
    else
        result.models[#result.models + 1] = {
            id = sloper.pickerId,
            transf = {1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1}
        }

        result.models[#result.models + 1] = {
            id = sloper.whitePickerId,
            transf = {10, 0, 0, 0, 0, 10, 0, 0, 0, 0, 10, 0, 0, 0, 3, 1}
        }
    end
end

function sloper.searchModel()
    local position = game.gui.getTerrainPos()
    local assets = game.interface.getEntities({pos = position, radius = 10}, {type = "ASSET_GROUP", includeData = true})

    local closest = nil
    local minDistance = nil

    for id, data in pairs(assets) do
        local distance = vec2.length(vec2.sub(position, data.position))
        if
            (not minDistance or distance < minDistance) and data.count == 1 and not data.models[sloper.finisherId] and
                not data.models[sloper.pickerId]
         then
            closest = data
            minDistance = distance
        end
    end

    if closest then
        for fileName, count in pairs(closest.models) do
            sloper.model = fileName
            return fileName
        end
    end

    return nil
end

function sloper.drop(result)
    sloper.model = nil
    result.models[#result.models + 1] = {
        id = "asset/snowball_funicular_finisher.mdl",
        transf = {1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1}
    }
end

function sloper.hide(result)
    result.models[#result.models + 1] = {
        id = "asset/snowball_funicular_picker.mdl",
        transf = {1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1}
    }
end

return sloper
