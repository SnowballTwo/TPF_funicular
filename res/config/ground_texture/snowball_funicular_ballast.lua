local tu = require "texutil"

function data()
return {
	detailTex = tu.makeTextureMipmapClampVertical("ground_texture/ballast_ground_boundary.dds", true, true),
	detailNrmlTex = tu.makeTextureMipmapClampVertical("default_normal_map.tga", true, true, true),
	detailSize = { 8.0, 2.0 },
	colorTex = tu.makeTextureMipmapRepeat("tracks/ballast_color.tga", false),
	colorSize = 256.0,
	priority = 10
}
end
