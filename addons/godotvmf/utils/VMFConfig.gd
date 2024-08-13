class_name VMFConfig;

static var _config = null;

static var config:
	get:
		if not _config: reload();
		return _config;
	
static func _validate_keys(keyset: Array[String], dict, resFolders: Array[String] = [], section := '') -> bool:
	var missingKeys: Array[String] = [];

	for key: String in keyset:
		if not key in dict:
			missingKeys.append(key);

		if resFolders.has(key) and not dict[key].begins_with('res://'):
			VMFLogger.error('The folder of "{0}" {1} should be internal'.format([key, dict[key]]));
			return false;

	if missingKeys.size() > 0:
		var str = ", ".join(missingKeys);
		if not section:
			VMFLogger.error('vmf.config.json is missing keys: ' + str);
		else:
			VMFLogger.error('vmf.config.json is missing keys in section "' + section + '": ' + str);
		return false;

	return true;

static func validate_config() -> bool:
	var checkKeys: Array[String] = [
		"import",
		"material",
	];

	var modelsDefined: bool = "models" in config and config.models.import;
	var materialsDefined: bool = "materials" in config and config.materials.importMode == 2;

	if config.material.importMode == 3:
		checkKeys.append("vtfcmd");

		if not "vtfcmd" in _config:
			VMFLogger.error('VTFCmd.exe not defined. Material scan disabled');
			config.material.importMode = 1;
		elif not FileAccess.file_exists(_config.vtfcmd):
			VMFLogger.error('VTFCmd.exe not found at {0}. Material scan disabled'.format([_config.vtfcmd]));
			config.material.importMode = 1;

	if modelsDefined or materialsDefined:
		checkKeys.append("gameInfoPath");

	if modelsDefined:
		checkKeys.append("mdl2obj");
		
		if not FileAccess.file_exists(_config.mdl2obj):
			VMFLogger.error('mdl2obj not found at {0}. Model import disabled'.format([_config.mdl2obj]));
			config.models.import = false;

	if not _validate_keys(checkKeys, config):
		return false;

	checkKeys = [
		"scale",
		"generateCollision",
		"generateLightmapUV2",
		"lightmapTexelSize",
		"entitiesFolder",
		"instancesFolder",
		"geometryFolder",
	];

	if not _validate_keys(checkKeys, config.import, ['entitiesFolder', 'instancesFolder'], 'import'):
		return false;

	checkKeys = [
		"importMode",
		"ignore",
		"fallbackMaterial",
		"defaultTextureSize",
		"targetFolder",
	];

	if not _validate_keys(checkKeys, config.material, ['targetFolder'], 'material'):
		return false;
	
	if "models" in config:
		checkKeys = [
			"generateCollision",
			"targetFolder",
			"lightmapTexelSize",
		];

		if not _validate_keys(checkKeys, config.models, ['targetFolder'], 'models'):
			return false;

	return true;

static func reload() -> void:
	if not FileAccess.file_exists('res://vmf.config.json'):
		VMFLogger.error('vmf.config.json not found in project root');

	var file = FileAccess.open('res://vmf.config.json', FileAccess.READ);
	_config = JSON.parse_string(file.get_as_text());

	if not validate_config():
		_config = null;
		return;

	_config.material.ignore = config.material.ignore\
			.map(func(i: String) -> String: return i.to_upper());

	_config.material.fallbackMaterial = load(config.material.fallbackMaterial) if config.material.fallbackMaterial != null else null;

	file.close();
