@tool
@icon("res://addons/godotvmf/icon.svg")
class_name VMFNode extends Node3D;

@export_global_file("*.vmf")
var vmf: String = '';

## Full import of VMF with specified options
@export var import: bool = false:
	set(value):
		if not value:
			return;
		importMap();
		import = false;

## Click here to reload vmf.config.json
@export var reloadConfig: bool = false:
	set(value):
		VMFConfig.checkProjectConfig();
		reloadConfig = false;

var _structure: Dictionary = {};
var _owner = null;

func _importGeometry(_reimport = false):
	if not _owner:
		_owner = get_tree().get_edited_scene_root();

	var _currentMesh = get_node_or_null("Geometry");

	if _currentMesh != null:
		remove_child(_currentMesh);
		_currentMesh.queue_free();

	var mesh = VMFTool.createMesh(_structure);

	if not mesh:
		return;

	_currentMesh = MeshInstance3D.new();
	_currentMesh.name = "Geometry";
	_currentMesh.set_mesh(mesh);

	add_child(_currentMesh);
	_currentMesh.set_owner(_owner);

	if VMFConfig.config.import.generateCollision:
		_currentMesh.create_trimesh_collision();

func _importMaterials():
	var list = [];
	var ignoreList = VMFConfig.config.material.ignore;
	var elapsedTime = Time.get_ticks_msec();

	if VMFConfig.config.material.importMode != VTFTool.TextureImportMode.IMPORT_DIRECTLY:
		return;

	VTFTool.clearCache();

	if "solid" in _structure.world:
		for brush in _structure.world.solid:
			for side in brush.side:
				if not list.has(side.material):
					list.append(side.material);

	if "entity" in _structure:
		for entity in _structure.entity:
			if not "solid" in entity:
				continue;

			for brush in entity.solid:
				if not brush is Dictionary:
					continue;
				for side in brush.side:
					if not list.has(side.material) and ignoreList.has(side.material):
						list.append(side.material);

	for material in list:
		VTFTool.importMaterial(material);

	VMFLogger.log("Imported " + str(len(list)) + " materials in " + str(Time.get_ticks_msec() - elapsedTime) + "ms");

# TODO: Make it in separate thread
func _importModels():
	if not VMFConfig.config.models.import:
		return false;

	if not "entity" in _structure:
		return;

	if not _owner:
		_owner = get_tree().get_edited_scene_root();

	var _modelsNode = get_node_or_null("Models");

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
		
		var resource = MDLManager.loadModel(ent.model, VMFConfig.config.models.generateCollision);
		var importScale = VMFConfig.config.import.scale;

		if not resource:
			continue;

		var model = resource.instantiate();
		var origin = Vector3(ent.origin.x * importScale, ent.origin.z * importScale, -ent.origin.y * importScale);
		var angles = Vector3(deg_to_rad(ent.angles.z) - PI / 2, deg_to_rad(ent.angles.y), deg_to_rad(-ent.angles.x));
		var scale = Vector3(importScale, importScale, importScale);

		model.transform.origin = origin;
		model.rotation_order = 3;
		model.rotation = angles;
		model.scale = scale;
		model.name = ent.model.get_file().split('.')[0] + '_' + str(ent.id);

		_modelsNode.add_child(model);
		model.set_owner(_owner);

func _clearStructure():
	_structure = {};

	for n in get_children():
		remove_child(n);
		n.queue_free();

func _readVMF():
	VMFLogger.log("Read vmf structure");
	_structure = ValveFormatParser.parse(vmf);

	## NOTE: In case if "entity" or "solid" fields are Dictionary,
	##		 we need to convert them to Array

	if "entity" in _structure:
		_structure.entity = [_structure.entity] if not _structure.entity is Array else _structure.entity;

	if "solid" in _structure.world:
		_structure.world.solid = [_structure.world.solid] if not _structure.world.solid is Array else _structure.world.solid;

func _importEntities(_reimport = false):
	var elapsedTime = Time.get_ticks_msec();
	var importScale = VMFConfig.config.import.scale;

	if not _owner:
		_owner = get_tree().get_edited_scene_root();

	if _reimport:
		_readVMF();

	var _entitiesNode = get_node_or_null("Entities");

	if _entitiesNode:
		remove_child(_entitiesNode);
		_entitiesNode.queue_free();

	_entitiesNode = Node3D.new();
	_entitiesNode.name = "Entities";
	add_child(_entitiesNode);
	_entitiesNode.set_owner(_owner);

	if not "entity" in _structure:
		return;

	for ent in _structure.entity:
		ent = ent.duplicate(true);

		var resPath = (VMFConfig.config.import.entitiesFolder + '/' + ent.classname + '.tscn').replace('//', '/').replace('res:/', 'res://');

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

	var time = Time.get_ticks_msec() - elapsedTime;
	VMFLogger.log("Imported entities in " + str(time) + "ms");

func importGeometryOnly():
	if not VMFConfig.config:
		return;

	_readVMF();
	_importMaterials();
	_importGeometry(true);

func importMap():
	if not VMFConfig.config:
		return;

	if not Engine.is_editor_hint():
		return;

	if not vmf:
		return;

	if not _owner:
		_owner = get_tree().get_edited_scene_root();

	VTFTool.clearCache();

	_clearStructure();
	_readVMF();
	_importMaterials();
	_importGeometry();
	_importModels();
	_importEntities();
