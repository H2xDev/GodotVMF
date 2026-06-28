class_name MStudioEvent_t extends RefCounted

static var scheme:
	get: return {
		cycle = ByteReader.Type.FLOAT,
		event = ByteReader.Type.INT,
		type = ByteReader.Type.INT,
		options = [ByteReader.Type.STRING, 64],
		szeventindex = ByteReader.Type.INT,
	}

var cycle: float
var event: int
var type: int
var options: String
var szeventindex: int

var address: int = 0

func _to_string():
	return "MStudioEvent_t: {cycle: %f, event: %d, type: %d, options: %s, szeventindex: %d}" % [cycle, event, type, options, szeventindex]
