class_name AniBlock extends MDLStruct

static func _scheme() -> Dictionary:
	return {
		bone = Type.BYTE,
		flags = Type.BYTE,
		next_offset = Type.SHORT,
	}

var bone: int
var flags: int
var next_offset: int
