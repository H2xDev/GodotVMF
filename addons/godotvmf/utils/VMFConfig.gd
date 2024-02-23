class_name VMFConfig;

static var config = {};

static func getConfig():
	if not config:
		checkProjectConfig();
	return config;

static func createConfig():
	var file = FileAccess.open('res://vmf.config.json', FileAccess.WRITE);

	var defaultConfig = {
		"gameInfoPath": "C:/Steam/steamapps/sourcemods/mymod",
		"vtflib": "C:/Steam/steamapps/sourcemods/mymod/tools/vtflib",
		"mdl2obj": "C:/Steam/steamapps/sourcemods/mymod/tools/mdl2obj",
		"modelsFolder": "res://Assets/Models",
		"materialsFolder": "res://Assets/Materials",
		"instancesFolder": "res://Assets/Instances",
		"entitiesFolder": "res://Assets/Entities",
		"nodeConfig": {
			"importScale": 0.025,
			"defaultTextureSize": 512,
			"generateCollision": true,
			"fallbackMaterial": null,
			"ignoreTextures": ['TOOLS/TOOLSNODRAW'],
			"textureImportMode": 1,
			"importModels": false,
			"generateCollisionForModel": true,
			"overrideModels": true,
		},
	};

	file.store_string(JSON.stringify(defaultConfig, "\t"));
	file.close();

static func checkProjectConfig():
	if not FileAccess.file_exists('res://vmf.config.json'):
		createConfig();

	var file = FileAccess.open('res://vmf.config.json', FileAccess.READ);
	config = JSON.parse_string(file.get_as_text());
	config.nodeConfig.ignoreTextures = config.nodeConfig.ignoreTextures\
			.map(func(i): return i.to_upper());

	file.close();
