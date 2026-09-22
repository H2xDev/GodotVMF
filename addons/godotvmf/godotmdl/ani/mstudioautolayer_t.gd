class_name MStudioAutoLayer_t extends RefCounted

static var scheme:
	get: return {
		iSequence = ByteReader.Type.SHORT,
		iPose = ByteReader.Type.SHORT,
		flags = ByteReader.Type.INT,
		start = ByteReader.Type.FLOAT,
		peak = ByteReader.Type.FLOAT,
		tail = ByteReader.Type.FLOAT,
		end = ByteReader.Type.FLOAT,
	}

var iSequence: int
var iPose: int
var flags: int
var start: float
var peak: float
var tail: float
var end: float

var address: int = 0

func _to_string():
	return "MStudioAutoLayer_t: {iSequence: %d, iPose: %d, flags: %d, start: %f, peak: %f, tail: %f, end: %f}" % [iSequence, iPose, flags, start, peak, tail, end]
