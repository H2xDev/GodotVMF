## VMF Importer
##
## Radik Khamatdinov (github.com/h2xdev)
## Sergey Shavin (github.com/ambiabstract)
##
## @license MIT

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

## This scale will be applied on everything that imports from VMF includes models, instances, etc.
var importScale: float = 0.025

## If true, then the collision will be generated for
## the imported geometry
var generateCollision: bool = true;


## Used in case when target texture was not found
## this value will be used as width and height of
## the texture
var defaultTextureSize: int = 512

## This material will be used in case if target
## material was not found
var fallbackMaterial: Material = null;

## Faces with specified textures will be ignored
var ignoreTextures: Array = ['TOOLS/TOOLSNODRAW'];

## During import automatically converts VTFs into 
## JPG and copies them to the project folder with
## saved folder structure
var textureImportMode: VMTManager.TextureImportMode = 1;

## If true, then the importer converts mdl files into obj and 
## convert again into godot mesh. 
##
## The import destination you can change in the vmf.config.json
##
## Materials of the model will be copied into the materials folder
## speciefied in the vmf.config.json
##
## Requires mdl2obj tool specified in vmf.config.json
var importModels: bool = false;

## If true, then the collision will be generated for the imported models
## by using create_multiple_convex_collisions
var generateCollisionForModel: bool = true;

## In case if model is already imported it will be overriden
var overrideModels: bool = true;

@export_category("Config")

## Click here to reload vmf.config.json
@export var reloadConfig: bool = false:
	set(value):
		VMFConfig.checkProjectConfig();
		applyConfig(VMFConfig.getConfig().nodeConfig);
		reloadConfig = false;

## Use it in case you updated materials in your mod's folder
@export var resetMaterialCache: bool = false:
	set(value):
		VMTManager.resetCache();
		resetMaterialCache = false;

var projectConfig: Dictionary:
	get:
		return VMFConfig.getConfig();

var _structure: Dictionary = {};
var _currentMesh: MeshInstance3D = $Geometry if has_node("Geometry") else null;
var _entitiesNode: Node3D = $Entities if has_node("Entities") else null;
var _owner = null;

func _collectDetails():
	VMFLogger.log("Making all func_detail as default geometry");

	if not "entity" in _structure:
		return;

	for ent in _structure.entity:
		if ent.classname != "func_detail":
			continue;

		if ent.solid is Array:
			_structure.world.solid.append_array(ent.solid);
		else:
			_structure.world.solid.append(ent.solid);

## Returns MeshInstance3D from parsed VMF structure
static func createMesh(
	vmfStructure: Dictionary,
	_scale = 0.1,
	_defaultTextureSize = 512,
	_textureImportMode: VMTManager.TextureImportMode = 0,
	_ignoreTextures = [],
	_fallbackMaterial: Material = null,
	_offset: Vector3 = Vector3(0, 0, 0),
) -> Mesh:
	var elapsedTime = Time.get_ticks_msec();

	if not "solid" in vmfStructure.world:
		return null;

	var brushes = vmfStructure.world.solid
	var materialSides = {};
	var textureCache = {};
	var mesh = ArrayMesh.new();
	var isNotResaved = false;

	## TODO Add displacement support
	##		I'm too dumb for this logic :'C

	for brush in brushes:
		for side in brush.side:
			var material = side.material
			
			if _ignoreTextures.has(material):
				continue;

			if not material in materialSides:
				materialSides[material] = [];
			materialSides[material].append(side);

	var index = 0;
	for sides in materialSides.values():
		var verts = [];
		var uvs = [];
		var normals = [];
		var indices = [];


		for side in sides:
			if not "vertices_plus" in side:
				isNotResaved = true;
				continue;

			var vertex_count = side.vertices_plus.v.size()
			if vertex_count < 3:
				continue;

			var base_index = verts.size()

			for vertex in side.vertices_plus.v:
				var vt = Vector3(vertex.x * _scale, vertex.z * _scale, -vertex.y * _scale) - _offset;
				verts.append(vt);

				var ux = side.uaxis.x;
				var uy = side.uaxis.y;
				var uz = side.uaxis.z;
				var ushift = side.uaxis.shift;
				var uscale = side.uaxis.scale;

				var vx = side.vaxis.x;
				var vy = side.vaxis.y;
				var vz = side.vaxis.z;
				var vshift = side.vaxis.shift;
				var vscale = side.vaxis.scale;

				var texture = VMTManager.getTextureInfo(side.material);
				
				var tsx = 1;
				var tsy = 1;
				var tw = texture.width if texture else _defaultTextureSize;
				var th = texture.height if texture else _defaultTextureSize;
				var aspect = tw / th;

				if texture and texture.transform:
					tsx /= texture.transform.scale.x;
					tsy /= texture.transform.scale.y;

				var uv = Vector3(ux, uy, uz);
				var vv = Vector3(vx, vy, vz);
				var v2 = Vector3(vertex.x, vertex.y, vertex.z);

				var u = (v2.dot(uv) + ushift * uscale) / tw / uscale / tsx;
				var v = (v2.dot(vv) + vshift * vscale) / tw / vscale / tsy;
				
				if aspect < 1:
					u *= aspect;
				else:
					v *= aspect;

				uvs.append(Vector2(u, v));
				
				var ab = side.plane[0] - side.plane[1];
				var ac = side.plane[2] - side.plane[1];
				var normal = ab.cross(ac).normalized();

				normals.append(normal);
				
				# TODO Here should be a logic for smoothing groups

			for i in range(1, vertex_count - 1):
				indices.append(base_index)
				indices.append(base_index + i)
				indices.append(base_index + i + 1)

		var surface = []
		surface.resize(Mesh.ARRAY_MAX);
		surface[Mesh.ARRAY_VERTEX] = PackedVector3Array(verts)
		surface[Mesh.ARRAY_TEX_UV] = PackedVector2Array(uvs)
		surface[Mesh.ARRAY_TEX_UV2] = PackedVector2Array(uvs)
		surface[Mesh.ARRAY_NORMAL] = PackedVector3Array(normals)
		surface[Mesh.ARRAY_INDEX] = PackedInt32Array(indices)

		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, surface)

		if _textureImportMode == VMTManager.TextureImportMode.COLLATE_BY_NAME:
			var godotMaterial = VMTManager.getMaterialFromProject(sides[0].material);

			if godotMaterial:
				mesh.surface_set_material(index, godotMaterial);
			else: if _fallbackMaterial:
				mesh.surface_set_material(index, _fallbackMaterial);
		else: if _textureImportMode == VMTManager.TextureImportMode.IMPORT_DIRECTLY:
			var material = VMTManager.importMaterial(sides[0].material);
			if material:
				mesh.surface_set_material(index, material);

		index += 1;
	elapsedTime = Time.get_ticks_msec() - elapsedTime;

	if elapsedTime > 100:
		VMFLogger.warn("Mesh generation took " + str(elapsedTime) + "ms");

	if isNotResaved:
		VMFLogger.warn("The VMF you imported has no vertices_plus data. Try to resave this map in Valve Hammer Editor and reimport.");


	return mesh;

func _importGeometry(_reimport = false):
	if _reimport:
		if not _owner:
			_owner = get_tree().get_edited_scene_root();
		VMFLogger.log("Reimporting geometry");
		_readVMF();
	else:
		VMFLogger.log("Generating the map mesh");

	if _currentMesh != null:
		remove_child(_currentMesh);
		_currentMesh.queue_free();

	var mesh = VMFNode.createMesh(
		_structure,
		importScale,
		defaultTextureSize,
		textureImportMode,
		ignoreTextures,
		fallbackMaterial,
	);

	if not mesh:
		return;

	_currentMesh = MeshInstance3D.new();
	_currentMesh.name = "Geometry";
	_currentMesh.set_mesh(mesh);

	add_child(_currentMesh);
	_currentMesh.set_owner(_owner);
	_currentMesh.create_trimesh_collision();

func _importMaterials():
	var list = [];
	var elapsedTime = Time.get_ticks_msec();

	if "solid" in _structure.world:
		for brush in _structure.world.solid:
			for side in brush.side:
				if not list.has(side.material):
					list.append(side.material);

	if "entity" in _structure:
		for entity in _structure.entity:
			if entity.classname == "prop_static":
				return;

			if not "solid" in entity:
				continue;

			for brush in entity.solid:
				if not brush is Dictionary:
					continue;
				for side in brush.side:
					if not list.has(side.material):
						list.append(side.material);

	for material in list:
		VMTManager.preloadMaterial(material);

	VMFLogger.log("Imported " + str(len(list)) + " materials in " + str(Time.get_ticks_msec() - elapsedTime) + "ms");

func _importModels():
	if not importModels:
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
		
		var resource = MDLManager.loadModel(ent.model, generateCollisionForModel, overrideModels);

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
	## 		 we need to convert them to Array

	if "entity" in _structure:
		_structure.entity = [_structure.entity] if not _structure.entity is Array else _structure.entity;

	if "solid" in _structure.world:
		_structure.world.solid = [_structure.world.solid] if not _structure.world.solid is Array else _structure.world.solid;

func _importEntities(_reimport = false):
	var elapsedTime = Time.get_ticks_msec();
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

	if not "entitiesFolder" in projectConfig:
		VMFLogger.error('"entitiesFolder" in not found in vmf.config.json. Entities import skipped');
		return;

	if not projectConfig.entitiesFolder.begins_with("res://"):
		VMFLogger.error('"entitiesFolder" should start from "res://" Entities import skipped');
		return;

	if not "entity" in _structure:
		return;

	for ent in _structure.entity:
		ent = ent.duplicate(true);

		var resPath = (projectConfig.entitiesFolder + '/' + ent.classname + '.tscn').replace('//', '/').replace('res:/', 'res://');

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

func applyConfig(config):
	var keys = [
		'importScale',
		'defaultTextureSize',
		'textureImportMode',
		'ignoreTextures',
		'importModels',
		'fallbackMaterial',
		'generateCollisionForModel',
		'overrideModels',
		'generateCollision',
	]

	for key in keys:
		if not key in config:
			continue;

		var value = config[key];

		if key == 'fallbackMaterial' and value != null:
			value = load(value);
			if not value:
				continue;

		self[key] = value;

func applySettingsFrom(vmfNode):
	importScale = vmfNode.importScale;
	defaultTextureSize = vmfNode.defaultTextureSize;
	textureImportMode = vmfNode.textureImportMode;
	ignoreTextures = vmfNode.ignoreTextures;
	importModels = vmfNode.importModels;
	fallbackMaterial = vmfNode.fallbackMaterial;
	generateCollisionForModel = vmfNode.generateCollisionForModel;
	overrideModels = vmfNode.overrideModels;
	generateCollision = vmfNode.generateCollision;

func _importInstances():
	VMFInstanceManager.importInstances(vmf, self);

func importMap():
	VMFConfig.checkProjectConfig();
	applyConfig(VMFConfig.getConfig().nodeConfig);

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
	_importInstances();
	_importEntities();
