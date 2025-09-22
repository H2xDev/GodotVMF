# File: AABBWire.gd
@tool
class_name AABBVisualizer extends Node3D
var aabb: AABB = AABB();

var mesh_instance: MeshInstance3D
var imesh: ImmediateMesh

func _init(_aabb: AABB):
	aabb = _aabb;
	mesh_instance = MeshInstance3D.new();
	add_child(mesh_instance);
	imesh = ImmediateMesh.new()
	mesh_instance.mesh = imesh
	mesh_instance.material_override = StandardMaterial3D.new() # можно настроить
	_build_wire()

func set_aabb(value: AABB) -> void:
	aabb = value
	_build_wire()

func _build_wire() -> void:
	# 8 вершин коробки
	var p = aabb.position
	var s = aabb.size
	var corners = [
		p + Vector3(0,0,0),
		p + Vector3(s.x,0,0),
		p + Vector3(s.x,s.y,0),
		p + Vector3(0,s.y,0),
		p + Vector3(0,0,s.z),
		p + Vector3(s.x,0,s.z),
		p + Vector3(s.x,s.y,s.z),
		p + Vector3(0,s.y,s.z)
	]
	var edges = [
		[0,1],[1,2],[2,3],[3,0], # нижняя рамка (z=0)
		[4,5],[5,6],[6,7],[7,4], # верхняя рамка (z=max)
		[0,4],[1,5],[2,6],[3,7]  # вертикали
	]

	imesh.clear_surfaces()
	imesh.surface_begin(Mesh.PRIMITIVE_LINES)
	for e in edges:
		imesh.surface_add_vertex(corners[e[0]])
		imesh.surface_add_vertex(corners[e[1]])
	imesh.surface_end()
