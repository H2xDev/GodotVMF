class_name VMFSide extends RefCounted

var id: int = -1;
var material: String = "";
var rotation: float = 0.0;
var lightmap_scale: float = 16.0;
var smoothing_groups: int = 0;

var plane: Plane;
var vaxis: VMFTexCoord;
var uaxis: VMFTexCoord;
var plane_points: PackedVector3Array;
var vertices: PackedVector3Array;
var is_displacement: bool = false;
var dispinfo: VMFDisplacementInfo;
var solid: VMFSolid;
var uv: Vector2 = Vector2.ZERO;

func _to_string() -> String:
	return "VMFSide(id=%d, material=%s, is_displacement=%s, vertices=%d)" % [id, material, is_displacement, vertices.size()];

func _init(raw: Dictionary, _solid: VMFSolid) -> void:
	id = raw.get("id", -1);
	material = raw.get("material", "");
	is_displacement = "dispinfo" in raw;
	smoothing_groups = raw.get("smoothing_groups", 0);
	solid = _solid;
	plane = raw.plane.value;

	vaxis = VMFTexCoord.new(raw.vaxis);
	uaxis = VMFTexCoord.new(raw.uaxis);
	plane_points = PackedVector3Array(raw.plane.points);

	if "vertices_plus" in raw:
		vertices = PackedVector3Array(raw.vertices_plus.v);

	if is_displacement:
		dispinfo = VMFDisplacementInfo.new(raw.dispinfo, self, solid);
	
## Internal method. Calculates the vertices of this side if they are not already calculated.
## Called automatically from VMFSolid
func calculate_vertices() -> void:
	# Already calculated
	if vertices.size() > 0: 
		if is_displacement:
			dispinfo.calculate_vertices();
		return; 

	var raw_vertices: Array[Vector3] = [];
	var cache = {};

	var is_vertice_exists = func(vector: Vector3):
		var hash_value: int = hash(Vector3i(vector));
		if hash_value in cache: return true;

		cache[hash_value] = 1;
		return false;

	for side2 in solid.sides:
		if side2 == self: continue;

		for side3 in solid.sides:
			if side2 == side3 or side3 == self: continue;
			var vertex = solid.get_planes_intersection_point(self, side2, side3);

			if vertex == null or is_vertice_exists.call(vertex): continue;
			raw_vertices.append(vertex as Vector3);

	raw_vertices = raw_vertices.filter(func(vertex):
		return not solid.sides.any(func(s: VMFSide): return s.plane.distance_to(vertex) > 0.001);
	);

	var side_normal: Vector3 = plane.normal;
	var center := (plane_points[0] + plane_points[1] + plane_points[2]) / 3.0;
	var vector_sorter: VMFVectorSorter = VMFVectorSorter.new(side_normal, center);

	raw_vertices.sort_custom(vector_sorter.sort);

	vertices = PackedVector3Array(raw_vertices);

	if is_displacement:
		dispinfo.calculate_vertices();

## Retrns the UV coordinates for the given vertex on this side
func get_uv(vertex: Vector3) -> Vector2:
	var uscale: float = uaxis.scale;
	var ushift: float = uaxis.shift * uscale;

	var vscale: float = vaxis.scale;
	var vshift: float = vaxis.shift * vscale;

	var tscale = Vector2.ONE;
	var tsize := VMTLoader.get_texture_size(material);

	var aspect := tsize.x / tsize.y;

	var uv := Vector3(uaxis.x, uaxis.y, uaxis.z);
	var vv := Vector3(vaxis.x, vaxis.y, vaxis.z);
	var v2 := Vector3(vertex.x, vertex.y, vertex.z);
	var normal = plane.normal;

	var u := (v2.dot(uv) + ushift) / tsize.x / uscale;
	var v := (v2.dot(vv) + vshift) / tsize.y / vscale;

	return Vector2(u, v);

## Returns true if the given point is inside this side (assuming the point is coplanar)
func is_point_inside(point: Vector3) -> bool:
	if vertices.size() < 3: return false

	var prev_sign := 0;
	var vertices_count := vertices.size();

	for i in range(vertices_count):
		var a := vertices[i];
		var b := vertices[(i + 1) % vertices_count];
		var edge := (b - a).normalized();
		var to_point := (point - a).normalized();
		var sign := signf(edge.cross(to_point).dot(plane.normal));
		if sign == 0: continue;

		if prev_sign == 0:
			prev_sign = sign;
			continue

		if sign != prev_sign:
			return false;

	return true

## Returns true if this side is completely inside the other side
func is_inside_of_face(other: VMFSide) -> bool:
	if vertices.size() < 3 or other.vertices.size() < 3: return false;
	if plane.get_center().distance_to(other.plane.get_center()) > 0.01: return false;

	for vertex in vertices:
		if not other.is_point_inside(vertex):
			return false;

	return true;

## Returns true if this side is equal to the other side (same vertices, regardless of order)
func is_equal_to(other: VMFSide) -> bool:
	if vertices.size() != other.vertices.size(): return false;

	var merged_vertices = 0;

	for va in vertices:
		for vb in other.vertices:
			if va.distance_to(vb) < 0.1:
				merged_vertices += 1;
				break;
	
	if merged_vertices != vertices.size(): return false;

	return true;

