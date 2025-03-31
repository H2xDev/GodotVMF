@tool
class_name MDLImporter extends EditorImportPlugin

func _get_importer_name(): return "MDL"
func _get_visible_name(): return "MDL"
func _get_recognized_extensions(): return ["mdl"];
func _get_save_extension(): return "tscn";
func _get_resource_type(): return "PackedScene";
func _get_priority(): return 1;
func _get_preset_count(): return 0;
func _get_import_order(): return 2;

func _can_import_threaded(): return false;

func _get_import_options(str, int):
	return [
		{
			name = "use_global_scale",
			default_value = true,
			type = TYPE_BOOL,
		},
		{
			name = "scale",
			default_value = 0.02,
			type = TYPE_FLOAT,
		},
		{
			name = "additional_rotation",
			description = "In case you have wrong oriented model you can add the additional rotaion here to correct the original orientation",
			default_value = Vector3.ZERO,
			type = TYPE_VECTOR3,
		},
		{
			name = "generate_occluder",
			default_value = false,
			type = TYPE_BOOL,
		},
		{
			name = "generate_lods",
			default_value = true,
			type = TYPE_BOOL,
		},
		{
			name = "primitive_occluder",
			default_value = false,
			type = TYPE_BOOL,
			description = "Generates a simple box for the model's occluder. If disabled, the occluder will be generated from the model's collision data."
		},
		{
			name = "primitive_occluder_scale",
			default_value = Vector3.ONE,
			type = TYPE_VECTOR3,
			description = "Occluder box scale"
		},
		{
			name = "gi_mode",
			default_value = 1,
			type = TYPE_INT,
			property_hint = PROPERTY_HINT_ENUM,
			hint_string = "Disabled,Static,Dynamic",
		}
	];

func _get_option_visibility(path: String, optionName: StringName, options: Dictionary): return true;

func _import(mdl_path: String, save_path: String, options: Dictionary, _platform_variants, _gen_files):
	var vtx_path = mdl_path.replace(".mdl", ".vtx");
	var vvd_path = mdl_path.replace(".mdl", ".vvd");
	var phy_path = mdl_path.replace(".mdl", ".phy");
	# var ani_path = mdl_path.replace(".mdl", ".ani");

	var mdl = MDLReader.new(mdl_path);
	var vtx = VTXReader.new(vtx_path, mdl.header.version);
	var vvd = VVDReader.new(vvd_path);
	var phy = PHYReader.new(phy_path);
	# var ani = ANIReader.new(mdl_path, mdl.header);

	var model_name = mdl_path.get_file().get_basename().replace(".mdl", "");

	if (!mdl or !vtx):
		push_error("Error while reading MDL or VTX file.");
		return false;

	if not vtx.header:
		return ERR_PARSE_ERROR;

	if (mdl.header.checksum != vtx.header.check_sum):
		push_error("MDL and VTX checksums do not match.");
		return ERR_PARSE_ERROR;

	var path_to_save = save_path + '.' + _get_save_extension();

	var scn = PackedScene.new();
	var model = MDLMeshGenerator.generate_mesh(mdl, vtx, vvd, phy, options);
	model.set_name(model_name);

	scn.pack(model);

	var error = ResourceSaver.save(scn, path_to_save, ResourceSaver.FLAG_COMPRESS);

	model.queue_free();

	return error;
