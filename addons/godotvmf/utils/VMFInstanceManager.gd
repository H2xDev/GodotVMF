class_name VMFInstanceManager extends RefCounted;

static func correctInstancePath(e, mainVmfPath: String) -> String:
	var instancePath = e.file.get_file().get_basename() + '.vmf'
	var mapBaseFolder := mainVmfPath.get_base_dir();
	var mapsFolder := str(VMFConfig.config.gameInfoPath).path_join('maps');
	var mapsrcFolder := str(VMFConfig.config.gameInfoPath).path_join('mapsrc');
	
	var instancePaths := [
		mapBaseFolder.path_join('instances').path_join(instancePath),
		mapBaseFolder.path_join(instancePath),
		mapsFolder.path_join('instances').path_join(instancePath),
		mapsFolder.path_join(instancePath),
		mapsrcFolder.path_join('instances').path_join(instancePath),
		mapsrcFolder.path_join(instancePath)
	];
	
	for path: String in instancePaths:
		if FileAccess.file_exists(path):
			return path;

	return '';

static func importInstance(file: String, vmfNode: Node):
	var instancesFolder: String = VMFConfig.config.import.instancesFolder;

	var filename := file.get_file().get_basename();
	var dir := ProjectSettings.globalize_path(instancesFolder);
	var path := dir + "/" + filename + ".tscn";

	if FileAccess.file_exists(path):
		return;

	var scn := PackedScene.new();
	var node := VMFNode.new();
	node.vmf = file;
	node.name = filename + '_instance';
	node._owner = node;
	node.importMap();
	node.set_editable_instance(node, true);

	scn.pack(node);

	if not DirAccess.dir_exists_absolute(dir):
		DirAccess.make_dir_recursive_absolute(dir);

	var err := ResourceSaver.save(scn, path);
	if err:
		VMFLogger.error("Failed to save instance resource: %s" % err);
		return;
	
	node.queue_free();
