class_name MStudioSeqDesc_t extends RefCounted

static var scheme:
	get: return {
		baseptr = ByteReader.Type.INT,
		szlabelindex = ByteReader.Type.INT,
		szactivitynameindex = ByteReader.Type.INT,
		flags = ByteReader.Type.INT,
		activity = ByteReader.Type.INT,
		actweight = ByteReader.Type.INT,
		numevents = ByteReader.Type.INT,
		eventindex = ByteReader.Type.INT,
		bbmin = ByteReader.Type.VECTOR3,
		bbmax = ByteReader.Type.VECTOR3,
		numblends = ByteReader.Type.INT,
		animindexindex = ByteReader.Type.INT,
		movementindex = ByteReader.Type.INT,
		groupsize = [ByteReader.Type.INT, 2],
		paramindex = [ByteReader.Type.INT, 2],
		paramstart = [ByteReader.Type.FLOAT, 2],
		paramend = [ByteReader.Type.FLOAT, 2],
		paramparent = ByteReader.Type.INT,
		fadeintime = ByteReader.Type.FLOAT,
		fadeouttime = ByteReader.Type.FLOAT,
		localentrynode = ByteReader.Type.INT,
		localexitnode = ByteReader.Type.INT,
		nodeflags = ByteReader.Type.INT,
		entryphase = ByteReader.Type.FLOAT,
		exitphase = ByteReader.Type.FLOAT,
		lastframe = ByteReader.Type.FLOAT,
		nextseq = ByteReader.Type.INT,
		pose = ByteReader.Type.INT,
		numikrules = ByteReader.Type.INT,
		numautolayers = ByteReader.Type.INT,
		autolayerindex = ByteReader.Type.INT,
		weightlistindex = ByteReader.Type.INT,
		posekeyindex = ByteReader.Type.INT,
		numiklocks = ByteReader.Type.INT,
		iklockindex = ByteReader.Type.INT,
		keyvalueindex = ByteReader.Type.INT,
		keyvaluesize = ByteReader.Type.INT,
		cycleposeindex = ByteReader.Type.INT,
		activitymodifierindex = ByteReader.Type.INT,
		numactivitymodifiers = ByteReader.Type.INT,
		animtagindex = ByteReader.Type.INT,
		numanimtags = ByteReader.Type.INT,
		rootDriverIndex = ByteReader.Type.INT,
		unused = [ByteReader.Type.INT, 2],
	}

var baseptr: int
var szlabelindex: int
var szactivitynameindex: int
var flags: int
var activity: int
var actweight: int
var numevents: int
var eventindex: int
var bbmin: Vector3
var bbmax: Vector3
var numblends: int
var animindexindex: int
var movementindex: int
var groupsize: Array[int]
var paramindex: Array[int]
var paramstart: Array[float]
var paramend: Array[float]
var paramparent: int
var fadeintime: float
var fadeouttime: float
var localentrynode: int
var localexitnode: int
var nodeflags: int
var entryphase: float
var exitphase: float
var lastframe: float
var nextseq: int
var pose: int
var numikrules: int
var numautolayers: int
var autolayerindex: int
var weightlistindex: int
var posekeyindex: int
var numiklocks: int
var iklockindex: int
var keyvalueindex: int
var keyvaluesize: int
var cycleposeindex: int
var activitymodifierindex: int
var numactivitymodifiers: int
var animtagindex: int
var numanimtags: int
var rootDriverIndex: int
var unused: Array[int]

var address: int = 0

func _to_string():
	return "MStudioSeqDesc_t: {baseptr: %d, flags: %d, activity: %d, numblends: %d}" % [baseptr, flags, activity, numblends]
