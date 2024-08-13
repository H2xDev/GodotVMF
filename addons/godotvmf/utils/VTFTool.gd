class_name VTFTool extends RefCounted

enum TextureImportMode {
	## Disable import materials
	DO_NOTHING,

	## Try to find materials with the same name and use it instad of importing
	COLLATE_BY_NAME,

	## Import materials directly from the game folder to the project
	IMPORT_DIRECTLY,

	## Automatically imports the project's materials into the mod folder by conversion textures to VTF
	SYNC,
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
	static var format_map:
		get: return {
			"13": Image.Format.FORMAT_DXT1,
			"14": Image.Format.FORMAT_DXT3,
			"15": Image.Format.FORMAT_DXT5,
		};

	static var supported_formats:
		get: return [
			ImageFormat.IMAGE_FORMAT_DXT1,
			ImageFormat.IMAGE_FORMAT_DXT3,
			ImageFormat.IMAGE_FORMAT_DXT5,
		];

	var file = null;
	var signature:
		get: return seek(0).get_buffer(16).get_string_from_utf8();

	var version:
		get:
			file.seek(4);
			return float(".".join([file.get_32(), file.get_32()]));

	var header_size:
		get: return seek(12).get_32();

	var width:
		get:
			var width = seek(16).get_16();
			return width if width > 0 else VMFConfig.config.defaultTextureSize;

	var height:
		get:
			var height = seek(18).get_16();
			return height if height > 0 else VMFConfig.config.defaultTextureSize;

	var flags:
		get: return seek(20).get_32();

	var frames:
		get: return seek(24).get_16();

	var first_frame:
		get: return seek(26).get_16();

	var reflectivity:
		get:
			file.seek(32);
			return Vector3(file.get_float(), file.get_float(), file.get_float());

	var bump_scale:
		get: return seek(48).get_float();

	var hires_image_format:
		get: return seek(52).get_32();

	var mipmap_count:
		get: return seek(56).get_8();

	var low_res_image_format:
		get: return seek(57).get_32();

	var low_res_image_width:
		get: return seek(61).get_8();

	var low_res_image_height:
		get: return seek(62).get_8();

	var depth:
		get:
			if version < 7.2: return 0;
			return seek(63).get_8();

	var num_resources:
		get:
			if version < 7.3: return 0;
			return seek(75).get_32();

	var frame_duration = 0;
	var path = '';
	var alpha = false;
	
	func seek(v: int):
		file.seek(v);
		return file;

	static func create(path: String, duration: float = 0):
		path = path.to_lower().replace('\\', '/').replace('//', '/');

		var fullPath = "{0}/materials/{1}.vtf" \
			.format([VMFConfig.config.gameInfoPath, path]) \
			.replace('\\', '/') \
			.replace('//', '/') \
			.replace('res:/', 'res://');

		if not FileAccess.file_exists(fullPath):
			VMFLogger.error("File {0} is not exist".format([fullPath]));
			return null;

		if not VMFConfig.config: return null;

		var vtf = VTF.new(path, duration);

		if not supported_formats.has(vtf.hires_image_format):
			VMFLogger.warn("Texture format {0} in not supported ({1})".format([VTFTool.formatLabels[vtf.hires_image_format], fullPath.get_file()]));
			vtf.done();
			return null;

		return vtf;

	func done(): file.close();

	func _read_frame(frame):
		var data = PackedByteArray();
		var byteRead = 0;
		var isDXT1 = hires_image_format == ImageFormat.IMAGE_FORMAT_DXT1;
		var format = format_map[str(hires_image_format)];

		frame = frames - 1 - frame;

		for i in range(mipmap_count):
			var mipWidth = max(1, width >> i);
			var mipHeight = max(1, height >> i);

			var multiplier = 8 if isDXT1 else 16;
			var mip_size = max(1, mipWidth / 4) * max(1, mipHeight / 4) * multiplier;

			file.seek(file.get_length() - byteRead - mip_size - mip_size * frame);
			data += file.get_buffer(mip_size);

			byteRead += mip_size + mip_size * (frames - 1);

		var img = Image.create_from_data(width, height, true, format, data);

		alpha = img.detect_alpha();

		if not img:
			VMFLogger.error("Corrupted file: {0}".format([file.get_path()]));
			return null;

		return ImageTexture.create_from_image(img);

	func compile_texture():
		if width == 0 or height == 0:
			VMFLogger.error("Corrupted file: {0}".format([file.get_path()]));
			return null;

		var path_to_save = "{0}/{1}.texture.tres" \
			.format([VMFConfig.config.material.targetFolder, path]) \
			.replace('//', '/') \
			.replace('res:/', 'res://');

		var tex;

		if frames > 1:
			tex = AnimatedTexture.new();
			tex.frames = frames;

			for frame in range(0, frames):
				tex.set_frame_texture(frame, _read_frame(frame));
				tex.set_frame_duration(frame, frame_duration);

		else:
			tex = _read_frame(0);
			
		if not tex: 
			VMFLogger.error("Texture not loaded: {0}".format([path_to_save]));
			return null;

		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path_to_save.get_base_dir()));
		ResourceSaver.save(tex, path_to_save);
		tex.take_over_path(path_to_save);
		VMFLogger.log("Texture imported: {0}".format([path_to_save]));

		return tex;

	func _init(path, duration):
		path = path.to_lower() \
			.replace('\\', '/') \
			.replace('//', '/') \
			.replace('res:/', 'res://');

		self.path = path;
		self.frame_duration = duration

		var fullPath = "{0}/materials/{1}.vtf".format([VMFConfig.config.gameInfoPath, path]);
		file = FileAccess.open(fullPath, FileAccess.READ);

class VMT:
	static var mappings:
		get: return {
			"$basetexture": "albedo_texture",
			"$basetexture2": "albedo_texture2",
			"$bumpmap": "normal_texture",
			"$bumpmap2": "normal_texture2",
			"$detail": ["detail_albedo", "detail_mask"],
			"$selfillummask": "emission_texture",
		};

	static var cache = {};

	static var feature_mappings:
		get: return {
			"$bumpmap": BaseMaterial3D.FEATURE_NORMAL_MAPPING,
			"$normalmap": BaseMaterial3D.FEATURE_NORMAL_MAPPING,
			"$detail": BaseMaterial3D.FEATURE_DETAIL,
		};

	static var materialMap:
		get: return {
			"worldvertextransition": WorldVertexTransitionMaterial,
		}

	static func create(material_path):
		if not VMFConfig.config:
			return null;

		material_path = material_path.to_lower().replace('\\', '/');

		var path = "{0}/materials/{1}.vmt"\
			.format([VMFConfig.config.gameInfoPath, material_path])\
			.replace('\\', '/').replace('//', '/')\
			.replace('res:/', 'res://');

		var h = hash(material_path);

		VMT.cache = {} if not VMT.cache else VMT.cache;

		if h in cache: return cache[h];

		if not FileAccess.file_exists(path):
			VMFLogger.error("VMT file not found: {0}".format([path]));
			return null;

		var instance = VMT.new(material_path);
		cache[h] = instance;

		return instance;

	var structure: Dictionary = {};
	var shader: String = "";
	var material: Material = null;

	func _load_textures():
		if material is StandardMaterial3D:
			material.detail_blend_mode = BaseMaterial3D.BLEND_MODE_MUL;
			material.emission_energy_multiplier = structure.get('$selfillummaskscale', 1.0);

			if shader == 'unlitgeneric' or shader == 'unlittwotexture':
				material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED;

			var emission_tint: Array[float]
			emission_tint.assign(structure.get('$selfillummasktint', '[1 1 1]') \
				.trim_suffix(']') \
				.trim_prefix('[') \
				.split_floats(' '))

			material.emission = Color(emission_tint[0], emission_tint[1], emission_tint[2]);
			
			if structure.get("$additive", 0) == 1:
				material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD;

			for key in feature_mappings.keys():
				if not key in structure: continue;

				material.set_feature(feature_mappings[key], true);

		for key in mappings.keys():
			if not key in structure: continue;

			var path = structure[key].to_lower()\
					.replace('\\', '/')\
					.replace('//', '/')\
					.replace('res:/', 'res://')\
					.replace('.vtf', '');

			var duration = float(structure.proxies.animatedtexture.animatedtextureframerate if "proxies" in structure and "animatedtexture" in structure.proxies else 30);
			duration = 1 / duration;

			var vtf = VTF.create(path, duration);
			if not vtf: continue;

			var texture = vtf.compile_texture();
			var feature = feature_mappings[key] if key in feature_mappings else null;

			if material is StandardMaterial3D:
				var transparency = BaseMaterial3D.TRANSPARENCY_DISABLED;

				if structure.get("$alphatest", 0) == 1:
					transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR;
				elif structure.get("$translucent", 0) == 1:
					transparency = BaseMaterial3D.TRANSPARENCY_ALPHA;
					
				if transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
					material.cull_mode = BaseMaterial3D.CULL_DISABLED;

				material.set_transparency(transparency);
				
			var tex = vtf.compile_texture();

			if mappings[key] is Array:
				for skey in mappings[key]:
					if not skey in material: continue;
					material[skey] = tex;
			else:
				material[mappings[key]] = tex;

			vtf.done();

	func _parse_transform():
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

	func _init(material_path):
		material_path = material_path.to_lower().replace('\\', '/');

		var path = "{0}/materials/{1}.vmt"\
				.format([VMFConfig.config.gameInfoPath, material_path])\
				.replace('\\', '/')\
				.replace('//', '/')\
				.replace('res:/', 'res://');

		structure = ValveFormatParser.parse(path, true);
		shader = structure.keys()[0];
		structure = structure[shader];
		material = materialMap[shader].new() if shader in materialMap else StandardMaterial3D.new();
		
		# NOTE: L4D2 Case
		if "insert" in structure:
			structure = structure.insert;

		_load_textures();
		_parse_transform();

static func clear_cache():
	VTFTool.logged = {};
	VTFTool.cache = {};
	VMT.cache = {};

static func get_material(material_path):
	material_path = material_path.to_lower().replace('\\', '/');
	material_path = "{0}/{1}.tres" \
			.format([VMFConfig.config.material.targetFolder, material_path]) \
			.replace('\\', '/') \
			.replace('//', '/') \
			.replace('res:/', 'res://');

	var h = hash(material_path);

	VTFTool.logged = {} if not VTFTool.logged else VTFTool.logged;
	VTFTool.cache = {} if not VTFTool.cache else VTFTool.cache;

	if h in VTFTool.cache: return VTFTool.cache[h];

	if ResourceLoader.exists(material_path):
		var mat = ResourceLoader.load(material_path);

		if mat:
			VTFTool.cache[h] = mat;
			return mat;
		
		return null;

	if not h in logged:
		VMFLogger.warn("Material not found: {0}".format([material_path]));
		logged[h] = true;

	return VMFConfig.config.material.fallbackMaterial;

static func import_material(material_path, isModel = false):
	material_path = material_path.to_lower().replace('\\', '/');
	var save_path = "{0}/{1}.tres" \
		.format([VMFConfig.config.material.targetFolder, material_path]) \
		.replace('//', '/') \
		.replace('res:/', 'res://');

	if ResourceLoader.exists(save_path): return;

	var vmt = VMT.create(material_path);
	if not vmt: 
		VMFLogger.error("Compiling texture...");
		return;

	if isModel: vmt.material.uv1_scale.y = -1;

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(save_path.get_base_dir()));
	ResourceSaver.save(vmt.material, save_path);
