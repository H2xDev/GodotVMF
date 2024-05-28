class_name VMFWatcher

var config:
	get: return VMFConfig.config;

var modMaterialsFolder:
	get: return (config.gameInfoPath + "/materials").replace("\\", "/").replace("//", "/");

var eplugin = null;

var currentTimer = null;
var projectMaterials = {};
var projectTextures = {};
var isInProcess = false;

var checksumsData = {
	"materialChecksums": {},
	"textureChecksums": {},
};

var materialChecksums:
	get: return checksumsData.materialChecksums;

var textureChecksums:
	get: return checksumsData.textureChecksums;

const CHECKSUM_FILE = "res://addons/godotvmf/texture_checksums.json";
const VTFCMD_COMMAND = "-file \"{0}\" -silent -version 7.1";

func _update_checksum_file():
	var file = FileAccess.open(CHECKSUM_FILE, FileAccess.WRITE);
	file.store_string(JSON.stringify(checksumsData, "\t"));
	file.close();

func _begin_watch(epluginInstance: EditorPlugin):
	eplugin = epluginInstance;

	var fs = eplugin.get_editor_interface().get_resource_filesystem();
	fs.filesystem_changed.connect(_debounce);

	checksumsData = {
		"materialChecksums": {},
		"textureChecksums": {},
	};

	if FileAccess.file_exists(CHECKSUM_FILE):
		var file = FileAccess.open(CHECKSUM_FILE, FileAccess.READ);
		checksumsData = JSON.parse_string(file.get_as_text());
		file.close();

	_preload_resources();
	_recheck_resources();
	_collect_texture_checksums();

func _stop_watch(epluginInstance: EditorPlugin):
	var fs = epluginInstance.get_editor_interface().get_resource_filesystem();
	fs.filesystem_changed.disconnect(_debounce);

func _debounce():
	if currentTimer:
		currentTimer.stop();
		currentTimer.queue_free();
		currentTimer = null;

	currentTimer = Timer.new();
	currentTimer.wait_time = 0.5;
	currentTimer.one_shot = true;
	currentTimer.autostart = true;
	currentTimer.timeout.connect(_recheck_resources);

	eplugin.add_child(currentTimer);
	currentTimer.start();

func _get_texture_checksum(materialPath: String):
	var key = materialPath.replace(config.material.targetFolder, "");
	var material = projectMaterials.get(key, null);

	if not material:
		return null;

	var resPath = material.albedo_texture.resource_path if material.albedo_texture else null;
	return FileAccess.get_md5(materialPath) if resPath && resPath.contains('::') else FileAccess.get_md5(resPath);

func _collect_texture_checksums():
	for textureKey in projectTextures.keys():
		var file = (config.material.targetFolder + '/' + textureKey).replace("//", "/").replace("res:/", "res://");
		textureChecksums[textureKey] = FileAccess.get_md5(file);
		_update_checksum_file();

func _preload_resources():
	var materialsFolder = config.material.targetFolder;
	var time = Time.get_ticks_msec();
	var resources = get_all_files(materialsFolder, "tres");
	resources.append_array(get_all_files(materialsFolder, "png"));
	resources.append_array(get_all_files(materialsFolder, "jpg"));
	var elapsed = Time.get_ticks_msec() - time;

	print("Preloading resources took: " + str(elapsed) + "ms");

	for file in resources:
		var key = file.replace(config.material.targetFolder, "");
		var data = projectMaterials.get(key, projectTextures.get(key, ResourceLoader.load(file)));

		if not data:
			continue;

		if data is Material:
			projectMaterials = projectMaterials if projectMaterials else {};
			projectMaterials[key] = data;

	for key in projectMaterials.keys():
		var material = projectMaterials[key];
		var texture = material.albedo_texture if "albedo_texture" in material and material.albedo_texture is Resource else null;

		if not texture: continue;

		var basetexture = texture.resource_path.replace(config.material.targetFolder, '');

		projectTextures[basetexture] = texture;

func _recheck_materials():
	for key in projectMaterials.keys():
		var file = (config.material.targetFolder + '/' + key).replace("//", "/").replace("res:/", "res://");

		if not FileAccess.file_exists(file):
			_on_material_removed(file);

	for key in projectMaterials.keys():
		var file = (config.material.targetFolder + '/' + key).replace("//", "/").replace("res:/", "res://");
		var vmtFile = file.replace(config.material.targetFolder, modMaterialsFolder).replace(".tres", ".vmt");

		var oldcheckSum = materialChecksums.get(key, null);
		materialChecksums[key] = FileAccess.get_md5(file);
		_update_checksum_file();

		if not FileAccess.file_exists(vmtFile):
			_on_material_added(file);
		elif oldcheckSum != materialChecksums.get(key, null):
			if oldcheckSum == null:
				_on_material_added(file);
			else:
				_on_material_changed(file);

func _recheck_textures():
	for key in projectTextures.keys():
		var file = (config.material.targetFolder + '/' + key).replace("//", "/").replace("res:/", "res://");
		var vtfFile = file.replace(config.material.targetFolder, modMaterialsFolder).replace(".tres", ".vtf").replace('.png', '.vtf').replace('.jpg', '.vtf');

		if not FileAccess.file_exists(file):
			DirAccess.remove_absolute(file.replace(".tres", ".vtf").replace(config.material.targetFolder, modMaterialsFolder));
			textureChecksums.erase(key);
			_update_checksum_file();
			continue;

		if not FileAccess.file_exists(vtfFile):
			_update_vtf(file);

		var oldcheckSum = textureChecksums.get(key, null);
		textureChecksums[key] = FileAccess.get_md5(file);
		_update_checksum_file();

		if oldcheckSum != textureChecksums.get(key, null):
			_update_vtf(file);

func _recheck_resources(_null = null):
	if isInProcess:
		return;

	VMFConfig.checkProjectConfig();

	if config.material.importMode != VTFTool.TextureImportMode.SYNC:
		return;

	isInProcess = true;
	
	_preload_resources();
	_recheck_materials();
	_recheck_textures();

	isInProcess = false;

func _on_material_added(file: String):
	var materialKey = file.replace(config.material.targetFolder, "");
	var vmtFile = file.replace(config.material.targetFolder, modMaterialsFolder).replace(".tres", ".vmt");
	var materialData = projectMaterials.get(materialKey, null);
	var basetexture;

	if "albedo_texture" in materialData:
		basetexture = materialData.albedo_texture.resource_path if materialData and materialData.albedo_texture else 'no_texture';
	else:
		basetexture = 'no_texture';

	var path = vmtFile.get_base_dir();

	if not materialData:
		materialData = ResourceLoader.load(file);
		projectMaterials[materialKey] = materialData;

	if basetexture != 'no_texture':
		var textureKey = basetexture.replace(config.material.targetFolder, '');

		if not textureKey in projectTextures:
			var texture = ResourceLoader.load(basetexture);
			projectTextures[textureKey] = texture;
			_recheck_textures();

	DirAccess.make_dir_recursive_absolute(path);

	var vmt = FileAccess.open(vmtFile, FileAccess.WRITE);

	if not vmt:
		VMFLogger.error("Failed to create VMT file: " + vmtFile);
		return;

	if not basetexture:
		VMFLogger.error("Failed to get basetexture for material: " + file);
		return;

	basetexture = basetexture\
		.replace(config.material.targetFolder, "") \
		.split(".")[0] \
		.substr(1, -1);

	vmt.store_string("\"LightmappedGeneric\"\n{\n");
	vmt.store_string("\t\"$basetexture\" \"" + basetexture + "\"\n");
	vmt.store_string("}");
	vmt.close();
	
	VMFLogger.log("Material added: " + file);

func _on_material_removed(file: String):
	var materialKey = file.replace(config.material.targetFolder, "");

	var vmtFile = file.replace(config.material.targetFolder, modMaterialsFolder).replace(".tres", ".vmt");
	var vtfFile = vmtFile.replace(".vmt", ".vtf");

	materialChecksums.erase(materialKey);
	_update_checksum_file();

	projectMaterials.erase(materialKey);

	if FileAccess.file_exists(vmtFile):
		DirAccess.remove_absolute(vmtFile);
	
	if FileAccess.file_exists(vtfFile):
		DirAccess.remove_absolute(vtfFile);

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

	return albedo.replace(config.material.targetFolder, "").get_basename();

func _update_vtf(file: String):
	var key = file.replace(config.material.targetFolder, "");
	var texture = projectTextures.get(key, null);

	var vtfFile = file.replace(config.material.targetFolder, modMaterialsFolder).split('.')[0] + ".vtf";
	var pngFile = vtfFile.replace(".vtf", ".png");

	var vtfcmd = config.get("vtfcmd", null);
	var path = vtfFile.get_base_dir();

	if not texture:
		VMFLogger.error("Texture not found: " + key);
		return;

	var fileToConvert = texture.resource_path if texture.resource_path.get_extension() != "tres" else pngFile;

	DirAccess.make_dir_recursive_absolute(path);

	if not vtfcmd or not FileAccess.file_exists(vtfcmd):
		VMFLogger.error("vtfcmd not specified in config or doesnt exist: " + vtfcmd);
	else:
		# NOTE: In case the texture is in internal format, we need to save it as PNG first and then convert it to VTF.
		var isTres = texture.resource_path.get_extension() == "tres";
		if isTres:
			texture.get_image().save_png(pngFile);

		# NOTE: Saving disk space by resizing the texture to 256x256 with the same aspect ratio.
		var aspect = float(texture.get_width()) / float(texture.get_height());

		if aspect == 0:
			VMFLogger.error("Invalid aspect ratio for texture: " + key);
			return;

		var isWidthPowerOfTwo = (texture.get_width() & (texture.get_width() - 1)) == 0;
		var isHeightPowerOfTwo = (texture.get_height() & (texture.get_height() - 1)) == 0;

		if not isWidthPowerOfTwo or not isHeightPowerOfTwo:
			return VMFLogger.error("Texture size is not power of two. Sync of this file aborted: " + key);

		if fileToConvert.begins_with("res://"):
			fileToConvert = ProjectSettings.globalize_path(fileToConvert);

		var params = [fileToConvert];
		var outVtf = fileToConvert.replace("." + fileToConvert.get_extension(), ".vtf");

		OS.execute(vtfcmd, VTFCMD_COMMAND.format(params).split(' '), [], false, false);

		if isTres: DirAccess.remove_absolute(pngFile);
		else: DirAccess.rename_absolute(outVtf, vtfFile);

		VMFLogger.log("VTF creates/updated: " + vtfFile);

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
		print("An error occurred when trying to access %s." % path);

	return files;

