class_name VTFTool

enum TextureImportMode {
	## Disable import materials
	DO_NOTHING,

	## Try to find materials with the same name and use it instad of importing
	COLLATE_BY_NAME,

	## Import materials directly from the game folder to the project
	IMPORT_DIRECTLY,
}

enum ImageFormat {
	IMAGE_FORMAT_RGBA8888,
	IMAGE_FORMAT_ABGR8888,
	IMAGE_FORMAT_RGB888,
	IMAGE_FORMAT_BGR888,
	IMAGE_FORMAT_RGB565,
	IMAGE_FORMAT_I8,
	IMAGE_FORMAT_IA88,
	IMAGE_FORMAT_P8,
	IMAGE_FORMAT_A8,
	IMAGE_FORMAT_RGB888_BLUESCREEN,
	IMAGE_FORMAT_BGR888_BLUESCREEN,
	IMAGE_FORMAT_ARGB8888,
	IMAGE_FORMAT_BGRA8888,
	IMAGE_FORMAT_DXT1,
	IMAGE_FORMAT_DXT3,
	IMAGE_FORMAT_DXT5,
	IMAGE_FORMAT_BGRX8888,
	IMAGE_FORMAT_BGR565,
	IMAGE_FORMAT_BGRX5551,
	IMAGE_FORMAT_BGRA4444,
	IMAGE_FORMAT_DXT1_ONEBITALPHA,
	IMAGE_FORMAT_BGRA5551,
	IMAGE_FORMAT_UV88,
	IMAGE_FORMAT_UVWQ8888,
	IMAGE_FORMAT_RGBA16161616F,
	IMAGE_FORMAT_RGBA16161616,
	IMAGE_FORMAT_UVLX8888,
	IMAGE_FORMAT_NONE = -1
}

enum Flags
{
	TEXTUREFLAGS_POINTSAMPLE = 0x00000001,
	TEXTUREFLAGS_TRILINEAR = 0x00000002,
	TEXTUREFLAGS_CLAMPS = 0x00000004,
	TEXTUREFLAGS_CLAMPT = 0x00000008,
	TEXTUREFLAGS_ANISOTROPIC = 0x00000010,
	TEXTUREFLAGS_HINT_DXT5 = 0x00000020,
	TEXTUREFLAGS_PWL_CORRECTED = 0x00000040,
	TEXTUREFLAGS_NORMAL = 0x00000080,
	TEXTUREFLAGS_NOMIP = 0x00000100,
	TEXTUREFLAGS_NOLOD = 0x00000200,
	TEXTUREFLAGS_ALL_MIPS = 0x00000400,
	TEXTUREFLAGS_PROCEDURAL = 0x00000800,

	TEXTUREFLAGS_ONEBITALPHA = 0x00001000,
	TEXTUREFLAGS_EIGHTBITALPHA = 0x00002000,

	TEXTUREFLAGS_ENVMAP = 0x00004000,
	TEXTUREFLAGS_RENDERTARGET = 0x00008000,
	TEXTUREFLAGS_DEPTHRENDERTARGET = 0x00010000,
	TEXTUREFLAGS_NODEBUGOVERRIDE = 0x00020000,
	TEXTUREFLAGS_SINGLECOPY	= 0x00040000,
	TEXTUREFLAGS_PRE_SRGB = 0x00080000,
	TEXTUREFLAGS_CLAMPU = 0x02000000,
	TEXTUREFLAGS_VERTEXTEXTURE = 0x04000000,
	TEXTUREFLAGS_SSBUMP = 0x08000000,			
	TEXTUREFLAGS_BORDER = 0x20000000,
};

static var formatLabels:
	get:
		return [
			"RGBA8888",
			"ABGR8888",
			"RGB888",
			"BGR888",
			"RGB565",
			"I8",
			"IA88",
			"P8",
			"A8",
			"RGB888_BLUESCREEN",
			"BGR888_BLUESCREEN",
			"ARGB8888",
			"BGRA8888",
			"DXT1",
			"DXT3",
			"DXT5",
			"BGRX8888",
			"BGR565",
			"BGRX5551",
			"BGRA4444",
			"DXT1_ONEBITALPHA",
			"BGRA5551",
			"UV88",
			"UVWQ8888",
			"RGBA16161616F",
			"RGBA16161616",
			"UVLX8888",
			"NONE",
		]

static var formatMap:
	get:
		return {
			"13": Image.Format.FORMAT_DXT1,
			"14": Image.Format.FORMAT_DXT3,
			"15": Image.Format.FORMAT_DXT5,
		}

static var cache = {};
static var logged = {};

static func _static_init():
	VTFTool.cache = {};

class VTF:
	static var cache = {};

	static var config:
		get: 
			return VMFConfig.getConfig().nodeConfig;

	var file = null;

	var signature:
		get:
			file.seek(0);
			return file.get_buffer(16).get_string_from_utf8();

	var version:
		get:
			file.seek(4);
			return float(".".join([file.get_32(), file.get_32()]));

	var headerSize:
		get:
			file.seek(12);
			return file.get_32();

	var width:
		get:
			file.seek(16);
			var width = file.get_16();

			return width if width > 0 else config.defaultTextureSize;

	var height:
		get:
			file.seek(18);

			var height = file.get_16();
			return height if height > 0 else config.defaultTextureSize;

	var flags:
		get:
			file.seek(20);
			return file.get_32();

	var frames:
		get:
			file.seek(24)
			return file.get_16();

	var firstFrame:
		get:
			file.seek(26);
			return file.get_16();

	var reflectivity:
		get:
			file.seek(32);
			return Vector3(file.get_float(), file.get_float(), file.get_float());

	var bumpScale:
		get:
			file.seek(48);
			return file.get_float();

	var hiresImageFormat:
		get:
			file.seek(52);
			return file.get_32();

	var mipmapCount:
		get:
			file.seek(56);
			return file.get_8();

	var lowResImageFormat:
		get:
			file.seek(57);
			return file.get_32();

	var lowResImageWidth:
		get:
			file.seek(61);
			return file.get_8();

	var lowResImageHeight:
		get:
			file.seek(62);
			return file.get_8();

	var depth:
		get:
			if version < 7.2:
				return 0;

			file.seek(63);
			return file.get_8();

	var numResources:
		get:
			if version < 7.3:
				return 0;

			file.seek(75);
			return file.get_32();

	var transform = {
		"scale": Vector2(1, 1),
	};

	static func create(fullPath):
		if not FileAccess.file_exists(fullPath):
			VMFLogger.error("File {0} is not exist".format([fullPath]));
			return null;

		VTF.cache = {} if not VTF.cache else VTF.cache;

		var h = hash(fullPath);

		if h in cache:
			return cache[h];

		var instance = VTF.new(fullPath);
		cache[h] = instance;

		return instance;

	func done():
		file.close();

	func compileTexture():
		var isDXT1 = hiresImageFormat == ImageFormat.IMAGE_FORMAT_DXT1;
		var isDXT3 = hiresImageFormat == ImageFormat.IMAGE_FORMAT_DXT3;
		var isDXT5 = hiresImageFormat == ImageFormat.IMAGE_FORMAT_DXT5;

		if not isDXT1 and not isDXT3 and not isDXT5:
			VMFLogger.error("Unsupported texture format: {0} for texture: {1}".format([VTFTool.formatLabels[hiresImageFormat], file.get_path()]));
			return null;

		if width == 0 or height == 0:
			VMFLogger.error("Corrupted file: {0}".format([file.get_path()]));
			return null;

		var divider = 2 if isDXT1 else 1;
		var bytesCount = (width * height) / divider;

		file.seek(file.get_length() - bytesCount);

		var data = file.get_buffer(bytesCount);
		var format = VTFTool.formatMap[str(hiresImageFormat)];

		var image = Image.new();
		image.set_data(width, height, false, format, data);

		return ImageTexture.create_from_image(image);

	func _init(fullPath):
		VTF.cache = {} if not VTF.cache else VTF.cache;
		file = FileAccess.open(fullPath, FileAccess.READ);

class VMT:
	static var fileProps = null; 
	static var mappings = null;;
	static var cache = {};

	static var config:
		get: 
			return VMFConfig.getConfig();

	static var featureMappings:
		get:
			return {
				"$bumpmap": BaseMaterial3D.FEATURE_NORMAL_MAPPING,
				"$normalmap": BaseMaterial3D.FEATURE_NORMAL_MAPPING,
				"$detail": BaseMaterial3D.FEATURE_DETAIL,
			};

	static func create(materialPath):
		materialPath = materialPath.to_lower().replace('\\', '/');

		var path = "{0}/materials/{1}.vmt".format([config.gameInfoPath, materialPath]).replace('\\', '/').replace('//', '/');

		var h = hash(materialPath);

		VMT.cache = {} if not VMT.cache else VMT.cache;

		if h in cache:
			return cache[h];

		if not FileAccess.file_exists(path):
			VMFLogger.error("VMT file not found: {0}".format([path]));
			return null;

		var instance = VMT.new(materialPath);
		cache[h] = instance;

		return instance;

	var structure = {};
	var shader = "";
	var material = null;

	func has(key):
		return key in structure;

	func get(key):
		var value = structure[key] if key in structure else null;

		if value == null:
			return null;

		if VMT.fileProps.has(key):
			return "{0}/materials/{1}.vtf".format([config.gameInfoPath, value]).replace('\\', '/').replace('//', '/').to_lower();

		return value;

	func _loadTextures():
		for key in mappings.keys():
			if not key in structure:
				continue;

			var path = structure[key].to_lower().replace('\\', '/').replace('//', '/');
			var fullPath = "{0}/materials/{1}.vtf".format([config.gameInfoPath, path]).replace('\\', '/').replace('//', '/');

			var vtf = VTF.create(fullPath);

			if not vtf:
				continue;

			var texture = vtf.compileTexture();

			var feature = featureMappings[key] if key in featureMappings else null;

			if vtf.flags & Flags.TEXTUREFLAGS_ONEBITALPHA or vtf.flags & Flags.TEXTUREFLAGS_EIGHTBITALPHA:
				material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR;

			if feature:
				material.set_feature(feature, true);
			material[mappings[key]] = vtf.compileTexture();

	func _parseTransform():
		if not "$basetexturetransform" in structure:
			material.set_meta("center", Vector2.ZERO);
			material.set_meta("scale", Vector2.ONE);
			material.set_meta("rotate", 0);
			material.set_meta("translate", Vector2.ZERO);
			return;

		var transformRegex = RegEx.new();
		transformRegex.compile('^"?center ([0-9-.]+) ([0-9-.]+) scale ([0-9-.]+) ([0-9-.]+) rotate ([0-9-.]+) translate ([0-9-.]+) ([0-9-.]+)"?$')

		var transformParams = transformRegex.search(structure['$basetexturetransform']);
		var center = Vector2(float(transformParams.get_string(1)), float(transformParams.get_string(2)));
		var scale = Vector2(float(transformParams.get_string(3)), float(transformParams.get_string(4)));
		var rotate = float(transformParams.get_string(5));
		var translate = Vector2(float(transformParams.get_string(6)), float(transformParams.get_string(7)));

		material.set_meta("center", center);
		material.set_meta("scale", scale);
		material.set_meta("rotate", rotate);
		material.set_meta("translate", translate);

	func _initStatic():
		VMT.fileProps = [
			"$basetexture",
			"$basetexture2",
			"$bumpmap",
			"$bumpmap2",
			"$normalmap",
			"$normalmap2",
			"$detail",
			"$detail2",
		];

		VMT.mappings = {
			"$basetexture": "albedo_texture",
			"$bumpmap": "normal_texture",
			"$detail": "detail_texture",
		}

	func _init(materialPath):
		_initStatic();
		materialPath = materialPath.to_lower().replace('\\', '/');

		var path = "{0}/materials/{1}.vmt".format([config.gameInfoPath, materialPath]).replace('\\', '/').replace('//', '/');

		structure = ValveFormatParser.parse(path);
		shader = structure.keys()[0];
		structure = structure[shader];
		material = StandardMaterial3D.new();

		for key in structure.keys():
			var needToTransform = key.to_lower() != key;
			if not needToTransform:
				continue;
			structure[key.to_lower()] = structure[key];
			structure.erase(key);

		_loadTextures();
		_parseTransform();

static func clearCache():
	VTFTool.cache = {};
	VMT.cache = {};
	VTF.cache = {};

static func getMaterial(materialPath):
	var config = VMFConfig.getConfig();
	materialPath = materialPath.to_lower().replace('\\', '/');
	materialPath = "{0}/{1}.tres".format([config.materialsFolder, materialPath]).replace('\\', '/').replace('//', '/').replace('res:/', 'res://');

	var h = hash(materialPath);

	VTFTool.cache = {} if not VTFTool.cache else VTFTool.cache;
	VTFTool.logged = {} if not VTFTool.logged else VTFTool.logged;

	if h in cache:
		return cache[h];

	if ResourceLoader.exists(materialPath):
		var material = ResourceLoader.load(materialPath);
		cache[h] = material;

		return material;

	if not h in logged:
		VMFLogger.warn("Material not found: {0}".format([materialPath]));
		logged[h] = true;

static func importMaterial(materialPath, isModel = false):
	var h = hash(materialPath);
	var config = VMFConfig.getConfig();

	VTFTool.cache = {} if not VTFTool.cache else VTFTool.cache;

	if h in cache:
		return;

	materialPath = materialPath.to_lower().replace('\\', '/');
	var savePath = "{0}/{1}.tres".format([config.materialsFolder, materialPath]).replace('//', '/').replace('res:/', 'res://');

	if ResourceLoader.exists(savePath):
		return;

	var vmt = VMT.create(materialPath);
	
	if not vmt:
		return;

	if isModel:
		vmt.material.uv1_scale.y = -1;

	cache[h] = vmt.material;

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(savePath.get_base_dir()));
	ResourceSaver.save(vmt.material, savePath);

	VMFLogger.log("Material imported: {0}".format([materialPath]));

