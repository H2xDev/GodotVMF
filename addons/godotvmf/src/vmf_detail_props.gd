class_name VMFDetailProps extends RefCounted

## Generates detail props from mesh based on material metadata
static func generate(original_mesh: ArrayMesh) -> Array[MultiMesh]:
	var chunk_size := VMFConfig.import.detail_props_chunk_size;
	var inv_chunk_size := 1.0 / chunk_size

	var result: Array[MultiMesh] = []

	# Pre-compute constant basis tilt (rotation around X by -PI/2)
	var tilt_basis := Basis.IDENTITY.rotated(Vector3.RIGHT, -PI / 2)
	var rotation_to_rad := PI / 180.0

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

		for prop_index in range(2):
			var index_postfix := "" if not prop_index else str(prop_index + 1)

			var detail_prop_path := material_details.get("$detailprop" + index_postfix, "") as String
			if detail_prop_path.is_empty():
				continue

			var density: float = material_details.get("$detailpropdensity" + index_postfix, 1.0)
			var scale_range: Vector2 = material_details.get("$detailpropscale" + index_postfix, Vector2(1.0, 1.0)) as Vector2
			var rotation_range: Vector2 = material_details.get("$detailproprotation" + index_postfix, Vector2(0.0, 360.0)) as Vector2
			var cast_shadows: bool = material_details.get("$detailpropshadows" + index_postfix, 1) == 1

			if not ResourceLoader.exists(detail_prop_path):
				VMFLogger.warn("Detail prop scene not found: " + detail_prop_path)
				continue

			var prop_mesh = ResourceLoader.load(detail_prop_path)
			if not prop_mesh:
				VMFLogger.error("Failed to load detail prop in %s" % material.resource_path)
				continue

			if prop_mesh is not Mesh:
				VMFLogger.error("The specified detail prop in %s is not Mesh" % material.resource_path)
				continue

			# Pass 1: Count instances per triangle to pre-allocate buffers
			var tri_counts := PackedInt32Array()
			tri_counts.resize(num_triangles)
			var total_estimate := 0

			for i in range(num_triangles):
				var i1 := indices[i * 3]
				var i2 := indices[i * 3 + 1]
				var i3 := indices[i * 3 + 2]
				var edge1 := vertices[i2] - vertices[i1]
				var edge2 := vertices[i3] - vertices[i1]
				var area := 0.5 * edge1.cross(edge2).length()
				var count := int(round(area * density))
				tri_counts[i] = count
				total_estimate += count

			if total_estimate == 0:
				continue

			# Pass 2: Generate points into a flat pre-allocated buffer
			var point_data := PackedFloat32Array()
			point_data.resize(total_estimate * 7)
			var chunk_indices := PackedInt32Array()
			chunk_indices.resize(total_estimate * 3)
			var actual_count := 0

			for i in range(num_triangles):
				var count := tri_counts[i]
				if count <= 0:
					continue

				var i1 := indices[i * 3]
				var i2 := indices[i * 3 + 1]
				var i3 := indices[i * 3 + 2]

				var v1 := vertices[i1]
				var v2 := vertices[i2]
				var v3 := vertices[i3]
				var n1 := normals[i1]
				var n2 := normals[i2]
				var n3 := normals[i3]

				var c1r := 1.0
				var c2r := 1.0
				var c3r := 1.0

				if has_colors:
					c1r = colors[i1].r
					c2r = colors[i2].r
					c3r = colors[i3].r

				# Cache component values to avoid repeated property access
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

					var alpha := absf(prop_index - (c1r * bw + c2r * bu + c3r * bv))
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

					var ci := actual_count * 3
					chunk_indices[ci] = int(floor(px * inv_chunk_size))
					chunk_indices[ci + 1] = int(floor(py * inv_chunk_size))
					chunk_indices[ci + 2] = int(floor(pz * inv_chunk_size))

					actual_count += 1

			if actual_count == 0:
				continue

			# Pass 3: Group instance indices by chunk key
			var chunk_map: Dictionary = {}
			for k in range(actual_count):
				var ci := k * 3
				var chunk_key := Vector3i(chunk_indices[ci], chunk_indices[ci + 1], chunk_indices[ci + 2])
				if not chunk_map.has(chunk_key):
					chunk_map[chunk_key] = PackedInt32Array()
				chunk_map[chunk_key].append(k)

			# Pass 4: Build MultiMesh transforms per chunk
			for instance_ids: PackedInt32Array in chunk_map.values():
				var instance_count := instance_ids.size()
				var mmi := MultiMesh.new()
				mmi.transform_format = MultiMesh.TRANSFORM_3D
				mmi.mesh = prop_mesh
				mmi.instance_count = instance_count
				mmi.set_meta("cast_shadows", cast_shadows)

				var transforms := PackedFloat32Array()
				transforms.resize(instance_count * 12)
				var ti := 0

				for k in range(instance_count):
					var base := instance_ids[k] * 7
					var point := Vector3(point_data[base], point_data[base + 1], point_data[base + 2])
					var normal := Vector3(point_data[base + 3], point_data[base + 4], point_data[base + 5])
					var alpha: float = point_data[base + 6]

					var scale := randf_range(scale_range.x, scale_range.y) * alpha
					var rotation := randf_range(rotation_range.x, rotation_range.y) * rotation_to_rad

					var basis := Basis.IDENTITY.rotated(normal, rotation) \
						* Basis.looking_at(normal, Vector3.UP) \
						* tilt_basis \
						.scaled(Vector3.ONE * scale)

					transforms[ti]     = basis.x.x; transforms[ti + 1]  = basis.y.x; transforms[ti + 2]  = basis.z.x; transforms[ti + 3]  = point.x
					transforms[ti + 4] = basis.x.y; transforms[ti + 5]  = basis.y.y; transforms[ti + 6]  = basis.z.y; transforms[ti + 7]  = point.y
					transforms[ti + 8] = basis.x.z; transforms[ti + 9]  = basis.y.z; transforms[ti + 10] = basis.z.z; transforms[ti + 11] = point.z
					ti += 12

				mmi.buffer = transforms
				result.append(mmi)

	return result
