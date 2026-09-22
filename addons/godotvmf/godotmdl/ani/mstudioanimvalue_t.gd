class_name MStudioAnimValue_t extends RefCounted

static var scheme:
	get: return {
		valid = ByteReader.Type.BYTE,
		total = ByteReader.Type.BYTE,
	}

var valid: int
var total: int

var address: int = 0

var value: int:
	get:
		var val = (total << 8) | valid
		if val > 32767:
			val -= 65536
		return val

func _to_string():
	return "MStudioAnimValue_t: {valid: %d, total: %d, value: %d}" % [valid, total, value]
