class_name VMFSolid extends RefCounted

var id: int = -1;
var sides: Array[VMFSide] = [];
var has_displacement: bool = false;
var min: Vector3 = Vector3(INF, INF, INF);
var max: Vector3 = Vector3(-INF, -INF, -INF);
var vertices: Array[Vector3] = [];

func _init(raw: Dictionary) -> void:
	if not raw.is_empty():
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

	var needs_computation := false;
	for s in sides:
		if s.vertices.size() == 0:
			needs_computation = true;
			break;

	if needs_computation:
		_compute_vertices_from_planes();

	for side in sides:
		side.calculate_vertices();

	vertices = [];

	for side in sides:
		for v in side.vertices:
			if v.x < min.x: min.x = v.x;
			if v.y < min.y: min.y = v.y;
			if v.z < min.z: min.z = v.z;
			if v.x > max.x: max.x = v.x;
			if v.y > max.y: max.y = v.y;
			if v.z > max.z: max.z = v.z;

## Computes vertices for all sides that don't have pre-computed vertices (i.e. no vertices_plus).
## Iterates all unique plane triples once (C(n,3)), tests each intersection against all planes,
## then distributes valid vertices to the three involved sides and sorts them.
func _compute_vertices_from_planes() -> void:
	var n := sides.size();
	var side_verts: Array[Dictionary] = [];
	side_verts.resize(n);
	for i in range(n):
		side_verts[i] = {};

	for i in range(n):
		for j in range(i + 1, n):
			for k in range(j + 1, n):
				var v: Variant = sides[i].plane.intersect_3(sides[j].plane, sides[k].plane);
				if v == null: continue;
				var vertex := v as Vector3;

				var valid := true;
				for s in sides:
					if s.plane.distance_to(vertex) > 0.01:
						valid = false;
						break;
				if not valid: continue;

				var vhash := hash(Vector3i(vertex));
				side_verts[i][vhash] = vertex;
				side_verts[j][vhash] = vertex;
				side_verts[k][vhash] = vertex;

	for i in range(n):
		if sides[i].vertices.size() > 0: continue;

		var raw: Array = side_verts[i].values();
		var side_normal := sides[i].plane.normal;
		var pp := sides[i].plane_points;
		var center := (pp[0] + pp[1] + pp[2]) / 3.0;
		var sorter := VMFVectorSorter.new(side_normal, center);
		raw.sort_custom(sorter.sort);
		sides[i].vertices = PackedVector3Array(raw);
