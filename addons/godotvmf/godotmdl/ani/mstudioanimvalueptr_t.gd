class_name MStudioAnimValuePtr_t extends RefCounted

static var scheme:
	get: return {
		offset = [ByteReader.Type.SHORT, 3],
	}

var offset: Array[int]

var address: int = 0

func _to_string():
	return "MStudioAnimValuePtr_t: {offset: %s}" % [offset]
