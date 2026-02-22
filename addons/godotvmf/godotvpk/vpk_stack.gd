class_name VPKStack extends RefCounted

var vpks: Array[VPKReader] = [];

## Creates a new VPKStack instance and initializes it by loading all VPK files from the specified gameinfo directory.
static func create(gameinfo_dir: String) -> VPKStack:
	return VPKStack.new(gameinfo_dir);

func _init(gameinfo_dir: String = ""):
	if gameinfo_dir != "":
		append(gameinfo_dir);

## Appends all VPK files from the specified gameinfo directory to the stack.
func append(gameinfo_dir: String):
	var vpk_files := Array(DirAccess.open(gameinfo_dir) \
		.get_files()) \
		.filter(func(file_name: String): return file_name.ends_with("_dir.vpk"));

	for vpk_file in vpk_files:
		var vpk_path = "%s/%s" % [gameinfo_dir, vpk_file];
		var vpk_reader = VPKReader.open(vpk_path);
		if vpk_reader:
			vpks.append(vpk_reader);
		else:
			VMFLogger.error("Failed to open VPK file: %s" % vpk_path);


## Frees all VPK readers in the stack and clears the list.
func free_vpks():
	for vpk in vpks:
		if vpk: vpk.free_vpk();

	vpks.clear();

## Checks if the specified file exists in any of the VPKs in the stack.
func exists(file_path: String) -> bool:
	for vpk in vpks:
		if vpk.is_file_exists(file_path): return true;

	return false;

## Extracts the specified file from the VPK stack and saves it to the output path. 
## Returns true on success, or false if the file is not found or an error occurs.
func extract(file_path: String, output_path: String) -> bool:
	for vpk in vpks:
		if vpk and vpk.is_file_exists(file_path):
			return vpk.extract_file(file_path, output_path);

	return false;

func get_file_data(file_path: String) -> Variant:
	for vpk in vpks:
		if vpk and vpk.is_file_exists(file_path):
			return vpk.get_file_data(file_path);

	return null;
