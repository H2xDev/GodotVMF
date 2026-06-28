class_name MStudioLocalHierarchy_t extends RefCounted

static var scheme:
	get: return {
		iBone = ByteReader.Type.INT,
		iNewParent = ByteReader.Type.INT,
		start = ByteReader.Type.FLOAT,
		peak = ByteReader.Type.FLOAT,
		tail = ByteReader.Type.FLOAT,
		end = ByteReader.Type.FLOAT,
		iStart = ByteReader.Type.INT,
		localanimindex = ByteReader.Type.INT,
		unused = [ByteReader.Type.INT, 4],
	}

var iBone: int
var iNewParent: int
var start: float
var peak: float
var tail: float
var end: float
var iStart: int
var localanimindex: int
var unused: Array[int]

var address: int = 0

func _to_string():
	return "MStudioLocalHierarchy_t: {iBone: %d, iNewParent: %d, start: %f, peak: %f, tail: %f, end: %f, iStart: %d, localanimindex: %d}" % [iBone, iNewParent, start, peak, tail, end, iStart, localanimindex]
