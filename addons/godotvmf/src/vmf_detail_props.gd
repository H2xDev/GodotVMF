class_name VMFDetailProps extends RefCounted

## Generates detail props from mesh based on material metadata
static func generate(original_mesh: ArrayMesh) -> Array[MultiMesh]:
	const CHUNK_SIZE := 32.0
	const DENSITY := 1.0
	var result: Array[MultiMesh] = []

	for surface_idx in range(original_mesh.get_surface_count()):
		var material := original_mesh.surface_get_material(surface_idx)
		if not material:
			continue

		for prop_index in range(2):
			var index_postfix = "" if not prop_index else str(prop_index + 1)
			var material_details := material.get_meta("details", {})

			var detail_prop_path := material_details.get("$detailprop" + index_postfix, "") as String
			if detail_prop_path.is_empty():
				continue

			var density: float = material_details.get("$detailpropdensity" + index_postfix, 1.0);
			var scale_range: Vector2 = material_details.get("$detailpropscale" + index_postfix, Vector2(1.0, 1.0)) as Vector2
			var rotation_range: Vector2 = material_details.get("$detailproprotation" + index_postfix, Vector2(0.0, 360.0)) as Vector2
			var offset_randomize: float = material_details.get("$detailpropoffsetrandomize" + index_postfix, 1.0)
			var cast_shadows: bool = material_details.get("$detailpropshadows" + index_postfix, 1) == 1;

			if not ResourceLoader.exists(detail_prop_path): 
				VMFLogger.warn("Detail prop scene not found: " + detail_prop_path)
				continue

			var prop_mesh = ResourceLoader.load(detail_prop_path);
			if not prop_mesh: 
				VMFLogger.error("Failed to load detail prop in %s" % material.resource_path);
				continue

			if prop_mesh is not Mesh:
				VMFLogger.error("The specified detail prop in %s is not Mesh" % material.resource_path);
				continue;

			var arrays := original_mesh.surface_get_arrays(surface_idx)
			var vertices := arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
			var normals := arrays[Mesh.ARRAY_NORMAL] as PackedVector3Array
			var colors := arrays[Mesh.ARRAY_COLOR] as PackedColorArray
			var indices := arrays[Mesh.ARRAY_INDEX] as PackedInt32Array

			if indices.is_empty(): continue

			var has_colors := not colors.is_empty()
			var chunks: Dictionary = {}

			var num_triangles := indices.size() / 3

			for i in range(num_triangles):
				var i1 := indices[i * 3];
				var i2 := indices[i * 3 + 1];
				var i3 := indices[i * 3 + 2];
				
				var v1 := vertices[i1];
				var v2 := vertices[i2];
				var v3 := vertices[i3];
				
				var edge1 := v2 - v1;
				var edge2 := v3 - v1;
				var area := 0.5 * edge1.cross(edge2).length();
				var count := int(round(area * density));
				
				if count <= 0: continue;

				var n1 := normals[i1];
				var n2 := normals[i2];
				var n3 := normals[i3];
				
				var c1r := 1.0;
				var c2r := 1.0;
				var c3r := 1.0;
				
				if has_colors:
					c1r = colors[i1].r;
					c2r = colors[i2].r;
					c3r = colors[i3].r;

				for j in range(count):
					var r1 := randf();
					var r2 := randf();
					var sqrt_r1 := sqrt(r1);
					
					var w := 1.0 - sqrt_r1;
					var u := sqrt_r1 * (1.0 - r2);
					var v := sqrt_r1 * r2;
					
					var alpha := abs(prop_index - (c1r * w + c2r * u + c3r * v));
					if alpha <= 0.01: continue;

					var point := v1 * w + v2 * u + v3 * v;
					var normal := (n1 * w + n2 * u + n3 * v).normalized();
					
					var chunk_key := Vector3i(floor(point.x / CHUNK_SIZE), floor(point.y / CHUNK_SIZE), floor(point.z / CHUNK_SIZE));
					
					if not chunks.has(chunk_key):
						chunks[chunk_key] = [];
					
					chunks[chunk_key].append([point, normal, alpha]);

			for chunk in chunks.values():
				var mmi := MultiMesh.new();
				mmi.transform_format = MultiMesh.TRANSFORM_3D;
				mmi.mesh = prop_mesh;
				mmi.instance_count = chunk.size();

				for k in range(chunk.size()):
					var data = chunk[k];
					var t := Transform3D();
					var scale := randf_range(scale_range.x, scale_range.y) * (data[2] as float);
					var rotation := randf_range(rotation_range.x, rotation_range.y) / 180.0 * PI;
					var normal: Vector3 = data[1];

					t.basis = Basis.IDENTITY.rotated(normal, rotation) \
						* Basis.looking_at(normal, Vector3.UP) \
						* Basis.IDENTITY.rotated(Vector3.RIGHT, -PI / 2) \
						.scaled(Vector3.ONE * scale);
					t.origin = data[0];
					
					mmi.set_instance_transform(k, t)

				result.append(mmi)

	return result
