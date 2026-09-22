class_name MStudioAnimDesc_t extends RefCounted

static var scheme:
	get: return {
	baseptr = ByteReader.Type.INT,
	pszName = ByteReader.Type.INLINE_STRING,
	fps = ByteReader.Type.FLOAT,
	flags = ByteReader.Type.INT,
	numframes = ByteReader.Type.INT,
	nummovements = ByteReader.Type.INT,
	movementindex = ByteReader.Type.INT,
	unused1 = [ByteReader.Type.INT, 6],
	animblock = ByteReader.Type.INT,
	animindex = ByteReader.Type.INT,
	numikrules = ByteReader.Type.INT,
	ikruleindex = ByteReader.Type.INT,
	animblockikruleindex = ByteReader.Type.INT,
	numlocalhierarchy = ByteReader.Type.INT,
	localhierarchyindex = ByteReader.Type.INT,
	sectionindex = ByteReader.Type.INT,
	sectionframes = ByteReader.Type.INT,
	zeroframespan = ByteReader.Type.SHORT,
	zeroframecount = ByteReader.Type.SHORT,
	zeroframeindex = ByteReader.Type.INT,
	zeroframestalltime = ByteReader.Type.FLOAT,
}

var baseptr: int
var pszName: String
var fps: float
var flags: int
var numframes: int
var nummovements: int
var movementindex: int
var unused1: Array[int]
var animblock: int
var animindex: int
var numikrules: int
var ikruleindex: int
var animblockikruleindex: int
var numlocalhierarchy: int
var localhierarchyindex: int
var sectionindex: int
var sectionframes: int
var zeroframespan: int
var zeroframecount: int
var zeroframeindex: int
var zeroframestalltime: float

var address: int = 0

func _to_string():
	return "MStudioAnimDesc_t: {baseptr: %d, pszName: %s, fps: %f, flags: %d, numframes: %d, nummovements: %d, movementindex: %d, unused1: %s, animblock: %d, animindex: %d, numikrules: %d, ikruleindex: %d, animblockikruleindex: %d, numlocalhierarchy: %d, localhierarchyindex: %d, sectionindex: %d, sectionframes: %d, zeroframespan: %d, zeroframecount: %d, zeroframeindex: %d, zeroframestalltime: %f}" % [baseptr, pszName, fps, flags, numframes, nummovements, movementindex, unused1, animblock, animindex, numikrules, ikruleindex, animblockikruleindex, numlocalhierarchy, localhierarchyindex, sectionindex, sectionframes, zeroframespan, zeroframecount, zeroframeindex, zeroframestalltime]
