class_name VMFDisplacementInfo extends RefCounted

var normals: Array[Vector3] = [];
var distances: Array[float] = [];
var offsets: Array[Vector3] = [];
var offset_normals: Array[Vector3] = [];
var alphas: Array[float] = [];

var verts_count: float = 0.0;
var edges_count: float = 0.0;
var disp_info = null;
var start_point := Vector3(0, 0, 0);
var side: VMFSide;
var brush: VMFSolid;
var vertices: PackedVector3Array;
var elevation: float = 0.0;

func _to_string() -> String:
	return "VMFDisplacementInfo(verts_count=%d, edges_count=%d, start_point=%s, side_id=%d, brush_id=%d)" % [verts_count, edges_count, start_point, side.id, brush.id];

func _init(raw: Dictionary, side: VMFSide, brush: VMFSolid) -> void:
	self.disp_info = raw;
	self.side = side;
	self.brush = brush;

	var start_numbers: Array[float];
	start_numbers.assign(raw.startposition.trim_suffix(']').trim_prefix('[').split_floats(" "));

	start_point = Vector3(start_numbers[0], start_numbers[1], start_numbers[2]);

	verts_count = pow(2, raw.power) + 1;
	edges_count = verts_count - 1;

	normals = _parse_vectors('normals');
	distances = _parse_floats('distances');
	offsets = _parse_vectors('offsets');
	offset_normals = _parse_vectors('offset_normals');
	alphas = _parse_floats('alphas');
	elevation = float(raw.get('elevation', 0.0));
	disp_info = null;

## Called from the VMFSide during the calculation of its vertices.
func calculate_vertices() -> void:
	vertices = PackedVector3Array(get_vertices());

func get_normal(x: float, y: float) -> Vector3:
	var index = y + x * verts_count;
	if normals.size() == 0:
		return Vector3.ZERO;

	return normals[index];

func get_offset(x: float, y: float) -> Vector3:
	var index = y + x * verts_count;
	if offsets.size() == 0:
		return Vector3.ZERO;
		
	return offsets[index];

func get_distance(x: float, y: float) -> Vector3:
	var index = y + x * verts_count;
	if distances.size() == 0:
		return Vector3.ZERO;

	return get_normal(x, y) * distances[index];

func get_color(x: float, y: float) -> Color:
	var index = y + x * verts_count;

	if alphas.size() == 0:
		return Color8(255, 0, 0);

	return Color8(int(alphas[index]), 0, 0);

func get_vertices() -> Array[Vector3]:
	if side.vertices.size() < 3:
		return [];

	var res: Array[Vector3] = [];
	var start_index := 1;

	for v in side.vertices:
		if v.distance_to(start_point) < 0.2:
			break;

		start_index += 1;

	var tl := side.vertices[(0 + start_index) % 4];
	var tr := side.vertices[(1 + start_index) % 4];
	var br := side.vertices[(2 + start_index) % 4];
	var bl := side.vertices[(3 + start_index) % 4];

	for i: int in range(0, pow(verts_count, 2)):
		var x := i / int(verts_count);
		var y := i % int(verts_count);

		var rblend := 1 - x / edges_count;
		var cblend := y / edges_count;

		var vl := tl.lerp(bl, rblend);
		var vr := tr.lerp(br, rblend);
		var vert := vl.lerp(vr, cblend);

		vert += get_distance(x, y) + get_offset(x, y) + side.plane.normal * elevation;

		res.append(vert);
	
	return res;

func _parse_vectors(key) -> Array[Vector3]:
	var vects: Array[Vector3] = [];
	
	if not key in disp_info:
		return vects;

	for row: String in disp_info[key].values():
		var vals: Array[float];
		vals.assign(row.trim_suffix(' ').trim_prefix(' ').split_floats(" "));
		
		var vecset: Array[Vector3] = [];

		for i: int in range(0, vals.size() / 3):
			vecset.append(Vector3(vals[i * 3], vals[i * 3 + 1], vals[i * 3 + 2]));

		vects.append_array(vecset);

	return vects;

func _parse_floats(key: String) -> Array[float]:
	var floats: Array[float] = [];

	if not key in disp_info:
		return floats;
		
	for row: String in disp_info[key].values():
		var vals: Array[float];
		vals.assign(row.trim_suffix(' ').trim_prefix(' ').split_floats(" "));
		
		floats.append_array(vals);

	return floats;
