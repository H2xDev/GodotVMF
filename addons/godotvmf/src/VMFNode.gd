@tool
@icon("res://addons/godotvmf/icon.svg")
class_name VMFNode extends Node3D;

enum MaterialImportMode {
	USE_EXISTING,
	IMPORT_FROM_MOD_FOLDER,
}

const MATERIAL_KEYS_TO_IMPORT = [
	"$basetexture",
	"$basetexture2",
	"$bumpmap",
	"$bumpmap2",
	"$selfillummask",
];

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

@export_category("Resource Generation")
## Save the resulting geometry mesh as a resource (saves to the geometryFolder in vmf.config.json)
@export var save_geometry: bool = true;

## Save the resulting collision shape as a resource (saves to the geometryFolder in vmf.config.json)
@export var save_collision: bool = true;

## Set this to true before import if you're goint to use this node in runtime
var is_runtime = false;

var _structure: Dictionary = {};
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

func import_geometry(_reimport := false) -> void:
	if _reimport:
		VMFConfig.load_config();
		_structure = {};
		read_vmf();
		import_materials();
		await for_resource_import();

	if navmesh: navmesh.free();
	if geometry: geometry.free();

	var mesh: ArrayMesh = VMFTool.create_mesh(_structure);
	if not mesh: return;

	var geometry_mesh := MeshInstance3D.new()
	geometry_mesh.name = "Geometry";
	geometry_mesh.set_display_folded(true);
	
	add_child(geometry_mesh);
	geometry_mesh.set_owner(_owner);

	var transform = geometry_mesh.global_transform;
	var texel_size = VMFConfig.import.lightmap_texel_size;

	geometry_mesh.mesh = mesh;

	VMFTool.generate_collisions(geometry_mesh);
	save_collision_file();

	if not get_meta("instance", false):
		generate_navmesh(geometry_mesh);

	geometry_mesh.mesh = VMFTool.cleanup_mesh(geometry_mesh.mesh);

	if VMFConfig.import.generate_lightmap_uv2 and not is_runtime:
		geometry_mesh.mesh.lightmap_unwrap(geometry_mesh.global_transform, texel_size);

	geometry_mesh.mesh = save_geometry_file(geometry_mesh.mesh);

func generate_navmesh(geometry_mesh: MeshInstance3D):
	if not VMFConfig.import.use_navigation_mesh: return;

	var navmesh_preset_path = VMFConfig.import.navigation_mesh_preset;
	var navmesh_preset = null;

	if ResourceLoader.exists(navmesh_preset_path):
		navmesh_preset = ResourceLoader.load(navmesh_preset_path);
		assert(navmesh_preset is NavigationMesh, "vmf.config.json -> import.navigationMeshPreset has wrong type. Expected NavigationMesh, got %s" % navmesh_preset.get_class());

	var navreg := NavigationRegion3D.new();
	navreg.navigation_mesh = NavigationMesh.new() if not navmesh_preset else navmesh_preset.duplicate();
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

func import_models():
	if not VMFConfig.models.import: return;
	if not "entity" in _structure: return;

	for entity in _structure.entity:
		if not "model" in entity: continue;
		if entity.classname != "prop_static": continue;

		var model_path = entity.get("model", "").to_lower().get_basename();
		if not model_path: continue;

		var mdl_path = VMFUtils.normalize_path(VMFConfig.gameinfo_path + "/" + model_path + ".mdl");
		var vtx_path = VMFUtils.normalize_path(VMFConfig.gameinfo_path + "/" + model_path + ".vtx");
		var vtx_dx90_path = VMFUtils.normalize_path(VMFConfig.gameinfo_path + "/" + model_path + ".dx90.vtx");
		var vvd_path = VMFUtils.normalize_path(VMFConfig.gameinfo_path + "/" + model_path + ".vvd");
		var phy_path = VMFUtils.normalize_path(VMFConfig.gameinfo_path + "/" + model_path + ".phy");
		var target_path = VMFUtils.normalize_path(VMFConfig.models.target_folder + "/" + model_path);

		if ResourceLoader.exists(target_path + ".mdl"): continue;

		if not FileAccess.file_exists(mdl_path): continue;
		if not FileAccess.file_exists(vtx_path): vtx_path = vtx_dx90_path;
		if not FileAccess.file_exists(vtx_path): continue;
		if not FileAccess.file_exists(vvd_path): continue;

		var model_materials = MDLReader.new(mdl_path).get_possible_material_paths();

		for material_path in model_materials:
			import_textures(material_path);
			import_material(material_path);

		DirAccess.make_dir_recursive_absolute(target_path.get_base_dir());
		DirAccess.copy_absolute(vtx_path, target_path + '.dx90.vtx');
		DirAccess.copy_absolute(vvd_path, target_path + ".vvd");
		if FileAccess.file_exists(phy_path): DirAccess.copy_absolute(phy_path, target_path + ".phy");
		DirAccess.copy_absolute(mdl_path, target_path + ".mdl");

		has_imported_resources = true;


func import_materials() -> void:
	if VMFConfig.materials.import_mode == VMFConfig.MaterialsConfig.ImportMode.USE_EXISTING:
		return;

	var list: Array[String] = [];
	var ignore_list: Array[String];
	ignore_list.assign(VMFConfig.materials.ignore);
	
	var elapsed_time := Time.get_ticks_msec();

	if "solid" in _structure.world:
		for brush in _structure.world.solid:
			for side in brush.side:
				var isIgnored = ignore_list.any(func(rx: String) -> bool: return side.material.match(rx));
				if isIgnored: continue;

				if not list.has(side.material):
					list.append(side.material);

	if "entity" in _structure:
		for entity in _structure.entity:
			if not "solid" in entity:
				continue;

			entity.solid = [entity.solid] if entity.solid is Dictionary else entity.solid;

			for brush in entity.solid:
				if not brush is Dictionary: continue;

				for side in brush.side:
					var isIgnored = ignore_list.any(func(rx): return side.material.match(rx));
					if isIgnored: continue;

					if not list.has(side.material):
						list.append(side.material);

	if not is_runtime and editor_interface:
		var fs = editor_interface.get_resource_filesystem() if Engine.is_editor_hint() else null;

		for material in list:
			import_textures(material);

		for material in list:
			import_material(material);

	elapsed_time = Time.get_ticks_msec() - elapsed_time;

	if elapsed_time > 1000:
		VMFLogger.warn("Imported " + str(len(list)) + " materials in " + str(elapsed_time) + "ms");

func import_material(material: String):
	material = material.to_lower();

	var vmt_path = VMFUtils.normalize_path(VMFConfig.gameinfo_path + "/materials/" + material + ".vmt");
	var target_path = VMFUtils.normalize_path(VMFConfig.materials.target_folder + "/" + material + ".vmt");

	if ResourceLoader.exists(target_path): return;
	if not FileAccess.file_exists(vmt_path): return;

	DirAccess.make_dir_recursive_absolute(target_path.get_base_dir());
	var has_error = DirAccess.copy_absolute(vmt_path, target_path);

	if not has_error: has_imported_resources = true;

func import_textures(material: String):
	material = material.to_lower();

	var target_path = VMFUtils.normalize_path(VMFConfig.gameinfo_path + "/materials/" + material + ".vmt");
	if not FileAccess.file_exists(target_path): 
		VMFLogger.error("Material not found: " + target_path);
		return;

	var details  = VDFParser.parse(target_path, true).values()[0];

	# NOTE: CS:GO/L4D
	if "insert" in details:
		details.merge(details["insert"]);

	for key in MATERIAL_KEYS_TO_IMPORT:
		if key not in details: continue;
		var vtf_path = VMFUtils.normalize_path(VMFConfig.gameinfo_path + "/materials/" + details[key].to_lower() + ".vtf");
		var target_vtf_path = VMFUtils.normalize_path(VMFConfig.materials.target_folder + "/" + details[key].to_lower() + ".vtf");

		if not FileAccess.file_exists(vtf_path): continue;
		if ResourceLoader.exists(target_vtf_path): continue;

		DirAccess.make_dir_recursive_absolute(target_vtf_path.get_base_dir());
		var has_error = DirAccess.copy_absolute(vtf_path, target_vtf_path);

		if not has_error: 
			has_imported_resources = true;
			continue;
		VMFLogger.error("Failed to copy texture: " + str(has_error));

func clear_structure() -> void:
	_structure = {};

	for n in get_children():
		remove_child(n);
		n.queue_free();

func read_vmf() -> void:
	var t = Time.get_ticks_msec();
	_structure = VDFParser.parse(vmf);

	## NOTE: In case if "entity" or "solid" fields are Dictionary,
	##		 we need to convert them to Array

	if "entity" in _structure:
		_structure.entity = [_structure.entity] if not _structure.entity is Array else _structure.entity;

	if "solid" in _structure.world:
		_structure.world.solid = [_structure.world.solid] if not _structure.world.solid is Array else _structure.world.solid;

	t = Time.get_ticks_msec() - t;
	if t > 1000:
		VMFLogger.warn("Read vmf in " + str(t) + "ms");

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

func import_entities(is_reimport := false) -> void:
	var elapsed_time := Time.get_ticks_msec();

	if is_reimport: read_vmf();
	reset_entities_node();

	if not "entity" in _structure: return;

	for ent: Dictionary in _structure.entity:
		ent = ent.duplicate(true);
		ent.vmf = vmf;

		var tscn = get_entity_scene(ent.classname);
		if not tscn: continue;

		var node = tscn.instantiate();
		if "is_runtime" in node:
			node.is_runtime = is_runtime;

		if "entity" in node:
			node.entity = ent;

		push_entity_to_group(ent.classname, node);
		set_editable_instance(node, true);

		var clazz = node.get_script();
		if clazz and "setup" in clazz: clazz.setup(ent, node);

		if not is_runtime and "_apply_entity" in node:
			node._apply_entity(ent);

	elapsed_time = Time.get_ticks_msec() - elapsed_time;

	if elapsed_time > 2000:
		VMFLogger.warn("Imported entities in " + str(elapsed_time) + "ms");

func generate_occluder(complex: bool = false):
	var mesh: MeshInstance3D = geometry
	var mesh_center = Vector3.ZERO;
	var vertices = mesh.mesh.get_faces();

	for v in vertices:
		mesh_center += v;

	mesh_center /= vertices.size();

	var occluder := OccluderInstance3D.new();

	if not complex:
		var box := BoxOccluder3D.new();

		box.size = mesh.get_aabb().size / 1.5;
		occluder.occluder = box;
		occluder.position = mesh_center;
	else:
		var box := ArrayOccluder3D.new();
		var colliders = VMFUtils.get_children_recursive(mesh).filter(func(n): return n is CollisionShape3D);
		var st = SurfaceTool.new();

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

		st.optimize_indices_for_cache();

		var arrays = st.commit_to_arrays();
		var simplified = st.generate_lod(0.1);

		box.set_arrays(arrays[Mesh.ARRAY_VERTEX], simplified);

		occluder.occluder = box;

	occluder.name = vmf.get_file().get_basename() + "_occluder";

	add_child(occluder);
	occluder.set_owner(_owner);

func for_resource_import():
	var fs = editor_interface.get_resource_filesystem() if Engine.is_editor_hint() else null;
	if not has_imported_resources: return;

	if fs: 
		fs.scan();
		await fs.resources_reimported;

	has_imported_resources = false;

func import_map() -> void:
	if not vmf: return;

	VMFConfig.load_config();

	clear_structure();
	read_vmf();

	import_materials();
	import_models();

	await for_resource_import();

	import_geometry();
	import_entities();
