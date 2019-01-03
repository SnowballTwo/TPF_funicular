function data()
local empty = "snowball_funicular/snowball_funicular_empty_bridge.mdl"
return {
	name = _("invisible unavailable bridge"),
	yearFrom = 224,
	yearTo = 225,
	carriers = { "RAIL" },
	speedLimit = 120.0 / 3.6,
	pillarBase = { empty },
	pillarRepeat = { empty },
	pillarTop = { empty },
	railingBegin = { empty, empty },
	railingRepeat = { empty, empty },
	railingEnd = { empty, empty },
	cost = 400,
}
end