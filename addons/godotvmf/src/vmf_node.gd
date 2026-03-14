@tool
@icon("res://addons/godotvmf/icon.svg")
class_name VMFNode extends Node3D;

## Emitted during batched import to report progress. Connect to update UI.
signal import_progress(phase: String, current: int, total: int)

## Batch sizes for chunked import — controls how many items are processed per frame yield.
const MATERIAL_BATCH_SIZE := 20
const MODEL_BATCH_SIZE := 5
const BRUSH_BATCH_SIZE := 50
const SURFACE_BATCH_SIZE := 10
const ENTITY_BATCH_SIZE := 10

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

var navmesh: NavigationRegion3D:
	get: return get_node_or_null("NavigationMesh");

var has_imported_resources = false;

## Async wrapper for property setter (which cannot use await)
func _do_import() -> void:
	await import_map();

## Returns true if this node is in the scene tree and can yield frames.
## Standalone nodes (e.g. created by VMFInstanceManager) cannot yield.
func _can_yield() -> bool:
	return get_tree() != null;

## Yields one frame and emits progress. Skips yield if not in scene tree.
func _yield_progress(phase: String, current: int, total: int) -> void:
	import_progress.emit(phase, current, total);
	if _can_yield():
		await get_tree().process_frame;

func _validate_property(property: Dictionary) -> void:
	if property.name == "vmf":
		property.hint = PROPERTY_HINT_GLOBAL_FILE if use_external_file else PROPERTY_HINT_FILE

func _ready() -> void:
	add_to_group("vmfnode_group");

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

	if is_runtime or not _can_yield():
		VMFResourceManager.import_materials(vmf_structure, is_runtime);
		VMFResourceManager.free_vpk_stack();
		await VMFResourceManager.for_resource_import();
		import_geometry();
	else:
		await _import_materials_batched();
		VMFResourceManager.free_vpk_stack();
		await VMFResourceManager.for_resource_import();
		await _import_geometry_batched();

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

func import_geometry() -> void:
	if navmesh: navmesh.free();
	if geometry: geometry.free();

	var mesh: ArrayMesh = VMFTool.create_mesh(vmf_structure, Vector3.ZERO, remove_merged_faces);
	if not mesh: return;

	var geometry_mesh := MeshInstance3D.new()
	geometry_mesh.name = "Geometry";
	geometry_mesh.set_display_folded(true);
	
	if double_sided_shadow_cast:
		geometry_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_DOUBLE_SIDED;
	
	add_child(geometry_mesh);
	geometry_mesh.set_owner(_owner);

	var transform = geometry_mesh.global_transform;
	geometry_mesh.mesh = mesh;

	VMFTool.generate_collisions(geometry_mesh, default_physics_mask);
	save_collision_file();
	generate_navmesh(geometry_mesh);
	generate_shadow_mesh(geometry_mesh.mesh);
	cleanup_geometry(geometry_mesh);
	generate_detail_props(geometry_mesh);
	unwrap_lightmap(geometry_mesh);
	save_geometry_file(geometry_mesh);

func generate_navmesh(geometry_mesh: MeshInstance3D):
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
	geometry_mesh.reparent(navreg);

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

	var collisions = $Geometry.get_children() as Array[StaticBody3D];

	for body in collisions:
		var collision := body.get_node('collision');
		var shape = collision.shape;
		var save_path := "%s/%s_collision_%s.res" % [VMFConfig.import.geometry_folder, _vmf_identifer(), body.name];

		if not DirAccess.dir_exists_absolute(save_path.get_base_dir()):
			DirAccess.make_dir_recursive_absolute(save_path.get_base_dir());

		var error := ResourceSaver.save(collision.shape, save_path, ResourceSaver.FLAG_COMPRESS);

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

	if is_runtime or not _can_yield():
		VMFResourceManager.import_materials(vmf_structure, is_runtime);
		VMFResourceManager.import_models(vmf_structure);
		VMFResourceManager.free_vpk_stack();
		await VMFResourceManager.for_resource_import();
		import_entities();
	else:
		await _import_materials_batched();
		await _import_models_batched();
		VMFResourceManager.free_vpk_stack();
		await VMFResourceManager.for_resource_import();
		await _import_entities_batched();

func import_entities() -> void:
	reset_entities_node();

	for ent in vmf_structure.entities:
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

func import_map() -> void:
	if not vmf: return;

	VMFCache.clear();
	VMFConfig.load_config();

	clear_structure();
	clear_scene_groups();

	await _yield_progress("Parsing VMF", 0, 1);
	read_vmf();

	VMFResourceManager.init_vpk_stack();

	if is_runtime or not _can_yield():
		# Non-batched path for runtime and standalone nodes (no yields, no risk of broken scripts)
		VMFResourceManager.import_materials(vmf_structure, is_runtime);
		VMFResourceManager.import_models(vmf_structure);
		VMFResourceManager.free_vpk_stack();
		await VMFResourceManager.for_resource_import();
		import_geometry();
		import_entities();
	else:
		# Batched path for editor (yields between chunks to keep editor responsive)
		await _import_materials_batched();
		await _import_models_batched();
		VMFResourceManager.free_vpk_stack();
		await VMFResourceManager.for_resource_import();
		await _import_geometry_batched();
		await _import_entities_batched();

	import_progress.emit("Done", 1, 1);

#region Batched import methods (editor only — yields between chunks)

## Imports materials in batches, yielding between chunks to prevent editor freeze.
## Uses VMFResourceManager for all import logic.
func _import_materials_batched() -> void:
	if VMFConfig.materials.import_mode == VMFConfig.MaterialsConfig.ImportMode.USE_EXISTING:
		return;

	var editor_interface = VMFResourceManager.get_editor_interface();
	if not editor_interface: return;

	var list := VMFResourceManager.collect_material_list(vmf_structure);
	var total := list.size();

	for i in range(total):
		VMFResourceManager.import_textures(list[i]);
		if i % MATERIAL_BATCH_SIZE == 0 and i > 0:
			await _yield_progress("Importing textures", i, total);

	for i in range(total):
		VMFResourceManager.import_material(list[i]);
		if i % MATERIAL_BATCH_SIZE == 0 and i > 0:
			await _yield_progress("Importing materials", i, total);

## Imports models in batches, yielding between chunks to prevent editor freeze.
## Uses VMFResourceManager.import_model_for_entity() for per-entity import logic.
func _import_models_batched() -> void:
	if not VMFConfig.models.import: return;
	if vmf_structure.entities.size() == 0: return;

	var entities_list = vmf_structure.entities;
	var total := entities_list.size();
	var batch_count := 0;

	for i in range(total):
		var did_import := VMFResourceManager.import_model_for_entity(entities_list[i]);

		if did_import:
			batch_count += 1;
			if batch_count % MODEL_BATCH_SIZE == 0:
				await _yield_progress("Importing models", batch_count, total);

## Imports geometry in batches, yielding between chunks to prevent editor freeze
func _import_geometry_batched() -> void:
	if navmesh: navmesh.free();
	if geometry: geometry.free();

	var brushes := vmf_structure.solids;
	if brushes.size() == 0: return;

	var import_scale := VMFConfig.import.scale;
	var offset := Vector3.ZERO;

	# Phase 1: Remove merged faces in batches
	if remove_merged_faces:
		var total := brushes.size();
		for i in range(total):
			VMFTool.remove_merged_faces(brushes[i], brushes);
			if i % BRUSH_BATCH_SIZE == 0 and i > 0:
				await _yield_progress("Optimizing faces", i, total);

	# Phase 2: Collect sides by material
	var material_sides: Dictionary = {};
	for brush in brushes:
		for side: VMFSide in brush.sides:
			var material_key: String = side.material.to_upper();
			if not material_key in material_sides:
				material_sides[material_key] = [];
			material_sides[material_key].append(side);

	# Phase 3: Build mesh surfaces in batches
	var mesh := ArrayMesh.new();
	var keys := material_sides.keys();
	var total_surfaces := keys.size();

	for i in range(total_surfaces):
		VMFTool.build_surface(mesh, material_sides[keys[i]], import_scale, offset, remove_merged_faces);
		if i % SURFACE_BATCH_SIZE == 0 and i > 0:
			await _yield_progress("Building surfaces", i, total_surfaces);

	if mesh.get_surface_count() == 0: return;

	# Phase 4: Post-processing (same as import_geometry)
	var geometry_mesh := MeshInstance3D.new();
	geometry_mesh.name = "Geometry";
	geometry_mesh.set_display_folded(true);

	if double_sided_shadow_cast:
		geometry_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_DOUBLE_SIDED;

	add_child(geometry_mesh);
	geometry_mesh.set_owner(_owner);

	var transform = geometry_mesh.global_transform;
	geometry_mesh.mesh = mesh;

	await _yield_progress("Generating collisions", 0, 1);
	VMFTool.generate_collisions(geometry_mesh, default_physics_mask);
	save_collision_file();
	generate_navmesh(geometry_mesh);
	generate_shadow_mesh(geometry_mesh.mesh);
	cleanup_geometry(geometry_mesh);
	generate_detail_props(geometry_mesh);
	unwrap_lightmap(geometry_mesh);
	save_geometry_file(geometry_mesh);

## Imports entities in batches, yielding between chunks to prevent editor freeze
func _import_entities_batched() -> void:
	reset_entities_node();

	var total := vmf_structure.entities.size();

	for i in range(total):
		var ent = vmf_structure.entities[i];
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

		if i % ENTITY_BATCH_SIZE == 0 and i > 0:
			await _yield_progress("Importing entities", i, total);

#endregion
