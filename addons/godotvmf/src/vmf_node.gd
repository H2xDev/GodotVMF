@tool
@icon("res://addons/godotvmf/icon.svg")
class_name VMFNode extends Node3D;

## Allow the file picker to select an external file
@export var use_external_file: bool = false:
	set(val):
		use_external_file = val;
		notify_property_list_changed();

## Path to the VMF file
@export_file("*.vmf")
var vmf: String = '';

## Full import of VMF with specified options
@export_tool_button("Import map", "Callable") var import_button = import_map;

@export_category("Tweaks")

## Enable double sided shadow casting for the geometry mesh. This will make the shadows casted by the geometry to be visible from both sides of the faces.
@export var double_sided_shadow_cast: bool = false;

## Enable chunked mesh generation. This will split the geometry into smaller chunks for better performance. Increases the import time.
@export var chunked_mesh: bool = true;

## Size of one chunk. This will affect the number of chunks generated and the performance of the import.
@export_range(32.0, 1024.0, 0.01) var chunked_mesh_size: float = 256.0;

@export_category("Resource Generation")

## If true, removes merged faces from the geometry mesh. This will reduce the number of faces in the mesh and improve performance. Increases the import time
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

@export_storage var navmesh: NavigationRegion3D;
@export_storage var geometry: Node3D;

var detail_props: Node3D:
	get: return geometry.get_node_or_null("DetailProps") if geometry else null;

var entities: Node3D:
	get: return get_node_or_null("Entities");

var has_imported_resources = false;

func is_instance() -> bool:
	return get_meta("instance", false);

func _validate_property(property: Dictionary) -> void:
	if property.name == "vmf":
		property.hint = PROPERTY_HINT_GLOBAL_FILE if use_external_file else PROPERTY_HINT_FILE

func _ready() -> void:
	add_to_group("vmfnode_group");

	storage_navmesh_node();
	storage_geometry_node();

func storage_geometry_node():
	geometry = get_node_or_null("Geometry") if not navmesh else navmesh.get_node_or_null("Geometry")

func storage_navmesh_node():
	navmesh = get_node_or_null("NavigationMesh");

func get_geometry_node(clazz := MeshInstance3D) -> Node3D:
	if geometry: return geometry;

	geometry = clazz.new();
	geometry.name = "Geometry";
	if not navmesh:
		add_child(geometry);
	else:
		navmesh.add_child(geometry);

	geometry.set_owner(_owner);
	geometry.set_display_folded(true);
	return geometry;

func clear_scene_groups():
	var tree = get_tree();
	var groups: Array[StringName] = tree.edited_scene_root.get_groups() if tree else self.get_groups();
	for group in groups:
		var nodes := tree.get_nodes_in_group(group);
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

	if Engine.is_editor_hint():
		EditorInterface.mark_scene_as_unsaved();
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
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON \
			if prop.get_meta("cast_shadows", true) \
			else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;

		mmi.visibility_range_end = VMFConfig.import.detail_props_draw_distance;
		mmi.visibility_range_end_margin = VMFConfig.import.detail_props_draw_distance / 2.0;
		mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF;
		mmi.gi_mode = GeometryInstance3D.GI_MODE_DYNAMIC;

		detail_node.add_child(mmi);
		mmi.set_owner(_owner);
	
func reimport_detail_props():
	var geometry_mesh = geometry as MeshInstance3D;
	if not geometry_mesh: return;
	VMFConfig.load_config();

	if detail_props: detail_props.free();

	generate_detail_props(geometry_mesh);

	if Engine.is_editor_hint():
		EditorInterface.mark_scene_as_unsaved();

func generate_shadow_mesh(raw_geometry_mesh: ArrayMesh) -> void:
	var shadow_mesh := VMFTool.generate_shadow_mesh(raw_geometry_mesh);
	if not shadow_mesh: return;

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

func process_geometry(geometry_mesh: MeshInstance3D) -> void:
	if double_sided_shadow_cast:
		geometry_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_DOUBLE_SIDED;

	if VMFConfig.import.generate_collision: 
		VMFTool.generate_collisions(geometry_mesh, default_physics_mask);
		save_collision_file(geometry_mesh, geometry_mesh.name);

	cleanup_geometry(geometry_mesh);
	generate_detail_props(geometry_mesh);
	unwrap_lightmap(geometry_mesh);
	save_geometry_file(geometry_mesh);

func import_geometry() -> void:
	if geometry: geometry.free();
	if navmesh: navmesh.free();

	var mesh: ArrayMesh = VMFTool.create_mesh(vmf_structure, Vector3.ZERO, remove_merged_faces);
	if not mesh: return;
	
	var geometry_root: Node3D;
	generate_shadow_mesh(mesh);

	if not chunked_mesh:
		geometry_root = get_geometry_node();
		geometry_root.mesh = mesh;
		process_geometry(geometry_root);
	else:
		geometry_root = get_geometry_node(Node3D);
		var chunk_meshes := VMFTool.split_mesh_by_chunks(mesh, chunked_mesh_size);
		var chunk_id := 0;
		
		for chunk_mesh in chunk_meshes:
			var mi := MeshInstance3D.new();
			mi.name = "chunk_" + str(chunk_id);
			mi.mesh = VMFTool.generate_lods(chunk_mesh);
			mi.set_display_folded(true);
			geometry_root.add_child(mi);
			mi.set_owner(_owner);
			process_geometry(mi);
			chunk_id += 1;

	generate_navmesh(geometry_root);

func generate_navmesh(geometry_mesh: Node3D):
	if not VMFConfig.import.use_navigation_mesh: return;
	if get_meta("instance", false): return;

	navmesh = NavigationRegion3D.new();

	var navmesh_preset := VMFConfig.import.navigation_mesh_preset;

	if navmesh_preset == "":
		navmesh.navigation_mesh = NavigationMesh.new();

	if ResourceLoader.exists(navmesh_preset):
		var res := load(navmesh_preset);

		if res is not NavigationMesh:
			VMFLogger.warn("Navigation mesh preset \"%s\" is not a NavigationMesh resource. Falling back to default." % navmesh_preset);
			navmesh.navigation_mesh = NavigationMesh.new();
		else:
			navmesh.navigation_mesh = load(navmesh_preset).duplicate();
	else:
		VMFLogger.warn("Navigation mesh preset \"%s\" is not found. Falling back to default." % navmesh_preset);
		navmesh.navigation_mesh = NavigationMesh.new();

	navmesh.name = "NavigationMesh";

	add_child(navmesh);
	navmesh.set_owner(_owner);
	geometry_mesh.reparent(navmesh);

	navmesh.bake_navigation_mesh.call_deferred();

func cleanup_geometry(target_mesh_instance: MeshInstance3D) -> void:
	target_mesh_instance.mesh = VMFTool.cleanup_mesh(target_mesh_instance.mesh);

func save_geometry_file(target_mesh_instance: MeshInstance3D, postfix: String = "") -> void:
	var target_mesh: Mesh = target_mesh_instance.mesh;
	if not save_geometry: return;
	var resource_path: String = "%s/%s%s_import.mesh" % [VMFConfig.import.geometry_folder, _vmf_identifer(), postfix];
	
	if not DirAccess.dir_exists_absolute(resource_path.get_base_dir()):
		DirAccess.make_dir_recursive_absolute(resource_path.get_base_dir());
	
	var err := ResourceSaver.save(target_mesh, resource_path, ResourceSaver.FLAG_COMPRESS);
	if err:
		VMFLogger.error("Failed to save geometry resource: %s" % err);
		return;
	
	target_mesh.take_over_path(resource_path);
	target_mesh_instance.mesh = load(resource_path);

func save_collision_file(mesh_instance: MeshInstance3D = geometry, postfix = "") -> void:
	if save_collision == false: return;
	var collisions := mesh_instance.get_children();

	for body in collisions:
		if body is not StaticBody3D: continue;

		var collision := body.get_node('collision');
		var shape = collision.shape;
		var save_path := "%s/%s%s_collision_%s.res" % [VMFConfig.import.geometry_folder, _vmf_identifer(), postfix, body.name];

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
	VMFResourceManager.import_materials(vmf_structure, is_runtime);
	VMFResourceManager.import_models(vmf_structure);
	VMFResourceManager.free_vpk_stack();

	await VMFResourceManager.for_resource_import();

	import_entities();

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
	read_vmf();

	VMFResourceManager.init_vpk_stack();
	VMFResourceManager.import_materials(vmf_structure, is_runtime);
	VMFResourceManager.import_models(vmf_structure);
	VMFResourceManager.free_vpk_stack();

	await VMFResourceManager.for_resource_import();

	import_geometry();
	import_entities();
