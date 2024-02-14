class_name MDLManager;

static var _modelCache = [];

static var projectConfig:
	get:
		return VMFConfig.getConfig();

static func getModelMaterials(modelPath: String):
	var input = (projectConfig.gameInfoPath + '/' + modelPath).replace('//', '/');

	if not FileAccess.file_exists(input):
		VMFLogger.warn('Model not found: ' + input);
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
	for i in range(textureDirCount):
		var offset = file.get_32();
		file.seek(offset);
		var dir = file.get_buffer(64).get_string_from_ascii().replace('\\', '/');
		dirs.append(dir);

	file.seek(textureOffset);

	for i in range(textureCount):
		var nameOffset = textureOffset + 64 * i + file.get_32();
		
		file.seek(nameOffset);
		var name = file.get_buffer(64).get_string_from_ascii();
		
		for path in dirs:
			materials.append(path + name);

	file.close();

	return materials;


static func loadModel(modelPath: String, generateCollision: bool = false, override: bool = false):
	var input = (projectConfig.gameInfoPath + '/' + modelPath).replace('//', '/');
	var resourcePath = (projectConfig.modelsFolder + '/' + input.split('models/')[-1]).replace('.mdl', '.tscn');
	var output = input.replace('.mdl', '.obj');
	var resourceFolder = '/'.join(resourcePath.split('/').slice(0, -1));

	if not "mdl2obj" in projectConfig:
		VMFLogger.error('MDL2OBJ not set in vmf.config.json, model import skipped');
		return;

	if not FileAccess.file_exists(projectConfig.mdl2obj):
		VMFLogger.error('MDL2OBJ not found, model import skipped');
		return;

	if not FileAccess.file_exists(input):
		VMFLogger.warn('Model not found: ' + input);
		return;

	if ResourceLoader.exists(resourcePath) and not override:
		return load(resourcePath);

	var materials = getModelMaterials(modelPath);
	var materialPath = materials[0] if materials.size() > 0 else null;
	var material = VMTManager.importMaterial(materialPath, true) if materialPath else null;

	var processOut = [];
	var process = OS.execute(projectConfig.mdl2obj, [input, output], processOut, false, false);
	var mesh = ObjParse.load_obj(output);
	DirAccess.remove_absolute(output);

	if material:
		mesh.surface_set_material(0, material);

	var scene = PackedScene.new();
	var root = Node3D.new();
	var model = MeshInstance3D.new();

	model.set_mesh(mesh);

	root.add_child(model);
	model.set_owner(root);

	if generateCollision:
		model.create_multiple_convex_collisions();


	scene.pack(root);
	print('Saving into ', resourcePath);

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(resourceFolder));
	ResourceSaver.save(scene, resourcePath);

	VMFLogger.log('MDL Imported: ' + input);
	VMFLogger.log('MDL Log:\n' + '\n'.join(processOut));

	return load(resourcePath);
