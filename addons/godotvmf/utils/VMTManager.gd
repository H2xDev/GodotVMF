class_name VMTManager;

class TextureTransform:
	var center: Vector2;
	var scale: Vector2;
	var rotate: float;
	var translate: Vector2;
	
	func _init(center: Vector2, scale: Vector2, rotate: float, translate: Vector2):
		self.center = center;
		self.scale = scale;
		self.rotate = rotate;
		self.translate = translate;

class TextureInfo:
	static var cache = {};
	var width: float;
	var height: float;
	var transform: TextureTransform;
	var normalTexturePath: String;
	var detailTexturePath: String;
	var baseTexturePath: String;

	func _init(baseTexturePath: String, width: float, height: float, transform: TextureTransform):
		self.width = width;
		self.height = height;
		self.transform = transform;
		self.baseTexturePath = baseTexturePath;

enum TextureImportMode {
	## Disable import materials
	DO_NOTHING,

	## Try to find materials with the same name and use it instad of importing
	COLLATE_BY_NAME,

	## Import materials directly from the game folder to the project
	IMPORT_DIRECTLY,
}

static var _textureCache = {};
static var _missingTextures = [];

static var config:
	get:
		return VMFConfig.getConfig();

static func resetCache():
	_textureCache = {};
	_missingTextures = [];

static func getMaterialFromProject(material: String):
	var materialPath = (config.materialsFolder + '/' + material.to_lower() + '.tres')\
		.replace('//', '/')\
		.replace('res:/', 'res://')
		
	if not ResourceLoader.exists(materialPath):
		VMFLogger.warn('Material TRES is not found in the project: ' + materialPath);
		return;

	return load(materialPath);

## Preloads a material from the game folder and saves it to the materials folder
static func preloadMaterial(materialPath: String, modelMaterial = false):
	var targetFile = (config.materialsFolder + '/' + materialPath.to_lower())\
		.replace('//', '/')\
		.replace('res:/', 'res://');

	var material = getMaterialFromProject(materialPath);

	if material:
		return true;

	var pngPath = targetFile + '.png';
	var textureInfo = getTextureInfo(materialPath);

	if not textureInfo:
		return false;

	if not FileAccess.file_exists(ProjectSettings.globalize_path(pngPath)):
		var isSuccess = copyTexture(textureInfo.baseTexturePath);

		if not isSuccess:
			return false;

	material = StandardMaterial3D.new();
	var texture = load(pngPath);

	material.albedo_texture = texture;

	if modelMaterial:
		material.set_uv1_scale(Vector3(1, -1, 1));

	ResourceSaver.save(material, targetFile + '.tres');

	return true;


## Returns a material from the materials folder or imports 
## In case of importing, the material is saved to the materials folder
static func importMaterial(materialPath: String, modelMaterial = false):
	var targetFile = (config.materialsFolder + '/' + materialPath.to_lower())\
		.replace('//', '/')\
		.replace('res:/', 'res://') + '.tres';

	if not ResourceLoader.exists(targetFile):
		var isSuccess = preloadMaterial(materialPath, modelMaterial);

		if not isSuccess:
			return;

	if not ResourceLoader.exists(targetFile):
		VMFLogger.error('Corrupted material: ' + targetFile);
		return;

	return load(targetFile);


## Converts vtf to png and copies it to the materials folder
static func copyTexture(baseTexture: String) -> bool:
	baseTexture = baseTexture.to_lower();

	if not "vtfedit" in config:
		VMFLogger.error('Missing "vtfedit" path in vmf.config.json');
		return false;

	if not FileAccess.file_exists(config.vtfedit):
		VMFLogger.error('Missing VTFEdit: ' + config.vtfedit + '\nTexture copying is skipped.');
		return false;

	if not config.materialsFolder.begins_with('res://'):
		VMFLogger.error('Invalid materials folder: ' + config.materialsFolder + '\nThe path must start with "res://"');
		return false;

	var outputPath = ProjectSettings.globalize_path(config.materialsFolder);
	var vtf = (config.gameInfoPath + '/materials/' + baseTexture + '.vtf')\
		.replace('//', '/')\
		.to_lower();
	
	var folder = "/".join((outputPath + '/' + baseTexture).split('/').slice(0, -1));
	var copyArgs = ['-file', vtf, '-exportformat', '"png"'];
	var pngFile = vtf.replace('.vtf', '.png');
	var outPngFile = outputPath + '/' + baseTexture + '.png';

	if not FileAccess.file_exists(vtf):
		return false;

	DirAccess.make_dir_recursive_absolute(folder);

	OS.execute(config.vtfedit, copyArgs, [], false, false);
	DirAccess.copy_absolute(pngFile, outPngFile);
	DirAccess.remove_absolute(pngFile);

	VMFLogger.log('Copied texture: ' + pngFile);

	return true;

static func getTextureInfo(material: String) -> TextureInfo:
	_missingTextures = _missingTextures if _missingTextures else [];
	_textureCache = _textureCache if _textureCache else {};

	if material in _textureCache:
		return _textureCache[material];

	var gameInfoPath = config.gameInfoPath if "gameInfoPath" in config else null;

	if not gameInfoPath:
		VMFLogger.error('Missing "gameInfoPath" in vmf.config.json');
		return;

	var vmtPath = (gameInfoPath + '/materials/' + material + '.vmt').replace('//', '/').to_lower();
	var vmt = ValveFormatParser.parse(vmtPath);

	if not vmt:
		if not _missingTextures.has(vmtPath):
			VMFLogger.warn('Missing VMT: ' + vmtPath);
			_missingTextures.append(vmtPath);
		return;

	if !vmt:
		return;

	var shaderData = vmt.values()[0];
	var baseTexture = shaderData['$basetexture'].replace('\\', '/') if '$basetexture' in shaderData else null;

	if not baseTexture:
		return;

	var vtf = (gameInfoPath + '/materials/' + baseTexture + '.vtf').replace('//', '/').to_lower();

	if not FileAccess.file_exists(vtf):
		if not _missingTextures.has(vtf):
			VMFLogger.warn('Missing VTF: ' + vtf);
			_missingTextures.append(vtf);
		return;

	var file = FileAccess.open(vtf, FileAccess.READ);
	file.get_buffer(16);

	var width = file.get_16();
	var height = file.get_16();
	var transform = null;

	if "$basetexturetransform" in shaderData:
		var transformRegex = RegEx.new();
		transformRegex.compile('^"?center ([0-9-.]+) ([0-9-.]+) scale ([0-9-.]+) ([0-9-.]+) rotate ([0-9-.]+) translate ([0-9-.]+) ([0-9-.]+)"?$')
		var transformParams = transformRegex.search(shaderData['$basetexturetransform']);

		transform = TextureTransform.new(
			Vector2(float(transformParams.get_string(1)), float(transformParams.get_string(2))),
			Vector2(float(transformParams.get_string(3)), float(transformParams.get_string(4))),
			float(transformParams.get_string(5)),
			Vector2(float(transformParams.get_string(6)), float(transformParams.get_string(7)))
		);

	_textureCache[material] = TextureInfo.new(baseTexture, width, height, transform);

	file.close();

	return _textureCache[material];
