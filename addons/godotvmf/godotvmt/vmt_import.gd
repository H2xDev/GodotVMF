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
func _can_import_threaded(): return false;

func _get_import_options(str, int): return [];
func _get_option_visibility(path: String, optionName: StringName, options: Dictionary): return true;

func _import(path: String, save_path: String, _a, _b, _c):
	var material = VMTLoader.load(path);
	var path_to_save = save_path + '.' + _get_save_extension();

	if ResourceLoader.exists(path_to_save):
		DirAccess.remove_absolute(path_to_save);

	var error = ResourceSaver.save(material, path_to_save, ResourceSaver.FLAG_COMPRESS);

	if (error == OK):
		material.take_over_path(path_to_save);

	return error;

static var cached_materials = {};
static var last_cache_changed = 0;

static func normalize_path(path: String) -> String:
	return path.replace('\\', '/').replace('//', '/').replace('res:/', 'res://');
