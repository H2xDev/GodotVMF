class_name MStudioCompressedIKError_t extends RefCounted

static var scheme:
	get: return {
		scale = [ByteReader.Type.FLOAT, 6],
		offset = [ByteReader.Type.SHORT, 6],
	}

var scale: Array[float]
var offset: Array[int]

var address: int = 0

func _to_string():
	return "MStudioCompressedIKError_t: {scale: %s, offset: %s}" % [scale, offset]
