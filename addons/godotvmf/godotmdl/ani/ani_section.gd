class_name AniSection extends MDLStruct

static func _scheme() -> Dictionary:
	return {
		animblock = Type.INT,
		animindex = Type.INT,
	}

var animblock: int;
var animindex: int;
