@static_unload
class_name VMFGameFolder extends RefCounted

## Returns an array of all game folder paths, including the main gameinfo path and any additional import paths
static func get_all_paths() -> Array[String]:
	var paths: Array[String] = [VMFConfig.gameinfo_path];
	paths += VMFConfig.import.additional_import_paths;

	return paths;

## Returns the full path to the file if it exists in any of the game folder paths, otherwise returns an empty string
static func get_import_path(file_path: String) -> String:
	for path in get_all_paths():
		var full_path = VMFUtils.normalize_path(path + "/" + file_path);
		if FileAccess.file_exists(full_path):
			return full_path;

	return "";

static func file_exists(file_path: String) -> bool:
	return get_import_path(file_path) != "";
