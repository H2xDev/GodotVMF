@tool
@icon("res://addons/godotvmf/icon.svg")
class_name VMFNode extends Node3D;

@export_category("VMF File")

## Allow the file picker to select an external file
@export var useExternalFile: bool = false:
	set(val):
		useExternalFile = val;
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
		importMap();
		import = false;

@export_category("Resource Generation")
## Save the resulting geometry mesh as a resource (saves to the geometryFolder in vmf.config.json)
@export var saveGeometry: bool = true;

## Save the resulting collision shape as a resource (saves to the geometryFolder in vmf.config.json)
@export var saveCollision: bool = true;

var _structure: Dictionary = {};
var _owner: Node = null;

func _validate_property(property: Dictionary) -> void:
	if property.name == "vmf":
		property.hint = PROPERTY_HINT_GLOBAL_FILE if useExternalFile else PROPERTY_HINT_FILE

func _ready() -> void:
	add_to_group(&"vmfnode_group");

func _importGeometry(_reimport := false) -> void:
	if not _owner:
		_owner = get_tree().get_edited_scene_root();
	
	var mesh: ArrayMesh = VMFTool.createMesh(_structure);
	if not mesh:
		return;
		
	if VMFConfig.config.import.generateLightmapUV2:
		mesh.lightmap_unwrap(
			global_transform, 
			VMFConfig.config.import.lightmapTexelSize
			);

	var _currentMesh := MeshInstance3D.new()
	_currentMesh.name = "Geometry";

	if saveGeometry:
		var resourcePath: String = "%s/%s_import.mesh" % [VMFConfig.config.import.geometryFolder, _vmfIdentifier()];
		
		if not DirAccess.dir_exists_absolute(resourcePath.get_base_dir()):
			DirAccess.make_dir_recursive_absolute(resourcePath.get_base_dir());
		
		var err := ResourceSaver.save(mesh, resourcePath, ResourceSaver.FLAG_COMPRESS);
		if err:
			VMFLogger.error("Failed to save resource: %s" % err);
			return;
		
		mesh.take_over_path(resourcePath);
		_currentMesh.mesh = load(resourcePath);
	else:
		_currentMesh.mesh = mesh;
	
	add_child(_currentMesh);
	_currentMesh.set_owner(_owner);
	
	if VMFConfig.config.import.generateCollision:
		_currentMesh.create_trimesh_collision();
		
		if saveCollision:
			_saveCollision.call_deferred()

func _saveCollision() -> void:
	var newCollisionShape: CollisionShape3D = $Geometry/Geometry_col/CollisionShape3D;
	if not newCollisionShape:
		VMFLogger.warn("Could not save find collision shape in " + name);
		return;
	
	var collisionResourcePath := "%s/%s_collision_import.res" % [VMFConfig.config.import.geometryFolder, _vmfIdentifier()];
	var shape: = newCollisionShape.shape;
	var err := ResourceSaver.save(shape, collisionResourcePath, ResourceSaver.FLAG_COMPRESS);
	if err:
		VMFLogger.error("Failed to save resource: %s" % err);
		return;
		
	shape.take_over_path(collisionResourcePath);
	newCollisionShape.shape = load(collisionResourcePath);

func _vmfIdentifier() -> String:
	return vmf.split('/')[-1].replace('.', '_');

func _importMaterials() -> void:
	var list: Array[String] = [];
	var ignoreList: Array[String];
	ignoreList.assign(VMFConfig.config.material.ignore);
	
	var elapsedTime := Time.get_ticks_msec();

	if VMFConfig.config.material.importMode != VTFTool.TextureImportMode.IMPORT_DIRECTLY:
		return;

	VTFTool.clearCache();
	

	if "solid" in _structure.world:
		for brush in _structure.world.solid:
			for side in brush.side:
				var isIgnored = ignoreList.any(func(rx: String) -> bool: return side.material.match(rx));
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
					var isIgnored = ignoreList.any(func(rx): return side.material.match(rx));
					if isIgnored: continue;

					if not list.has(side.material):
						list.append(side.material);

	for material in list:
		VTFTool.importMaterial(material);

	VMFLogger.log("Imported " + str(len(list)) + " materials in " + str(Time.get_ticks_msec() - elapsedTime) + "ms");

# TODO: Make it in separate thread
func _importModels() -> void:
	if not "models" in VMFConfig.config:
		return;
	if not VMFConfig.config.models.import:
		return;

	if not "entity" in _structure:
		return;

	if not _owner:
		_owner = get_tree().get_edited_scene_root();

	var _modelsNode: Node3D = get_node_or_null("Models");

	if _modelsNode:
		remove_child(_modelsNode);
		_modelsNode.queue_free();

	MDLManager.clearCache();

	_modelsNode = Node3D.new();
	_modelsNode.name = "Models";
	add_child(_modelsNode);
	_modelsNode.set_owner(_owner);

	for ent in _structure.entity:
		if ent.classname != 'prop_static':
			continue;

		if not "model" in ent:
			continue;

		var lightmapTexelSize = VMFConfig.config.models.lightmapTexelSize

		if VMFConfig.config.import.generateLightmapUV2 and "lightmapTexelSize" in ent:
			lightmapTexelSize = float(ent.lightmapTexelSize)
			VMFLogger.log('prop_static (%s) overrides lightmapTexelSize to \'%f\'' % [ent.id, lightmapTexelSize])

		var resource = MDLManager.loadModel(ent.model, VMFConfig.config.models.generateCollision, VMFConfig.config.import.generateLightmapUV2, lightmapTexelSize);
		var importScale: float = VMFConfig.config.import.scale;

		if not resource:
			continue;
		
		ent = ent.duplicate();
		var model = resource.instantiate();
		var origin := Vector3(ent.origin.x * importScale, ent.origin.z * importScale, -ent.origin.y * importScale);
		var scale := Vector3(importScale, importScale, importScale);

		model.transform.origin = origin;
		model.basis = ValveIONode.get_entity_basis(ent);
		model.scale = scale;
		model.name = ent.model.get_file().split('.')[0] + '_' + str(ent.id);

		_modelsNode.add_child(model);
		model.set_owner(_owner);

func _clearStructure() -> void:
	_structure = {};

	for n in get_children():
		remove_child(n);
		n.queue_free();

func _readVMF() -> void:
	VMFLogger.log("Read vmf structure");
	_structure = ValveFormatParser.parse(vmf);

	## NOTE: In case if "entity" or "solid" fields are Dictionary,
	##		 we need to convert them to Array

	if "entity" in _structure:
		_structure.entity = [_structure.entity] if not _structure.entity is Array else _structure.entity;

	if "solid" in _structure.world:
		_structure.world.solid = [_structure.world.solid] if not _structure.world.solid is Array else _structure.world.solid;

func _importEntities(_reimport := false) -> void:
	if not is_inside_tree():
		queue_free()
		return
	
	var elapsedTime := Time.get_ticks_msec();
	var importScale: float = VMFConfig.config.import.scale;

	if not _owner:
		_owner = get_tree().get_edited_scene_root();

	if _reimport:
		_readVMF();

	var _entitiesNode: Node3D = get_node_or_null("Entities");

	if _entitiesNode:
		remove_child(_entitiesNode);
		_entitiesNode.queue_free();

	_entitiesNode = Node3D.new();
	_entitiesNode.name = "Entities";
	add_child(_entitiesNode);
	_entitiesNode.set_owner(_owner);

	if not "entity" in _structure: return;

	for ent: Dictionary in _structure.entity:
		ent = ent.duplicate(true);

		var resPath: String = (VMFConfig.config.import.entitiesFolder + '/' + ent.classname + '.tscn').replace('//', '/').replace('res:/', 'res://');

		# NOTE: In case when custom entity wasn't found - use plugin's entities list
		if not ResourceLoader.exists(resPath):
			resPath = 'res://addons/godotvmf/entities/' + ent.classname + '.tscn';

			if not ResourceLoader.exists(resPath):
				continue;

		var tscn = load(resPath);
		var node = tscn.instantiate();

		_entitiesNode.add_child(node);
		node.set_owner(_owner);
		
		if ent.classname and ent.classname != "func_instance":
			set_editable_instance(node, true);
		
		if "origin" in ent:
			ent.origin = Vector3(ent.origin.x, ent.origin.z, -ent.origin.y) * importScale;

		if "_apply_entity" in node:
			node._apply_entity(ent, self);

	var time := Time.get_ticks_msec() - elapsedTime;
	VMFLogger.log("Imported entities in " + str(time) + "ms");

func importGeometryOnly() -> void:
	VMFConfig.checkProjectConfig();
	
	if not VMFConfig.validateConfig(): return;
	if not VMFConfig.config: return;

	_readVMF();
	_importMaterials();
	_importGeometry(true);

func importMap() -> void:
	if not is_inside_tree():
		queue_free()
		return
	
	VMFConfig.checkProjectConfig();
	if not VMFConfig.validateConfig(): return;
	if not VMFConfig.config: return;
	if not Engine.is_editor_hint(): return;
	if not vmf: return;

	if not _owner:
		_owner = get_tree().get_edited_scene_root();

	VTFTool.clearCache();
	
	_clearStructure();
	_readVMF();
	_importMaterials();
	_importGeometry();
	_importModels();
	_importEntities();
