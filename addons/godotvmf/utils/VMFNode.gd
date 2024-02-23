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

@export_category("Config")

## Click here to reload vmf.config.json
@export var reloadConfig: bool = false:
	set(value):
		VMFConfig.checkProjectConfig();
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
static var vertexCache = [];
static var intersections = {};

static func getSimilarVertex(vertex):
	vertexCache = vertexCache if vertexCache else [];

	for v in vertexCache:
		if (v - vertex).length() < 0.1:
			return v;

	vertexCache.append(vertex);
	return vertex;

## Credit: https://github.com/Dylancyclone/VMF2OBJ/blob/master/src/main/java/com/lathrum/VMF2OBJ/dataStructure/VectorSorter.java;
class VectorSorter:
	var normal: Vector3;
	var center: Vector3;
	var pp: Vector3;
	var qp: Vector3;

	func longer(a, b):
		return a if a.length() > b.length() else b;

	func _init(normal, center):
		self.normal = normal;
		self.center = center;

		var i = normal.cross(Vector3(1, 0, 0));
		var j = normal.cross(Vector3(0, 1, 0));
		var k = normal.cross(Vector3(0, 0, 1));

		self.pp = longer(i, longer(j, k));
		self.qp = normal.cross(self.pp);

	func getOrder(v):
		var normalized = v - self.center;
		return atan2(self.normal.dot(normalized.cross(self.pp)), self.normal.dot(normalized.cross(self.qp)));

static func clearCaches():
	vertexCache = [];
	intersections = {};

static func getPlanesIntersectionPoint(side, side2, side3):
	var d = [side.id, side2.id, side3.id];
	d.sort();

	var ihash = hash(d);
	var isIntersectionDefined = ihash in intersections;

	if isIntersectionDefined:
		return intersections[ihash];
	else:
		var vertex = side.plane.value.intersect_3(side2.plane.value, side3.plane.value);
		intersections[ihash] = vertex;
		return vertex;

## Returns vertices_plus
static func calculateVertices(side, brush):
	var vertices = [];
	var cache = {};

	var isVerticeExists = func(vector):
		var hash = hash(Vector3i(vector));
		
		if hash in cache:
			return true;

		cache[hash] = 1;

		return false;

	var isBrushCenterDefined = "center" in brush;

	var brushCenter = brush.center if isBrushCenterDefined else Vector3.ZERO;

	for side2 in brush.side:
		if not isBrushCenterDefined:
			brushCenter += side2.plane.vecsum / 3;

		if side2 == side:
			continue;

		for side3 in brush.side:
			if side2 == side3 or side3 == side:
				continue;

			var vertex = getPlanesIntersectionPoint(side, side2, side3);

			if vertex == null:
				continue;

			if isVerticeExists.call(vertex):
				continue;

			vertices.append(vertex);

	vertices = vertices.filter(func(vertex):
		return not brush.side.any(func(s):
			return s.plane.value.distance_to(vertex) > 0.01;
		)
	);

	if not isBrushCenterDefined:
		brushCenter /= brush.side.size();
		brush.center = brushCenter;

	var sideNormal = side.plane.value.normal;
	var vectorSorter = VectorSorter.new(sideNormal, brushCenter);

	vertices.sort_custom(func(a, b):
		return vectorSorter.getOrder(a) < vectorSorter.getOrder(b);
	);

	return vertices;

static func calculateUVForSide(side, vertex):
	var defaultTextureSize = VMFConfig.getConfig().nodeConfig.defaultTextureSize;

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
	var tw = texture.width if texture else defaultTextureSize;
	var th = texture.height if texture else defaultTextureSize;
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

	return Vector2(u, v);

## Returns MeshInstance3D from parsed VMF structure
static func createMesh(vmfStructure: Dictionary, _offset: Vector3 = Vector3(0, 0, 0)) -> Mesh:
	clearCaches();

	var projectConfig = VMFConfig.getConfig();

	var fbm = projectConfig.nodeConfig.fallbackMaterial;

	var _scale = projectConfig.nodeConfig.importScale;
	var _defaultTextureSize = projectConfig.nodeConfig.defaultTextureSize;
	var _ignoreTextures = projectConfig.nodeConfig.ignoreTextures;
	var _fallbackMaterial = load(fbm) if fbm && ResourceLoader.exists(fbm) else null;
	var _textureImportMode = projectConfig.nodeConfig.textureImportMode;

	var elapsedTime = Time.get_ticks_msec();

	if not "solid" in vmfStructure.world:
		return null;

	var brushes = vmfStructure.world.solid
	var materialSides = {};
	var textureCache = {};
	var mesh = ArrayMesh.new();

	## TODO Add displacement support
	##		I'm too dumb for this logic :'C

	for brush in brushes:
		for side in brush.side:
			var material = side.material
			
			if _ignoreTextures.has(material):
				continue;

			if not material in materialSides:
				materialSides[material] = [];

			materialSides[material].append({
				"side": side,
				"brush": brush,
			});

	for sides in materialSides.values():
		var surfaceTool = SurfaceTool.new();
		surfaceTool.begin(Mesh.PRIMITIVE_TRIANGLES);

		var index = 0;
		for sideData in sides:
			var side = sideData.side;
			var base_index = index;

			## NOTE: Generating vertices in case the VMF is from vanilla Hammer
			if not "vertices_plus" in side:
				side.vertices_plus = {
					"v": calculateVertices(side, sideData.brush),
				};

			var vertex_count = side.vertices_plus.v.size();
			if vertex_count < 3:
				continue;

			var normal = side.plane.value.normal;
			surfaceTool.set_normal(Vector3(normal.x, normal.z, -normal.y));

			for v in side.vertices_plus.v:
				var vertex = getSimilarVertex(v);
				var uv = calculateUVForSide(side, vertex);
				surfaceTool.set_uv(uv);

				var vt = Vector3(vertex.x * _scale, vertex.z * _scale, -vertex.y * _scale) - _offset;
				var sg = -1 if side.smoothing_groups == 0 else int(side.smoothing_groups);
				
				surfaceTool.set_smooth_group(sg);
				surfaceTool.add_vertex(vt);
				index += 1;

			for i in range(1, vertex_count - 1):
				surfaceTool.add_index(base_index);
				surfaceTool.add_index(base_index + i);
				surfaceTool.add_index(base_index + i + 1);

		var targetMaterial = sides[0].side.material;

		if _textureImportMode == VMTManager.TextureImportMode.COLLATE_BY_NAME:
			var loadedMaterial = VMTManager.getMaterialFromProject(targetMaterial);
			var materialToSet = loadedMaterial if loadedMaterial else _fallbackMaterial;
			surfaceTool.set_material(materialToSet);

		elif _textureImportMode == VMTManager.TextureImportMode.IMPORT_DIRECTLY:
			var material = VMTManager.importMaterial(targetMaterial);
			if material:
				surfaceTool.set_material(material);

		surfaceTool.deindex();
		surfaceTool.generate_normals();
		surfaceTool.generate_tangents();
		surfaceTool.commit(mesh);

	elapsedTime = Time.get_ticks_msec() - elapsedTime;

	if elapsedTime > 100:
		VMFLogger.warn("Mesh generation took " + str(elapsedTime) + "ms");

	return mesh;

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

	var mesh = VMFNode.createMesh(_structure);

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
	var elapsedTime = Time.get_ticks_msec();

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
					if not list.has(side.material):
						list.append(side.material);

	for material in list:
		VMTManager.preloadMaterial(material);

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
