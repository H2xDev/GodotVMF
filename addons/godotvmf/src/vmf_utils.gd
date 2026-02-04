class_name VMFUtils extends RefCounted

static func normalize_path(path: String) -> String:
	return path.replace('\\', '/') \
			.replace('//', '/') \
			.replace('//', '/') \
			.replace('res:/', 'res://') \
			.replace('res:///', 'res://');

static func get_children_recursive(node: Node3D) -> Array:
	var children = [];
	for child in node.get_children():
		children.append(child);
		children.append_array(get_children_recursive(child));
	return children;

static func set_owner_recursive(node: Node, owner: Node):
	node.set_owner(owner);
	for child in node.get_children():
		set_owner_recursive(child, owner);

static func object_assign(target: Object, source: Dictionary) -> void:
	for key in source.keys():
		if key in target:
			target[key] = source[key];

static func merge_surfaces(mesh: ArrayMesh) -> ArrayMesh:
	var result := ArrayMesh.new();
	var surface_count := mesh.get_surface_count();
	if surface_count == 0:
		return result;

	var combined_vertices := PackedVector3Array();
	var combined_indices := PackedInt32Array();
	var vertex_offset := 0;
	var primitive_type := mesh.surface_get_primitive_type(0);

	for surface_index in range(surface_count):
		var arrays := mesh.surface_get_arrays(surface_index);
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX];
		if vertices.is_empty():
			continue;

		combined_vertices.append_array(vertices);

		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX];
		if indices.is_empty():
			for i in range(vertices.size()):
				combined_indices.append(vertex_offset + i);
		else:
			for index in indices:
				combined_indices.append(index + vertex_offset);

		vertex_offset += vertices.size();

	var surface_arrays := [];
	surface_arrays.resize(Mesh.ARRAY_MAX);
	surface_arrays[Mesh.ARRAY_VERTEX] = combined_vertices;
	surface_arrays[Mesh.ARRAY_INDEX] = combined_indices;
	result.add_surface_from_arrays(primitive_type, surface_arrays);
	return result;
