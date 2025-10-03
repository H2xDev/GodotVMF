@static_unload
class_name VMFResourceManager extends RefCounted

const MATERIAL_KEYS_TO_IMPORT = [
	"$basetexture",
	"$basetexture2",
	"$bumpmap",
	"$bumpmap2",
	"$selfillummask",
];

static var has_imported_resources: bool = false;

static func for_resource_import() -> void:
	var editor_interface = Engine.get_singleton("EditorInterface") if Engine.is_editor_hint() else null;
	if not editor_interface: return;

	var fs = editor_interface.get_resource_filesystem() if Engine.is_editor_hint() else null;
	if not has_imported_resources: return;

	if not fs: return;

	fs.scan();
	await fs.resources_reimported;

	has_imported_resources = false;

## Returns true if any resources were imported
static func import_models(vmf_structure: VMFStructure) -> bool:
	if not VMFConfig.models.import: return false;
	if not "entity" in vmf_structure: return false;

	for entity in vmf_structure.entity:
		if not "model" in entity: continue;
		if entity.classname != "prop_static": continue;

		var model_path = entity.get("model", "").to_lower().get_basename();
		if not model_path: continue;

		var mdl_path = VMFUtils.normalize_path(VMFConfig.gameinfo_path + "/" + model_path + ".mdl");
		var vtx_path = VMFUtils.normalize_path(VMFConfig.gameinfo_path + "/" + model_path + ".vtx");
		var vtx_dx90_path = VMFUtils.normalize_path(VMFConfig.gameinfo_path + "/" + model_path + ".dx90.vtx");
		var vvd_path = VMFUtils.normalize_path(VMFConfig.gameinfo_path + "/" + model_path + ".vvd");
		var phy_path = VMFUtils.normalize_path(VMFConfig.gameinfo_path + "/" + model_path + ".phy");
		var target_path = VMFUtils.normalize_path(VMFConfig.models.target_folder + "/" + model_path);

		if ResourceLoader.exists(target_path + ".mdl"): continue;

		if not FileAccess.file_exists(mdl_path): continue;
		if not FileAccess.file_exists(vtx_path): vtx_path = vtx_dx90_path;
		if not FileAccess.file_exists(vtx_path): continue;
		if not FileAccess.file_exists(vvd_path): continue;

		var model_materials = MDLReader.new(mdl_path).get_possible_material_paths();

		for material_path in model_materials:
			import_textures(material_path);
			import_material(material_path);

		DirAccess.make_dir_recursive_absolute(target_path.get_base_dir());
		DirAccess.copy_absolute(vtx_path, target_path + '.dx90.vtx');
		DirAccess.copy_absolute(vvd_path, target_path + ".vvd");
		if FileAccess.file_exists(phy_path): DirAccess.copy_absolute(phy_path, target_path + ".phy");
		DirAccess.copy_absolute(mdl_path, target_path + ".mdl");

		has_imported_resources = true;

	return has_imported_resources;

static func import_material(material: String) -> bool:
	material = material.to_lower();

	var vmt_path = VMFUtils.normalize_path(VMFConfig.gameinfo_path + "/materials/" + material + ".vmt");
	var target_path = VMFUtils.normalize_path(VMFConfig.materials.target_folder + "/" + material + ".vmt");

	if ResourceLoader.exists(target_path): return false;
	if not FileAccess.file_exists(vmt_path): return false;

	DirAccess.make_dir_recursive_absolute(target_path.get_base_dir());
	var has_error = DirAccess.copy_absolute(vmt_path, target_path);

	if has_error: return false;

	return true;

static func import_materials(vmf_structure: VMFStructure, is_runtime := false) -> void:
	var editor_interface = Engine.get_singleton("EditorInterface") if Engine.is_editor_hint() else null;

	if VMFConfig.materials.import_mode == VMFConfig.MaterialsConfig.ImportMode.USE_EXISTING:
		return;

	var list: Array[String] = [];
	var ignore_list: Array[String];
	ignore_list.assign(VMFConfig.materials.ignore);

	for solid in vmf_structure.solids:
		for side in solid.sides:
			var isIgnored = ignore_list.any(func(rx: String) -> bool: return side.material.match(rx));
			if isIgnored: continue;

			if not list.has(side.material):
				list.append(side.material);

	for entity in vmf_structure.entities:
		if not entity.has_solid:
			continue;

		for solid in entity.solids:
			for side in solid.sides:
				var isIgnored = ignore_list.any(func(rx): return side.material.match(rx));
				if isIgnored: continue;

				if not list.has(side.material):
					list.append(side.material);

	if not is_runtime and editor_interface:
		var fs = editor_interface.get_resource_filesystem() if Engine.is_editor_hint() else null;

		for material in list:
			import_textures(material);

		for material in list:
			import_material(material);

static func import_textures(material: String) -> bool:
	material = material.to_lower();

	var target_path = VMFUtils.normalize_path(VMFConfig.gameinfo_path + "/materials/" + material + ".vmt");
	if not FileAccess.file_exists(target_path): 
		VMFLogger.error("Material not found: " + target_path);
		return false;

	var details  = VDFParser.parse(target_path, true).values()[0];

	# NOTE: CS:GO/L4D
	if "insert" in details:
		details.merge(details["insert"]);

	for key in MATERIAL_KEYS_TO_IMPORT:
		if key not in details: continue;
		var vtf_path = VMFUtils.normalize_path(VMFConfig.gameinfo_path + "/materials/" + details[key].to_lower() + ".vtf");
		var target_vtf_path = VMFUtils.normalize_path(VMFConfig.materials.target_folder + "/" + details[key].to_lower() + ".vtf");

		if not FileAccess.file_exists(vtf_path): continue;
		if ResourceLoader.exists(target_vtf_path): continue;

		DirAccess.make_dir_recursive_absolute(target_vtf_path.get_base_dir());
		var has_error = DirAccess.copy_absolute(vtf_path, target_vtf_path);

		if not has_error: 
			has_imported_resources = true;
			continue;
		VMFLogger.error("Failed to copy texture: " + str(has_error));

	return has_imported_resources;
