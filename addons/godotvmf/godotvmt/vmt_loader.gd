class_name VMTLoader extends RefCounted

class VMTTransformer:
	func basetexture(material: Material, value: Variant):
		if "albedo_texture" in material:
			material.set("albedo_texture", VTFLoader.get_texture(value));
	
	func basetexture2(material: Material, value: Variant):
		if "albedo_texture2" in material:
			material.set("albedo_texture2", VTFLoader.get_texture(value));

	func bumpmap(material: Material, value: Variant):
		if "normal_texture" in material:
			material.set("normal_texture", VTFLoader.get_texture(value));
		if "normal_enabled" in material:
			material.normal_enabled = true;
	
	func bumpmap2(material: Material, value: Variant):
		if "normal_texture2" in material:
			material.set("normal_texture2", VTFLoader.get_texture(value));

	func selfillum(material: Material, value: Variant):
		if "emission_enabled" in material:
			material.emission_enabled = value == 1;

	func selfillummask(material: Material, value: Variant):
		if "emission_texture" in material:
			material.set("emission_texture", VTFLoader.get_texture(value));
			material.emission_enabled = true;

	func emissioncolor(material: Material, value: Variant):
		if "emission" in material:
			material.set("emission", value);

	func emissionenergy(material: Material, value: Variant):
		if "emission_energy_multiplier" in material:
			material.set("emission_energy_multiplier", value);

	func emissionoperator(material: Material, value: Variant):
		if "emission_operator" in material:
			material.set("emission_operator", value);
	
	func roughnesstexture(material: Material, value: Variant):
		if "roughness_texture" in material:
			material.set("roughness_texture", VTFLoader.get_texture(value));
	
	func roughnessfactor(material: Material, value: Variant):
		if "roughness" in material:
			material.set("roughness", value);
	
	func metalnesstexture(material: Material, value: Variant):
		if "metallic_texture" in material:
			material.set("metallic_texture", VTFLoader.get_texture(value));
	
	func ambientocclusiontexture(material: Material, value: Variant):
		if "ao_texture" in material:
			material.set("ao_texture", VTFLoader.get_texture(value));
			material.ao_enabled = true;
	
	func bumpmapscale(material: Material, value: Variant):
		if "normal_scale" in material:
			material.set("normal_scale", value);
	
	func nocull(material: Material, value: Variant):
		material.cull_mode = BaseMaterial3D.CULL_DISABLED \
				if value == 1 else BaseMaterial3D.CULL_BACK;

	func translucent(material: Material, value: Variant):
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA \
				if value == 1 else BaseMaterial3D.TRANSPARENCY_DISABLED;

	func alphatest(material: Material, value: Variant):
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR \
				if value == 1 else BaseMaterial3D.TRANSPARENCY_DISABLED;

	func alphatestreference(material: Material, value: Variant):
		material.alpha_scissor_threshold = value;

	func nextpass(material: Material, value: Variant):
		var shader_material = VMTShaderBasedMaterial.load("res://" + value + ".gdshader");
		material.next_pass = shader_material;
	
	func detail(material: Material, value: Variant):
		return;
		if "detail_mask" in material:
			var texture = VTFLoader.get_texture(value);
			if not texture: return;
			material.set("detail_mask", texture);
			material.detail_enabled = true;

	func detailblendmode(material: Material, value: Variant):
		if "detail_blend_mode" in material:
			material.set("detail_blend_mode", value);

	func surfaceprop(material: Material, value: Variant):
		material.set_meta("surfaceprop", value);

	func basetexturetransform(material: Material, value: Variant):
		if "uv1_scale" not in material:
			return;
		if "uv1_offset" not in material:
			return;

		var transform = VMTLoader.parse_transform(value);
		material.uv1_scale = Vector3(transform.scale.x, transform.scale.y, 1);
		material.uv1_offset = Vector3(transform.translate.x, transform.translate.y, 0);

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

static var cached_materials: Dictionary;

static func clear_cache():
	cached_materials = {};

static func has_material(material: String) -> bool:
	var material_path = normalize_path(VMFConfig.materials.target_folder + "/" + material + ".tres").to_lower();

	if not ResourceLoader.exists(material_path):
		material_path = material_path.replace(".tres", ".vmt");

	if not ResourceLoader.exists(material_path):
		return false;

	return true;

static func get_material(material: String):
	var material_path = normalize_path(VMFConfig.materials.target_folder + "/" + material + ".tres").to_lower();

	if not ResourceLoader.exists(material_path):
		material_path = material_path.replace(".tres", ".vmt");

	if not ResourceLoader.exists(material_path):
		VMFLogger.warn("Material not found: " + material_path);
		material_path = VMFConfig.materials.fallback_material
	
		if not material_path or not ResourceLoader.exists(material_path): return null;

	var res = ResourceLoader.load(material_path);

	return res;
