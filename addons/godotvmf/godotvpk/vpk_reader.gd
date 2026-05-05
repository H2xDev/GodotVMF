class_name VPKReader extends RefCounted

var vpk_content: Dictionary;
var vpk_file: FileAccess;
var archives: Array[FileAccess] = [];
var debug_mode: bool = false;
var header: VPKHeader;

## developer.valvesoftware.com - If ArchiveIndex is 0x7fff, the offset of the file data relative to the end of the directory (see the header for more details).
const ZERO_ARCHIVE: int = 0x7fff;

static func open(file_path: String) -> VPKReader:
	if not FileAccess.file_exists(file_path): return null;

	return VPKReader.new(file_path);

func _init(file_path: String = ""):
	vpk_file = FileAccess.open(file_path, FileAccess.READ);
	read_vpk_header();
	read_directory();

func free_vpk():
	if vpk_file: vpk_file.close();

	if archives.size() > 0:
		for archive in archives:
			if archive: archive.close();

	if debug_mode: print("Closed VPK file.");

func is_file_exists(file_path: String) -> bool:
	return vpk_content.has(file_path);

## Returns the file data as a PackedByteArray, or null if the file is not found or an error occurs
func get_file_data(file_path: String) -> Variant:
	if not is_file_exists(file_path):
		if debug_mode: print("File not found in VPK: %s" % file_path);
		return null;

	var entry: VPKDirectoryEntry = vpk_content.get(file_path, null);
	var dataset: PackedByteArray;

	if entry.archive_index == ZERO_ARCHIVE:
		vpk_file.seek(header.tree_size + entry.offset);
		dataset = vpk_file.get_buffer(entry.length);
	else:
		var archive_path = "%s_%03d.vpk" % [vpk_file.get_path().get_basename().replace("_dir", ""), entry.archive_index];
		var archive_file: FileAccess;

		if debug_mode: print("Reading from archive: %s (index: %d)" % [archive_path, entry.archive_index]);

		if not FileAccess.file_exists(archive_path):
			if debug_mode: print("Archive file not found: %s" % archive_path);
			return null;

		# Check if the archive is already open
		for archive in archives:
			if archive and archive.get_path() == archive_path:
				archive_file = archive;
				break;

		if not archive_file:
			archive_file = FileAccess.open(archive_path, FileAccess.READ);
			if not archive_file:
				if debug_mode: print("Failed to open archive file: %s" % archive_path);
				return null;
			archives.append(archive_file);

		archive_file.seek(entry.offset);
		dataset = archive_file.get_buffer(entry.length);

	return dataset;

func read_vpk_header() -> void:
	var header := VMFStruct.transform_struct(vpk_file, VPKHeader, VPKHeader._schema());

	if header.version == 2:
		vpk_file.seek(0);
		header = VMFStruct.transform_struct(vpk_file, VPKHeaderV2, VPKHeaderV2._schema());

	if not header.is_valid: 
		if debug_mode:
			print("Invalid VPK file: signature mismatch (0x%X)" % header.signature);
			print("Expected signature: 0x55AA1234");
		return;

func read_directory() -> void:
	while not vpk_file.eof_reached():
		var extension := VMFStruct.get_null_terminated_string(vpk_file);
		if extension == "": break;

		while not vpk_file.eof_reached():
			var path := VMFStruct.get_null_terminated_string(vpk_file);
			if path == "": break;

			while not vpk_file.eof_reached():
				var filename := VMFStruct.get_null_terminated_string(vpk_file);
				if filename == "": break;

				var full_path = VMFUtils.normalize_path("%s/%s.%s" % [path, filename, extension]);

				if debug_mode:
					print("Reading directory entry for file: %s" % full_path);

				vpk_content[full_path] = read_directory_entry(vpk_file);


func read_directory_entry(file: FileAccess) -> VPKDirectoryEntry:
	return VMFStruct.transform_struct(file, VPKDirectoryEntry, VPKDirectoryEntry._schema());

func extract_file(file_path: String, output_path: String) -> bool:
	var file_data = get_file_data(file_path);
	if file_data == null:
		VMFLogger.error("Failed to extract file: %s (file not found or error occurred)" % file_path);
		return false;

	if DirAccess.dir_exists_absolute(output_path.get_base_dir()) == false:
		if DirAccess.make_dir_recursive_absolute(output_path.get_base_dir()):
			VMFLogger.error("Failed to create output directory: %s" % output_path.get_base_dir());
			return false;

	var output_file = FileAccess.open(output_path, FileAccess.WRITE);
	if not output_file:
		VMFLogger.error("Failed to open output file for writing: %s" % output_path);
		return false;

	output_file.store_buffer(file_data);
	output_file.close();

	if debug_mode: print("Successfully extracted file '%s' to '%s'" % [file_path, output_path]);
	return true;
