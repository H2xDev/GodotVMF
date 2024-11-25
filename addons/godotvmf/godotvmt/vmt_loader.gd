class_name VMTLoader extends RefCounted

static var default_shaders:
	get: return [
		'lightmappedgeneric'
	];

static var texture_mappings:
	get: return {
		basetexture = "albedo_texture",
		basetexture2 = "albedo_texture2",
		bumpmap = "normal_texture",
		bumpmap2 = "normal_texture2",
		detail = "detail_mask",
		roughnesstexture = "roughness_texture",
		metalnesstexture = "metallic_texture",
		ambientocclusiontexture = "ao_texture",
		selfillummask = "emission_texture",
	};

static var feature_mappings:
	get: return {
		bumpmap = "normal_enabled",
		detail = "detail_enabled",
		ambientocclusiontexture = "ao_enabled",
		selfillummask = "emission_enabled",
	}

static var boolean_mappings:
	get: return {
		selfillum = "emission_enabled",
	}

static var numberic_mappings:
	get: return {
		bumpmapscale = "normal_scale",
		roughnessfactor = "roughness",
		metallnessfactor = "metallic",
		specularfactor = "metallic_specular",
		ambientocclusionlightaffect = "ao_light_affect",
		detailblendmode = "detail_blend_mode",
		emissioncolor = "emission",
		emissionenergy = "emission_energy",
	}

static func is_file_valid(path: String):
	var import_path = path + ".import";

	if not FileAccess.file_exists(import_path): return false;

	var file = FileAccess.open(import_path, FileAccess.READ);
	var is_valid = file.get_as_text().contains("valid=false");

	file.close();

	return not is_valid;

static func _parse_transform(structure):
	var transformRegex = RegEx.new();
	transformRegex.compile('^"?center\\s+([0-9-.]+)\\s+([0-9-.]+)\\s+scale\\s+([0-9-.]+)\\s+([0-9-.]+)\\s+rotate\\s+([0-9-.]+)\\s+translate\\s+([0-9-.]+)\\s+([0-9-.]+)"?$')

	var transformParams = transformRegex.search(structure['$basetexturetransform']);
	
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
	
	# NOTE: CS:GO/L4D
	if "insert" in details:
		details.merge(details["insert"]);

	if "$shader" in details:
		var shader_path = "res://" + details["$shader"] + ".gdshader";
		material = VMTShaderBasedMaterial.load(shader_path);
	else:
		material = StandardMaterial3D.new();

	material.set_meta("surfaceprop", details.get("$surfaceprop", "default"));

	if material is BaseMaterial3D:
		if details.get("$translucent") == 1:
			material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA;

		if details.get("$alphatest") == 1:
			material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR;
			material.alpha_scissor_threshold = details.get("$alphatestreference", 0.0);

		if details.get("$nocull") == 1:
			material.cull_mode = BaseMaterial3D.CULL_DISABLED;

		if details.get(">=dx90_20b"):
			details.merge(details['>=dx90_20b']);

		if details.get("$basetexturetransform"):
			var transform = _parse_transform(details);
			material.uv1_scale = Vector3(transform.scale.x, transform.scale.y, 1);
			material.uv1_offset = Vector3(transform.translate.x, transform.translate.y, 0);

		if details.get("$nextpass"):
			var shader_material = VMTShaderBasedMaterial.load("res://" + details["$nextpass"] + ".gdshader");
			material.next_pass = shader_material;


	for key in details.keys():
		key = key.replace('$', '');

		if key in texture_mappings:
			var material_key = texture_mappings[key];
			var root = VMFConfig.config.material.targetFolder
			var texture_path = str(details['$' + key]).to_lower()

			if material_key in material:
				var loaded_texture = VTFLoader.get_texture(texture_path);
				if loaded_texture:
					material.set(material_key, loaded_texture);

					if key in feature_mappings:
						material[feature_mappings[key]] = true;
			continue;

		if key in numberic_mappings:
			var material_key = numberic_mappings[key];
			material[material_key] = details['$' + key];
			continue;

		if key in boolean_mappings:
			var material_key = boolean_mappings[key];
			material[material_key] = details['$' + key] == 1;
			continue;

	material.set_meta("details", details);

	return material;

static func normalize_path(path: String) -> String:
	return path.replace('\\', '/').replace('//', '/').replace('res:/', 'res://');

static var last_cache_changed: float;
static var cached_materials: Dictionary;

static func get_material(material: String):
	var material_path = normalize_path(VMFConfig.config.material.targetFolder + "/" + material + ".tres").to_lower();

	if last_cache_changed == null:
		last_cache_changed = 0;

	if not ResourceLoader.exists(material_path):
		material_path = material_path.replace(".tres", ".vmt");

	if not ResourceLoader.exists(material_path):
		VMFLogger.warn("Material not found: " + material);
		return null;

	cached_materials = cached_materials if cached_materials else {};
	if Time.get_ticks_msec() - last_cache_changed > 10000:
		cached_materials = {};

	if material in cached_materials:
		return cached_materials[material];

	var res = ResourceLoader.load(material_path);
	cached_materials[material] = res;

	last_cache_changed = Time.get_ticks_msec();

	return res;
