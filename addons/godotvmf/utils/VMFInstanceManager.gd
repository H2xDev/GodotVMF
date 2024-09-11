class_name VMFInstanceManager extends RefCounted;

static func get_instance_path(entity: Dictionary) -> String:
	var instance_path = entity.file.get_file().get_basename() + '.vmf';
	var map_base_folder = entity.vmf.get_base_dir() if "vmf" in entity else "";
	var maps_folder := str(VMFConfig.config.gameInfoPath).path_join('maps');
	var mapsrc_folder := str(VMFConfig.config.gameInfoPath).path_join('mapsrc');

	var instance_paths := [
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

static func get_imported_instance_path(instance_name: String):
	var folder: String = VMFConfig.config.import.instancesFolder;
	var dir := ProjectSettings.globalize_path(folder);
	return dir + "/" + instance_name + ".tscn";

static func load_instance(instance_name: String):
	if not is_instance_exists(instance_name):
		VMFLogger.error("Failed to find instance file: %s" % instance_name);
		return;

	var path = get_imported_instance_path(instance_name);
	var scn := ResourceLoader.load(path);

	if not scn:
		VMFLogger.error("Failed to load instance resource: %s" % path);
		return;

	return scn;
	
static func is_instance_exists(instance_name: String):
	var path = get_imported_instance_path(instance_name);
	
	return FileAccess.file_exists(path);

static func import_instance(entity: Dictionary):
	var instances_folder: String = VMFConfig.config.import.instancesFolder;
	var file = get_instance_path(entity);

	if file == '':
		VMFLogger.error("Failed to find instance file for entity: %s" % entity.file);
		return;

	var filename := file.get_file().get_basename();
	var dir := ProjectSettings.globalize_path(instances_folder);
	var path := dir + "/" + filename + ".tscn";
	var is_instance_already_imported := FileAccess.file_exists(path);

	if is_instance_already_imported: return load_instance(filename);

	var structure = ValveFormatParser.parse(file);
	var subinstances = get_subinstances(structure, entity);

	if subinstances.size() > 0:
		for subinstance in subinstances:
			import_instance(subinstance);

	var scn := PackedScene.new();
	var node := VMFNode.new();

	node.vmf = file;
	node.name = filename + '_instance';
	node.save_geometry = false;
	node.save_collision = false;
	node.ignore_global_import = true;
	node.import_map();

	scn.pack(node);

	if not DirAccess.dir_exists_absolute(dir):
		DirAccess.make_dir_recursive_absolute(dir);

	var err := ResourceSaver.save(scn, path);
	if err:
		VMFLogger.error("Failed to save instance resource: %s" % err);
		return;
	
	node.queue_free();
	
	return load_instance(filename);
