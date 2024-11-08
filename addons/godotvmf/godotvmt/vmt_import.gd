@tool
class_name VMTImporter extends EditorImportPlugin

func _get_importer_name(): return "VMT";
func _get_visible_name(): return "VMT Importer";
func _get_recognized_extensions(): return ["vmt"];
func _get_save_extension(): return "vmt.tres";
func _get_resource_type(): return "Material";
func _get_preset_count(): return 0;
func _get_import_order(): return 1;
func _get_priority(): return 1;
func _can_import_threaded(): return true;

func _get_import_options(str, int): return [];
func _get_option_visibility(path: String, optionName: StringName, options: Dictionary): return true;

func _import(path: String, save_path: String, _a, _b, _c):
	var path_to_save = save_path + '.' + _get_save_extension();
	var material = VMTLoader.load(path);

	return ResourceSaver.save(material, path_to_save, ResourceSaver.FLAG_COMPRESS);

static func normalize_path(path: String) -> String:
	return path.replace('\\', '/').replace('//', '/').replace('res:/', 'res://');

static func load(material: String):
	var material_path = normalize_path(VMFConfig.config.material.targetFolder + "/" + material + ".tres");

	if not ResourceLoader.exists(material_path):
		material_path = material_path.replace(".tres", ".vmt");

	if not ResourceLoader.exists(material_path):
		VMFLogger.warn("Material not found: " + material);
		return null;

	return ResourceLoader.load(material_path);
