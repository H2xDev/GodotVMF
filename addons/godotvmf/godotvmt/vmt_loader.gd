@static_unload
class_name VMTLoader extends RefCounted

static var texture_sizes_cache: Dictionary = {};
static var cached_materials: Dictionary = {};
static var logged_materials: Array = [];

static func is_file_valid(path: String):
	var import_path = path + ".import";

	if not FileAccess.file_exists(import_path): return false;

	var file = FileAccess.open(import_path, FileAccess.READ);
	var is_valid = file.get_as_text().contains("valid=false");

	file.close();

	return not is_valid;

static func parse_transform(transform_data: String):
	var transformRegex = RegEx.new();
	transformRegex.compile('^"?center\\s+([0-9-.]+)\\s+([0-9-.]+)\\s+scale\\s+([0-9-.]+)\\s+([0-9-.]+)\\s+rotate\\s+([0-9-.]+)\\s+translate\\s+([0-9-.]+)\\s+([0-9-.]+)"?$')

	var transformParams = transformRegex.search(transform_data);
	
	var center = Vector2(float(transformParams.get_string(1)), float(transformParams.get_string(2)));
	var scale = Vector2(float(transformParams.get_string(3)), float(transformParams.get_string(4)));
	var rotate = float(transformParams.get_string(5));
	var translate = Vector2(float(transformParams.get_string(6)), float(transformParams.get_string(7)));

	return {
		center = center,
		scale = scale,
		rotate = rotate,
		translate = translate,
	}

static func load(path: String):
	var structure = VDFParser.parse(path, true);

	var shader_name = structure.keys()[0];
	var details = structure[shader_name];
	var material = null; 
	var is_blend_texture = shader_name == "worldvertextransition";
	
	# NOTE: CS:GO/L4D
	if "insert" in details:
		details.merge(details["insert"]);

	if details.get(">=dx90_20b"):
		details.merge(details['>=dx90_20b']);

	if "$shader" in details:
		var extension = ".gdshader" if not details["$shader"].get_extension() else "";
		var shader_path = "res://" + details["$shader"] + extension;
		material = VMTShaderBasedMaterial.load(shader_path);
	else:
		material = StandardMaterial3D.new() if not is_blend_texture else WorldVertexTransitionMaterial.new();

	var transformer = VMTTransformer.new();
	var extend_transformer = Engine.get_main_loop().root.get_node_or_null("VMTExtend");
	var uniforms: Array = material.shader.get_shader_uniform_list() if material is ShaderMaterial else [];

	for key in details.keys():
		var value = details[key];
		var is_compile_key = key.begins_with("%");
		key = key.replace('$', '').replace('%', '');

		if is_compile_key and value and key != "keywords":
			var compile_keys = material.get_meta("compile_keys", []);
			compile_keys.append(key);
			material.set_meta("compile_keys", compile_keys);

		if material is ShaderMaterial:
			var mat: ShaderMaterial = material;
			if uniforms.find(key) > -1:
				var is_texture = value.has("/");
				mat.set_shader_parameter(key, VTFLoader.get_texture(value) if is_texture else value);
				continue;

		if extend_transformer and key in extend_transformer:
			extend_transformer[key].call(material, value);
			continue;

		if key in transformer:
			transformer[key].call(material, value);

	material.set_meta("details", details);

	return material;

static func normalize_path(path: String) -> String:
	return path.replace('\\', '/').replace('//', '/').replace('res:/', 'res://');

static func clear_cache():
	cached_materials = {};
	texture_sizes_cache = {};
	logged_materials = [];

static func has_material(material: String) -> bool:
	var material_path = normalize_path(VMFConfig.materials.target_folder + "/" + material + ".tres").to_lower();

	if not ResourceLoader.exists(material_path):
		material_path = material_path.replace(".tres", ".vmt");

	if not ResourceLoader.exists(material_path):
		return false;

	return true;

static func get_material(material: String):
	cached_materials = cached_materials if cached_materials else {};
	logged_materials = logged_materials if logged_materials else [];

	if material in cached_materials:
		return cached_materials[material];

	var material_path = normalize_path(VMFConfig.materials.target_folder + "/" + material + ".tres").to_lower();

	if not ResourceLoader.exists(material_path):
		material_path = material_path.replace(".tres", ".vmt");

	if not ResourceLoader.exists(material_path):
		if not logged_materials.has(material_path):
			VMFLogger.warn("Material not found: " + material_path);
			logged_materials.append(material_path);

		material_path = VMFConfig.materials.fallback_material
	
		if not material_path or not ResourceLoader.exists(material_path): return null;

	cached_materials[material] = ResourceLoader.load(material_path);

	return cached_materials[material];

static func get_texture_size(side_material: String) -> Vector2:
	texture_sizes_cache = texture_sizes_cache if texture_sizes_cache else {};

	var default_texture_size: int = VMFConfig.materials.default_texture_size;
	var has_cached_value = side_material in texture_sizes_cache;

	if has_cached_value and texture_sizes_cache[side_material]:
		return texture_sizes_cache[side_material];

	var material = get_material(side_material) \
		if not has_cached_value \
		else texture_sizes_cache[side_material];
	
	if not material:
		texture_sizes_cache[side_material] = Vector2(default_texture_size, default_texture_size);
		return texture_sizes_cache[side_material];

	var texture = material.albedo_texture \
		if material is BaseMaterial3D \
		else material.get_shader_parameter('albedo_texture');

	if not texture and (material is ShaderMaterial):
		texture = material.get_shader_parameter('basetexture');
	
	if not texture: return Vector2(default_texture_size, default_texture_size);

	var tsize: Vector2 = texture.get_size() \
		if texture \
		else Vector2(default_texture_size, default_texture_size);

	texture_sizes_cache[side_material] = tsize;

	return tsize;
