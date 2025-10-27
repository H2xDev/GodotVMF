@tool
class_name VTFImporter extends EditorImportPlugin

func _get_importer_name(): return "VTF";
func _get_visible_name(): return "VTF Importer";
func _get_recognized_extensions(): return ["vtf"];
func _get_save_extension(): return "vtf.res";
func _get_resource_type(): return "Texture";
func _get_preset_count(): return 0;
func _get_import_order(): return 0;
func _get_priority(): return 1;
func _can_import_threaded(): return false;

func _get_import_options(str, int): return [
	{
		name = "srgb_conversion_method",
		default_value = 1,
		type = TYPE_INT,
		property_hint = PROPERTY_HINT_ENUM,
		hint_string = "Disabled, During import, Process in shader",
		description = "Perform conversion from SRGB to Linear"
	}
];

func _get_option_visibility(path: String, optionName: StringName, options: Dictionary): return true;

func _import(path: String, save_path: String, options: Dictionary, _b, _c):
	var path_to_save = save_path + '.' + _get_save_extension();
	var vtf = VTFLoader.create(path, 0.033); # 30 FPS

	if !vtf: return ERR_FILE_UNRECOGNIZED;

	var texture = vtf.compile_texture(options.srgb_conversion_method);
	if not texture: return ERR_FILE_CORRUPT;
	texture.set_meta("srgb_conversion_method", options.srgb_conversion_method);

	return ResourceSaver.save(texture, path_to_save, ResourceSaver.FLAG_COMPRESS);
