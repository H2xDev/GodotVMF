class_name VMTWatcher extends RefCounted

var config:
	get: return VMFConfig;

var mod_materials_folder:
	get: return _path_join(config.gameinfo_path, "materials");

var eplugin = null;

var current_timer = null;
var project_materials = {};
var project_textures = {};
var is_in_process = false;
var debug_mode = false;

var checksums_data = {
	"material_checksums": {},
	"texture_checksums": {},
};

var material_checksums:
	get: return checksums_data.material_checksums;

var texture_checksums:
	get: return checksums_data.texture_checksums;

const CHECKSUM_FILE = "res://addons/godotvmf/texture_checksums.json";
const VTFCMD_COMMAND = "-file \"{0}\" -silent -version 7.1";

func _path_join(pathA: String, pathB: String):
	var a = pathA if pathA.ends_with("/") else pathA + "/";
	var b = pathB if not pathB.begins_with("/") else pathB.substr(1, -1);

	return a + b;

func _update_checksum_file():
	var file = FileAccess.open(CHECKSUM_FILE, FileAccess.WRITE);
	file.store_string(JSON.stringify(checksums_data, "\t"));
	file.close();

func _create_watcher_structure():
	var fs = EditorInterface.get_resource_filesystem();
	fs.filesystem_changed.connect(_debounce);

	checksums_data = {
		"material_checksums": {},
		"texture_checksums": {},
	};

	if FileAccess.file_exists(CHECKSUM_FILE):
		var file = FileAccess.open(CHECKSUM_FILE, FileAccess.READ);
		checksums_data = JSON.parse_string(file.get_as_text());
		file.close();

	_preload_resources();
	_recheck_resources();
	_collect_texture_checksums();

	VMFLogger.log("Material watcher initialized");

func _begin_watch(eplugin_instance: EditorPlugin):
	eplugin = eplugin_instance;
	
	call_deferred("_create_watcher_structure");

func _stop_watch(eplugin_instance: EditorPlugin):
	var fs = EditorInterface.get_resource_filesystem();
	fs.filesystem_changed.disconnect(_debounce);

func _debounce():
	if current_timer:
		current_timer.stop();
		current_timer.queue_free();
		current_timer = null;

	current_timer = Timer.new();
	current_timer.wait_time = 0.5;
	current_timer.one_shot = true;
	current_timer.autostart = true;
	current_timer.timeout.connect(_recheck_resources);

	eplugin.add_child(current_timer);
	current_timer.start();

func _get_texture_checksum(material_path: String):
	var key = material_path.replace(config.materials.target_folder, "");
	var material = project_materials.get(key, null);

	if not material:
		return null;

	var res_path = material.albedo_texture.resource_path if material.albedo_texture else null;
	return FileAccess.get_md5(material_path) if res_path && res_path.contains('::') else FileAccess.get_md5(res_path);

func _collect_texture_checksums():
	for texture_key in project_textures.keys():
		var file = _path_join(config.materials.target_folder, texture_key);
		texture_checksums[texture_key] = FileAccess.get_md5(file);
		_update_checksum_file();

func _preload_resources():
	var materials_folder = config.materials.target_folder;
	var time = Time.get_ticks_msec();

	var resources = get_all_files(materials_folder, "tres");
	resources.append_array(get_all_files(materials_folder, "png"));
	resources.append_array(get_all_files(materials_folder, "jpg"));

	var elapsed = Time.get_ticks_msec() - time;

	for file in resources:
		var key = file.replace(config.materials.target_folder, "");
		var data = project_materials.get(key, project_textures.get(key, ResourceLoader.load(file)));

		if not data:
			continue;

		if data is Material:
			project_materials = project_materials if project_materials else {};
			project_materials[key] = data;

	for key in project_materials.keys():
		var material = project_materials[key];
		var texture = material.albedo_texture if "albedo_texture" in material and material.albedo_texture is Resource else null;

		if not texture: continue;

		var basetexture = texture.resource_path.replace(config.materials.target_folder, '');

		project_textures[basetexture] = texture;

func _recheck_materials():
	for key in project_materials.keys():
		var file = _path_join(config.materials.target_folder, key);

		if not FileAccess.file_exists(file):
			_on_material_removed(file);

	for key in project_materials.keys():
		var file = _path_join(config.materials.target_folder, key);
		var vmt_file = _to_target_path(file).replace(".tres", ".vmt");

		var oldcheckSum = material_checksums.get(key, null);
		material_checksums[key] = FileAccess.get_md5(file);
		_update_checksum_file();

		if not FileAccess.file_exists(vmt_file):
			_on_material_added(file);
		elif oldcheckSum != material_checksums.get(key, null):
			if oldcheckSum == null:
				_on_material_added(file);
			else:
				_on_material_changed(file);

func _recheck_textures():
	for key in project_textures.keys():
		var file = _path_join(config.materials.target_folder, key);
		var vtf_file = ProjectSettings.globalize_path(_to_target_path(file).split(".")[0] + ".vtf");

		if not FileAccess.file_exists(ProjectSettings.globalize_path(file)):
			DirAccess.remove_absolute(vtf_file);
			texture_checksums.erase(key);
			_update_checksum_file();
			continue;

		var oldcheckSum = texture_checksums.get(key, null);
		texture_checksums[key] = FileAccess.get_md5(file);
		_update_checksum_file();

		if not FileAccess.file_exists(vtf_file):
			_update_vtf(file)
		elif oldcheckSum != texture_checksums.get(key, null):
			_update_vtf(file);

func _recheck_resources(_null = null):
	if is_in_process:
		return;

	VMFConfig.load_config();

	is_in_process = true;
	
	_preload_resources();
	_recheck_materials();
	_recheck_textures();

	is_in_process = false;

func _on_material_added(file: String):
	var materialKey = file.replace(config.materials.target_folder, "");
	var vmt_file = _to_target_path(file).replace(".tres", ".vmt");
	var materialData = project_materials.get(materialKey, null);
	var basetexture;

	if "albedo_texture" in materialData:
		basetexture = materialData.albedo_texture.resource_path if materialData and materialData.albedo_texture else 'no_texture';
	else:
		basetexture = 'no_texture';

	var path = vmt_file.get_base_dir();

	if not materialData:
		materialData = ResourceLoader.load(file);
		project_materials[materialKey] = materialData;

	if basetexture != 'no_texture':
		var textureKey = basetexture.replace(config.materials.target_folder, '');

		if not textureKey in project_textures:
			var texture = ResourceLoader.load(basetexture);
			project_textures[textureKey] = texture;
			_recheck_textures();

	DirAccess.make_dir_recursive_absolute(path);

	var vmt = FileAccess.open(vmt_file, FileAccess.WRITE);

	if not vmt:
		VMFLogger.error("Failed to create VMT file: " + vmt_file);
		return;

	if not basetexture:
		VMFLogger.error("Failed to get basetexture for material: " + file);
		return;

	basetexture = basetexture\
		.replace(config.materials.target_folder, "") \
		.split(".")[0] \
		.substr(1, -1);

	vmt.store_string("\"LightmappedGeneric\"\n{\n");
	vmt.store_string("\t\"$basetexture\" \"" + basetexture + "\"\n");
	vmt.store_string("}");
	vmt.close();
	
	VMFLogger.log("Material added: " + file);

func _on_material_removed(file: String):
	var materialKey = file.replace(config.materials.target_folder, "");

	var vmt_file = _to_target_path(file).replace(".tres", ".vmt");
	var vtf_file = vmt_file.replace(".vmt", ".vtf");

	material_checksums.erase(materialKey);
	_update_checksum_file();

	project_materials.erase(materialKey);

	if FileAccess.file_exists(vmt_file):
		DirAccess.remove_absolute(vmt_file);
	
	if FileAccess.file_exists(vtf_file):
		DirAccess.remove_absolute(vtf_file);

	VMFLogger.log("Material removed: " + file);

func _on_material_changed(file: String):
	_on_material_added(file);

	VMFLogger.log("Material changed: " + file);

func _get_basetexture(material: Material):
	if not material:
		return null;

	var albedo = material.albedo_texture.resource_path if material.albedo_texture else material.resource_path;

	if not albedo:
		return null;

	return albedo.replace(config.materials.target_folder, "").get_basename();

func _to_target_path(path: String):
	return path\
			.replace(config.materials.target_folder, mod_materials_folder)\
			.replace(ProjectSettings.globalize_path(config.materials.target_folder), mod_materials_folder);

func _update_vtf(file: String):
	var elapsed_time = Time.get_ticks_msec();

	var key = ProjectSettings.localize_path(file).replace(config.materials.target_folder, "");
	var texture = project_textures.get(key, null);

	var vtf_file = ProjectSettings.globalize_path(_to_target_path(file).split(".")[0] + ".vtf");
	var png_file = vtf_file.replace(".vtf", ".png");

	var vtfcmd = ProjectSettings.globalize_path(config.vtfcmd);
	var path = vtf_file.get_base_dir();

	if not texture:
		VMFLogger.error("Texture not found: " + key);
		return;

	var file_to_convert = texture.resource_path if texture.resource_path.get_extension() != "tres" else png_file;

	DirAccess.make_dir_recursive_absolute(path);

	if not vtfcmd or not FileAccess.file_exists(vtfcmd):
		VMFLogger.error("vtfcmd not specified in config or doesnt exist: " + vtfcmd);
	else:
		# NOTE: In case the texture is in internal format, we need to save it as PNG first and then convert it to VTF.
		var isTres = texture.resource_path.get_extension() == "tres";
		if isTres:
			if debug_mode:
				print("Saving texture as PNG: " + png_file);
			texture.get_image().save_png(png_file);

		var is_width_power_of_two = (texture.get_width() & (texture.get_width() - 1)) == 0;
		var is_height_power_of_two = (texture.get_height() & (texture.get_height() - 1)) == 0;

		if not is_width_power_of_two or not is_height_power_of_two:
			return VMFLogger.error("Texture size is not power of two. Sync of this file aborted: " + key);

		if file_to_convert.begins_with("res://"):
			file_to_convert = ProjectSettings.globalize_path(file_to_convert);

		var params = [file_to_convert];
		var out_vtf = file_to_convert.replace("." + file_to_convert.get_extension(), ".vtf");

		var args = VTFCMD_COMMAND.format(params).split(' ');
		if debug_mode:
			print("Running VTF command: " + vtfcmd + " " + " ".join(args));

		var exitCode = OS.execute(vtfcmd, args);

		if isTres:
			DirAccess.remove_absolute(png_file);
		else:
			DirAccess.rename_absolute(out_vtf, vtf_file);

		VMFLogger.log("VTF creates/updated: " + vtf_file);

	elapsed_time = Time.get_ticks_msec() - elapsed_time;

	if debug_mode:
		print("VTF conversion took: " + str(elapsed_time) + "ms");
	return;

## Credit: https://gist.github.com/hiulit/772b8784436898fd7f942750ad99e33e
##         by Github users @hiulit and @RedwanFox
func get_all_files(path: String, file_ext := "", files := []):
	var dir = DirAccess.open(path)

	if DirAccess.get_open_error() == OK:
		dir.list_dir_begin()

		var file_name = dir.get_next()

		while file_name != "":
			if dir.current_is_dir():
				files = get_all_files(dir.get_current_dir() +"/"+ file_name, file_ext, files)
			else:
				if file_ext and file_name.get_extension() != file_ext:
					file_name = dir.get_next()
					continue
				
				files.append(dir.get_current_dir() +"/"+ file_name)

			file_name = dir.get_next()
	else:
		VMFLogger.error("An error occurred when trying to access %s." % path);

	return files;
