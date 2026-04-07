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
static var vpk_stack: VPKStack;

static func get_editor_interface():
	return Engine.get_singleton("EditorInterface") if Engine.has_singleton("EditorInterface") else null;

## Initializes the VPK stack by loading all VPK files from the specified gameinfo directory. 
## This should be called before attempting to import any resources, as it allows the manager 
## to check for the existence of files within the VPKs and extract them if necessary.
static func init_vpk_stack() -> void:
	if not VMFConfig.models.import and VMFConfig.materials.import_mode == VMFConfig.MaterialsConfig.ImportMode.USE_EXISTING: return;
	vpk_stack = VPKStack.create(VMFConfig.gameinfo_path);

static func free_vpk_stack() -> void:
	if vpk_stack:
		vpk_stack.free_vpks();
		vpk_stack = null;

static func for_resource_import() -> void:
	if not has_imported_resources: return;

	var editor_interface = get_editor_interface();
	if not editor_interface: return;

	var fs = editor_interface.get_resource_filesystem();
	if not fs: return;

	fs.scan();
	await fs.resources_reimported;

	has_imported_resources = false;

## Returns true if any resources were imported
static func import_models(vmf_structure: VMFStructure) -> bool:
	if not VMFConfig.models.import: return false;
	if vmf_structure.entities.size() == 0: return false;

	for entity in vmf_structure.entities:
		if not "model" in entity.data: continue;
		if entity.classname != "prop_static": continue;

		var model_path = entity.data.get("model", "").to_lower().get_basename();
		if not model_path: continue;

		# Game directory paths
		var gamedir_path = VMFUtils.normalize_path(VMFConfig.gameinfo_path + "/" + model_path);
		var mdl_path = VMFUtils.normalize_path(gamedir_path + ".mdl");
		var vtx_path = VMFUtils.normalize_path(gamedir_path + ".vtx");
		var vtx_dx90_path = VMFUtils.normalize_path(gamedir_path + ".dx90.vtx");
		var vvd_path = VMFUtils.normalize_path(gamedir_path + ".vvd");
		var phy_path = VMFUtils.normalize_path(gamedir_path + ".phy");

		# VPK paths
		var vpk_mdl_path = VMFUtils.normalize_path(model_path + ".mdl");
		var vpk_vtx_path = VMFUtils.normalize_path(model_path + ".dx90.vtx");
		var vpk_vvd_path = VMFUtils.normalize_path(model_path + ".vvd");
		var vpk_phy_path = VMFUtils.normalize_path(model_path + ".phy");

		var target_path = VMFUtils.normalize_path(VMFConfig.models.target_folder + "/" + model_path);

		if ResourceLoader.exists(target_path + ".mdl"): continue;

		var found_in_game_dir := FileAccess.file_exists(mdl_path) \
			and FileAccess.file_exists(vtx_path) \
			and FileAccess.file_exists(vvd_path);

		var found_in_vpk := file_exists_in_vpk(vpk_mdl_path) \
			and file_exists_in_vpk(vpk_vtx_path) \
			and file_exists_in_vpk(vpk_vvd_path);

		if not found_in_game_dir and not found_in_vpk:
			VMFLogger.error("Model files not found for: " + vpk_mdl_path);
			continue;

		if found_in_game_dir:
			DirAccess.make_dir_recursive_absolute(target_path.get_base_dir());
			DirAccess.copy_absolute(vtx_path, target_path + '.dx90.vtx');
			DirAccess.copy_absolute(vvd_path, target_path + ".vvd");
			if FileAccess.file_exists(phy_path): DirAccess.copy_absolute(phy_path, target_path + ".phy");
			DirAccess.copy_absolute(mdl_path, target_path + ".mdl");

		elif found_in_vpk:
			if not vpk_stack.extract(vpk_vtx_path, target_path + '.dx90.vtx'):
				VMFLogger.error("Failed to extract VTX from VPK: " + vpk_vtx_path);
				continue;

			if not vpk_stack.extract(vpk_vvd_path, target_path + ".vvd"):
				VMFLogger.error("Failed to extract VVD from VPK: " + vpk_vvd_path);
				continue;

			if file_exists_in_vpk(vpk_phy_path):
				if not vpk_stack.extract(vpk_phy_path, target_path + ".phy"):
					VMFLogger.error("Failed to extract PHY from VPK: " + vpk_phy_path);

			if not vpk_stack.extract(vpk_mdl_path, target_path + ".mdl"):
				VMFLogger.error("Failed to extract MDL from VPK: " + vpk_mdl_path);
				continue;

		var model_materials = MDLReader.new(target_path + ".mdl").get_possible_material_paths();

		for material_path in model_materials:
			import_textures(material_path);
			import_material(material_path);

		has_imported_resources = true;

	return has_imported_resources;

static func file_exists_in_vpk(vpk_file_path: String) -> bool:
	if not vpk_stack: return false;
	return vpk_stack.exists(vpk_file_path);

static func import_material(material: String) -> bool:
	material = material.to_lower();

	var vpk_path = "materials/" + material + ".vmt";
	var vmt_path = VMFUtils.normalize_path(VMFConfig.gameinfo_path + "/materials/" + material + ".vmt");
	var target_path = VMFUtils.normalize_path(VMFConfig.materials.target_folder + "/" + material + ".vmt");

	if ResourceLoader.exists(target_path): return false;

	# Trying to find material in game directory first, as it can be overridden by mods and thus differ from the one in VPKs
	if FileAccess.file_exists(vmt_path):
		DirAccess.make_dir_recursive_absolute(target_path.get_base_dir());
		if DirAccess.copy_absolute(vmt_path, target_path): return false;

		has_imported_resources = true;

	# Trying to find material in VPKs
	elif file_exists_in_vpk(vpk_path):
		if not vpk_stack.extract(vpk_path, target_path):
			VMFLogger.error("Failed to extract material from VPK: " + vpk_path);
			return false;

		has_imported_resources = true;

	else:
		VMFLogger.error("Material not found: " + vpk_path);
		return false;

	return has_imported_resources;

static func import_materials(vmf_structure: VMFStructure, is_runtime := false) -> void:
	var editor_interface = get_editor_interface();

	if VMFConfig.materials.import_mode == VMFConfig.MaterialsConfig.ImportMode.USE_EXISTING:
		return;

	var list: Array[String] = [];
	var ignore_list: Array[String];
	ignore_list.assign(VMFConfig.materials.ignore);

	for solid in vmf_structure.solids:
		for side in solid.sides:
			var is_ignored = ignore_list.any(func(rx: String) -> bool: return side.material.match(rx));
			if is_ignored: continue;

			if not list.has(side.material):
				list.append(side.material);

	for entity in vmf_structure.entities:
		if not entity.has_solid: continue;

		for solid in entity.solids:
			for side in solid.sides:
				var is_ignored = ignore_list.any(func(rx): return side.material.match(rx));
				if is_ignored: continue;

				if not list.has(side.material):
					list.append(side.material);

	if not is_runtime and editor_interface:
		for material in list:
			import_textures(material);

		for material in list:
			import_material(material);

static func import_textures(material: String) -> bool:
	material = material.to_lower();

	var target_path = VMFUtils.normalize_path(VMFConfig.gameinfo_path + "/materials/" + material + ".vmt");
	var vmt_vpk_path = "materials/" + material + ".vmt";

	var details: Dictionary = {};

	if FileAccess.file_exists(target_path): 
		details = VDFParser.parse(target_path, true).values()[0];

	elif file_exists_in_vpk(vmt_vpk_path):
		var vmt_data = vpk_stack.get_file_data(vmt_vpk_path);
		if not vmt_data:
			VMFLogger.error("Failed to read material data from VPK: " + vmt_vpk_path);
			return false;
		details = VDFParser.parse_from_string(vmt_data.get_string_from_utf8(), true).values()[0];

	else:
		VMFLogger.error("Failed to find material for texture import: " + material);
		return false;


	# NOTE: CS:GO/L4D
	if "insert" in details:
		details.merge(details["insert"]);

	for key in MATERIAL_KEYS_TO_IMPORT:
		if key not in details: continue;
		var vpk_path = VMFUtils.normalize_path("materials/" + details[key].to_lower() + ".vtf");
		var vtf_path = VMFUtils.normalize_path(VMFConfig.gameinfo_path + "/materials/" + details[key].to_lower() + ".vtf");
		var target_vtf_path = VMFUtils.normalize_path(VMFConfig.materials.target_folder + "/" + details[key].to_lower() + ".vtf");

		if ResourceLoader.exists(target_vtf_path): continue;

		# Trying to find texture in game directory first, as it can be overridden by mods and thus differ from the one in VPKs
		if FileAccess.file_exists(vtf_path): 
			DirAccess.make_dir_recursive_absolute(target_vtf_path.get_base_dir());

			if DirAccess.copy_absolute(vtf_path, target_vtf_path):
				VMFLogger.error("Failed to copy texture: " + vtf_path);
			else:
				has_imported_resources = true;

		# Trying to find texture in VPKs
		elif file_exists_in_vpk(vpk_path):
			if not vpk_stack.extract(vpk_path, target_vtf_path):
				VMFLogger.error("Failed to extract texture from VPK: " + vpk_path);
			else:
				has_imported_resources = true;
		
		else:
			VMFLogger.error("Failed to copy texture: " + vpk_path);

	return true;
