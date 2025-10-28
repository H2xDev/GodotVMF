@static_unload
class_name VMFTool extends RefCounted

static func clear_caches() -> void:
	VMTLoader.clear_cache();

## Generates collisions from mesh for each surface. It adds ability to use sufraceprop values
static func generate_collisions(mesh_instance: MeshInstance3D):
	var bodies: Array[StaticBody3D] = [];
	var surface_props = {};
	var mesh = mesh_instance.mesh;
	var corrector := VMFGeometryCorrector.new();
	var extend_corrector = Engine.get_main_loop().root.get_node_or_null("VMFExtendGeometryCorrector");

	for surface_idx in range(mesh.get_surface_count()):
		var material = mesh.surface_get_material(surface_idx);
		var material_name = mesh.get_meta("surface_material_" + str(surface_idx), "").to_lower();

		var is_ignored = VMFConfig.materials.ignore.any(func(rx: String) -> bool: return material_name.match(rx.to_lower()));
		if is_ignored: continue;

		var compilekeys = material.get_meta("compile_keys", []) if material else [];
		var surface_prop = (material.get_meta("surfaceprop", "default") if material else "default");
		
		# NOTE: Blend textures can have more than one surface prop. In this case we'll choose the first one.
		if surface_prop is Array:
			surface_prop = surface_prop[0];

		if compilekeys.size() > 0:
			surface_prop = "tool_" + compilekeys[0];

		var has_nocollision_extender = extend_corrector and "nocollision" in extend_corrector;
		var is_no_collision = false;

		for key in compilekeys:
			if has_nocollision_extender:
				if extend_corrector.nocollision.has(key): 
					is_no_collision = true;
					break;

			if is_no_collision: break;

			if corrector.nocollision.has(key): 
				is_no_collision = true;
				break;

		if is_no_collision: continue;

		if not surface_prop in surface_props:
			surface_props[surface_prop] = ArrayMesh.new();

		var array_mesh = surface_props[surface_prop];
		var arrays = mesh.surface_get_arrays(surface_idx);
		array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays);

		if compilekeys.size() > 0:
			array_mesh.set_meta("compile_keys", compilekeys);
	
	for surface_prop in surface_props.keys():
		var static_body = StaticBody3D.new();
		var collision = CollisionShape3D.new();
		var compilekeys = surface_props[surface_prop].get_meta("compile_keys", []);

		for key in compilekeys:
			if extend_corrector and key in extend_corrector:
				extend_corrector[key].call(static_body);
				continue;

			if key in corrector:
				corrector[key].call(static_body);

		static_body.name = "surface_prop_" + surface_prop;
		static_body.set_meta("surface_prop", surface_prop);

		collision.name = "collision";
		collision.shape = surface_props[surface_prop].create_trimesh_shape();

		static_body.add_child(collision);
		collision.set_owner(static_body);

		mesh_instance.add_child(static_body);
		VMFUtils.set_owner_recursive(static_body, mesh_instance.get_owner());

## Clear mesh from ignored textures and materials
static func cleanup_mesh(original_mesh: ArrayMesh):
	var is_44 = Engine.get_version_info().minor >= 4;

	var ignored_textures = VMFConfig.materials.ignore;
	var duplicated_mesh = ArrayMesh.new() if not is_44 else null;
	var corrector := VMFGeometryCorrector.new();
	var extend_corrector = Engine.get_main_loop().root.get_node_or_null("VMFExtendGeometryCorrector");
	var mt = MeshDataTool.new() if not is_44 else null;

	var surface_removed = 0;
	for surface_idx in range(original_mesh.get_surface_count()):
		# NOTE: Remapping surface material meta to the new index in case previous surface were removed
		original_mesh.set_meta("surface_material_" + str(surface_idx - surface_removed), original_mesh.get_meta("surface_material_" + str(surface_idx), ""));
		surface_idx -= surface_removed;

		var material_name = original_mesh.get_meta("surface_material_" + str(surface_idx), "").to_lower();
		var material = original_mesh.surface_get_material(surface_idx);
		var compilekeys = material.get_meta("compile_keys", []) if material else [];

		var is_ignored = ignored_textures.any(func(rx: String) -> bool: return material_name.match(rx.to_lower()));
		if is_ignored and is_44:
			original_mesh.surface_remove(surface_idx);
			surface_removed += 1;
			continue;

		var is_norender = false;

		for key in compilekeys:
			if is_ignored: break;
			if extend_corrector and "norender" in extend_corrector.norender:
				is_norender = extend_corrector.norender.has(key);
				break;

			is_norender = corrector.norender.has(key);
			if is_norender: break;

		if is_norender and is_44:
			original_mesh.surface_remove(surface_idx);
			surface_removed += 1;
			continue;

		if is_norender or is_44: continue;

		mt.create_from_surface(original_mesh, surface_idx);
		mt.commit_to_surface(duplicated_mesh, surface_idx);
		duplicated_mesh.set_meta("surface_material_" + str(surface_idx), material_name);

	return duplicated_mesh if not is_44 else original_mesh;

static func is_material_transparent(material: Material) -> bool:
	if material is ShaderMaterial: return true;
	if material is BaseMaterial3D:
		var bm := material as BaseMaterial3D;

		return bm.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED;
	return false;

static func remove_merged_faces(brush_a: VMFSolid, brushes: Array[VMFSolid]) -> void:
	for brush_b in brushes:
		if brush_a == brush_b: continue;

		for side_a in brush_a.sides:
			var a_removed = false;

			for side_b in brush_b.sides:
				if side_a.plane.normal.dot(side_b.plane.normal) > -0.99: continue;
				if side_a.plane.get_center().distance_to(side_b.plane.get_center()) > 0.01: continue;

				var material_a: Material = VMTLoader.get_material(side_a.material);
				var material_b: Material = VMTLoader.get_material(side_b.material);
				if is_material_transparent(material_a): continue;
				if is_material_transparent(material_b): continue;

				if side_a.is_equal_to(side_b):
					brush_b.sides.erase(side_b);
					brush_a.sides.erase(side_a);
					a_removed = true;
					break;

				if side_a.is_inside_of_face(side_b):
					brush_a.sides.erase(side_a);
					a_removed = true;
					break;

			if a_removed: break;


## Returns MeshInstance3D from parsed VMF structure
static func create_mesh(vmf_structure: VMFStructure, offset: Vector3 = Vector3.ZERO, optimized: bool = true) -> ArrayMesh:
	clear_caches();
	var import_scale := VMFConfig.import.scale;

	if vmf_structure.solids.size() == 0:
		return null;

	var brushes := vmf_structure.solids;
	var material_sides: Dictionary = {};
	var mesh := ArrayMesh.new();

	for brush in brushes:
		if optimized: remove_merged_faces(brush, brushes);

		for side: VMFSide in brush.sides:
			var material: String = side.material.to_upper();

			if not material in material_sides:
				material_sides[material] = [];

			material_sides[material].append(side);

	for sides in material_sides.values():
		var sf := SurfaceTool.new();
		sf.begin(Mesh.PRIMITIVE_TRIANGLES);

		var index: int = 0;
		for side: VMFSide in sides:
			var base_index := index;

			if not side.is_displacement and side.solid.has_displacement:
				continue;

			if side.vertices.size() < 3:
				VMFLogger.error("Side corrupted: " + str(side.id));
				continue;

			if not side.plane: continue;

			if not side.is_displacement:
				var normal = side.plane.normal;
				var sg := -1 if side.smoothing_groups == 0 else side.smoothing_groups;

				sf.set_normal(Vector3(normal.x, normal.z, -normal.y));
				sf.set_color(Color(1, 1, 1));
				sf.set_smooth_group(sg);
	
				for v: Vector3 in side.vertices:
					sf.set_uv(side.get_uv(v));
					sf.add_vertex(Vector3(v.x, v.z, -v.y) * import_scale - offset);
					index += 1;

				for i: int in range(1, side.vertices.size() - 1):
					sf.add_index(base_index);
					sf.add_index(base_index + i);
					sf.add_index(base_index + i + 1);
			else:
				var disp: VMFDisplacementInfo = side.dispinfo;
				var edges_count := int(disp.edges_count);
				var verts_count := int(disp.verts_count);
				sf.set_smooth_group(1);

				for i: int in range(0, side.dispinfo.vertices.size()):
					var x := i / verts_count;
					var y := i % verts_count;
					var v := side.dispinfo.vertices[i];
					var normal := disp.get_normal(x, y);
					var dist := disp.get_distance(x, y);
					var voffset := disp.get_offset(x, y);
					var uv := side.get_uv(v - dist - voffset);

					sf.set_uv(uv);
					sf.set_color(disp.get_color(x, y));
					sf.set_normal(Vector3(normal.x, normal.z, -normal.y));
					sf.add_vertex(Vector3(v.x, v.z, -v.y) * import_scale - offset);
					index += 1;

				for i: int in range(0, pow(edges_count, 2)):
					var x := i / edges_count;
					var y := i % edges_count;
					var is_odd := (x + y) % 2 == 1;

					if is_odd:
						sf.add_index(base_index + x + 1 + y * verts_count);
						sf.add_index(base_index + x + (y + 1) * verts_count);
						sf.add_index(base_index + x + 1 + (y + 1) * verts_count);

						sf.add_index(base_index + x + y * verts_count);
						sf.add_index(base_index + x + (y + 1) * verts_count);
						sf.add_index(base_index + x + 1 + y * verts_count);
					else:
						sf.add_index(base_index + x + y * verts_count);
						sf.add_index(base_index + x + (y + 1) * verts_count);
						sf.add_index(base_index + x + 1 + (y + 1) * verts_count);

						sf.add_index(base_index + x + y * verts_count);
						sf.add_index(base_index + x + 1 + (y + 1) * verts_count);
						sf.add_index(base_index + x + 1 + y * verts_count);

		# NOTE: In case no mesh were generated just skip commiting
		if index == 0: continue;

		var material = VMTLoader.get_material(sides[0].material);
		if material: sf.set_material(material);
		
		if optimized: sf.optimize_indices_for_cache();
		sf.generate_normals();
		sf.generate_tangents();
		sf.commit(mesh);

		mesh.set_meta("surface_material_" + str(mesh.get_surface_count() - 1), sides[0].material);

	return mesh;

static func generate_lods(mesh: ArrayMesh) -> ArrayMesh:
	var importer_mesh := ImporterMesh.new();
	for surface_idx in range(mesh.get_surface_count()):
		importer_mesh.add_surface(
			ArrayMesh.PRIMITIVE_TRIANGLES,
			mesh.surface_get_arrays(surface_idx),
			[], {},
			mesh.surface_get_material(surface_idx),
			'surface_' + str(surface_idx)
		);

	importer_mesh.generate_lods(60, 60, []);

	return importer_mesh.get_mesh();
