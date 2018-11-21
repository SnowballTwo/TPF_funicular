local tu = require "texutil"

function data()
return {
	detailTex = tu.makeTextureMipmapRepeat("tracks/ballast.tga", false),
	detailNrmlTex = tu.makeTextureMipmapRepeat("tracks/ballast_nrml.tga", false),
	detailSize = { 2.0, 2.0 },
	colorTex = tu.makeTextureMipmapRepeat("tracks/ballast_color.tga", false),
	colorSize = 128.0,
	priority = 10
}
end
