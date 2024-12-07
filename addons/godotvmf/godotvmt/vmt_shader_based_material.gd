class_name VMTShaderBasedMaterial extends ShaderMaterial

var albedo_texture: Texture = null:
	get: 
		if not uniforms.has("albedo_texture"): return null;
		return get_shader_parameter("albedo_texture");
	set(value): 
		if not uniforms.has("albedo_texture"): return null;
		set_shader_parameter("albedo_texture", value);

var transparency: float = 1.0;
var cull_mode: int = 1;

var normal_enabled = true;
var normal_texture: Texture = null:
	get: 
		if not uniforms.has("normal_texture"): return null;
		return get_shader_parameter("normal_texture");
	set(value): 
		if not uniforms.has("normal_texture"): return null;
		set_shader_parameter("normal_texture", value);

var normal_scale: float = 1.0:
	get: 
		if not uniforms.has("normal_scale"): return 1.0;
		return get_shader_parameter("normal_scale");
	set(value): 
		if not uniforms.has("normal_scale"): return;
		set_shader_parameter("normal_scale", value);

var detail_enabled = false;
var detail_mask: Texture = null:
	get: 
		if not uniforms.has("detail_mask"): return null;
		return get_shader_parameter("detail_mask");
	set(value): 
		if not uniforms.has("detail_mask"): return null;
		set_shader_parameter("detail_mask", value);

var roughness: float = 0.0:
	get: 
		if not uniforms.has("roughness"): return 0.0;
		return get_shader_parameter("roughness");
	set(value): 
		if not uniforms.has("roughness"): return;
		set_shader_parameter("roughness", value);
var roughness_texture: Texture = null:
	get: 
		if not uniforms.has("roughness_texture"): return null;
		return get_shader_parameter("roughness_texture");
	set(value): 
		if not uniforms.has("roughness_texture"): return null;
		set_shader_parameter("roughness_texture", value);

var metallic_texture: Texture = null:
	get: 
		if not uniforms.has("metallic_texture"): return null;
		return get_shader_parameter("metallic_texture");
	set(value): 
		if not uniforms.has("metallic_texture"): return null;
		set_shader_parameter("metallic_texture", value);

var metallic: float = 0.0:
	get: 
		if not uniforms.has("metallic"): return 0.0;
		return get_shader_parameter("metallic");
	set(value): 
		if not uniforms.has("metallic"): return;
		set_shader_parameter("metallic", value);

var metallic_specular: float = 0.0:
	get: 
		if not uniforms.has("metallic_specular"): return 0.0;
		return get_shader_parameter("metallic_specular");
	set(value): 
		if not uniforms.has("metallic_specular"): return;
		set_shader_parameter("metallic_specular", value);

var emission_enabled = true;
var emission_texture: Texture = null:
	get: 
		if not uniforms.has("emission_texture"): return null;
		return get_shader_parameter("emission_texture");
	set(value): 
		if not uniforms.has("emission_texture"): return null;
		set_shader_parameter("emission_texture", value);

var emission_energy:
	get: 
		if not uniforms.has("emission_energy"): return 1.0;
		return get_shader_parameter("emission_energy");
	set(value): 
		if not uniforms.has("emission_energy_multiplier"): return;
		set_shader_parameter("emission_energy_multiplier", value);

var emission: Color = Color(0, 0, 0):
	get: 
		if not uniforms.has("emission"): return Color(0, 0, 0);
		return get_shader_parameter("emission");
	set(value): 
		if not uniforms.has("emission"): return;
		set_shader_parameter("emission", value);

var uv1_scale: Vector2 = Vector2(1, 1):
	get: 
		if not uniforms.has("uv1_scale"): return Vector2(1, 1);
		return get_shader_parameter("uv1_scale");
	set(value): 
		if not uniforms.has("uv1_scale"): return;
		set_shader_parameter("uv1_scale", value);

var uv1_offset: Vector2 = Vector2(0, 0):
	get: 
		if not uniforms.has("uv1_offset"): return Vector2(0, 0);
		return get_shader_parameter("uv1_offset");
	set(value): 
		if not uniforms.has("uv1_offset"): return;
		set_shader_parameter("uv1_offset", value);

var uv2_scale: Vector2 = Vector2(1, 1):
	get: 
		if not uniforms.has("uv2_scale"): return Vector2(1, 1);
		return get_shader_parameter("uv2_scale");
	set(value): 
		if not uniforms.has("uv2_scale"): return;
		set_shader_parameter("uv2_scale", value);

var uv2_offset: Vector2 = Vector2(0, 0):
	get: 
		if not uniforms.has("uv2_offset"): return Vector2(0, 0);
		return get_shader_parameter("uv2_offset");
	set(value): 
		if not uniforms.has("uv2_offset"): return;
		set_shader_parameter("uv2_offset", value);

var uniforms: Array = [];

static func load(path: String):
	if not ResourceLoader.exists(path):
		print("VMTShaderBasedMaterial: Shader doesn't exists: " + path);
		return StandardMaterial3D.new();

	var shader = ResourceLoader.load(path);
	if shader:
		return VMTShaderBasedMaterial.new().assign(shader);

func assign(shader: Shader):
	self.shader = shader;
	uniforms = shader.get_shader_uniform_list().map(func (u): return u.name);
	return self;
