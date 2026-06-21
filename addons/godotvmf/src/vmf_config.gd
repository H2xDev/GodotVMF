@static_unload
class_name VMFConfig extends RefCounted

const CONFIG_FILE_PATH = "res://vmf.config.json";

const SETTINGS_TO_LOAD = {
	"godot_vmf/import/gameinfo_path": {
		"default_value": "res://",
		"type": TYPE_STRING,
		"hint": PROPERTY_HINT_GLOBAL_DIR,
	},
	"godot_vmf/models/import": {
		"default_value": false,
		"type": TYPE_BOOL,
		"hint": PROPERTY_HINT_NONE,
	},
	"godot_vmf/models/target_folder": {
		"default_value": "res://",
		"type": TYPE_STRING,
		"hint": PROPERTY_HINT_NONE,
	},
	"godot_vmf/models/lightmap_texel_size": {
		"default_value": 0.4,
		"type": TYPE_FLOAT,
		"hint": PROPERTY_HINT_RANGE,
		"hint_string": "0,100.0,0.000001",
	},
	"godot_vmf/materials/import_mode": {
		"default_value": 0,
		"type": TYPE_INT,
		"hint": PROPERTY_HINT_ENUM,
		"hint_string": "Use Existing, Import from the GameInfo folder",
	},
	"godot_vmf/materials/target_folder": {
		"default_value": "res://materials",
		"type": TYPE_STRING,
		"hint": PROPERTY_HINT_NONE,
	},
	"godot_vmf/materials/ignore": {
		"default_value": ["tools/toolsnodraw", "tools/toolsskybox", "tools/toolsinvisible"],
		"type": TYPE_ARRAY,
		"hint": PROPERTY_HINT_ARRAY_TYPE,
		"hint_string": "%d:String" % TYPE_STRING,
	},
	"godot_vmf/materials/fallback_material": {
		"default_value": "",
		"type": TYPE_STRING,
		"hint": PROPERTY_HINT_RESOURCE_TYPE,
		"hint_string": "Material",
	},
	"godot_vmf/materials/default_texture_size": {
		"default_value": 512,
		"type": TYPE_INT,
		"hint": PROPERTY_HINT_NONE,
	},
	"godot_vmf/import/scale": {
		"default_value": 0.02,
		"type": TYPE_FLOAT,
		"hint": PROPERTY_HINT_RANGE,
		"hint_string": "0,100.0,0.000001",
	},
	"godot_vmf/import/generate_lightmap_uv2": {
		"default_value": true,
		"type": TYPE_BOOL,
		"hint": PROPERTY_HINT_NONE,
	},
	"godot_vmf/import/generate_collision": {
		"default_value": true,
		"type": TYPE_BOOL,
		"hint": PROPERTY_HINT_NONE,
	},
	"godot_vmf/import/generate_navigation_mesh": {
		"default_value": false,
		"type": TYPE_BOOL,
		"hint": PROPERTY_HINT_NONE,
	},
	"godot_vmf/import/navigation_mesh_preset": {
		"default_value": "",
		"type": TYPE_STRING,
		"hint": PROPERTY_HINT_RESOURCE_TYPE,
		"hint_string": "NavigationMesh",
	},
	"godot_vmf/import/lightmap_texel_size": {
		"default_value": 0.2,
		"type": TYPE_FLOAT,
		"hint": PROPERTY_HINT_RANGE,
		"hint_string": "0,100.0,0.000001",
	},
	"godot_vmf/import/instances_folder": {
		"default_value": "res://instances",
		"type": TYPE_STRING,
		"hint": PROPERTY_HINT_DIR,
	},
	"godot_vmf/import/entities_folder": {
		"default_value": "res://entities",
		"type": TYPE_STRING,
		"hint": PROPERTY_HINT_DIR,
	},
	"godot_vmf/import/geometry_folder": {
		"default_value": "res://geometry",
		"type": TYPE_STRING,
		"hint": PROPERTY_HINT_DIR,
	},
	"godot_vmf/import/entity_aliases": {
		"default_value": {},
		"type": TYPE_DICTIONARY,
		"hint": PROPERTY_HINT_DICTIONARY_TYPE,
		"hint_string": "%d:;%d/%d:*.tscn" % [TYPE_STRING, TYPE_STRING, PROPERTY_HINT_FILE],
	},
	"godot_vmf/import/detail_props_chunk_size": {
		"default_value": 32.0,
		"type": TYPE_FLOAT,
		"hint": PROPERTY_HINT_RANGE,
		"hint_string": "0,1000.0,0.000001",
	},
	"godot_vmf/import/detail_props_draw_distance": {
		"default_value": 100.0,
		"type": TYPE_FLOAT,
		"hint": PROPERTY_HINT_RANGE,
		"hint_string": "0,1000.0,0.000001",
	},
	"godot_vmf/import/additional_import_paths": {
		"default_value": [],
		"type": TYPE_ARRAY,
		"hint": PROPERTY_HINT_ARRAY_TYPE,
		"hint_string": "%d/%d:" % [TYPE_STRING, PROPERTY_HINT_GLOBAL_DIR],
	}
};

class ModelsConfig:
	## If true, the importer will import models from the mod folder
	var import: bool = ProjectSettings.get_setting("godot_vmf/models/import", false):
		set(value):
			ProjectSettings.set_setting("godot_vmf/models/import", value);

	## Texel size for the imported models
	var lightmap_texel_size: float = ProjectSettings.get_setting("godot_vmf/models/lightmap_texel_size", 0.4):
		set(value):
			ProjectSettings.set_setting("godot_vmf/models/lightmap_texel_size", value);

	## Folder where importer will copy models from the mod folder
	## Also this is where the prop_static will grab models from
	var target_folder: String = ProjectSettings.get_setting("godot_vmf/models/target_folder", "res://"):
		set(value):
			ProjectSettings.set_setting("godot_vmf/models/target_folder", value);

class MaterialsConfig:
	enum ImportMode {
		USE_EXISTING = 0,
		IMPORT_FROM_MOD_FOLDER = 1,
	};

	var import_mode: ImportMode = ProjectSettings.get_setting("godot_vmf/materials/import_mode", ImportMode.USE_EXISTING);

	## Folder where importer or target materials be stored
	var target_folder: String = ProjectSettings.get_setting("godot_vmf/materials/target_folder", "res://materials");

	## Materials in this list will be ignored during import
	var ignore: Array = ProjectSettings.get_setting("godot_vmf/materials/ignore", []);

	## A material that will be used as a fallback for missing materials
	var fallback_material: String = ProjectSettings.get_setting("godot_vmf/materials/fallback_material", "");

	## Fallback texture size for missing textures
	var default_texture_size: int = ProjectSettings.get_setting("godot_vmf/materials/default_texture_size", 512);

class ImportConfig:
	## Target scale that will be applied to all imported models and maps
	var scale: float = ProjectSettings.get_setting("godot_vmf/import/scale", 0.02);

	## If true, the importer will generate collision meshes for the level geometry
	var generate_collision: bool = ProjectSettings.get_setting("godot_vmf/import/generate_collision", true);

	## If true, the importer will generate lightmap UV2 for the level geometry
	var generate_lightmap_uv2: bool = ProjectSettings.get_setting("godot_vmf/import/generate_lightmap_uv2", true);

	## Texel size for lightmap 
	var lightmap_texel_size: float = ProjectSettings.get_setting("godot_vmf/import/lightmap_texel_size", 0.2);

	## Lightmap texture size
	var lightmap_size: int = ProjectSettings.get_setting("godot_vmf/import/lightmap_size", 1024);

	## The path where imported instances be saved
	var instances_folder: String = ProjectSettings.get_setting("godot_vmf/import/instances_folder", "res://instances");

	## The path from importer will grab entities
	var entities_folder: String = ProjectSettings.get_setting("godot_vmf/import/entities_folder", "res://entities");

	## The path where imported geometry and collision be saved
	var geometry_folder: String = ProjectSettings.get_setting("godot_vmf/import/geometry_folder", "res://geometry");

	## A dictionary of entity aliases where key is an entity name and value is a path to the scene
	var entity_aliases: Dictionary = ProjectSettings.get_setting("godot_vmf/import/entity_aliases", {}):
		set(value):
			ProjectSettings.set_setting("godot_vmf/entity_aliases", value);

	## If true, the importer will generate a navigation mesh for the level geometry
	var use_navigation_mesh: bool = ProjectSettings.get_setting("godot_vmf/import/generate_navigation_mesh", false);

	## If specified, the importer will use this preset for the navigation mesh
	var navigation_mesh_preset: String = ProjectSettings.get_setting("godot_vmf/import/navigation_mesh_preset", "");

	## Detail props are meshes instanced across the level geometry based on material metadata. 
	## This field defines a size of one chunk of detail props. The bigger the chunk size, the less multimesh instances will be created, 
	## but the more detail props will be in one chunk, which can lead to worse performance.
	var detail_props_chunk_size: float = ProjectSettings.get_setting("godot_vmf/import/detail_props_chunk_size", 32.0);

	## The maximum distance at which detail props will be visible. This is important for performance, as rendering too many detail props at long distances can be costly.
	var detail_props_draw_distance: float = ProjectSettings.get_setting("godot_vmf/import/detail_props_draw_distance", 100.0);

	var gameinfo_path: String = ProjectSettings.get_setting("godot_vmf/import/gameinfo_path", "res://");

	var additional_import_paths: Array = ProjectSettings.get_setting("godot_vmf/import/additional_import_paths", []);

## NOTE: Support previous version of this config where this field wasn't a part of ImportConfig
static var gameinfo_path: String:
	get: return ProjectSettings.get_setting("godot_vmf/import/gameinfo_path", "res://");

static var models: ModelsConfig:
	get:
		if not models:
			models = ModelsConfig.new();
		return models;

static var materials: MaterialsConfig:
	get:
		if not materials:
			materials = MaterialsConfig.new();
		return materials;

static var import: ImportConfig:
	get:
		if not import:
			import = ImportConfig.new();
		return import;

static func assign(target, source: Dictionary):
	if not target: return;
	for key in source.keys():
		if not key in target and target is not Dictionary: continue;

		if source[key] is Dictionary and source[key] is not Array:
			target[key]	= assign(target[key], source[key]);
		else:
			target[key] = source[key];

	return target;

static func is_dictionary_equal(a: Dictionary, b: Dictionary):
	if a.keys().size() != b.keys().size():
		return false;

	for key in a.keys():
		if not key in b: return false;
		if a[key] != b[key]: return false;
	
	return true;

static func update_config_field():
	gameinfo_path = ProjectSettings.get_setting("godot_vmf/import/gameinfo_path", "res://");

	import = ImportConfig.new();
	models = ModelsConfig.new();
	materials = MaterialsConfig.new();

static func detach_signals():
	ProjectSettings.settings_changed.disconnect(update_config_field);

static func define_project_settings():
	for setting in SETTINGS_TO_LOAD:
		var info = SETTINGS_TO_LOAD[setting]
		var default_val = info["default_value"]
		if not ProjectSettings.has_setting(setting):
			ProjectSettings.set_setting(setting, default_val)
		ProjectSettings.set_initial_value(setting, default_val)
		ProjectSettings.set_as_basic(setting, true)

		var prop_info = info.duplicate()
		prop_info["name"] = setting
		ProjectSettings.add_property_info(prop_info)

	ProjectSettings.settings_changed.connect.call_deferred(update_config_field);

static func load_config():
	if not Engine.is_editor_hint(): return;
	if not FileAccess.file_exists(CONFIG_FILE_PATH): return;
	var file = FileAccess.open(CONFIG_FILE_PATH, FileAccess.READ);
	var json = JSON.parse_string(file.get_as_text());
	file.close();

	assign(VMFConfig, json);
	update_config_field();
