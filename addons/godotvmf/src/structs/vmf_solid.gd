class_name VMFSolid extends RefCounted

var id: int = -1;
var sides: Array[VMFSide] = [];
var has_displacement: bool = false;
var intersections: Dictionary = {};
var min: Vector3 = Vector3(INF, INF, INF);
var max: Vector3 = Vector3(-INF, -INF, -INF);

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
	
	for side in sides:
		side.calculate_vertices();
	
	intersections = {};
	
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
