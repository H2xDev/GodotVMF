class_name VMFSolid extends RefCounted

var id: int = -1;
var sides: Array[VMFSide] = [];
var has_displacement: bool = false;
var intersections: Dictionary = {};

func _init(raw: Dictionary) -> void:
	id = int(raw.get("id", -1));
	define_sides(raw)

func _to_string() -> String:
	var line1 = "VMFSolid(id=%d, sides=%d, has_displacement=%s)\n\t" % [id, sides.size(), has_displacement];

	var line2 = "  Sides:\n\t"

	for side in sides:
		line2 += "    %s\n\t" % side;

	return line1 + line2;

func define_sides(raw: Dictionary) -> void:
	if not "side" in raw: return;

	for side in raw.side:
		var side_instance := VMFSide.new(side, self);
		sides.append(side_instance);

		if side_instance.is_displacement:
			has_displacement = true;

func calculate_vertices(side: VMFSide) -> PackedVector3Array:
	var vertices: Array[Vector3] = [];
	var cache = {};

	if "vertices_plus" in side:
		vertices.assign(side.vertices_plus)
		return vertices;

	var is_vertice_exists = func(vector: Vector3):
		var hash_value: int = hash(Vector3i(vector));
		if hash_value in cache: return true;

		cache[hash_value] = 1;
		return false;

	for side2 in sides:
		if side2 == side: continue;

		for side3 in sides:
			if side2 == side3 or side3 == side: continue;
			var vertex := get_planes_intersection_point(side, side2, side3);

			if vertex == null or is_vertice_exists.call(vertex): continue;
			vertices.append(vertex as Vector3);

	vertices = vertices.filter(func(vertex):
		return not sides.any(func(s: VMFSide): return s.plane.distance_to(vertex) > 0.2);
	);

	var side_normal: Vector3 = side.plane.normal;
	var center: Vector3 = (side.plane_points[0] + side.plane_points[1] + side.plane_points[2]) / 3.0;
	var vector_sorter: VMFVectorSorter = VMFVectorSorter.new(side_normal, center);

	vertices.sort_custom(vector_sorter.sort);

	return vertices;
	
func get_planes_intersection_point(side: VMFSide, side2: VMFSide, side3: VMFSide) -> Variant:
	var d: Array[int] = [side.id, side2.id, side3.id];
	d.sort();

	var ihash := hash(d);
	var is_intersection_defined: bool = ihash in intersections;

	if is_intersection_defined:
		return intersections[ihash];
	else:
		var vertex: Variant = side.plane.intersect_3(side2.plane, side3.plane);
		intersections[ihash] = vertex;
		return vertex;
