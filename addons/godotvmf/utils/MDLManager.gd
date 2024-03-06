class_name MDLManager;

static var _modelCache = [];
static var logged = {};
static var cache = {};

static func clearCache():
	MDLManager.cache = {};
	MDLManager.logged = {};

static func getModelMaterials(modelPath: String):
	var input = (VMFConfig.config.gameInfoPath + '/' + modelPath).replace('//', '/');
	MDLManager.logged = {} if not MDLManager.logged else MDLManager.logged;

	var h = hash(modelPath);

	if not FileAccess.file_exists(input):
		if not h in logged:
			VMFLogger.warn('Model not found: ' + input);
			logged[h] = true;
		return [];

	var file = FileAccess.open(input, FileAccess.READ);
	file.seek(204); ## Skip til textureCount;
	var textureCount = file.get_32();
	var textureOffset = file.get_32();
	var textureDirCount = file.get_32();
	var textureDirOffset = file.get_32();

	var materials = [];
	var dirOffsets = [];
	var dirs = [];
	
	file.seek(textureDirOffset);
	file.seek(file.get_32());
	for i in range(textureDirCount):
		var bytes = PackedByteArray();
		var currentByte = file.get_8();

		while (currentByte != 0):
			bytes.append(currentByte);
			currentByte = file.get_8();
		
		var dir = bytes.get_string_from_ascii();
		if dir: dirs.append(dir);

	file.seek(textureOffset);

	for i in range(textureCount):
		var mstudiotextureOffset = textureOffset + 64 * i;
		file.seek(mstudiotextureOffset);
		
		var nameOffset = file.get_32();
		file.seek(mstudiotextureOffset + nameOffset);
		
		var bytes = PackedByteArray();
		var currentByte = file.get_8();

		while (currentByte != 0):
			bytes.append(currentByte);
			currentByte = file.get_8();
		
		var name = bytes.get_string_from_ascii();
		
		for path in dirs:
			materials.append(path + name);
			
	file.close();

	return materials;


static func loadModel(modelPath: String, generateCollision: bool = false):
	var input = (VMFConfig.config.gameInfoPath + '/' + modelPath).replace('//', '/');
	var resourcePath = (VMFConfig.config.models.targetFolder + '/' + input.split('models/')[-1]).replace('.mdl', '.tscn');

	MDLManager.logged = {} if not MDLManager.logged else MDLManager.logged;
	MDLManager.cache = {} if not MDLManager.cache else MDLManager.cache;

	var output = input.replace('.mdl', '.obj');
	var resourceFolder = '/'.join(resourcePath.split('/').slice(0, -1));

	var h = hash(modelPath);

	if not FileAccess.file_exists(input):
		if not h in logged:
			VMFLogger.warn('Model not found: ' + input);
			logged[h] = true;
		return;

	if h in MDLManager.cache:
		return MDLManager.cache[h]

	if ResourceLoader.exists(resourcePath):
		var res = load(resourcePath);
		MDLManager.cache[h] = res;
		return res;

	var materials = getModelMaterials(modelPath)\
	.map(
		func (materialPath):
			VTFTool.importMaterial(materialPath, true);
			return VTFTool.getMaterial(materialPath);
	)\
	.filter(func(material): return material != null);

	var processOut = [];
	var executable = ProjectSettings.globalize_path(VMFConfig.config.mdl2obj) if VMFConfig.config.mdl2obj.begins_with("res:") else VMFConfig.config.mdl2obj;
	var process = OS.execute(executable, [input, output], processOut, false, false);
	var mesh = ObjParse.load_obj(output);
	DirAccess.remove_absolute(output);

	var scene = PackedScene.new();
	var root = Node3D.new();
	var model = MeshInstance3D.new();

	root.name = modelPath.get_file().get_basename();
	model.name = modelPath.get_file().get_basename() + '_mesh';
	model.set_mesh(mesh);
	root.add_child(model);
	
	model.set_owner(root);

	var matIndex = 0;
	for material in materials:
		mesh.surface_set_material(matIndex, material);
		matIndex += 1;

	if generateCollision:
		model.create_multiple_convex_collisions();

	scene.pack(root);

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(resourceFolder));
	ResourceSaver.save(scene, resourcePath);

	model.queue_free();
	root.queue_free();

	scene.take_over_path(resourcePath);

	MDLManager.cache[h] = scene;
	
	return scene;
