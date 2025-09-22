@tool
class_name OctNode extends GeometryInstance3D

const MAX_DEPTH = 11;

enum SpaceType { EMPTY, SOLID, MIXED }

@export var type: SpaceType = SpaceType.EMPTY;

var depth: int = 0;
var index: int = 0;
var ff: FloodFill;

var is_solid: bool = false;
var is_outside: bool = false;
var is_visited: bool = false;

static func create(_ff: FloodFill, _size: Vector3, _depth: int = 0, _index: int = 0) -> OctNode: 
	var instance := OctNode.new();
	instance.ff = _ff;
	instance.custom_aabb = AABB(-_size / 2, _size);
	instance.depth = _depth;
	instance.index = _index;
	instance.name = "OctNode_" + str(_depth) + "_" + str(_index);
	instance.split_node.call_deferred();
	return instance;

func split_node() -> void:
	if is_inside_solid():
		type = SpaceType.SOLID;
		return;

	if not has_solid_inside():
		type = SpaceType.EMPTY;
		return;

	type = SpaceType.MIXED;

	if depth >= MAX_DEPTH: return;

	for c_index in range(8):
		var nsize: Vector3 = custom_aabb.size / 2;
		var child := OctNode.create(ff, nsize, depth + 1, index + c_index);
		var offset := Vector3(
			nsize.x * (1 if (c_index & 1) == 1 else -1),
			nsize.y * (1 if (c_index & 2) == 2 else -1),
			nsize.z * (1 if (c_index & 4) == 4 else -1)
		) / 2;

		add_child(child);
		child.set_position(offset);
		child.set_owner(ff.get_tree().edited_scene_root);

func convert_vector(v: Vector3) -> Vector3:
	return Vector3(v.x, v.y, v.z);

func is_inside_solid() -> bool:
	var aabb := global_transform * custom_aabb;
	for solid in ff.vmf_structure.world.solid:
		if ff.is_aabb_inside_solid(solid, aabb):
			return true;

	return false;


func has_solid_inside() -> bool:
	var aabb := global_transform * custom_aabb;

	for solid in ff.vmf_structure.world.solid:
		if ff.is_aabb_partially_inside_solid(solid, aabb):
			return true;

		for side in solid.side:
			var points = side.plane.points
			var point1 = convert_vector(points[0]);
			var point2 = convert_vector(points[1]);
			var point3 = convert_vector(points[2]);

			if aabb.intersects_segment(point1, point2):
				return true;
			if aabb.intersects_segment(point2, point3):
				return true;
			if aabb.intersects_segment(point3, point1):
				return true;


	return false;

func has_point_inside(point: Vector3) -> bool:
	var aabb := custom_aabb;
	return aabb.has_point(point);

func get_node_at_point(point: Vector3) -> OctNode:
	if type != SpaceType.MIXED:
		return self;

	for child in get_children() as Array[OctNode]:
		if child.has_point_inside(point):
			return child.get_node_at_point(point);

	return self;
