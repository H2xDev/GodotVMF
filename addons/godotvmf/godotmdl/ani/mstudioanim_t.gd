class_name MStudioAnim_t extends RefCounted

static var scheme:
	get: return {
		bone = ByteReader.Type.BYTE,
		flags = ByteReader.Type.BYTE,
		nextoffset = ByteReader.Type.SHORT,
	}

var bone: int
var flags: int
var nextoffset: int

var address: int = 0

func _to_string():
	return "MStudioAnim_t: {bone: %d, flags: %d, nextoffset: %d}" % [bone, flags, nextoffset]
