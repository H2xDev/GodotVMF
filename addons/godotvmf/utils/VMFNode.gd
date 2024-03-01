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

var projectConfig: Dictionary:
	get:
		return VMFConfig.getConfig();

var _structure: Dictionary = {};
var _currentMesh: MeshInstance3D = $Geometry if has_node("Geometry") else null;
var _entitiesNode: Node3D = $Entities if has_node("Entities") else null;
var _owner = null;

func _importGeometry(_reimport = false):
	if _reimport:
		if not _owner:
			_owner = get_tree().get_edited_scene_root();
		VMFLogger.log("Reimporting geometry");
		_readVMF();
	else:
		VMFLogger.log("Generating the map mesh");

	_currentMesh = _currentMesh if _currentMesh != null else get_node_or_null("Geometry");

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

	if projectConfig.nodeConfig.generateCollision:
		_currentMesh.create_trimesh_collision();

func _importMaterials():
	var list = [];
	var ignoreList = projectConfig.nodeConfig.ignoreTextures;
	var elapsedTime = Time.get_ticks_msec();

	if projectConfig.nodeConfig.textureImportMode != VTFTool.TextureImportMode.IMPORT_DIRECTLY:
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

func _importModels():
	if not projectConfig.nodeConfig.importModels:
		return false;
	VMFLogger.log("Importing models");

	if not FileAccess.file_exists(projectConfig.mdl2obj):
		VMFLogger.warn('MDL2OBJ not found, models will not be imported');
		return;

	if not "entity" in _structure:
		return;

	for ent in _structure.entity:
		if ent.classname != 'prop_static':
			continue;

		if not "model" in ent:
			continue;
		
		var resource = MDLManager.loadModel(ent.model, projectConfig.nodeConfig.generateCollisionForModel, projectConfig.nodeConfig.overrideModels);
		var importScale = projectConfig.nodeConfig.importScale;

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

		add_child(model);
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
	var importScale = projectConfig.nodeConfig.importScale;

	if not _owner:
		_owner = get_tree().get_edited_scene_root();

	if _reimport:
		_readVMF();

	if _entitiesNode:
		remove_child(_entitiesNode);
		_entitiesNode.queue_free();

	_entitiesNode = Node3D.new();
	_entitiesNode.name = "Entities";
	add_child(_entitiesNode);
	_entitiesNode.set_owner(_owner);

	var isEntitiesFolderDefined = "entitiesFolder" in projectConfig;
	var isEntitiesFolderValid = projectConfig.entitiesFolder.begins_with("res://");

	if not isEntitiesFolderDefined:
		VMFLogger.error('"entitiesFolder" in not found in vmf.config.json. Entities import skipped');

	if not isEntitiesFolderValid:
		VMFLogger.error('"entitiesFolder" should start from "res://" Entities import skipped');

	if not "entity" in _structure:
		return;

	for ent in _structure.entity:
		ent = ent.duplicate(true);

		var resPath = "";

		if isEntitiesFolderDefined and isEntitiesFolderValid:
			resPath = (projectConfig.entitiesFolder + '/' + ent.classname + '.tscn').replace('//', '/').replace('res:/', 'res://');

		# NOTE: In case when custom entity wasn't found - use plugin's entities list
		if resPath == "" or not ResourceLoader.exists(resPath):
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
	_readVMF();
	_importMaterials();
	_importGeometry(true);

func importMap():
	VMFConfig.checkProjectConfig();
	VMFLogger.log('Gameinfo path: ' + projectConfig.gameInfoPath);

	if not Engine.is_editor_hint():
		return;

	if not vmf:
		return;

	if not _owner:
		_owner = get_tree().get_edited_scene_root();

	_clearStructure();
	_readVMF();
	_importMaterials();
	_importGeometry();
	_importModels();
	_importEntities();
