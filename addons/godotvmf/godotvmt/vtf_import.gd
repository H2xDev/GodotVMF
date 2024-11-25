@tool
class_name VTFImporter extends EditorImportPlugin

func _get_importer_name(): return "VTF";
func _get_visible_name(): return "VTF Importer";
func _get_recognized_extensions(): return ["vtf"];
func _get_save_extension(): return "vtf.tres";
func _get_resource_type(): return "Texture";
func _get_preset_count(): return 0;
func _get_import_order(): return 0;
func _get_priority(): return 1;
func _can_import_threaded(): return false;

func _get_import_options(str, int): return [];
func _get_option_visibility(path: String, optionName: StringName, options: Dictionary): return true;

func _import(path: String, save_path: String, _a, _b, _c):
	var path_to_save = save_path + '.' + _get_save_extension();
	var vtf = VTFLoader.create(path, 0);

	if !vtf: return ERR_FILE_UNRECOGNIZED;

	var texture = vtf.compile_texture();
	return ResourceSaver.save(texture, path_to_save, ResourceSaver.FLAG_CHANGE_PATH);
