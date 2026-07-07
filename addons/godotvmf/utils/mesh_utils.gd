class_name VMFMeshUtils extends RefCounted

static func simplify_mesh(mesh: Mesh, target_reduction: float) -> Mesh:
	if not mesh or mesh.get_surface_count() == 0:
		return mesh;

	var reduction := clampf(target_reduction, 0.0, 1.0);
	if is_zero_approx(reduction):
		return mesh;

	var importer_mesh := ImporterMesh.from_mesh(mesh);
	importer_mesh.generate_lods(60.0, -1.0, []);

	var simplified_mesh := ArrayMesh.new();
	for surface_idx in range(importer_mesh.get_surface_count()):
		var surface_arrays: Array = importer_mesh.get_surface_arrays(surface_idx).duplicate(true);
		var lod_indices := _pick_lod_indices(importer_mesh, surface_idx, reduction, surface_arrays);
		if lod_indices != null:
			surface_arrays[Mesh.ARRAY_INDEX] = lod_indices;

		simplified_mesh.add_surface_from_arrays(
			importer_mesh.get_surface_primitive_type(surface_idx),
			surface_arrays
		);

		var material := importer_mesh.get_surface_material(surface_idx);
		if material:
			simplified_mesh.surface_set_material(surface_idx, material);

	_copy_metadata(mesh, simplified_mesh);
	return simplified_mesh;

static func _pick_lod_indices(importer_mesh: ImporterMesh, surface_idx: int, target_reduction: float, surface_arrays: Array) -> Variant:
	var lod_count := importer_mesh.get_surface_lod_count(surface_idx);
	if lod_count == 0:
		return null;

	var base_indices: PackedInt32Array = surface_arrays[Mesh.ARRAY_INDEX] if surface_arrays[Mesh.ARRAY_INDEX] else PackedInt32Array();
	var base_vertices: PackedVector3Array = surface_arrays[Mesh.ARRAY_VERTEX];
	var base_index_count := base_indices.size() if not base_indices.is_empty() else base_vertices.size();
	if base_index_count == 0:
		return null;

	var best_difference := target_reduction;
	var best_indices: PackedInt32Array = PackedInt32Array();
	var found_match := false;

	for lod_idx in range(lod_count):
		var lod_indices := importer_mesh.get_surface_lod_indices(surface_idx, lod_idx);
		if lod_indices.is_empty():
			continue;

		var lod_reduction := 1.0 - (float(lod_indices.size()) / float(base_index_count));
		var reduction_difference := absf(target_reduction - lod_reduction);
		if reduction_difference >= best_difference:
			continue;

		best_difference = reduction_difference;
		best_indices = lod_indices;
		found_match = true;

	return best_indices if found_match else null;

static func _copy_metadata(source: Object, target: Object) -> void:
	for meta_key in source.get_meta_list():
		target.set_meta(meta_key, source.get_meta(meta_key));
