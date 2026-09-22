class_name MStudioActivityModifier_t extends RefCounted

static var scheme:
	get: return {
		sznameindex = ByteReader.Type.INT,
	}

var sznameindex: int

var address: int = 0

func _to_string():
	return "MStudioActivityModifier_t: {sznameindex: %d}" % [sznameindex]
