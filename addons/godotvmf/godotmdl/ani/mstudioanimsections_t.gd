class_name MStudioAnimSections_t extends RefCounted

static var scheme:
	get: return {
		animblock = ByteReader.Type.INT,
		animindex = ByteReader.Type.INT,
	}

var animblock: int
var animindex: int

var address: int = 0

func _to_string():
	return "MStudioAnimSections_t: {animblock: %d, animindex: %d}" % [animblock, animindex]
