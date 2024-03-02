class_name VMFConfig;

static var _config = null;

static var config:
	get:
		if not _config:
			checkProjectConfig();
		return _config;
	
static func _validateKeys(keyset, dict, resFolders = [], section = ''):
	var missingKeys = [];

	for key in keyset:
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


static func _validateConfig():
	var checkKeys = [
		"import",
		"material",
	];

	var modelsDefined = "models" in config and config.models.import;
	var materialsDefined = "materials" in config and config.materials.importMode == 2;

	if modelsDefined or materialsDefined:
		checkKeys.append("gameInfoPath");

	if modelsDefined:
		checkKeys.append("mdl2obj");
		
		if not FileAccess.file_exists(_config.mdl2obj):
			VMFLogger.error('mdl2obj not found at {0}. Model import disabled'.format([_config.mdl2obj]));
			config.models.import = false;

	if not _validateKeys(checkKeys, config):
		return false;

	checkKeys = [
		"scale",
		"generateCollision",
		"entitiesFolder",
		"instancesFolder",
	];

	if not _validateKeys(checkKeys, config.import, ['entitiesFolder', 'instancesFolder'], 'import'):
		return false;

	checkKeys = [
		"importMode",
		"generateMipmaps",
		"ignore",
		"fallbackMaterial",
		"defaultTextureSize",
		"targetFolder",
	];

	if not _validateKeys(checkKeys, config.material, ['targetFolder'], 'material'):
		return false;
	
	if "models" in config:
		checkKeys = [
			"generateCollision",
			"targetFolder",
		];

		if not _validateKeys(checkKeys, config.models, ['targetFolder'], 'models'):
			return false;

	return true;

static func checkProjectConfig():
	if not FileAccess.file_exists('res://vmf.config.json'):
		VMFLogger.error('vmf.config.json not found in project root');

	var file = FileAccess.open('res://vmf.config.json', FileAccess.READ);
	_config = JSON.parse_string(file.get_as_text());

	if not _validateConfig():
		_config = null;
		return;

	_config.material.ignore = config.material.ignore\
			.map(func(i): return i.to_upper());

	_config.material.fallbackMaterial = load(config.material.fallbackMaterial) if config.material.fallbackMaterial != null else null;

	file.close();
