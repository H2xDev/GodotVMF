class_name VTFLoader extends RefCounted
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
		return width if width > 0 else 512;

var height:
	get:
		var height = seek(18).get_16();
		return height if height > 0 else 512;

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

var file_name: String = '':
	get: return path.get_file().get_basename();

func seek(v: int):
	file.seek(v);
	return file;

static func create(path: String, duration: float = 0):
	if not FileAccess.file_exists(path):
		push_error("File {0} is not exist".format([path]));
		return null;

	var vtf = VTFLoader.new(path, duration);

	if not supported_formats.has(vtf.hires_image_format):
		push_warning("Texture format {0} in not supported ({1})" \
			  .format([VTFLoader.formatLabels[vtf.hires_image_format], path.get_file()]));
		vtf.done();
		return null;

	return vtf;

func done(): file.close();

func compile_texture():
	if width == 0 or height == 0:
		push_error("Corrupted file: {0}".format([file.get_path()]));
		return null;

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
		push_error("Texture not loaded: {0}".format([path]));
		return null;

	return tex;

static var normal_conversion_shader: Shader;
static var shader_material: ShaderMaterial;

func _read_frame(frame):
	var data = PackedByteArray();
	var byteRead = 0;
	var isDXT1 = hires_image_format == ImageFormat.IMAGE_FORMAT_DXT1;
	var format = format_map[str(hires_image_format)];
	var use_mipmaps = not (flags & Flags.TEXTUREFLAGS_NOMIP);

	frame = frames - 1 - frame;

	for i in range(mipmap_count):
		var mipWidth = max(1, width >> i);
		var mipHeight = max(1, height >> i);

		var multiplier = 8 if isDXT1 else 16;
		var mip_size = max(1, mipWidth / 4) * max(1, mipHeight / 4) * multiplier;

		file.seek(file.get_length() - byteRead - mip_size - mip_size * frame);
		data += file.get_buffer(mip_size);

		byteRead += mip_size + mip_size * (frames - 1);

	var img = Image.create_from_data(width, height, use_mipmaps, format, data);

	alpha = flags & Flags.TEXTUREFLAGS_ONEBITALPHA or flags & Flags.TEXTUREFLAGS_EIGHTBITALPHA;

	if not img:
		push_error("Corrupted file: {0}".format([file.get_path()]));
		return null;

	if flags & Flags.TEXTUREFLAGS_NORMAL:
		img.decompress()
		img.normal_map_to_xy();

	return ImageTexture.create_from_image(img);

func _init(path, duration):
	self.path = path;
	self.frame_duration = duration;

	file = FileAccess.open(path, FileAccess.READ);

static func normalize_path(path: String) -> String:
	return path.replace('\\', '/').replace('//', '/').replace('res:/', 'res://');

static func get_texture(texture: String):
	var texture_path = normalize_path(VMFConfig.config.material.targetFolder + "/" + texture + ".vtf");

	if not ResourceLoader.exists(texture_path):
		VMFLogger.warn("Texture not found: " + texture);
		return null;

	return ResourceLoader.load(texture_path);
