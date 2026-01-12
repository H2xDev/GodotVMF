@tool
@icon("res://addons/godotvmf/icon.svg")
class_name VMFNode extends Node3D;

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
		import_map();
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

var editor_interface:
	get: return Engine.get_singleton("EditorInterface");

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

func _validate_property(property: Dictionary) -> void:
	if property.name == "vmf":
		property.hint = PROPERTY_HINT_GLOBAL_FILE if use_external_file else PROPERTY_HINT_FILE

func _ready() -> void:
	add_to_group("vmfnode_group");

func clear_scene_groups():
	var groups := get_tree().edited_scene_root.get_groups();
	for group in groups:
		var nodes := get_tree().get_nodes_in_group(group);
		for node in nodes:
			node.remove_from_group(group);

func reimport_geometry() -> void:
	VMFConfig.load_config();
	read_vmf();
	VMFResourceManager.import_materials(vmf_structure, is_runtime);

	await VMFResourceManager.for_resource_import();

	import_geometry();

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
	var texel_size = VMFConfig.import.lightmap_texel_size;

	geometry_mesh.mesh = mesh;

	VMFTool.generate_collisions(geometry_mesh, default_physics_mask);
	save_collision_file();

	if not get_meta("instance", false):
		generate_navmesh(geometry_mesh);

	geometry_mesh.mesh = VMFTool.cleanup_mesh(geometry_mesh.mesh);

	if VMFConfig.import.generate_lightmap_uv2 and not is_runtime:
		geometry_mesh.mesh.lightmap_unwrap(geometry_mesh.global_transform, texel_size);

	geometry_mesh.mesh = save_geometry_file(geometry_mesh.mesh);

func generate_navmesh(geometry_mesh: MeshInstance3D):
	if not VMFConfig.import.use_navigation_mesh: return;

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

func save_geometry_file(target_mesh: Mesh):
	if not save_geometry: return target_mesh;
	var resource_path: String = "%s/%s_import.mesh" % [VMFConfig.import.geometry_folder, _vmf_identifer()];
	
	if not DirAccess.dir_exists_absolute(resource_path.get_base_dir()):
		DirAccess.make_dir_recursive_absolute(resource_path.get_base_dir());
	
	var err := ResourceSaver.save(target_mesh, resource_path, ResourceSaver.FLAG_COMPRESS);
	if err:
		VMFLogger.error("Failed to save geometry resource: %s" % err);
		return;
	
	target_mesh.take_over_path(resource_path);
	return target_mesh;

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
	import_entities();

func import_entities() -> void:
	reset_entities_node();

	for ent in vmf_structure.entities:
		ent.vmf = vmf;

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

	VMFResourceManager.import_materials(vmf_structure, is_runtime);
	VMFResourceManager.import_models(vmf_structure);

	await VMFResourceManager.for_resource_import();

	import_geometry();
	import_entities();
