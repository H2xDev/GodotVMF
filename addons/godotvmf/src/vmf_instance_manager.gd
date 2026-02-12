class_name VMFInstanceManager extends RefCounted

static var instances_cache = {};
static var last_cache_changed = 0;

static func get_instance_path(entity: Dictionary) -> String:
	var instance_path = entity.file.replace(".vmf", "") + '.vmf'; # Ensure the path ends with .vmf
	var intance_filename = instance_path.get_file(); 
	var map_base_folder = entity.vmf.get_base_dir() if "vmf" in entity else "";
	var maps_folder := str(VMFConfig.gameinfo_path).path_join('maps');
	var mapsrc_folder := str(VMFConfig.gameinfo_path).path_join('mapsrc');

	var instance_paths := [
		map_base_folder.path_join('instances').path_join(intance_filename),
		map_base_folder.path_join(intance_filename),
		map_base_folder.path_join('instances').path_join(instance_path),
		map_base_folder.path_join(instance_path),
		maps_folder.path_join('instances').path_join(instance_path),
		maps_folder.path_join(instance_path),
		mapsrc_folder.path_join('instances').path_join(instance_path),
		mapsrc_folder.path_join(instance_path)
	];

	for path: String in instance_paths:
		if FileAccess.file_exists(path):
			return path;

	return '';

static func get_subinstances(structure: Dictionary, entity_source: Dictionary) -> Array:
	if not structure.has('entity'):
		return [];

	var entities = structure.entity \
			if structure.entity is Array \
			else [structure.entity];
	
	var subinstances = [];

	for entity in entities:
		if entity.classname == 'func_instance':
			entity.vmf = entity_source.file;
			subinstances.append(entity);

	return subinstances;

static func load_instance(instance_path: String):
	if not ResourceLoader.exists(instance_path):
		VMFLogger.error("Failed to find instance file: %s" % instance_path);
		return;

	var cached_value := VMFCache.get_cached(instance_path);
	if cached_value: return cached_value;

	var scn := ResourceLoader.load(instance_path);

	VMFCache.add_cached(instance_path, scn);

	if not scn:
		VMFLogger.error("Failed to load instance resource: %s" % instance_path);
		return;

	return scn;

static func import_instance(entity: Dictionary):
	var instances_folder: String = VMFConfig.import.instances_folder;
	var instance_vmf_file = get_instance_path(entity);

	if instance_vmf_file == '':
		VMFLogger.error("Failed to find instance file for entity: %s" % entity.file);
		return;

	var instance_name = instance_vmf_file.get_file().replace(".vmf", "");
	var map_path = entity.vmf.get_base_dir() if "vmf" in entity else "unknown_map";
	var relative_instance_path := instance_vmf_file.replace(".vmf", ".scn").replace(map_path + "/", "").replace("instances/", "") as String;
	var instance_scene_path := VMFConfig.import.instances_folder.path_join(relative_instance_path);

	var is_instance_already_imported := FileAccess.file_exists(instance_scene_path);
	if is_instance_already_imported: return load_instance(instance_scene_path);

	var structure = VDFParser.parse(instance_vmf_file);
	var subinstances = get_subinstances(structure, entity);

	if subinstances.size() > 0:
		for subinstance in subinstances:
			import_instance(subinstance);

	var scn := PackedScene.new();
	var node := VMFNode.new();

	node.set_meta("instance", true);
	node.vmf = instance_vmf_file;
	node.name = instance_name + '_instance';
	node.save_geometry = false;
	node.save_collision = false;
	node.import_map();

	scn.pack(node);

	var dir := instance_scene_path.get_base_dir();
	if not DirAccess.dir_exists_absolute(dir):
		DirAccess.make_dir_recursive_absolute(dir);

	var err := ResourceSaver.save(scn, instance_scene_path, ResourceSaver.FLAG_COMPRESS);
	if err:
		VMFLogger.error("Failed to save instance resource: %s" % err);
		return;
	
	node.queue_free();
	
	return load_instance(instance_scene_path);
