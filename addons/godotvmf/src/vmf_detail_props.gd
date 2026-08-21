class_name VMFDetailProps extends RefCounted

## Creates and returns a DetailProps Node3D containing MultiMeshInstance3D nodes,
## parented to geometry_mesh with owner set. Returns null if there are no props.
static func create_detail_props_node(geometry_mesh: MeshInstance3D, owner: Node) -> void:
	var props := generate(geometry_mesh.mesh)
	if props.is_empty():
		return;
	var existing_node := geometry_mesh.get_node_or_null("DetailProps");
	if existing_node:
		existing_node.free();

	var detail_node := Node3D.new()
	detail_node.name = "DetailProps"
	detail_node.set_display_folded(true)
	geometry_mesh.add_child(detail_node)
	detail_node.set_owner(owner)

	var draw_distance := VMFConfig.import.detail_props_draw_distance;

	for prop in props:
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = prop
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON \
			if prop.get_meta("cast_shadows", true) \
			else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;

		mmi.gi_mode = GeometryInstance3D.GI_MODE_DYNAMIC
		mmi.layers = prop.get_meta("render_layer", 1)
		detail_node.add_child(mmi)
		mmi.set_owner(owner)

		if draw_distance != 0.0:
			var mat := prop.mesh.surface_get_material(0);
			if mat is ShaderMaterial:
				mmi.visibility_range_end = draw_distance;
				mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DEPENDENCIES;
				mmi.set_instance_shader_parameter("draw_distance", draw_distance)
			else:
				mmi.visibility_range_end = draw_distance;
				mmi.visibility_range_end_margin = draw_distance / 2.0;
				mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF;

## Generates detail props from mesh based on material metadata
static func generate(original_mesh: ArrayMesh) -> Array[MultiMesh]:
	var chunk_size := VMFConfig.import.detail_props_chunk_size;
	var inv_chunk_size := 1.0 / chunk_size

	var result: Array[MultiMesh] = []
	var mesh_cache: Dictionary = {}

	for surface_idx in range(original_mesh.get_surface_count()):
		var material := original_mesh.surface_get_material(surface_idx)
		if not material:
			continue
		var material_details := material.get_meta("details", {})

		var arrays := original_mesh.surface_get_arrays(surface_idx)
		var vertices := arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
		var normals := arrays[Mesh.ARRAY_NORMAL] as PackedVector3Array
		var colors := arrays[Mesh.ARRAY_COLOR] as PackedColorArray
		var indices := arrays[Mesh.ARRAY_INDEX] as PackedInt32Array

		if indices.is_empty():
			continue

		var has_colors := not colors.is_empty()
		var num_triangles := indices.size() / 3

		# Pre-compute triangle areas once per surface, shared across both prop passes
		var tri_areas := PackedFloat32Array()
		tri_areas.resize(num_triangles)
		for i in range(num_triangles):
			var i1 := indices[i * 3]
			var i2 := indices[i * 3 + 1]
			var i3 := indices[i * 3 + 2]
			var edge1 := vertices[i2] - vertices[i1]
			var edge2 := vertices[i3] - vertices[i1]
			tri_areas[i] = 0.5 * edge1.cross(edge2).length()

		for prop_index in range(2):
			# Without vertex colors, prop 1 always yields alpha = 0 — nothing to place
			if not has_colors and prop_index == 1:
				continue

			var index_postfix := "" if not prop_index else str(prop_index + 1)

			var detail_prop_path := material_details.get("$detailprop" + index_postfix, "") as String
			if detail_prop_path.is_empty():
				continue

			var density: float = material_details.get("$detailpropdensity" + index_postfix, 1.0)
			var scale_range: Vector2 = material_details.get("$detailpropscale" + index_postfix, Vector2(1.0, 1.0)) as Vector2
			var rotation_range: Vector2 = material_details.get("$detailproprotation" + index_postfix, Vector2(0.0, 360.0)) as Vector2
			var cast_shadows: bool = material_details.get("$detailpropshadows" + index_postfix, 1) == 1
			var render_layer: int = material_details.get("$detailproplayer" + index_postfix, 1)
			var blend_hardness: float = material_details.get("$detailprophardness", 1.0);

			var prop_mesh: Mesh
			if mesh_cache.has(detail_prop_path):
				prop_mesh = mesh_cache[detail_prop_path]
				if prop_mesh == null:
					continue
			else:
				if not ResourceLoader.exists(detail_prop_path):
					VMFLogger.warn("Detail prop scene not found: " + detail_prop_path)
					mesh_cache[detail_prop_path] = null
					continue
				var loaded = ResourceLoader.load(detail_prop_path)
				if not loaded:
					VMFLogger.error("Failed to load detail prop in %s" % material.resource_path)
					mesh_cache[detail_prop_path] = null
					continue
				if loaded is not Mesh:
					VMFLogger.error("The specified detail prop in %s is not Mesh" % material.resource_path)
					mesh_cache[detail_prop_path] = null
					continue
				prop_mesh = loaded as Mesh
				mesh_cache[detail_prop_path] = prop_mesh

			# Pass 1: Count instances per triangle to pre-allocate buffers
			var tri_counts := PackedInt32Array()
			tri_counts.resize(num_triangles)
			var total_estimate := 0

			for i in range(num_triangles):
				var count := int(round(tri_areas[i] * density))
				tri_counts[i] = count
				total_estimate += count

			if total_estimate == 0:
				continue

			# Precompute random ranges outside the hot loop
			var scale_lo := scale_range.x
			var scale_delta := scale_range.y - scale_range.x
			var rot_lo := rotation_range.x * (PI / 180.0)
			var rot_delta := (rotation_range.y - rotation_range.x) * (PI / 180.0)

			# Pass 2: Generate points and group into chunks simultaneously.
			# Uses Array (reference type) for chunk buckets to ensure append() mutates in place.
			var point_data := PackedFloat32Array()
			point_data.resize(total_estimate * 7)
			var chunk_map: Dictionary = {}
			var actual_count := 0

			for i in range(num_triangles):
				var count := tri_counts[i]
				if count <= 0:
					continue

				var i1 := indices[i * 3]
				var i2 := indices[i * 3 + 1]
				var i3 := indices[i * 3 + 2]

				var v1 := vertices[i1]; var v2 := vertices[i2]; var v3 := vertices[i3]
				var n1 := normals[i1]; var n2 := normals[i2]; var n3 := normals[i3]

				var c1r := 1.0; var c2r := 1.0; var c3r := 1.0
				if has_colors:
					c1r = colors[i1].r; c2r = colors[i2].r; c3r = colors[i3].r

				var v1x := v1.x; var v1y := v1.y; var v1z := v1.z
				var v2x := v2.x; var v2y := v2.y; var v2z := v2.z
				var v3x := v3.x; var v3y := v3.y; var v3z := v3.z
				var n1x := n1.x; var n1y := n1.y; var n1z := n1.z
				var n2x := n2.x; var n2y := n2.y; var n2z := n2.z
				var n3x := n3.x; var n3y := n3.y; var n3z := n3.z

				for _j in range(count):
					var r1 := randf()
					var r2 := randf()
					var sqrt_r1 := sqrt(r1)

					var bw := 1.0 - sqrt_r1
					var bu := sqrt_r1 * (1.0 - r2)
					var bv := sqrt_r1 * r2

					var alpha := absf(float(prop_index) - (c1r * bw + c2r * bu + c3r * bv))
					alpha = pow(alpha, blend_hardness);
					if alpha <= 0.01:
						continue

					var px := v1x * bw + v2x * bu + v3x * bv
					var py := v1y * bw + v2y * bu + v3y * bv
					var pz := v1z * bw + v2z * bu + v3z * bv

					var nx := n1x * bw + n2x * bu + n3x * bv
					var ny := n1y * bw + n2y * bu + n3y * bv
					var nz := n1z * bw + n2z * bu + n3z * bv
					var inv_len := 1.0 / sqrt(nx * nx + ny * ny + nz * nz)
					nx *= inv_len; ny *= inv_len; nz *= inv_len

					var base := actual_count * 7
					point_data[base] = px; point_data[base + 1] = py; point_data[base + 2] = pz
					point_data[base + 3] = nx; point_data[base + 4] = ny; point_data[base + 5] = nz
					point_data[base + 6] = alpha

					var chunk_key := Vector3i(
						int(floor(px * inv_chunk_size)),
						int(floor(py * inv_chunk_size)),
						int(floor(pz * inv_chunk_size))
					)
					if not chunk_map.has(chunk_key):
						chunk_map[chunk_key] = []
					chunk_map[chunk_key].append(actual_count)

					actual_count += 1

			if actual_count == 0:
				continue

			# Pass 3: Build MultiMesh transforms per chunk
			for instance_ids in chunk_map.values():
				var instance_count: int = instance_ids.size()
				var mmi := MultiMesh.new()
				mmi.transform_format = MultiMesh.TRANSFORM_3D
				mmi.mesh = prop_mesh
				mmi.instance_count = instance_count
				mmi.set_meta("cast_shadows", cast_shadows)
				mmi.set_meta("render_layer", render_layer)

				var transforms := PackedFloat32Array()
				transforms.resize(instance_count * 12)
				var ti := 0

				for k in range(instance_count):
					var pt_idx: int = instance_ids[k]
					var base := pt_idx * 7
					var px: float = point_data[base]
					var py: float = point_data[base + 1]
					var pz: float = point_data[base + 2]
					var nx: float = point_data[base + 3]
					var ny: float = point_data[base + 4]
					var nz: float = point_data[base + 5]
					var alpha: float = point_data[base + 6]

					var scale := (scale_lo + randf() * scale_delta) * alpha
					var rotation := rot_lo + randf() * rot_delta

					# Build surface-aligned basis directly (Y-axis = normal) with yaw rotation.
					# Avoids creating Basis objects; equivalent to:
					#   Basis.IDENTITY.rotated(normal, rotation) * Basis.looking_at(normal, UP) * tilt_basis * scale
					# tangent = UP.cross(-normal) = (-nz, 0, nx), normalized
					var lsq := nx * nx + nz * nz
					var tx: float; var ty: float; var tz: float
					var bx: float; var by: float; var bz: float
					if lsq > 1e-6:
						var L := sqrt(lsq)
						var linv := 1.0 / L
						tx = -nz * linv; ty = 0.0; tz = nx * linv
						# bitangent = (-normal).cross(tangent)
						bx = -ny * nx * linv; by = L; bz = -ny * nz * linv
					else:
						# Nearly vertical normal — use RIGHT.cross(-normal) = (0, nz, -ny)
						var linv2 := 1.0 / sqrt(nz * nz + ny * ny)
						tx = 0.0; ty = nz * linv2; tz = -ny * linv2
						bx = 1.0; by = 0.0; bz = 0.0

					# Rotate tangent/bitangent around normal (Rodrigues, perpendicular case)
					var cos_r := cos(rotation)
					var sin_r := sin(rotation)
					var xax := (tx * cos_r - bx * sin_r) * scale
					var xay := (ty * cos_r - by * sin_r) * scale
					var xaz := (tz * cos_r - bz * sin_r) * scale
					var zax := (bx * cos_r + tx * sin_r) * scale
					var zay := (by * cos_r + ty * sin_r) * scale
					var zaz := (bz * cos_r + tz * sin_r) * scale
					var yax := nx * scale; var yay := ny * scale; var yaz := nz * scale

					transforms[ti]     = xax; transforms[ti + 1]  = yax; transforms[ti + 2]  = zax; transforms[ti + 3]  = px
					transforms[ti + 4] = xay; transforms[ti + 5]  = yay; transforms[ti + 6]  = zay; transforms[ti + 7]  = py
					transforms[ti + 8] = xaz; transforms[ti + 9]  = yaz; transforms[ti + 10] = zaz; transforms[ti + 11] = pz
					ti += 12

				mmi.buffer = transforms
				result.append(mmi)

	return result
