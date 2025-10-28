class_name VMTTransformer extends RefCounted

func texturefilter(material: Material, value: Variant):
	if material is not BaseMaterial3D:
		return;

	var enum_field: String = "TEXTURE_FILTER_" + value;
	var base_material: BaseMaterial3D = material;

	if not enum_field in BaseMaterial3D:
		VMFLogger.error("VMT: Unknown texturefilter value: " + value);
		return;

	base_material.texture_filter = BaseMaterial3D[enum_field];

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

func blendmodulatetexture(material: Material, value: Variant):
	if not "blend_modulate_texture" in material: return;
	var texture: Texture = VTFLoader.get_texture(value);

	if texture:
		var process_srgb: bool = texture.get_meta("srgb_conversion_method", 0) == VTFLoader.SRGBConversionMethod.PROCESS_IN_SHADER;
		material.set("convert_to_srgb", process_srgb);

	material.set("blend_modulate_texture", VTFLoader.get_texture(value));
