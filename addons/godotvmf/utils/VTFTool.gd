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


static var cache = {};
static var logged = {};

class VTF:
	static var formatMap:
		get:
			return {
				"13": Image.Format.FORMAT_DXT1,
				"14": Image.Format.FORMAT_DXT3,
				"15": Image.Format.FORMAT_DXT5,
			};

	static var supportedFormats:
		get:
			return [
				ImageFormat.IMAGE_FORMAT_DXT1,
				ImageFormat.IMAGE_FORMAT_DXT3,
				ImageFormat.IMAGE_FORMAT_DXT5,
			];

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

			return width if width > 0 else VMFConfig.config.defaultTextureSize;

	var height:
		get:
			file.seek(18);

			var height = file.get_16();
			return height if height > 0 else VMFConfig.config.defaultTextureSize;

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

	var frameDuration = 0;
	var path = '';

	static func create(path, duration = 0):
		path = path.to_lower().replace('\\', '/').replace('//', '/');
		var fullPath = "{0}/materials/{1}.vtf".format([VMFConfig.config.gameInfoPath, path]).replace('\\', '/').replace('//', '/');

		if not FileAccess.file_exists(fullPath):
			VMFLogger.error("File {0} is not exist".format([fullPath]));
			return null;

		if not VMFConfig.config:
			return null;

		var vtf = VTF.new(path, duration);

		if not supportedFormats.has(vtf.hiresImageFormat):
			VMFLogger.warn("Texture format {0} in not supported ({1})".format([VTFTool.formatLabels[vtf.hiresImageFormat], fullPath.get_file()]));
			vtf.done();
			return null;

		return vtf;

	func done():
		file.close();

	func _readFrame(frame):
		var data = PackedByteArray();
		var byteRead = 0;
		var isDXT1 = hiresImageFormat == ImageFormat.IMAGE_FORMAT_DXT1;
		var format = formatMap[str(hiresImageFormat)];

		frame = frames - 1 - frame;

		for i in range(mipmapCount):
			var mipWidth = max(1, width >> i);
			var mipHeight = max(1, height >> i);

			var multiplier = 8 if isDXT1 else 16;
			var mipSize = max(1, mipWidth / 4) * max(1, mipHeight / 4) * multiplier;

			file.seek(file.get_length() - byteRead - mipSize - mipSize * frame);
			data += file.get_buffer(mipSize);

			byteRead += mipSize + mipSize * (frames - 1);

		var img = Image.create_from_data(width, height, true, format, data);

		if not img:
			VMFLogger.error("Corrupted file: {0}".format([file.get_path()]));
			return null;

		return ImageTexture.create_from_image(img);

	func compileTexture():
		if width == 0 or height == 0:
			VMFLogger.error("Corrupted file: {0}".format([file.get_path()]));
			return null;

		var pathToSave = "{0}/{1}.texture.tres".format([VMFConfig.config.material.targetFolder, path]).replace('//', '/').replace('res:/', 'res://');

		var tex;

		if frames > 1:
			tex = AnimatedTexture.new();
			tex.frames = frames;

			for frame in range(0, frames):
				tex.set_frame_texture(frame, _readFrame(frame));
				tex.set_frame_duration(frame, frameDuration);

		else:
			tex = _readFrame(0);
			
		if not tex:
			return null;

		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(pathToSave.get_base_dir()));
		ResourceSaver.save(tex, pathToSave);
		tex.take_over_path(pathToSave);

		return tex;

	func _init(path, duration):
		path = path.to_lower().replace('\\', '/').replace('//', '/');
		self.path = path;
		self.frameDuration = duration

		var fullPath = "{0}/materials/{1}.vtf".format([VMFConfig.config.gameInfoPath, path]);
		file = FileAccess.open(fullPath, FileAccess.READ);

class VMT:
	static var mappings:
		get:
			return {
			"$basetexture": "albedo_texture",
			"$basetexture2": "albedo_texture2",
			"$bumpmap": "normal_texture",
			"$bumpmap2": "normal_texture2",
			"$detail": ["detail_albedo", "detail_mask"],
		};

	static var cache = {};

	static var featureMappings:
		get:
			return {
				"$bumpmap": BaseMaterial3D.FEATURE_NORMAL_MAPPING,
				"$normalmap": BaseMaterial3D.FEATURE_NORMAL_MAPPING,
				"$detail": BaseMaterial3D.FEATURE_DETAIL,
			};

	static var materialMap:
		get:
			return {
				"worldvertextransition": WorldVertexTransitionMaterial,
			}

	static func create(materialPath):
		if not VMFConfig.config:
			return null;

		materialPath = materialPath.to_lower().replace('\\', '/');

		var path = "{0}/materials/{1}.vmt".format([VMFConfig.config.gameInfoPath, materialPath]).replace('\\', '/').replace('//', '/');

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
	var material: Material = null;

	func has(key):
		return key in structure;

	func getVal(key):
		return structure[key] if key in structure else null;

	func _loadTextures():
		for key in mappings.keys():
			if not key in structure:
				continue;

			var path = structure[key].to_lower().replace('\\', '/').replace('//', '/').replace('.vtf', '');
			var duration = float(structure.proxies.animatedtexture.animatedtextureframerate if "proxies" in structure and "animatedtexture" in structure.proxies else 1);

			duration = 1 / duration if duration > 0 else 1;

			var vtf = VTF.create(path, duration);

			if not vtf:
				continue;

			var texture = vtf.compileTexture();
			var feature = featureMappings[key] if key in featureMappings else null;

			if material is StandardMaterial3D:
				var transparency = BaseMaterial3D.TRANSPARENCY_DISABLED;

				if getVal("$alphatest") == 1:
					transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR;
				elif getVal("$translucent") == 1:
					transparency = BaseMaterial3D.TRANSPARENCY_ALPHA;
					
				if transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
					material.cull_mode = BaseMaterial3D.CULL_DISABLED;

				material.set_transparency(transparency);

				if feature:
					material.set_feature(feature, true);
				
			var tex = vtf.compileTexture();

			if mappings[key] is Array:
				for skey in mappings[key]:
					material[skey] = tex;
			else:
				material[mappings[key]] = tex;

			vtf.done();

	func _parseTransform():
		if not "$basetexturetransform" in structure:
			material.set_meta("center", Vector2.ZERO);
			material.set_meta("scale", Vector2.ONE);
			material.set_meta("rotate", 0);
			material.set_meta("translate", Vector2.ZERO);
			return;

		var transformRegex = RegEx.new();
		transformRegex.compile('^"?center\\s+([0-9-.]+)\\s+([0-9-.]+)\\s+scale\\s+([0-9-.]+)\\s+([0-9-.]+)\\s+rotate\\s+([0-9-.]+)\\s+translate\\s+([0-9-.]+)\\s+([0-9-.]+)"?$')

		var transformParams = transformRegex.search(structure['$basetexturetransform']);
		
		var center = Vector2(float(transformParams.get_string(1)), float(transformParams.get_string(2)));
		var scale = Vector2(float(transformParams.get_string(3)), float(transformParams.get_string(4)));
		var rotate = float(transformParams.get_string(5));
		var translate = Vector2(float(transformParams.get_string(6)), float(transformParams.get_string(7)));

		material.set_meta("center", center);
		material.set_meta("scale", scale);
		material.set_meta("rotate", rotate);
		material.set_meta("translate", translate);

	func _init(materialPath):
		materialPath = materialPath.to_lower().replace('\\', '/');

		var path = "{0}/materials/{1}.vmt".format([VMFConfig.config.gameInfoPath, materialPath]).replace('\\', '/').replace('//', '/');

		structure = ValveFormatParser.parse(path, true);
		shader = structure.keys()[0];
		structure = structure[shader];
		material = materialMap[shader].new() if shader in materialMap else StandardMaterial3D.new();

		if material is StandardMaterial3D:
			material.detail_blend_mode = BaseMaterial3D.BLEND_MODE_MUL;
		
		# NOTE: L4D2 Case
		if "insert" in structure:
			structure = structure.insert;

		_loadTextures();
		_parseTransform();

static func clearCache():
	VTFTool.logged = {};
	VTFTool.cache = {};
	VMT.cache = {};

static func getMaterial(materialPath):
	materialPath = materialPath.to_lower().replace('\\', '/');
	materialPath = "{0}/{1}.tres".format([VMFConfig.config.material.targetFolder, materialPath]).replace('\\', '/').replace('//', '/').replace('res:/', 'res://');

	var h = hash(materialPath);

	VTFTool.logged = {} if not VTFTool.logged else VTFTool.logged;
	VTFTool.cache = {} if not VTFTool.cache else VTFTool.cache;

	if h in VTFTool.cache:
		return VTFTool.cache[h];

	if ResourceLoader.exists(materialPath):
		var mat = ResourceLoader.load(materialPath);

		if mat:
			VTFTool.cache[h] = mat;
			return mat;
		
		return null;

	if not h in logged:
		VMFLogger.warn("Material not found: {0}".format([materialPath]));
		logged[h] = true;

	return VMFConfig.config.material.fallbackMaterial;

static func importMaterial(materialPath, isModel = false):
	materialPath = materialPath.to_lower().replace('\\', '/');
	var savePath = "{0}/{1}.tres".format([VMFConfig.config.material.targetFolder, materialPath]).replace('//', '/').replace('res:/', 'res://');

	if ResourceLoader.exists(savePath):
		return;

	var vmt = VMT.create(materialPath);
	
	if not vmt:
		return;

	if isModel:
		vmt.material.uv1_scale.y = -1;

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(savePath.get_base_dir()));
	ResourceSaver.save(vmt.material, savePath);

	VMFLogger.log("Material imported: {0}".format([materialPath]));

