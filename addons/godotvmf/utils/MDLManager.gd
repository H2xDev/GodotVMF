class_name MDLManager extends RefCounted;

static var _modelCache = [];
static var logged = {};
static var cache = {};

static func clear_cache():
	MDLManager.cache = {};
	MDLManager.logged = {};

static func get_model_materials(model_path: String):
	var input = (VMFConfig.config.gameInfoPath + '/' + model_path).replace('//', '/');
	MDLManager.logged = {} if not MDLManager.logged else MDLManager.logged;

	var h = hash(model_path);

	if not FileAccess.file_exists(input):
		if not h in logged:
			VMFLogger.warn('Model not found: ' + input);
			logged[h] = true;
		return [];

	var file = FileAccess.open(input, FileAccess.READ);
	file.seek(204); ## Skip til textureCount;
	var texture_count = file.get_32();
	var texture_offset = file.get_32();
	var texture_dir_count = file.get_32();
	var texture_dir_offset = file.get_32();

	var materials = [];
	var dirOffsets = [];
	var dirs = [];
	
	file.seek(texture_dir_offset);
	file.seek(file.get_32());
	for i in range(texture_dir_count):
		var bytes = PackedByteArray();
		var current_byte = file.get_8();

		while (current_byte != 0):
			bytes.append(current_byte);
			current_byte = file.get_8();
		
		var dir = bytes.get_string_from_ascii();
		if dir: dirs.append(dir);

	file.seek(texture_offset);

	for i in range(texture_count):
		var mstudio_texture_offset = texture_offset + 64 * i;
		file.seek(mstudio_texture_offset);
		
		var name_offset = file.get_32();
		file.seek(mstudio_texture_offset + name_offset);
		
		var bytes = PackedByteArray();
		var current_byte = file.get_8();

		while (current_byte != 0):
			bytes.append(current_byte);
			current_byte = file.get_8();
		
		var name = bytes.get_string_from_ascii();
		
		for path in dirs:
			materials.append(path + name);
			
	file.close();

	return materials;


static func load_model(model_path: String, generate_collision: bool = false, generate_lightmap_uv2: bool = false, lightmap_texel_size: float = 0.4):
	var input = (VMFConfig.config.gameInfoPath + '/' + model_path).replace('//', '/');
	var resource_path = (VMFConfig.config.models.targetFolder + '/' + input.split('models/')[-1]).replace('.mdl', '.tscn');

	MDLManager.logged = {} if not MDLManager.logged else MDLManager.logged;
	MDLManager.cache = {} if not MDLManager.cache else MDLManager.cache;

	var output = input.replace('.mdl', '.obj');
	var resourceFolder = '/'.join(resource_path.split('/').slice(0, -1));

	var h = hash(model_path);

	if not FileAccess.file_exists(input):
		if not h in logged:
			VMFLogger.warn('Model not found: ' + input);
			logged[h] = true;
		return;

	if h in MDLManager.cache:
		return MDLManager.cache[h]

	if ResourceLoader.exists(resource_path):
		var res = load(resource_path);
		
		if generate_lightmap_uv2:
			## ISSUE: PackedScene metadata is not saved #76366
			## We're doing it to store texel size and rebuild tscn on texel size change
			var file = FileAccess.open(resource_path.replace('.tscn', '.tscn_meta'), FileAccess.READ)

			if file:
				var meta = JSON.parse_string(file.get_line())
				
				if meta and 'lightmap_texel_size' in meta and meta['lightmap_texel_size'] == lightmap_texel_size:
					MDLManager.cache[h] = res;
					return res;
		else:
			MDLManager.cache[h] = res;
			return res;


	var materials = get_model_materials(model_path) \
	.map(
		func (materialPath):
			VTFTool.import_material(materialPath, true);
			return VTFTool.get_material(materialPath);
	) \
	.filter(func(material): return material != null);

	var process_out = [];
	var executable = ProjectSettings.globalize_path(VMFConfig.config.mdl2obj) if VMFConfig.config.mdl2obj.begins_with("res:") else VMFConfig.config.mdl2obj;
	var process = OS.execute(executable, [input, output], process_out, false, false);
	var mesh = ObjParse.load_obj(output);
	DirAccess.remove_absolute(output);

	var scene = PackedScene.new();
	var root = Node3D.new();
	var model = MeshInstance3D.new();

	root.name = model_path.get_file().get_basename();
	model.name = model_path.get_file().get_basename() + '_mesh';
	
	if generate_lightmap_uv2:
		mesh.lightmap_unwrap(model.global_transform, lightmap_texel_size);
		## Issue: PackedScene metadata is not saved #76366
		## We're doing it to store texel size and rebuild tscn on texel size change
		var tmp = { 'lightmap_texel_size': lightmap_texel_size }
		var file = FileAccess.open(resource_path.replace('.tscn', '.tscn_meta'), FileAccess.WRITE)

		if file:
			file.store_line(JSON.stringify(tmp))
	
	model.set_mesh(mesh);
	root.add_child(model);
	
	model.set_owner(root);

	var matIndex = 0;
	for material in materials:
		mesh.surface_set_material(matIndex, material);
		matIndex += 1;

	if generate_collision:
		model.create_multiple_convex_collisions();

	scene.pack(root);

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(resourceFolder));
	ResourceSaver.save(scene, resource_path);

	model.queue_free();
	root.queue_free();

	scene.take_over_path(resource_path);

	MDLManager.cache[h] = scene;
	
	return scene;
