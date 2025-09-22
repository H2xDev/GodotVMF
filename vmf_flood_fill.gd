@tool
class_name FloodFill extends Node3D

var vmf_structure: Dictionary = {};
var aabb: AABB;
var bmin: Vector3 = Vector3.INF;
var bmax: Vector3 = -Vector3.INF;
var octree_root: OctNode;

@export_file var vmf_path: String = "res://maps/test.vmf";

@export_tool_button("Run Flood Fill")
var run_flood_fill := _run_flood_fill;

@export var material: StandardMaterial3D;


func _run_flood_fill() -> void:
	vmf_structure = VDFParser.parse(vmf_path);
	define_bounds();
	create_octree();

func define_bounds() -> void:
	bmin = -16384.0 * Vector3.ONE;
	bmax = 16384.0 * Vector3.ONE;

func is_aabb_inside_solid(solid: Dictionary, aabb: AABB) -> bool:
	var aabb_points := [
		aabb.position,
		aabb.position + Vector3(aabb.size.x, 0, 0),
		aabb.position + Vector3(0, aabb.size.y, 0),
		aabb.position + Vector3(0, 0, aabb.size.z),
		aabb.position + Vector3(aabb.size.x, aabb.size.y, 0),
		aabb.position + Vector3(aabb.size.x, 0, aabb.size.z),
		aabb.position + Vector3(0, aabb.size.y, aabb.size.z),
		aabb.position + aabb.size
	] as Array[Vector3];

	for point in aabb_points:
		if not is_inside_solid(solid, point):
			return false;

	return true;

func is_aabb_partially_inside_solid(solid: Dictionary, aabb: AABB) -> bool:
	var aabb_points := [
		aabb.position,
		aabb.position + Vector3(aabb.size.x, 0, 0),
		aabb.position + Vector3(0, aabb.size.y, 0),
		aabb.position + Vector3(0, 0, aabb.size.z),
		aabb.position + Vector3(aabb.size.x, aabb.size.y, 0),
		aabb.position + Vector3(aabb.size.x, 0, aabb.size.z),
		aabb.position + Vector3(0, aabb.size.y, aabb.size.z),
		aabb.position + aabb.size
	] as Array[Vector3];

	for point in aabb_points:
		if is_inside_solid(solid, point):
			return true;

	return false;

func is_inside_solid(solid: Dictionary, point: Vector3) -> bool:
	for side in solid.side:
		var plane: Plane = side.plane.value;
		if plane.distance_to(point) > 0.0:
			return false;

	return true;

func create_octree() -> void:
	for child in get_children():
		child.queue_free();

	octree_root = OctNode.create(self, bmax - bmin);
	octree_root.position = (bmax - bmin) / 2.0 + bmin;

	add_child(octree_root);
	octree_root.set_owner(get_tree().edited_scene_root);

func begin_flood_fill() -> void:
	pass;
