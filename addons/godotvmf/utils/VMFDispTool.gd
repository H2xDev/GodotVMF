class_name VMFDispTool extends RefCounted;

var normals: Array[Vector3] = [];
var distances: Array[float] = [];
var offsets: Array[Vector3] = [];
var offsetNormals: Array[Vector3] = [];
var alphas: Array[float] = [];

var vertsCount: float = 0;
var edgesCount: float = 0;
var dispInfo = null;
var startPoint := Vector3(0, 0, 0);
var side: Dictionary;
var brush: Dictionary;

static func hasDisplacement(brush: Dictionary) -> bool:
	for side in brush.side:
		if "dispinfo" in side:
			return true;

	return false;

func _init(side: Dictionary, brush: Dictionary) -> void:
	self.dispInfo = side.dispinfo;
	self.side = side;
	self.brush = brush;

	var startNumbers: Array[float]
	startNumbers.assign(dispInfo.startposition.trim_suffix(']').trim_prefix('[').split_floats(" "));

	startPoint = Vector3(startNumbers[0], startNumbers[1], startNumbers[2]);

	vertsCount = pow(2, dispInfo.power) + 1;
	edgesCount = vertsCount - 1;

	normals = _parseVectors('normals');
	distances = _parseFloats('distances');
	offsets = _parseVectors('offsets');
	offsetNormals = _parseVectors('offset_normals');
	alphas = _parseFloats('alphas');

func getNormal(x: float, y: float) -> Vector3:
	var index = y + x * vertsCount;
	if normals.size() == 0:
		return Vector3.ZERO;

	return normals[index];

func getOffset(x: float, y: float) -> Vector3:
	var index = y + x * vertsCount;
	if offsets.size() == 0:
		return Vector3.ZERO;
		
	return offsets[index];

func getDistance(x: float, y: float) -> Vector3:
	var index = y + x * vertsCount;
	if distances.size() == 0:
		return Vector3.ZERO;

	return getNormal(x, y) * distances[index];

func getColor(x: float, y: float) -> Color:
	var index = y + x * vertsCount;

	if alphas.size() == 0:
		return Color8(255, 0, 0);

	return Color8(int(alphas[index]), 0, 0);

func getVertices() -> Array[Vector3]:
	var vertices := VMFTool.calculateVertices(side, brush);
	
	if vertices.size() < 3:
		return [];

	var res: Array[Vector3] = [];
	var startIndex := 1;

	for v in vertices:
		if v.distance_to(startPoint) < 0.2:
			break;

		startIndex += 1;

	var tl := vertices[(0 + startIndex) % 4];
	var tr := vertices[(1 + startIndex) % 4];
	var br := vertices[(2 + startIndex) % 4];
	var bl := vertices[(3 + startIndex) % 4];

	for i: int in range(0, pow(vertsCount, 2)):
		var x := i / int(vertsCount);
		var y := i % int(vertsCount);

		var rblend := 1 - x / edgesCount;
		var cblend := y / edgesCount;

		var vl := tl.lerp(bl, rblend);
		var vr := tr.lerp(br, rblend);
		var vert := vl.lerp(vr, cblend);

		vert += getDistance(x, y) + getOffset(x, y) + side.plane.value.normal * dispInfo.elevation;

		res.append(vert);
	
	return res;

func _parseVectors(key) -> Array[Vector3]:
	var vects: Array[Vector3] = [];
	
	if not key in dispInfo:
		return vects;

	for row: String in dispInfo[key].values():
		var vals: Array[float];
		vals.assign(row.trim_suffix(' ').trim_prefix(' ').split_floats(" "));
		
		var vecset: Array[Vector3] = [];

		for i: int in range(0, vals.size() / 3):
			vecset.append(Vector3(vals[i * 3], vals[i * 3 + 1], vals[i * 3 + 2]));

		vects.append_array(vecset);

	return vects;

func _parseFloats(key: String) -> Array[float]:
	var floats: Array[float] = [];

	if not key in dispInfo:
		return floats;
		
	for row: String in dispInfo[key].values():
		var vals: Array[float];
		vals.assign(row.trim_suffix(' ').trim_prefix(' ').split_floats(" "));
		
		floats.append_array(vals);

	return floats;

