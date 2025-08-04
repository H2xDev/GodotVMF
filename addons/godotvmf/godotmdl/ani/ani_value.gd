class_name AniValue extends MDLStruct

static func _scheme() -> Dictionary:
	return {
		valid = Type.BYTE,
		total = Type.BYTE,
		value = Type.SHORT,
	}

var valid: int;
var total: int;
var value: int;
