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
	"$detail",
	"$selfillummask",
];

signal output(message: String);

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
		if not value:
			return;
		import_map();
		import = false;
## If true then button "Full", "Entities" and "Geometry" won't trigger import on this Node.
@export var ignore_global_import: bool = false;

@export_category("Resource Generation")
## Save the resulting geometry mesh as a resource (saves to the geometryFolder in vmf.config.json)
@export var save_geometry: bool = true;

## Save the resulting collision shape as a resource (saves to the geometryFolder in vmf.config.json)
@export var save_collision: bool = true;

var is_runtime = false;
var _structure: Dictionary = {};
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

var navmesh: NavigationRegion3D:
	get: return get_node_or_null("NavigationMesh");

func _validate_property(property: Dictionary) -> void:
	if property.name == "vmf":
		property.hint = PROPERTY_HINT_GLOBAL_FILE if use_external_file else PROPERTY_HINT_FILE

func _ready() -> void:
	add_to_group("vmfnode_group");

func set_owner_recurive(node: Node, owner: Node):
	node.set_owner(owner);
	for child in node.get_children():
		set_owner_recurive(child, owner);

func import_geometry(_reimport := false) -> void:
	output.emit("Importing geometry...");

	if _reimport:
		VMFConfig.reload();
		
		if not VMFConfig.validate_config(): return;
		if not VMFConfig.config: return;

		read_vmf();
		import_materials();

	var mesh: ArrayMesh = VMFTool.create_mesh(_structure);
	if not mesh:
		return;

	var _current_mesh := MeshInstance3D.new()
	_current_mesh.name = "Geometry";

	
	add_child(_current_mesh);
	_current_mesh.set_owner(_owner);

	var transform = _current_mesh.global_transform if _current_mesh.is_inside_tree() else self.transform;
	var texel_size = VMFConfig.config.import.lightmapTexelSize;

	if VMFConfig.config.import.generateLightmapUV2 and not is_runtime:
		mesh.lightmap_unwrap(transform, texel_size);

	if save_geometry:
		var resource_path: String = "%s/%s_import.mesh" % [VMFConfig.config.import.geometryFolder, _vmf_identifer()];
		
		if not DirAccess.dir_exists_absolute(resource_path.get_base_dir()):
			DirAccess.make_dir_recursive_absolute(resource_path.get_base_dir());
		
		var err := ResourceSaver.save(mesh, resource_path, ResourceSaver.FLAG_COMPRESS);
		if err:
			VMFLogger.error("Failed to save resource: %s" % err);
			return;
		
		mesh.take_over_path(resource_path);
		_current_mesh.mesh = load(resource_path);
	else:
		_current_mesh.mesh = mesh;
	
	if VMFConfig.config.import.generateCollision:
		var bodies = VMFTool.generate_collisions(_current_mesh.mesh);
		var body_idx = 0
		for body in bodies:
			_current_mesh.add_child(body);
			set_owner_recurive(body, _owner);
			body_idx += 1;

	# NOTE Clear surface that has materials in ignore list
	# FIXME Currently we don't have a way to remove surface from ArrayMesh since `surface_remove` were removed in 4.x
	#  		Engine's github issue: https://github.com/godotengine/godot/issues/67181

	# var _ignore_textures = VMFConfig.config.material.ignore;

	# for surface_idx in _current_mesh.mesh.get_surface_count():
	# 	var material = _current_mesh.mesh.get_meta("surface_material_" + str(surface_idx), "").to_lower();
	# 	var isIgnored = _ignore_textures.any(func(rx: String) -> bool: return material.match(rx.to_lower()));
	# 	if isIgnored:
	# 		_current_mesh.mesh.surface_remove(surface_idx);
	# 		continue;

	_save_collision();

	if VMFConfig.config.import.get("useNavigationMesh", false):
		var navmesh_preset_path = VMFConfig.config.import.get("navigationMeshPreset", "default");
		var navmesh_preset = null;

		if ResourceLoader.exists(navmesh_preset_path):
			navmesh_preset = ResourceLoader.load(navmesh_preset_path);
			assert(navmesh_preset is NavigationMesh, "vmf.config.json -> import.navigationMeshPreset has wrong type. Expected NavigationMesh, got %s" % navmesh_preset.get_class());

		var navreg := NavigationRegion3D.new();
		navreg.navigation_mesh = NavigationMesh.new() if not navmesh_preset else navmesh_preset.duplicate();
		navreg.name = "NavigationMesh";

		add_child(navreg);
		navreg.set_owner(_owner);
		_current_mesh.reparent(navreg);

		navreg.bake_navigation_mesh.call_deferred();


func _save_collision() -> void:
	output.emit("Save collision into a file...");

	var collisions = $Geometry.get_children() as Array[StaticBody3D];

	for body in collisions:
		var collision := body.get_node('collision');
		var shape = collision.shape;
		var save_path := "%s/%s_collision_%s.res" % [VMFConfig.config.import.geometryFolder, _vmf_identifer(), body.name];
		var error := ResourceSaver.save(collision.shape, save_path, ResourceSaver.FLAG_COMPRESS);

		if error:
			VMFLogger.error("Failed to save resource: %s" % error);
			continue;
		shape.take_over_path(save_path);
		collision.shape = load(save_path);
		

func _vmf_identifer() -> String:
	return vmf.split('/')[-1].replace('.', '_');

func normalize_path(path: String) -> String:
	return path.replace('\\', '/').replace('//', '/').replace('res:/', 'res://');

func import_materials() -> void:
	if VMFConfig.config.material.importMode == MaterialImportMode.USE_EXISTING:
		return;

	output.emit("Importing materials...");
	var list: Array[String] = [];
	var ignore_list: Array[String];
	ignore_list.assign(VMFConfig.config.material.ignore);
	
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

	if not is_runtime:
		var fs = EditorInterface.get_resource_filesystem() if Engine.is_editor_hint() else null;

		for material in list:
			import_material(material);
		
		if fs: await fs.resources_reimported;

		for material in list:
			import_textures(material);

		if fs: await fs.resources_reimported;

	elapsed_time = Time.get_ticks_msec() - elapsed_time;

	if elapsed_time > 1000:
		VMFLogger.warn("Imported " + str(len(list)) + " materials in " + str(Time.get_ticks_msec() - elapsed_time) + "ms");

func import_material(material: String):
	var vmt_path = normalize_path(VMFConfig.config.gameInfoPath + "/materials/" + material + ".vmt");
	var target_path = normalize_path(VMFConfig.config.material.targetFolder + "/" + material + ".vmt");
	if ResourceLoader.exists(target_path): return;

	DirAccess.make_dir_recursive_absolute(target_path.get_base_dir());
	DirAccess.copy_absolute(vmt_path, target_path);

func import_textures(material: String):
	var target_path = normalize_path(VMFConfig.config.material.targetFolder + "/" + material + ".vmt");
	var target_material = ResourceLoader.load(target_path);

	var details = target_material.get_meta("details", {});

	for key in MATERIAL_KEYS_TO_IMPORT:
		if key not in details: continue;
		var vtf_path = normalize_path(VMFConfig.config.gameInfoPath + "/materials/" + details[key] + ".vtf");
		var target_vtf_path = normalize_path(VMFConfig.config.material.targetFolder + "/" + details[key] + ".vtf");
		DirAccess.make_dir_recursive_absolute(vtf_path.get_base_dir());
		DirAccess.copy_absolute(vtf_path, target_vtf_path);

func clear_structure() -> void:
	_structure = {};

	for n in get_children():
		remove_child(n);
		n.queue_free();

func read_vmf() -> void:
	output.emit("Reading vmf...");
	_structure = VDFParser.parse(vmf);

	## NOTE: In case if "entity" or "solid" fields are Dictionary,
	##		 we need to convert them to Array

	if "entity" in _structure:
		_structure.entity = [_structure.entity] if not _structure.entity is Array else _structure.entity;

	if "solid" in _structure.world:
		_structure.world.solid = [_structure.world.solid] if not _structure.world.solid is Array else _structure.world.solid;

func import_entities(_reimport := false) -> void:
	output.emit("Importing entities...");
	var elapsed_time := Time.get_ticks_msec();
	var import_scale: float = VMFConfig.config.import.scale;

	if _reimport: read_vmf();

	var _entities_node: Node3D = get_node_or_null("Entities");

	if _entities_node:
		remove_child(_entities_node);
		_entities_node.queue_free();

	_entities_node = Node3D.new();
	_entities_node.name = "Entities";
	add_child(_entities_node);
	_entities_node.set_owner(_owner);

	if not "entity" in _structure: return;

	for ent: Dictionary in _structure.entity:
		ent = ent.duplicate(true);
		ent.vmf = vmf;

		var resPath: String = (VMFConfig.config.import.entitiesFolder + '/' + ent.classname + '.tscn').replace('//', '/').replace('res:/', 'res://');

		# NOTE: In case when custom entity wasn't found - use plugin's entities list
		if not ResourceLoader.exists(resPath):
			resPath = 'res://addons/godotvmf/entities/' + ent.classname + '.tscn';

			if not ResourceLoader.exists(resPath):
				continue;

		var tscn = load(resPath);
		var node = tscn.instantiate();
		if "is_runtime" in node:
			node.is_runtime = is_runtime;

		if "entity" in node:
			node.entity = ent;

		if "origin" in ent:
			ent.origin = Vector3(ent.origin.x, ent.origin.z, -ent.origin.y) * import_scale;

		_entities_node.add_child(node);
		node.set_owner(_owner);

		if not is_runtime and "_apply_entity" in node:
			node._apply_entity(ent);

		set_editable_instance(node, true);

	var time := Time.get_ticks_msec() - elapsed_time;

	if time > 2000:
		VMFLogger.warn("Imported entities in " + str(time) + "ms");

func import_map() -> void:
	VMFConfig.reload();
	if not VMFConfig.validate_config(): return;
	if not VMFConfig.config: return;
	if not vmf: return;

	clear_structure();
	read_vmf();
	import_materials();
	import_geometry();
	import_entities();
