@static_unload
class_name VMFConfig extends RefCounted

const CONFIG_FILE_PATH = "res://vmf.config.json";

const SETTINGS_TO_LOAD = [
	"godot_vmf/models/import",
	"godot_vmf/models/target_folder",
	"godot_vmf/models/lightmap_texel_size",
	"godot_vmf/materials/import_mode",
	"godot_vmf/materials/target_folder",
	"godot_vmf/materials/ignore",
	"godot_vmf/materials/fallback_material",
	"godot_vmf/materials/default_texture_size",
	"godot_vmf/import/scale",
	"godot_vmf/import/generate_lightmap_uv2",
	"godot_vmf/import/generate_collision",
	"godot_vmf/import/generate_navigation_mesh",
	"godot_vmf/import/navigation_mesh_preset",
	"godot_vmf/import/lightmap_texel_size",
	"godot_vmf/import/instances_folder",
	"godot_vmf/import/entities_folder",
	"godot_vmf/import/geometry_folder",
	"godot_vmf/import/entity_aliases",
];

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
	var navigation_mesh_preset: String = ProjectSettings.get_setting("godot_vmf/import/navigation_mesh_preset");

static var gameinfo_path: String = ProjectSettings.get_setting("godot_vmf/import/gameinfo_path", "res://");

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
	if not ProjectSettings.has_setting("godot_vmf/import/gameinfo_path"):
		ProjectSettings.set_setting("godot_vmf/import/gameinfo_path", "res://");
	ProjectSettings.set_initial_value("godot_vmf/import/gameinfo_path", "res://");


	## Import
	if not ProjectSettings.has_setting("godot_vmf/import/scale"):
		ProjectSettings.set_setting("godot_vmf/import/scale", 0.02);
	ProjectSettings.set_initial_value("godot_vmf/import/scale", 0.02);

	if not ProjectSettings.has_setting("godot_vmf/import/generate_lightmap_uv2"):
		ProjectSettings.set_setting("godot_vmf/import/generate_lightmap_uv2", true);
	ProjectSettings.set_initial_value("godot_vmf/import/generate_lightmap_uv2", true);

	if not ProjectSettings.has_setting("godot_vmf/import/generate_collision"):
		ProjectSettings.set_setting("godot_vmf/import/generate_collision", true);
	ProjectSettings.set_initial_value("godot_vmf/import/generate_collision", true);

	if not ProjectSettings.has_setting("godot_vmf/import/generate_navigation_mesh"):
		ProjectSettings.set_setting("godot_vmf/import/generate_navigation_mesh", false);
	ProjectSettings.set_initial_value("godot_vmf/import/generate_navigation_mesh", false);


	if not ProjectSettings.has_setting("godot_vmf/import/navigation_mesh_preset"):
		ProjectSettings.set_setting("godot_vmf/import/navigation_mesh_preset", "");
	ProjectSettings.set_initial_value("godot_vmf/import/navigation_mesh_preset", "");


	if not ProjectSettings.has_setting("godot_vmf/import/lightmap_texel_size"):
		ProjectSettings.set_setting("godot_vmf/import/lightmap_texel_size", 0.2);
	ProjectSettings.set_initial_value("godot_vmf/import/lightmap_texel_size", 0.2);

	if not ProjectSettings.has_setting("godot_vmf/import/instances_folder"):
		ProjectSettings.set_setting("godot_vmf/import/instances_folder", "res://instances");
	ProjectSettings.set_initial_value("godot_vmf/import/instances_folder", "res://instances");

	if not ProjectSettings.has_setting("godot_vmf/import/entities_folder"):
		ProjectSettings.set_setting("godot_vmf/import/entities_folder", "res://entities");
	ProjectSettings.set_initial_value("godot_vmf/import/entities_folder", "res://entities");

	if not ProjectSettings.has_setting("godot_vmf/import/geometry_folder"):
		ProjectSettings.set_setting("godot_vmf/import/geometry_folder", "res://geometry");
	ProjectSettings.set_initial_value("godot_vmf/import/geometry_folder", "res://geometry");

	if not ProjectSettings.has_setting("godot_vmf/import/entity_aliases"):
		ProjectSettings.set_setting("godot_vmf/import/entity_aliases", {});
	ProjectSettings.set_initial_value("godot_vmf/import/entity_aliases", {});


	## Models
	if not ProjectSettings.has_setting("godot_vmf/models/import"):
		ProjectSettings.set_setting("godot_vmf/models/import", false);
	ProjectSettings.set_initial_value("godot_vmf/models/import", false);

	if not ProjectSettings.has_setting("godot_vmf/models/target_folder"):
		ProjectSettings.set_setting("godot_vmf/models/target_folder", "res://");
	ProjectSettings.set_initial_value("godot_vmf/models/target_folder", "res://");

	if not ProjectSettings.has_setting("godot_vmf/models/lightmap_texel_size"):
		ProjectSettings.set_setting("godot_vmf/models/lightmap_texel_size", 0.4);
	ProjectSettings.set_initial_value("godot_vmf/models/lightmap_texel_size", 0.4);


	## Materials
	if not ProjectSettings.has_setting("godot_vmf/materials/import_mode"):
		ProjectSettings.set_setting("godot_vmf/materials/import_mode", 0);
	ProjectSettings.set_initial_value("godot_vmf/materials/import_mode", 0);

	if not ProjectSettings.has_setting("godot_vmf/materials/target_folder"):
		ProjectSettings.set_setting("godot_vmf/materials/target_folder", "res://materials");
	ProjectSettings.set_initial_value("godot_vmf/materials/target_folder", "res://materials");

	if not ProjectSettings.has_setting("godot_vmf/materials/ignore"):
		ProjectSettings.set_setting("godot_vmf/materials/ignore", ["tools/toolsnodraw", "tools/toolsskybox", "tools/toolsinvisible"]);
	ProjectSettings.set_initial_value("godot_vmf/materials/ignore", ["tools/toolsnodraw", "tools/toolsskybox", "tools/toolsinvisible"]);

	if not ProjectSettings.has_setting("godot_vmf/materials/fallback_material"):
		ProjectSettings.set_setting("godot_vmf/materials/fallback_material", "");
	ProjectSettings.set_initial_value("godot_vmf/materials/fallback_material", "");

	if not ProjectSettings.has_setting("godot_vmf/materials/default_texture_size"):
		ProjectSettings.set_setting("godot_vmf/materials/default_texture_size", 512);
	ProjectSettings.set_initial_value("godot_vmf/materials/default_texture_size", 512);
	
	ProjectSettings.add_property_info({
		"name": "godot_vmf/import/gameinfo_path",
		"type": TYPE_STRING,
		"hint": PROPERTY_HINT_GLOBAL_FILE ,
		"hint_string": "gameinfo.txt,GameInfo.txt",
		"default_value": 'res://',
	})

	## Import
	ProjectSettings.add_property_info({
		"name": "godot_vmf/import/scale",
		"type": TYPE_FLOAT,
		"hint": PROPERTY_HINT_NONE,
		"default_value": 0.02,
	})

	ProjectSettings.add_property_info({
		"name": "godot_vmf/import/generate_lightmap_uv2",
		"type": TYPE_BOOL,
		"hint": PROPERTY_HINT_NONE,
		"default_value": true,
	})

	ProjectSettings.add_property_info({
		"name": "godot_vmf/import/generate_navigation_mesh",
		"type": TYPE_BOOL,
		"hint": PROPERTY_HINT_NONE,
		"default_value": false,
	})

	ProjectSettings.add_property_info({
		"name": "godot_vmf/import/navigation_mesh_preset",
		"type": TYPE_STRING,
		"hint": PROPERTY_HINT_RESOURCE_TYPE,
		"hint_string": "NavigationMesh",
		"default_value": "",
	})

	ProjectSettings.add_property_info({
		"name": "godot_vmf/import/generate_collision",
		"type": TYPE_BOOL,
		"hint": PROPERTY_HINT_NONE,
		"default_value": false,
	})

	ProjectSettings.add_property_info({
		"name": "godot_vmf/import/lightmap_texel_size",
		"type": TYPE_FLOAT,
		"hint": PROPERTY_HINT_NONE,
		"default_value": 0.2,
	})

	ProjectSettings.add_property_info({
		"name": "godot_vmf/import/instances_folder",
		"type": TYPE_STRING,
		"hint": PROPERTY_HINT_DIR,
		"default_value": "res://instances",
	})

	ProjectSettings.add_property_info({
		"name": "godot_vmf/import/entities_folder",
		"type": TYPE_STRING,
		"hint": PROPERTY_HINT_DIR,
		"default_value": "res://entities",
	})

	ProjectSettings.add_property_info({
		"name": "godot_vmf/import/geometry_folder",
		"type": TYPE_STRING,
		"hint": PROPERTY_HINT_DIR,
		"default_value": "res://geometry",
	})

	ProjectSettings.add_property_info({
		"name": "godot_vmf/import/entity_aliases",
		"type": TYPE_DICTIONARY,
		"hint": PROPERTY_HINT_DICTIONARY_TYPE,
		"hint_string": "%d:;%d/%d:*.tscn" % [TYPE_STRING, TYPE_STRING, PROPERTY_HINT_FILE],
		"default_value": {},
	})

	## Models
	ProjectSettings.add_property_info({
		"name": "godot_vmf/models/import",
		"type": TYPE_BOOL,
		"hint": PROPERTY_HINT_NONE,
		"default_value": false
	})

	ProjectSettings.add_property_info({
		"name": "godot_vmf/models/target_folder",
		"type": TYPE_STRING,
		"hint": PROPERTY_HINT_NONE,
		"default_value": "res://"
	})

	ProjectSettings.add_property_info({
		"name": "godot_vmf/models/lightmap_texel_size",
		"type": TYPE_FLOAT,
		"hint": PROPERTY_HINT_NONE,
		"default_value": 0.4,
	})

	## Materials
	ProjectSettings.add_property_info({
		"name": "godot_vmf/materials/import_mode",
		"type": TYPE_INT,
		"hint": PROPERTY_HINT_ENUM,
		"hint_string": "Use Existing, Import from the GameInfo folder",
		"default_value": 0,
	})

	ProjectSettings.add_property_info({
		"name": "godot_vmf/materials/target_folder",
		"type": TYPE_STRING,
		"hint": PROPERTY_HINT_NONE,
		"default_value": "res://materials",
	})

	ProjectSettings.add_property_info({
		"name": "godot_vmf/materials/ignore",
		"type": TYPE_ARRAY,
		"hint": PROPERTY_HINT_ARRAY_TYPE,
		"hint_string": "%d:String" % TYPE_STRING,
		"default_value": ["tools/toolsnodraw", "tools/toolsskybox", "tools/toolsinvisible"],
	})

	ProjectSettings.add_property_info({
		"name": "godot_vmf/materials/fallback_material",
		"type": TYPE_STRING,
		"hint": PROPERTY_HINT_RESOURCE_TYPE,
		"hint_string": "Material",
		"default_value": "",
	})

	ProjectSettings.add_property_info({
		"name": "godot_vmf/materials/default_texture_size",
		"type": TYPE_INT,
		"hint": PROPERTY_HINT_NONE,
		"default_value": 512,
	})

	ProjectSettings.settings_changed.connect.call_deferred(update_config_field);

static func load_config():
	if not Engine.is_editor_hint(): return;
	if not FileAccess.file_exists(CONFIG_FILE_PATH): return;
	var file = FileAccess.open(CONFIG_FILE_PATH, FileAccess.READ);
	var json = JSON.parse_string(file.get_as_text());
	file.close();

	assign(VMFConfig, json);
