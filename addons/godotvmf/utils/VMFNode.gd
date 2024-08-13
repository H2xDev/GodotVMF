@tool
@icon("res://addons/godotvmf/icon.svg")
class_name VMFNode extends Node3D;

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

@export_category("Resource Generation")
## Save the resulting geometry mesh as a resource (saves to the geometryFolder in vmf.config.json)
@export var save_geometry: bool = true;

## Save the resulting collision shape as a resource (saves to the geometryFolder in vmf.config.json)
@export var save_collision: bool = true;

var _structure: Dictionary = {};
var _owner:
	get: 
		var o = get_owner();
		if o == null: return self;

		return o;

func _validate_property(property: Dictionary) -> void:
	if property.name == "vmf":
		property.hint = PROPERTY_HINT_GLOBAL_FILE if use_external_file else PROPERTY_HINT_FILE

func _ready() -> void:
	add_to_group(&"vmfnode_group");

func import_geometry(_reimport := false) -> void:
	output.emit("Importing geometry...");
	var mesh: ArrayMesh = VMFTool.create_mesh(_structure);
	if not mesh:
		return;

	if _reimport:
		VMFConfig.reload();
		
		if not VMFConfig.validate_config(): return;
		if not VMFConfig.config: return;

		_read_vmf();
		_import_materials();

	var _current_mesh := MeshInstance3D.new()
	_current_mesh.name = "Geometry";

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
	
	add_child(_current_mesh);
	_current_mesh.set_owner(_owner);
		
	# FIXME - is_inside_tree always false
	var transform = _current_mesh.global_transform;
	var texel_size = VMFConfig.config.import.lightmapTexelSize;

	if VMFConfig.config.import.generateLightmapUV2:
		_current_mesh.mesh.lightmap_unwrap(transform, texel_size);
	
	if VMFConfig.config.import.generateCollision:
		_current_mesh.create_trimesh_collision();
		
		if _save_collision:
			_save_collision.call_deferred();

func _save_collision() -> void:
	output.emit("Save collision into a file...");
	var new_collision_shape: CollisionShape3D = $Geometry/Geometry_col/CollisionShape3D;
	if not new_collision_shape:
		VMFLogger.warn("Could not save find collision shape in " + name);
		return;
	
	var collision_resource_path := "%s/%s_collision_import.res" % [VMFConfig.config.import.geometryFolder, _vmf_identifer()];
	var shape: = new_collision_shape.shape;
	var err := ResourceSaver.save(shape, collision_resource_path, ResourceSaver.FLAG_COMPRESS);
	if err:
		VMFLogger.error("Failed to save resource: %s" % err);
		return;
		
	shape.take_over_path(collision_resource_path);
	new_collision_shape.shape = load(collision_resource_path);

func _vmf_identifer() -> String:
	return vmf.split('/')[-1].replace('.', '_');

func _import_materials() -> void:
	output.emit("Importing materials...");
	var list: Array[String] = [];
	var ignore_list: Array[String];
	ignore_list.assign(VMFConfig.config.material.ignore);
	
	var elapsed_time := Time.get_ticks_msec();

	if VMFConfig.config.material.importMode != VTFTool.TextureImportMode.IMPORT_DIRECTLY:
		return;

	VTFTool.clear_cache();
	

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

	for material in list:
		VTFTool.import_material(material);

	elapsed_time = Time.get_ticks_msec() - elapsed_time;

	if elapsed_time > 1000:
		VMFLogger.warn("Imported " + str(len(list)) + " materials in " + str(Time.get_ticks_msec() - elapsed_time) + "ms");

# TODO: Make it in a separate thread
func import_models() -> void:
	output.emit("Importing models...");
	if not "models" in VMFConfig.config:
		return;
	if not VMFConfig.config.models.import:
		return;

	if not "entity" in _structure:
		return;

	var _modelsNode: Node3D = get_node_or_null("Models");

	if _modelsNode:
		remove_child(_modelsNode);
		_modelsNode.queue_free();

	MDLManager.clear_cache();

	_modelsNode = Node3D.new();
	_modelsNode.name = "Models";
	add_child(_modelsNode);
	_modelsNode.set_owner(_owner);

	for ent in _structure.entity:
		if ent.classname != 'prop_static':
			continue;

		if not "model" in ent:
			continue;

		var lightmap_texel_size = VMFConfig.config.models.lightmapTexelSize;
		var generate_collision = VMFConfig.config.models.generateCollision;
		var generate_lightmap_uv2 = VMFConfig.config.models.generateLightmapUV2;

		if generate_lightmap_uv2 and "lightmapTexelSize" in ent:
			lightmap_texel_size = float(ent.lightmapTexelSize);
			VMFLogger.log('prop_static (%s) overrides lightmapTexelSize to \'%f\'' % [ent.id, lightmap_texel_size]);

		var resource = MDLManager.load_model(ent.model, generate_collision, generate_lightmap_uv2, lightmap_texel_size);
		var import_scale: float = VMFConfig.config.import.scale;

		if not resource:
			continue;
		
		ent = ent.duplicate();
		var model = resource.instantiate();
		var origin := Vector3(ent.origin.x * import_scale, ent.origin.z * import_scale, -ent.origin.y * import_scale);
		var scale := Vector3(import_scale, import_scale, import_scale);

		model.transform.origin = origin;
		model.basis = ValveIONode.get_entity_basis(ent);
		model.scale = scale;
		model.name = ent.model.get_file().split('.')[0] + '_' + str(ent.id);

		_modelsNode.add_child(model);
		model.set_owner(_owner);

func _clear_structure() -> void:
	_structure = {};

	for n in get_children():
		remove_child(n);
		n.queue_free();

func _read_vmf() -> void:
	output.emit("Reading vmf...");
	_structure = ValveFormatParser.parse(vmf);

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

	if _reimport: _read_vmf();

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

		if "entity" in node:
			node.entity = ent;
		
		if "origin" in ent:
			ent.origin = Vector3(ent.origin.x, ent.origin.z, -ent.origin.y) * import_scale;

		_entities_node.add_child(node);
		node.set_owner(_owner);

	var time := Time.get_ticks_msec() - elapsed_time;
	VMFLogger.log("Imported entities in " + str(time) + "ms");

func import_map(_deprecated = null) -> void:
	VMFConfig.reload();
	if not VMFConfig.validate_config(): return;
	if not VMFConfig.config: return;
	if not vmf: return;

	VTFTool.clear_cache();

	_clear_structure();
	_read_vmf();
	_import_materials();
	import_geometry();
	import_models();
	import_entities();
