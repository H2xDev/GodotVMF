@tool
@icon("res://addons/godotvmf/icon.svg")
class_name VMFNode extends Node3D;

## Emitted during batched import to report progress. Connect to update UI.
signal import_progress(phase: String, current: int, total: int)


## Keys preserved when wiping entity data after _entity_setup
const RUNTIME_KEYS = ["targetname", "connections", "parentname", "spawnflags", "classname", "id", "StartDisabled"]

enum MaterialImportMode {
	USE_EXISTING,
	IMPORT_FROM_MOD_FOLDER,
}

@export_category("VMF File")

## Allow the file picker to select an external file
@export var use_external_file: bool = false:
	set(val):
		use_external_file = val;
		notify_property_list_changed();

## Path to the VMF file
@export_file("*.vmf")
var vmf: String = '';

@export_category("Import")

## Full import of VMF with specified options
@export var import: bool = false:
	set(value):
		if not value: return;
		# Property setters cannot be async, so use a wrapper
		_do_import();
		import = false;

@export var double_sided_shadow_cast: bool = false;

@export_category("Resource Generation")

## During import the importer will remove all invisible faces from the mesh.
## Increases the import time
@export var remove_merged_faces: bool = true;

## Save the resulting geometry mesh as a resource (saves to the "Geometry folder" in Project Settings)
@export var save_geometry: bool = true;

## Save the resulting collision shape as a resource (saves to the "Geometry folder" in Project Settings)
@export var save_collision: bool = true;

@export_flags_3d_physics var default_physics_mask: int = 1;

@export_category("Navigation")

## Bake navigation mesh (temporarily creates collision for baking, then removes it)
@export var bake_navigation: bool = false

## Set this to true before import if you're goint to use this node in runtime
var is_runtime: bool = false;

var vmf_structure: VMFStructure;

var _owner:
	get: 
		var o = get_owner();
		if o == null: return self;

		return o;

var geometry: Node3D:
	get: 
		var node = get_node_or_null("Geometry");
		node = get_node_or_null(NodePath("NavigationMesh/Geometry")) \
			if node == null else node;

		return node;

var entities: Node3D:
	get: return get_node_or_null("Entities");

var navmesh: Node3D:
	get: return get_node_or_null("NavigationMesh");

var has_imported_resources = false;

## Async wrapper for property setter (which cannot use await)
func _do_import() -> void:
	await import_map();


func _validate_property(property: Dictionary) -> void:
	if property.name == "vmf":
		property.hint = PROPERTY_HINT_GLOBAL_FILE if use_external_file else PROPERTY_HINT_FILE

var _physics_bodies: Array[RID] = [];
var _visual_instances: Array[RID] = [];
var _visual_resources: Array = [];  # prevent GC of loaded MultiMesh resources

func _ready() -> void:
	add_to_group("vmfnode_group");

	# Create prop_static visuals via RenderingServer (no nodes needed, works in editor + runtime)
	_create_runtime_visuals();

	# Create collision bodies at runtime via PhysicsServer3D (no nodes needed)
	if not Engine.is_editor_hint():
		_create_runtime_collisions();

func _exit_tree() -> void:
	_cleanup_runtime_visuals();
	_cleanup_runtime_collisions();

## Creates physics bodies from stored collision data using PhysicsServer3D directly.
## No StaticBody3D/CollisionShape3D nodes are created — just server-side RIDs.
func _create_runtime_collisions() -> void:
	var collision_data: Array = _load_collision_data();
	if collision_data.is_empty(): return;

	var ps := PhysicsServer3D;
	var space := get_world_3d().space;

	for entry in collision_data:
		var shape: Shape3D = entry.shape;
		if not shape: continue;
		var body := ps.body_create();
		ps.body_set_mode(body, PhysicsServer3D.BODY_MODE_STATIC);
		ps.body_set_space(body, space);
		ps.body_add_shape(body, shape.get_rid());
		ps.body_set_state(body, PhysicsServer3D.BODY_STATE_TRANSFORM, entry.transform);
		ps.body_set_collision_layer(body, default_physics_mask);
		_physics_bodies.append(body);

## Loads collision data from the external .res file referenced in metadata.
## Falls back to inline metadata for backwards compatibility.
func _load_collision_data() -> Array:
	var path: String = get_meta("prop_collision_path", "");
	if not path.is_empty() and ResourceLoader.exists(path):
		var res = ResourceLoader.load(path);
		if res and res is Resource:
			return res.get_meta("collision_data", []);
	# Fallback: inline metadata (backwards compatibility)
	return get_meta("prop_collision_data", []);

## Saves collected collision data to an external .res file and stores the path in metadata.
## Call after all entities have been imported.
func _save_collision_data_external() -> void:
	var collision_data: Array = get_meta("prop_collision_data", []);
	if collision_data.is_empty(): return;

	var save_path := "%s/%s_collision_data.res" % [VMFConfig.import.geometry_folder, _vmf_identifer()];

	if not DirAccess.dir_exists_absolute(save_path.get_base_dir()):
		DirAccess.make_dir_recursive_absolute(save_path.get_base_dir());

	# Store collision data as metadata on a lightweight Resource
	var container := Resource.new();
	container.set_meta("collision_data", collision_data);

	var err := ResourceSaver.save(container, save_path, ResourceSaver.FLAG_COMPRESS);
	if err:
		VMFLogger.error("Failed to save collision data: %s" % err);
		return;

	# Replace inline metadata with a path reference
	remove_meta("prop_collision_data");
	set_meta("prop_collision_path", save_path);

## Saves the prop_static visual manifest to an external .res file.
func _save_visual_manifest(manifest: Array) -> void:
	var save_path := "%s/%s_visuals.res" % [VMFConfig.import.geometry_folder, _vmf_identifer()];

	if not DirAccess.dir_exists_absolute(save_path.get_base_dir()):
		DirAccess.make_dir_recursive_absolute(save_path.get_base_dir());

	var container := Resource.new();
	container.set_meta("entries", manifest);

	var err := ResourceSaver.save(container, save_path, ResourceSaver.FLAG_COMPRESS);
	if err:
		VMFLogger.error("Failed to save visual manifest: %s" % err);
		return;

	set_meta("prop_visuals_path", save_path);

func _cleanup_runtime_collisions() -> void:
	var ps := PhysicsServer3D;
	for body in _physics_bodies:
		ps.free_rid(body);
	_physics_bodies.clear();

## Creates prop_static visuals + collision from the saved manifest.
## Uses individual RenderingServer instances per prop (godotwind pattern).
## No MultiMesh, no chunking — Godot handles per-instance frustum culling via AABB.
## Runs in both editor (@tool) and runtime.
func _create_runtime_visuals() -> void:
	var manifest_path: String = get_meta("prop_visuals_path", "");
	if manifest_path.is_empty():
		return;
	if not ResourceLoader.exists(manifest_path):
		print("[VMF] Visuals manifest not found: ", manifest_path);
		return;

	var manifest_res = ResourceLoader.load(manifest_path);
	if not manifest_res or not (manifest_res is Resource):
		print("[VMF] Failed to load visuals manifest");
		return;

	var entries: Array = manifest_res.get_meta("entries", []);
	if entries.is_empty():
		print("[VMF] Visuals manifest is empty");
		return;

	print("[VMF] Loading ", entries.size(), " prop_static entries via RenderingServer");

	var rs := RenderingServer;
	var scenario := get_world_3d().scenario;
	var ps := PhysicsServer3D;
	var space: RID = get_world_3d().space if not Engine.is_editor_hint() else RID();
	var do_collision := not Engine.is_editor_hint();

	# Step 1: Collect unique model paths
	var unique_models := {};  # model_key -> model_path
	for entry in entries:
		var model_key: String = entry.model;
		if unique_models.has(model_key): continue;
		unique_models[model_key] = VMFUtils.normalize_path(VMFConfig.models.target_folder + "/" + model_key);

	print("[VMF] Loading ", unique_models.size(), " unique models");

	# Step 2: Load models and build mesh cache
	var mesh_cache := {};  # group_key -> { mesh_rid, mesh_resource, collision_shapes }
	var loaded_count := 0;

	for model_key in unique_models:
		var model_path: String = unique_models[model_key];
		if not ResourceLoader.exists(model_path): continue;
		var model_scene: PackedScene = ResourceLoader.load(model_path) as PackedScene;
		if not model_scene: continue;

		var temp = model_scene.instantiate();
		if not temp or not (temp is MeshInstance3D):
			if temp: temp.free()
			continue;

		var mesh: ArrayMesh = temp.mesh;
		var skin_meta := {};
		for meta_key in temp.get_meta_list():
			if meta_key.begins_with("skin_"):
				skin_meta[meta_key] = temp.get_meta(meta_key);

		var collision_shapes: Array[Shape3D] = [];
		var stack = [temp];
		while stack.size() > 0:
			var node = stack.pop_back();
			if node is CollisionShape3D and node.shape:
				collision_shapes.append(node.shape.duplicate());
			for child in node.get_children():
				stack.append(child);

		temp.free();

		if not mesh:
			continue;

		loaded_count += 1;

		# Pre-cache all skin variants for this model
		# Default (no skin) entry
		var base_key: String = model_key + "::0";
		if not mesh_cache.has(base_key):
			_visual_resources.append(mesh);
			mesh_cache[base_key] = {
				"mesh_rid": mesh.get_rid(),
				"mesh_resource": mesh,
				"collision_shapes": collision_shapes,
			};

		for skin_key_name in skin_meta:
			var skin_id_str: String = skin_key_name.replace("skin_", "");
			var group_key: String = model_key + "::" + skin_id_str;
			if mesh_cache.has(group_key): continue;

			var skinned_mesh: ArrayMesh = mesh.duplicate() as ArrayMesh;
			var materials = skin_meta[skin_key_name];
			for s in range(skinned_mesh.get_surface_count()):
				if s < materials.size():
					skinned_mesh.surface_set_material(s, materials[s]);
			_visual_resources.append(skinned_mesh);
			mesh_cache[group_key] = {
				"mesh_rid": skinned_mesh.get_rid(),
				"mesh_resource": skinned_mesh,
				"collision_shapes": collision_shapes,
			};

	print("[VMF] Loaded ", loaded_count, "/", unique_models.size(), " model variants, creating instances...");

	# Step 3: Create RenderingServer + PhysicsServer instances for all entries
	for entry in entries:
		var group_key: String = entry.model + "::" + str(entry.skin);
		var cached = mesh_cache.get(group_key);
		if cached == null: continue;

		# Build transform with model_scale applied
		var t: Transform3D = entry.transform;
		var ms: float = entry.model_scale;
		t.basis = t.basis.scaled(Vector3.ONE * ms * ms);

		# Create RenderingServer visual instance
		var instance := rs.instance_create();
		rs.instance_set_scenario(instance, scenario);
		rs.instance_set_base(instance, cached.mesh_rid);
		rs.instance_set_transform(instance, t);
		rs.instance_geometry_set_flag(instance, RenderingServer.INSTANCE_FLAG_USE_BAKED_LIGHT, true);
		rs.instance_geometry_set_cast_shadows_setting(instance, RenderingServer.SHADOW_CASTING_SETTING_ON);

		# Visibility range (fade)
		var fade_max: float = entry.fade_max;
		var fade_min: float = entry.fade_min;
		var ssf: bool = entry.ssf;
		if fade_max > 0.0:
			var fade_mode = RenderingServer.VISIBILITY_RANGE_FADE_SELF \
				if ssf else RenderingServer.VISIBILITY_RANGE_FADE_DISABLED;
			var end_margin: float = (fade_max - fade_min) if ssf else 0.0;
			rs.instance_geometry_set_visibility_range(instance, 0.0, fade_max, 0.0, end_margin, fade_mode);

		_visual_instances.append(instance);

		# Collision (runtime only)
		if do_collision and not cached.collision_shapes.is_empty():
			for shape in cached.collision_shapes:
				var body := ps.body_create();
				ps.body_set_mode(body, PhysicsServer3D.BODY_MODE_STATIC);
				ps.body_set_space(body, space);
				ps.body_add_shape(body, shape.get_rid());
				ps.body_set_state(body, PhysicsServer3D.BODY_STATE_TRANSFORM, t);
				ps.body_set_collision_layer(body, default_physics_mask);
				_physics_bodies.append(body);

	print("[VMF] Created ", _visual_instances.size(), " RenderingServer instances");

func _cleanup_runtime_visuals() -> void:
	var rs := RenderingServer;
	for instance in _visual_instances:
		if instance.is_valid():
			rs.free_rid(instance);
	_visual_instances.clear();
	_visual_resources.clear();

## Size of each navmesh tile edge in Godot units. Smaller = more tiles = less geometry per bake.
const NAVMESH_TILE_SIZE := 128.0

## Bakes navigation mesh using tiled approach to avoid Recast crashes on large maps.
## Splits the map into NxN tiles, bakes each separately. Multiple NavigationRegion3D nodes
## on the same map merge automatically for seamless pathfinding.
func bake_navmesh_with_collisions() -> void:
	# Clean up any existing navmesh tiles
	var nav_parent = get_node_or_null("NavigationMesh");
	if nav_parent:
		nav_parent.free();

	# Collect all source geometry
	var source_geo := NavigationMeshSourceGeometryData3D.new();

	# Add world geometry meshes
	var geom = geometry;
	if geom:
		if geom is MeshInstance3D and geom.mesh:
			source_geo.add_mesh(geom.mesh, geom.global_transform);
		else:
			for child in geom.get_children():
				if child is MeshInstance3D and child.mesh:
					source_geo.add_mesh(child.mesh, child.global_transform);

	# Add stored collision data
	var collision_data: Array = _load_collision_data();
	for entry in collision_data:
		var shape: Shape3D = entry.shape;
		if shape is ConcavePolygonShape3D:
			source_geo.add_faces(shape.get_faces(), entry.transform);

	# Add prop_static meshes from manifest
	var manifest_path: String = get_meta("prop_visuals_path", "");
	if not manifest_path.is_empty() and ResourceLoader.exists(manifest_path):
		var manifest_res = ResourceLoader.load(manifest_path);
		if manifest_res and manifest_res is Resource:
			var entries: Array = manifest_res.get_meta("entries", []);
			var nav_mesh_cache := {};
			for entry in entries:
				var model_key: String = entry.model;
				if not nav_mesh_cache.has(model_key):
					var model_path = VMFUtils.normalize_path(VMFConfig.models.target_folder + "/" + model_key);
					if ResourceLoader.exists(model_path):
						var model_scene: PackedScene = ResourceLoader.load(model_path) as PackedScene;
						if model_scene:
							var temp = model_scene.instantiate();
							if temp and temp is MeshInstance3D:
								nav_mesh_cache[model_key] = temp.mesh;
								temp.free();
							else:
								if temp: temp.free()
								nav_mesh_cache[model_key] = null;
						else:
							nav_mesh_cache[model_key] = null;
					else:
						nav_mesh_cache[model_key] = null;

				var mesh: Mesh = nav_mesh_cache[model_key];
				if not mesh: continue;

				var t: Transform3D = entry.transform;
				var ms: float = entry.model_scale;
				t.basis = t.basis.scaled(Vector3.ONE * ms * ms);
				source_geo.add_mesh(mesh, t);

	if not source_geo.has_data():
		print("[VMF] Navmesh bake: no source geometry found");
		return;

	# Get total bounds and compute dynamic tile count
	var bounds: AABB = source_geo.get_bounds();
	var tiles_x: int = max(1, int(ceil(bounds.size.x / NAVMESH_TILE_SIZE)));
	var tiles_z: int = max(1, int(ceil(bounds.size.z / NAVMESH_TILE_SIZE)));
	var tile_size_x: float = bounds.size.x / tiles_x;
	var tile_size_z: float = bounds.size.z / tiles_z;
	var total_tiles: int = tiles_x * tiles_z;

	print("[VMF] Navmesh bake: bounds=", bounds, " tiles=", tiles_x, "x", tiles_z, " (", total_tiles, " total)");

	# Create parent node for all navmesh tiles
	var nav_container := Node3D.new();
	nav_container.name = "NavigationMesh";
	add_child(nav_container);
	nav_container.set_owner(_owner);

	# Bake each tile
	var baked := 0;

	for tx in range(tiles_x):
		for tz in range(tiles_z):
			var tile_pos := Vector3(
				bounds.position.x + tx * tile_size_x,
				bounds.position.y,
				bounds.position.z + tz * tile_size_z
			);
			var nav := NavigationMesh.new();
			nav.cell_size = 0.25;
			nav.cell_height = 0.25;
			nav.agent_radius = 0.1;
			nav.agent_height = 1.44;
			nav.agent_max_climb = 0.36;
			nav.border_size = 0.5;
			nav.edge_max_error = 1.0;

			# Expand tile AABB by border_size so adjacent tiles overlap and connect
			var tile_aabb := AABB(tile_pos, Vector3(tile_size_x, bounds.size.y, tile_size_z));
			tile_aabb = tile_aabb.grow(nav.border_size);
			nav.filter_baking_aabb = tile_aabb;

			var navreg := NavigationRegion3D.new();
			navreg.name = "tile_%d_%d" % [tx, tz];
			navreg.navigation_mesh = nav;

			nav_container.add_child(navreg);
			navreg.set_owner(_owner);

			NavigationServer3D.bake_from_source_geometry_data(nav, source_geo);
			baked += 1;
			print("[VMF] Navmesh bake: tile %d/%d done" % [baked, total_tiles]);

func clear_scene_groups():
	var tree = get_tree();
	var groups := get_tree().edited_scene_root.get_groups() if tree else self.get_groups();
	for group in groups:
		var nodes := get_tree().get_nodes_in_group(group);
		for node in nodes:
			node.remove_from_group(group);

func reimport_geometry() -> void:
	VMFConfig.load_config();
	read_vmf();

	VMFResourceManager.init_vpk_stack();
	VMFResourceManager.import_materials(vmf_structure, is_runtime);
	VMFResourceManager.free_vpk_stack();
	await VMFResourceManager.for_resource_import();
	import_geometry();

func generate_detail_props(geometry_mesh: MeshInstance3D) -> void:
	var detail_props := VMFDetailProps.generate(geometry_mesh.mesh);
	if detail_props.size() == 0: return;

	var detail_node := Node3D.new();

	detail_node.name = "DetailProps";
	detail_node.set_display_folded(true);
	geometry_mesh.add_child(detail_node);
	detail_node.set_owner(_owner);

	for prop in detail_props:
		var mmi := MultiMeshInstance3D.new();
		mmi.multimesh = prop;
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if prop.get_meta("cast_shadows", true) \
			else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;

		detail_node.add_child(mmi);
		mmi.set_owner(_owner);

func generate_shadow_mesh(raw_geometry_mesh: ArrayMesh) -> void:
	var shadow_mesh := VMFTool.generate_shadow_mesh(raw_geometry_mesh);
	var shadow_mesh_instance := MeshInstance3D.new();
	shadow_mesh_instance.name = "ShadowMesh";
	shadow_mesh_instance.mesh = shadow_mesh;
	shadow_mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY;
	geometry.add_child(shadow_mesh_instance);
	shadow_mesh_instance.set_owner(_owner);

func unwrap_lightmap(geometry_mesh: MeshInstance3D) -> void:
	var texel_size = VMFConfig.import.lightmap_texel_size;
	if VMFConfig.import.generate_lightmap_uv2 and not is_runtime:
		geometry_mesh.mesh.lightmap_unwrap(geometry_mesh.global_transform, texel_size);

## Merges func_detail brush solids into the world geometry solids array.
## func_detail is just detailed world geometry — no runtime behavior, safe to merge.
func _merge_func_detail_solids() -> void:
	for ent in vmf_structure.entities:
		if ent.classname != "func_detail": continue;
		if not "solid" in ent.data: continue;
		var raw_solids = ent.data.solid if ent.data.solid is Array else [ent.data.solid];
		for raw_solid in raw_solids:
			vmf_structure.solids.append(VMFSolid.new(raw_solid));

func import_geometry() -> void:
	if geometry: geometry.free();

	# Merge func_detail solids into world geometry (same mesh + collision)
	_merge_func_detail_solids();

	var result = VMFTool.create_mesh(vmf_structure, Vector3.ZERO, remove_merged_faces);
	if not result: return;

	# Handle single mesh or array of meshes (split at 256 surface limit)
	var mesh_list: Array[ArrayMesh] = [];
	if result is ArrayMesh:
		mesh_list.append(result);
	elif result is Array:
		mesh_list.assign(result);

	# Create parent Geometry node
	var geom_parent := Node3D.new();
	geom_parent.name = "Geometry";
	geom_parent.set_display_folded(true);
	add_child(geom_parent);
	geom_parent.set_owner(_owner);

	var first_mesh_instance: MeshInstance3D = null;

	for i in range(mesh_list.size()):
		var geometry_mesh := MeshInstance3D.new();
		geometry_mesh.name = "mesh_%d" % i if mesh_list.size() > 1 else "mesh";
		geometry_mesh.mesh = mesh_list[i];

		if double_sided_shadow_cast:
			geometry_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_DOUBLE_SIDED;

		geom_parent.add_child(geometry_mesh);
		geometry_mesh.set_owner(_owner);

		VMFTool.generate_collisions(geometry_mesh, default_physics_mask);
		cleanup_geometry(geometry_mesh);
		unwrap_lightmap(geometry_mesh);

		if i == 0:
			first_mesh_instance = geometry_mesh;

	if first_mesh_instance:
		save_collision_file();
		generate_navmesh(geom_parent);
		generate_shadow_mesh(first_mesh_instance.mesh);
		generate_detail_props(first_mesh_instance);
		save_geometry_file(first_mesh_instance);

func generate_navmesh(geometry_node: Node3D):
	if not VMFConfig.import.use_navigation_mesh: return;
	if get_meta("instance", false): return;

	var navreg := NavigationRegion3D.new();

	var navmesh_preset := VMFConfig.import.navigation_mesh_preset;

	if navmesh_preset == "":
		navreg.navigation_mesh = NavigationMesh.new();

	if ResourceLoader.exists(navmesh_preset):
		var res := load(navmesh_preset);

		if res is not NavigationMesh:
			VMFLogger.warn("Navigation mesh preset \"%s\" is not a NavigationMesh resource. Falling back to default." % navmesh_preset);
			navreg.navigation_mesh = NavigationMesh.new();
		else:
			navreg.navigation_mesh = load(navmesh_preset);
	else:
		VMFLogger.warn("Navigation mesh preset \"%s\" is not found. Falling back to default." % navmesh_preset);
		navreg.navigation_mesh = NavigationMesh.new();

	navreg.name = "NavigationMesh";

	add_child(navreg);
	navreg.set_owner(_owner);
	geometry_node.reparent(navreg);

	navreg.bake_navigation_mesh.call_deferred();

func cleanup_geometry(target_mesh_instance: MeshInstance3D) -> void:
	target_mesh_instance.mesh = VMFTool.cleanup_mesh(target_mesh_instance.mesh);

func save_geometry_file(target_mesh_instance: MeshInstance3D) -> void:
	var target_mesh: Mesh = target_mesh_instance.mesh;
	if not save_geometry: return;
	var resource_path: String = "%s/%s_import.mesh" % [VMFConfig.import.geometry_folder, _vmf_identifer()];
	
	if not DirAccess.dir_exists_absolute(resource_path.get_base_dir()):
		DirAccess.make_dir_recursive_absolute(resource_path.get_base_dir());
	
	var err := ResourceSaver.save(target_mesh, resource_path, ResourceSaver.FLAG_COMPRESS);
	if err:
		VMFLogger.error("Failed to save geometry resource: %s" % err);
		return;
	
	target_mesh.take_over_path(resource_path);
	target_mesh_instance.mesh = load(resource_path);

func save_collision_file() -> void:
	if save_collision == false: return;
	var geom = geometry;
	if not geom: return;

	# Find all StaticBody3D nodes under Geometry (may be nested under MeshInstance3D children)
	var bodies: Array[StaticBody3D] = [];
	var stack: Array[Node] = [geom];
	while not stack.is_empty():
		var node = stack.pop_back();
		if node is StaticBody3D:
			bodies.append(node);
		for child in node.get_children():
			stack.append(child);

	for body in bodies:
		var collision = body.get_node_or_null("collision");
		if not collision or not collision.shape: continue;
		var shape = collision.shape;
		var save_path := "%s/%s_collision_%s.res" % [VMFConfig.import.geometry_folder, _vmf_identifer(), body.name];

		if not DirAccess.dir_exists_absolute(save_path.get_base_dir()):
			DirAccess.make_dir_recursive_absolute(save_path.get_base_dir());

		var error := ResourceSaver.save(shape, save_path, ResourceSaver.FLAG_COMPRESS);

		if error:
			VMFLogger.error("Failed to save collision resource: %s" % error);
			continue;

		shape.take_over_path(save_path);
		collision.shape = load(save_path);

func _vmf_identifer() -> String:
	return vmf.split('/')[-1].replace('.', '_');

func clear_structure() -> void:
	vmf_structure = null;
	for n in get_children():
		remove_child(n);
		n.queue_free();

func read_vmf() -> void:
	VMFLogger.measure_call(5000, "VMF reading took %f ms", func():
		vmf_structure = VMFStructure.new(VDFParser.parse(vmf))
	);

func get_entity_scene(clazz: String):
	var res_path: String = (VMFConfig.import.entities_folder + '/' + clazz + '.tscn').replace('//', '/').replace('res:/', 'res://');

	# NOTE: In case when custom entity wasn't found - use aliases from config
	if not ResourceLoader.exists(res_path):
		res_path = VMFConfig.import.entity_aliases.get(clazz, "");

	# NOTE: In case when custom entity wasn't found - use plugin's entities list
	if not ResourceLoader.exists(res_path):
		res_path = 'res://addons/godotvmf/entities/' + clazz + '.tscn';

	if not ResourceLoader.exists(res_path):
		return null;

	return load(res_path);

func push_entity_to_group(classname: String, target_node: Node):
	var group_name = classname.split('_')[0] + 's';
	var group = entities.get_node_or_null(group_name);

	if not group:
		group = Node3D.new();
		group.name = group_name;
		entities.add_child(group);
		group.set_owner(_owner);
		group.set_display_folded(true);
	
	group.add_child(target_node);
	target_node.set_owner(_owner);
	target_node.set_display_folded(true);

func reset_entities_node():
	if entities: entities.free();

	var enode = Node3D.new();
	enode.name = "Entities";
	add_child(enode);
	enode.set_owner(_owner);

func reimport_entities():
	read_vmf();

	VMFResourceManager.init_vpk_stack();
	VMFResourceManager.import_materials(vmf_structure, is_runtime);
	VMFResourceManager.import_models(vmf_structure);
	VMFResourceManager.free_vpk_stack();
	await VMFResourceManager.for_resource_import();
	import_entities();

## Wipes import-time entity data, preserving only runtime-essential keys
static func _wipe_entity_import_data(node: VMFEntityNode) -> void:
	var preserved := {};
	for key in RUNTIME_KEYS:
		if key in node.entity:
			preserved[key] = node.entity[key];
	node.entity = preserved;
	node.reference = null;

## Ensures model resources are loaded and cached. Returns resources dict or null.
## NOTE: No longer used during import — model loading is deferred to _create_runtime_visuals().
## Kept for potential use by other code paths.
#func _ensure_model_resources(model_key: String) -> Variant:
#	var resources = VMFCache.get_model_resources(model_key);
#	if resources: return resources;
#	var model_path = VMFUtils.normalize_path(VMFConfig.models.target_folder + "/" + model_key);
#	var model_scene: PackedScene = VMFCache.get_cached(model_key);
#	if not model_scene:
#		if not ResourceLoader.exists(model_path):
#			if not VMFCache.is_file_logged(model_key):
#				VMFLogger.warn("Model not found: " + model_path);
#				VMFCache.add_logged_file(model_key);
#			return null;
#		model_scene = ResourceLoader.load(model_path) as PackedScene;
#		VMFCache.add_cached(model_key, model_scene);
#		if not model_scene: return null;
#	resources = prop_studio._extract_and_cache_resources(model_key, model_scene);
#	return resources if resources and not resources.is_empty() else null;

## Collects prop_static entity data and saves it as a lightweight manifest.
## No model loading, no MultiMesh building — all deferred to _ready() via RenderingServer.
## Returns a set of entity IDs that should be skipped in the normal entity loop.
func _preprocess_prop_statics() -> Dictionary:
	var processed_ids := {};
	var geom = geometry;
	if not geom: return processed_ids;

	var import_scale = VMFConfig.import.scale;
	var entries: Array = [];

	for ent in vmf_structure.entities:
		if ent.classname != "prop_static": continue;
		var model_path_val = ent.data.get("model", "");
		if model_path_val.is_empty(): continue;

		entries.append({
			"model": model_path_val,
			"skin": int(ent.data.get("skin", 0)),
			"transform": VMFEntityNode.get_entity_transform(ent),
			"model_scale": float(ent.data.get("modelscale", 1.0)),
			"fade_min": float(ent.data.get("fademindist", 0.0)) * import_scale,
			"fade_max": float(ent.data.get("fademaxdist", 0.0)) * import_scale,
			"ssf": int(ent.data.get("screenspacefade", 0)) == 1,
		});

		processed_ids[ent.id] = true;

	# Save raw entity data to external file — no model loading, no mesh building
	if not entries.is_empty():
		_save_visual_manifest(entries);

	return processed_ids;

## NOTE: _chunk_instances, _create_multimesh_prop_static, _collect_prop_collision_data
## are no longer used — MultiMesh building + collision is deferred to _create_runtime_visuals().

func import_entities() -> void:
	reset_entities_node();

	## Pre-process prop_statics into MultiMesh groups (avoids instantiating individual nodes)
	var processed_prop_statics := await _preprocess_prop_statics();

	for ent in vmf_structure.entities:
		if ent.id in processed_prop_statics: continue;
		if ent.classname == "func_detail": continue;  # merged into world geometry

		ent.data.vmf = vmf;

		var tscn = get_entity_scene(ent.classname);
		if not tscn: continue;

		var node = tscn.instantiate(PackedScene.GEN_EDIT_STATE_MAIN_INHERITED);

		if node is VMFEntityNode:
			node.is_runtime = is_runtime;
			node.reference = ent;

		push_entity_to_group(ent.classname, node);
		set_editable_instance(node, true);

		var clazz = node.get_script();
		if clazz and "setup" in clazz: clazz.setup(ent, node);

		if not is_runtime:
			node._entity_pre_setup(ent);

			## Workaround to support deprecated method
			if node._apply_entity(ent.data) == -1:
				node._entity_setup(ent);

			## Wipe import-time entity data, preserving runtime-essential keys
			if node is VMFEntityNode:
				_wipe_entity_import_data(node);

func import_map() -> void:
	if not vmf: return;

	VMFCache.clear();
	VMFConfig.load_config();

	clear_structure();
	clear_scene_groups();

	import_progress.emit("Parsing VMF", 0, 6);
	if get_tree(): await get_tree().process_frame;
	read_vmf();

	VMFResourceManager.init_vpk_stack();

	import_progress.emit("Importing materials", 1, 6);
	VMFResourceManager.import_materials(vmf_structure, is_runtime);

	import_progress.emit("Importing models", 2, 6);
	VMFResourceManager.import_models(vmf_structure);
	VMFResourceManager.free_vpk_stack();
	await VMFResourceManager.for_resource_import();

	import_progress.emit("Building geometry", 3, 6);
	if get_tree(): await get_tree().process_frame;
	import_geometry();

	import_progress.emit("Importing entities", 4, 6);
	if get_tree(): await get_tree().process_frame;
	import_entities();

	import_progress.emit("Loading prop_statics", 5, 6);
	if get_tree(): await get_tree().process_frame;
	_save_collision_data_external();
	_create_runtime_visuals();

	import_progress.emit("Baking navigation", 5, 6);
	if get_tree(): await get_tree().process_frame;
	if bake_navigation:
		bake_navmesh_with_collisions();

	import_progress.emit("Done", 6, 6);
