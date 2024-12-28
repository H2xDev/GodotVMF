class_name MDLMeshGenerator extends RefCounted

static func generate_mesh(mdl: MDLReader, vtx: VTXReader, vvd: VVDReader, phy: PHYReader, options: Dictionary) -> MeshInstance3D:
	var mesh_instance = MeshInstance3D.new();
	var array_mesh = ArrayMesh.new();
	var st = SurfaceTool.new();

	var scale = options.scale if not options.use_global_scale else VMFConfig.import.scale;

	var additional_rotation: Vector3 = options.get("additional_rotation", Vector3.ZERO);
	var additional_basis = Basis.from_euler(additional_rotation / 180.0 * PI).scaled(Vector3.ONE * scale);
	var materials_root = options.get("materials_root", VMFConfig.materials.target_folder);

	var _process_mesh = func(mesh: VTXReader.VTXMesh, body_part_index: int, model_index: int, mesh_index: int):
		var mdl_model = mdl.body_parts[body_part_index].models[model_index];
		var mdl_mesh = mdl_model.meshes[mesh_index];

		var model_vertex_index_start = mdl_model.vert_index / 0x30 | 0; # WTF?????

		for strip_group in mesh.strip_groups:
			st.begin(Mesh.PRIMITIVE_TRIANGLES);
	
			for vert_info in strip_group.vertices:
				var vid = vvd.find_vertex_index(model_vertex_index_start + mdl_mesh.vertex_index_start + vert_info.orig_mesh_vert_id);
				var vert = vvd.vertices[vid];
				var tangent = vvd.tangents[vid];
	
				st.set_normal(vert.normal * additional_basis);
				st.set_tangent(tangent);
				st.set_uv(vert.uv);
				st.set_bones(vert.bone_weight.bone_bytes);
				st.set_weights(vert.bone_weight.weight_bytes);
				st.add_vertex(vert.position * additional_basis);
	
			for indice in strip_group.indices:
				st.add_index(indice);
	
			st.optimize_indices_for_cache();
			st.commit(array_mesh);

	var _process_lod = func(lod: VTXReader.VTXLod, body_part_index: int, model_index: int):
		var mesh_index = 0;
		for mesh in lod.meshes:
			_process_mesh.call(mesh, body_part_index, model_index, mesh_index);
			mesh_index += 1;

	var _process_model = func(model: VTXReader.VTXModel, body_part_index: int, model_index: int):
		# NOTE: Since godot doesn't support importing custom 
		# 		lod models, we will only use the first lod
		_process_lod.call(model.lods[0], body_part_index, model_index);

	var _process_body_part = func(body_part: VTXReader.VTXBodyPart, body_part_index: int):
		var model_index = 0;
		for model in body_part.models:
			_process_model.call(model, body_part_index, model_index);
			model_index += 1;

	var body_part_index = 0;
	for body_part in vtx.body_parts: 
		_process_body_part.call(body_part, body_part_index);
		body_part_index += 1;
	

	var skeleton;

	# NOTE: Disabled since there's no any sence to import it without animations
	# if Engine.get_version_info().minor >= 4:
	# 	skeleton = generate_skeleton(mdl, options)
	# 	var skin = skeleton.create_skin_from_rest_transforms();

	# 	skeleton.name = "skeleton";
	# 	mesh_instance.set_skeleton_path("skeleton");
	# 	mesh_instance.add_child(skeleton);
	# 	mesh_instance.set_skin(skin);
	# 	skeleton.set_owner(mesh_instance);

	array_mesh.lightmap_unwrap(Transform3D.IDENTITY, VMFConfig.models.lightmap_texel_size);
	mesh_instance.name = "mesh";
	mesh_instance.set_mesh(array_mesh);

	generate_collision(mesh_instance, skeleton, phy, options);
	assign_materials(array_mesh, mdl, mesh_instance, materials_root);
	create_occluder(mesh_instance, options);

	return mesh_instance;

static func create_occluder(mesh_instance: MeshInstance3D, options):
	if not options.generate_occluder: return;

	var occluder := OccluderInstance3D.new();
	var am: ArrayMesh = ArrayMesh.new();
	var box = ArrayOccluder3D.new();

	var colliders = VMFUtils.get_children_recursive(mesh_instance).filter(func(n): return n is CollisionShape3D);
	if not options.primitive_occluder:
		var st = SurfaceTool.new();
		var vertices = [];
		var indices = [];

		var begin_vid = 0;

		st.begin(Mesh.PRIMITIVE_TRIANGLES);

		for child in colliders:
			var s: ConcavePolygonShape3D = child.shape;
			var points = s.get_faces();

			for p in points:
				st.add_vertex(p);

			for i in range(points.size()):
				st.add_index(begin_vid + i);

			begin_vid += points.size();

		st.commit(am);
		st.optimize_indices_for_cache();

		var arrays = am.surface_get_arrays(0);
		if arrays.size() > 0:
			box.set_arrays(arrays[Mesh.ARRAY_VERTEX], arrays[Mesh.ARRAY_INDEX]);
	else:
		box = BoxOccluder3D.new();
		var aabb = mesh_instance.mesh.get_aabb();
		box.size = aabb.size * options.primitive_occluder_scale;
		occluder.position = aabb.position + aabb.size / 2.0;

	occluder.occluder = box;
	occluder.name = "occluder";

	mesh_instance.add_child(occluder);
	occluder.set_owner(mesh_instance);

static func generate_collision(root: Node3D, skeleton: Skeleton3D, phy: PHYReader, options: Dictionary):
	var scale = options.scale if not options.use_global_scale else VMFConfig.import.scale;
	var additional_rotation: Vector3 = options.get("additional_rotation", Vector3.ZERO);
	var additional_basis = Basis.from_euler(additional_rotation / 180.0 * PI).scaled(Vector3.ONE * scale);

	var yup_to_zup = Basis().rotated(Vector3(1, 0, 0), PI / 2);
	var yup_to_zup_transform = Transform3D(yup_to_zup, Vector3.ZERO);

	var surface_index = 0;
	for surface in phy.surfaces:
		var solid_index = 0;

		for solid in surface.solids:
			# NOTE: Skip the last solid since it's a fullbody collision shape
			if solid_index == surface.solids.size() - 1 and surface.solids.size() > 1: break;

			var static_body: StaticBody3D = StaticBody3D.new();
			var collision: CollisionShape3D = CollisionShape3D.new();

			# FIXME: Use ConvexPolygonShape3D instead of ConcavePolygonShape3D
			# 		 but if it used then for some models it triggers an error
			# 		 "Failed to build convex hull godot"
			var shape: ConcavePolygonShape3D = ConcavePolygonShape3D.new();

			collision.shape = shape;
			collision.name = "collision_" + str(surface_index) + "_" + str(solid_index);
			static_body.name = "solid_" + str(surface_index) + "_" + str(solid_index);

			var vertices = [];

			for face in solid.faces:
				var v1 = surface.vertices[face.v1] * additional_basis;
				var v2 = surface.vertices[face.v2] * additional_basis;
				var v3 = surface.vertices[face.v3] * additional_basis;

				vertices.append_array([v1, v2, v3]);

			collision.shape.set_faces(PackedVector3Array(vertices));

			if skeleton:
				var bone_attachment: BoneAttachment3D = BoneAttachment3D.new();
				bone_attachment.name = "bone_attachment_" + str(surface_index) + "_" + str(solid_index);
				bone_attachment.bone_idx = max(0, solid.bone_index - 1);
				bone_attachment.add_child(static_body);
				skeleton.add_child(bone_attachment);
				bone_attachment.set_owner(root);
			else:
				root.add_child(static_body);
				static_body.set_owner(root);

			static_body.add_child(collision);
			collision.set_owner(root);

			solid_index += 1;

		surface_index += 1;

static func generate_skeleton(mdl: MDLReader, options: Dictionary) -> Skeleton3D:
	var scale = options.scale if not options.use_global_scale else VMFConfig.import.scale;
	var skeleton = Skeleton3D.new();
	var additional_rotation: Vector3 = options.get("additional_rotation", Vector3.ZERO);
	var additional_basis = Basis.from_euler(Vector3.ZERO);

	for bone in mdl.bones:
		skeleton.add_bone(bone.name);

	for bone in mdl.bones:
		if bone.parent != -1:
			skeleton.set_bone_parent(bone.id, bone.parent);

		var parent_bone = mdl.bones[bone.parent];
		var parent_transform = parent_bone.pos_to_bone if parent_bone else Transform3D.IDENTITY;
		var target_transform = bone.pos_to_bone * parent_transform;
		var transform = Transform3D(Basis(bone.quat) * additional_basis, bone.pos * scale);

		skeleton.set_bone_global_pose_override(bone.id, target_transform, 1.0);
		skeleton.set_bone_pose_position(bone.id, transform.origin);
		skeleton.set_bone_pose_rotation(bone.id, transform.basis.get_rotation_quaternion());

		var target_rest_pose = skeleton.get_bone_pose(bone.id);

		skeleton.set_bone_rest(bone.id, target_rest_pose);
		skeleton.reset_bone_pose(bone.id);

	return skeleton;

static func assign_materials(mesh: ArrayMesh, mdl: MDLReader, mesh_instance: MeshInstance3D, materials_root: String):
	var materials = [];
	var skin = 0;

	for tex in mdl.textures:
		for dir in mdl.textureDirs:
			var path = VMFUtils.normalize_path(dir + "/" + tex.name);
			var material = VMTLoader.get_material(path);
			if not material: continue;

			materials.append(material);

	var skin_family = mdl.skin_families[skin];
	for surface_idx in range(mesh.get_surface_count()):
		if skin_family[surface_idx] <= materials.size() - 1:
			mesh.surface_set_material(surface_idx, materials[skin_family[surface_idx]]);

	var skin_idx = 0;
	mesh_instance.set_meta("skins", []);
	for sf in mdl.skin_families:
		var skin_materials = [];
		for surface_idx in range(mesh.get_surface_count()):
			if not materials.has(surface_idx): continue;
			skin_materials.append(materials[surface_idx].get_path());
		mesh_instance.get_meta("skins").append(skin_materials);
