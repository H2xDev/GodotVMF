class_name VTFLoader extends RefCounted
enum SRGBConversionMethod {
	DISABLED,
	DURING_IMPORT,
	PROCESS_IN_SHADER
}

enum ImageFormat {
	RGBA8888,
	ABGR8888,
	RGB888,
	BGR888,
	RGB565,
	I8,
	IA88,
	P8,
	A8,
	RGB888_BLUESCREEN,
	BGR888_BLUESCREEN,
	ARGB8888,
	BGRA8888,
	DXT1,
	DXT3,
	DXT5,
	BGRX8888,
	BGR565,
	BGRX5551,
	BGRA4444,
	DXT1_ONEBITALPHA,
	BGRA5551,
	UV88,
	UVWQ8888,
	RGBA16161616F,
	RGBA16161616,
	UVLX8888,
	NONE = -1
}

enum Flags
{
	TEXTUREFLAGS_POINTSAMPLE = 0x00000001,
	TEXTUREFLAGS_TRILINEAR = 0x00000002,
	TEXTUREFLAGS_CLAMPS = 0x00000004,
	TEXTUREFLAGS_CLAMPT = 0x00000008,
	TEXTUREFLAGS_ANISOTROPIC = 0x00000010,
	TEXTUREFLAGS_HINT_DXT5 = 0x00000020,
	TEXTUREFLAGS_SRGB = 0x00000040,
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

static var format_labels:
	get: return [
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
];

static var frame_readers: Dictionary:
	get: return {
		ImageFormat.DXT1: VTFDXT,
		ImageFormat.DXT3: VTFDXT,
		ImageFormat.DXT5: VTFDXT,
		ImageFormat.RGBA8888: VTFRGBA,
		ImageFormat.ABGR8888: VTFRGBA,
		ImageFormat.RGB888: VTFRGBA,
		ImageFormat.BGR888: VTFRGBA,
		ImageFormat.I8: VTFI8,
		ImageFormat.IA88: VTFI8,
	};

static var format_map:
	get: return {
		"13": Image.Format.FORMAT_DXT1,
		"14": Image.Format.FORMAT_DXT3,
		"15": Image.Format.FORMAT_DXT5,
	};

var file: FileAccess;
var signature: String:
	get: return seek(0).get_buffer(16).get_string_from_utf8();

var version: float:
	get:
		file.seek(4);
		return float(".".join([file.get_32(), file.get_32()]));

var header_size: int:
	get: return seek(12).get_32();

var width: int:
	get:
		var width = seek(16).get_16();
		return width if width > 0 else 512;

var height: int:
	get:
		var height = seek(18).get_16();
		return height if height > 0 else 512;

var flags: int:
	get: return seek(20).get_32();

var frames: int:
	get: return seek(24).get_16();

var first_frame: int:
	get: return seek(26).get_16();

var reflectivity: Vector3:
	get:
		file.seek(32);
		return Vector3(file.get_float(), file.get_float(), file.get_float());

var bump_scale: float:
	get: return seek(48).get_float();

var hires_image_format: int:
	get: return seek(52).get_32();

var mipmap_count: int:
	get: 
		if not use_mipmaps: return 1;
		return seek(56).get_8();

var low_res_image_format: int:
	get: return seek(57).get_32();

var low_res_image_width: int:
	get: return seek(61).get_8();

var low_res_image_height: int:
	get: return seek(62).get_8();

var depth: int:
	get:
		if version < 7.2: return 0;
		return seek(63).get_8();

var num_resources: int:
	get:
		if version < 7.3: return 0;
		return seek(75).get_32();

var use_mipmaps: bool:
	get: return not (flags & Flags.TEXTUREFLAGS_NOMIP);

var frame_duration: float = 0;
var path: String = '';
var alpha: bool = false;

var file_name: String = '':
	get: return path.get_file().get_basename();

var is_format_supported: bool:
	get: return hires_image_format in frame_readers;

static func create(path: String, duration: float = 0):
	if not FileAccess.file_exists(path):
		push_error("File {0} is not exist".format([path]));
		return null;

	var vtf = VTFLoader.new(path, duration);

	if not vtf.is_format_supported:
		VMFLogger.warn("Texture format {0} in not supported ({1})" \
			  .format([VTFLoader.format_labels[vtf.hires_image_format], path.get_file()]));
		vtf.done();
		return null;

	return vtf;

func seek(v: int) -> FileAccess:
	file.seek(v);
	return file;

func done(): file.close();

func compile_texture(srgb_conversion_method: SRGBConversionMethod):
	if width == 0 or height == 0:
		VMFLogger.error("Corrupted file: {0}".format([file.get_path()]));
		return null;

	var tex: Texture;

	if frames > 1:
		tex = AnimatedTexture.new();
		tex.frames = frames;

		for frame in range(0, frames):
			tex.set_frame_texture(frame, read_frame(frame, srgb_conversion_method));
			tex.set_frame_duration(frame, frame_duration);

	else:
		tex = read_frame(0, srgb_conversion_method);
		
	if not tex: 
		push_error("Texture not loaded: {0}".format([path]));
		return null;

	return tex;

static var normal_conversion_shader: Shader;
static var shader_material: ShaderMaterial;

func read_frame(frame, srgb_conversion_method: SRGBConversionMethod):
	var reader = VTFLoader.frame_readers.get(hires_image_format, null);

	if not reader:
		VMFLogger.error("Unsupported texture format: {0} in file {1}" \
			  .format([VTFLoader.format_labels[hires_image_format], file.get_path()]));
		return null;

	var tex := reader.read(self, frame, srgb_conversion_method) as Texture;

	if not tex: 
		VMFLogger.error("Corrupted file: {0}".format([file.get_path()]));
		return null;

	return tex;

func _init(path, duration):
	self.path = path;
	self.frame_duration = duration;

	file = FileAccess.open(path, FileAccess.READ);

static func get_texture(texture: String):
	texture = texture.to_lower();
	const extensions_priority = ['.vtf', '.tga', '.png', '.jpg'];
	
	for ext in extensions_priority:
		var texture_path = VMFUtils.normalize_path(VMFConfig.materials.target_folder + "/" + texture + ext);
		if ResourceLoader.exists(texture_path):
			return ResourceLoader.load(texture_path);

	VMFLogger.warn("Texture not found: %s" % texture);
