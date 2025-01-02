@tool
class_name VMFConfigClass
extends Node

const CONFIG_FILE_PATH = "res://vmf.config.json";

class ModelsConfig:
	## If true, the importer will import models from the mod folder
	var import: bool = false;

	## Texel size for the imported models
	var lightmap_texel_size: float = 0.4;

	## Folder where importer will copy models from the mod folder
	## Also this is where the prop_static will grab models from
	var target_folder: String = "res://";

class MaterialsConfig:
	enum ImportMode {
		USE_EXISTING = 0,
		IMPORT_FROM_MOD_FOLDER = 1,
	};

	var import_mode: ImportMode = 0;

	## Folder where importer or target materials be stored
	var target_folder: String = "res://materials";

	## Materials in this list will be ignored during import
	var ignore: Array = [];

	## A material that will be used as a fallback for missing materials
	var fallback_material = "";

	## Fallback texture size for missing textures
	var default_texture_size: int = 512;

class ImportConfig:
	## Target scale that will be applied to all imported models and maps
	var scale: float = 0.02;

	## If true, the importer will generate collision meshes for the level geometry
	var generate_collision: bool = true;

	## If true, the importer will generate lightmap UV2 for the level geometry
	var generate_lightmap_uv2: bool = true;

	## Texel size for lightmap 
	var lightmap_texel_size: float = 0.4;

	## Lightmap texture size
	var lightmap_size: int = 1024;

	## The path where imported instances be saved
	var instances_folder: String = "res://instances";

	## The path from importer will grab entities
	var entities_folder: String = "res://entities";

	## The path where imported geometry and collision be saved
	var geometry_folder: String = "res://geometry";

	## A dictionary of entity aliases where key is an entity name and value is a path to the scene
	var entity_aliases: Dictionary = {}

	## If true, the importer will generate a navigation mesh for the level geometry
	var use_navigation_mesh: bool = false;

	## If specified, the importer will use this preset for the navigation mesh
	var navigation_mesh_preset: String = "";

var gameinfo_path: String = "res://";
var models: ModelsConfig = ModelsConfig.new();
var materials: MaterialsConfig = MaterialsConfig.new();
var import: ImportConfig = ImportConfig.new();
var vtfcmd: String = "";

func assign(target, source: Dictionary):
	for key in source.keys():
		if not key in target and target is not Dictionary: continue;

		if source[key] is Dictionary and source[key] is not Array:
			target[key]	= assign(target[key], source[key]);
		else:
			target[key] = source[key];

	return target;

func load_config():
	if not FileAccess.file_exists(CONFIG_FILE_PATH): return;
	var file = FileAccess.open(CONFIG_FILE_PATH, FileAccess.READ);
	var json = JSON.parse_string(file.get_as_text());
	file.close();

	assign(self, json);

func _ready(): load_config();
