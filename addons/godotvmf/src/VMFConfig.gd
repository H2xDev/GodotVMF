@static_unload
class_name VMFConfig extends RefCounted

const CONFIG_FILE_PATH = "res://vmf.config.json";

class ModelsConfig:
	## If true, the importer will import models from the mod folder
	var import: bool = false:
		get:
			return ProjectSettings.get_setting("godot_vmf/models/import", false);
		set(value):
			ProjectSettings.set_setting("godot_vmf/models/import", value);

	## Texel size for the imported models
	var lightmap_texel_size: float = 0.4:
		get:
			return ProjectSettings.get_setting("godot_vmf/models/lightmap_texel_size", 0.4);
		set(value):
			ProjectSettings.set_setting("godot_vmf/models/lightmap_texel_size", value);

	## Folder where importer will copy models from the mod folder
	## Also this is where the prop_static will grab models from
	var target_folder: String = "res://":
		get:
			return ProjectSettings.get_setting("godot_vmf/models/target_folder", "res://");
		set(value):
			ProjectSettings.set_setting("godot_vmf/models/target_folder", value);

class MaterialsConfig:
	enum ImportMode {
		USE_EXISTING = 0,
		IMPORT_FROM_MOD_FOLDER = 1,
	};

	var import_mode: ImportMode = 0:
		get:
			return ProjectSettings.get_setting("godot_vmf/materials/import_mode", ImportMode.USE_EXISTING);
		set(value):
			ProjectSettings.set_setting("godot_vmf/materials/import_mode", value);

	## Folder where importer or target materials be stored
	var target_folder: String = "res://materials":
		get:
			return ProjectSettings.get_setting("godot_vmf/materials/target_folder", "res://materials");
		set(value):
			ProjectSettings.set_setting("godot_vmf/materials/target_folder", value);

	## Materials in this list will be ignored during import
	var ignore: Array = []:
		get:
			return ProjectSettings.get_setting("godot_vmf/materials/ignore", []);
		set(value):
			ProjectSettings.set_setting("godot_vmf/materials/ignore", value);

	## A material that will be used as a fallback for missing materials
	var fallback_material = "":
		get:
			return ProjectSettings.get_setting("godot_vmf/materials/fallback_material", "");
		set(value):
			ProjectSettings.set_setting("godot_vmf/materials/fallback_material", value);

	## Fallback texture size for missing textures
	var default_texture_size: int = 512:
		get:
			return ProjectSettings.get_setting("godot_vmf/materials/default_texture_size", 512);
		set(value):
			ProjectSettings.set_setting("godot_vmf/materials/default_texture_size", value);

class ImportConfig:
	## Target scale that will be applied to all imported models and maps
	var scale: float = 0.02:
		get:
			return ProjectSettings.get_setting("godot_vmf/scale", 0.02);
		set(value):
			ProjectSettings.set_setting("godot_vmf/scale", value);

	## If true, the importer will generate collision meshes for the level geometry
	var generate_collision: bool = true:
		get:
			return ProjectSettings.get_setting("godot_vmf/generate_collision", true);
		set(value):
			ProjectSettings.set_setting("godot_vmf/generate_collision", value);

	## If true, the importer will generate lightmap UV2 for the level geometry
	var generate_lightmap_uv2: bool = true:
		get:
			return ProjectSettings.get_setting("godot_vmf/generate_lightmap_uv2", true);
		set(value):
			ProjectSettings.set_setting("godot_vmf/generate_lightmap_uv2", value);

	## Texel size for lightmap 
	var lightmap_texel_size: float = 0.4:
		get:
			return ProjectSettings.get_setting("godot_vmf/lightmap_texel_size", 0.2);
		set(value):
			ProjectSettings.set_setting("godot_vmf/lightmap_texel_size", value);

	## Lightmap texture size
	var lightmap_size: int = 1024:
		get:
			return ProjectSettings.get_setting("godot_vmf/lightmap_size", 1024);
		set(value):
			ProjectSettings.set_setting("godot_vmf/lightmap_size", value);

	## The path where imported instances be saved
	var instances_folder: String = "res://instances":
		get:
			return ProjectSettings.get_setting("godot_vmf/instances_folder", "res://instances");
		set(value):
			ProjectSettings.set_setting("godot_vmf/instances_folder", value);

	## The path from importer will grab entities
	var entities_folder: String = "res://entities":
		get:
			return ProjectSettings.get_setting("godot_vmf/entities_folder", "res://entities");
		set(value):
			ProjectSettings.set_setting("godot_vmf/entities_folder", value);

	## The path where imported geometry and collision be saved
	var geometry_folder: String = "res://geometry":
		get:
			return ProjectSettings.get_setting("godot_vmf/geometry_folder", "res://geometry");
		set(value):
			ProjectSettings.set_setting("godot_vmf/geometry_folder", value);

	## The path where imported materials be saved
	var steam_materials_folder: String = "res://steam_audio_materials":
		get:
			return ProjectSettings.get_setting("godot_vmf/steam_materials_folder", "res://steam_audio_materials");
		set(value):
			ProjectSettings.set_setting("godot_vmf/steam_materials_folder", value);

	## A dictionary of entity aliases where key is an entity name and value is a path to the scene
	var entity_aliases: Dictionary = {}:
		get:
			return ProjectSettings.get_setting("godot_vmf/entity_aliases", {});
		set(value):
			ProjectSettings.set_setting("godot_vmf/entity_aliases", value);

	## If true, the importer will generate a navigation mesh for the level geometry
	var use_navigation_mesh: bool = false:
		get:
			return ProjectSettings.get_setting("godot_vmf/generate_navigation_mesh", false);
		set(value):
			ProjectSettings.set_setting("godot_vmf/generate_navigation_mesh", value);

	## If specified, the importer will use this preset for the navigation mesh
	var navigation_mesh_preset: NavigationMesh = null:
		get:
			return ProjectSettings.get_setting("godot_vmf/navigation_mesh_preset", null);
		set(value):
			ProjectSettings.set_setting("godot_vmf/navigation_mesh_preset", value);

static var gameinfo_path: String = "res://":
	get:
		return ProjectSettings.get_setting("godot_vmf/gameinfo_path", "res://");
	set(value):
		ProjectSettings.set_setting("godot_vmf/gameinfo_path", value);

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

static var vtfcmd: String = "":
	get:
		if not vtfcmd:
			vtfcmd = "";
		return vtfcmd;

static func assign(target, source: Dictionary):
	if not target: return;
	for key in source.keys():
		if not key in target and target is not Dictionary: continue;

		if source[key] is Dictionary and source[key] is not Array:
			target[key]	= assign(target[key], source[key]);
		else:
			target[key] = source[key];

	return target;

static func define_project_settings():
	ProjectSettings.set_setting("godot_vmf/gameinfo_path", "res://");
	ProjectSettings.set_initial_value("godot_vmf/gameinfo_path", "res://");
	ProjectSettings.set_setting("godot_vmf/scale", 0.02);
	ProjectSettings.set_initial_value("godot_vmf/scale", 0.02);
	ProjectSettings.set_setting("godot_vmf/generate_lightmap_uv2", true);
	ProjectSettings.set_initial_value("godot_vmf/generate_lightmap_uv2", true);
	ProjectSettings.set_setting("godot_vmf/generate_collision", true);
	ProjectSettings.set_initial_value("godot_vmf/generate_collision", true);
	ProjectSettings.set_setting("godot_vmf/generate_navigation_mesh", false);
	ProjectSettings.set_initial_value("godot_vmf/generate_navigation_mesh", false);
	ProjectSettings.set_setting("godot_vmf/navigation_mesh_preset", "");
	ProjectSettings.set_initial_value("godot_vmf/navigation_mesh_preset", "");
	ProjectSettings.set_setting("godot_vmf/lightmap_texel_size", 0.2);
	ProjectSettings.set_initial_value("godot_vmf/lightmap_texel_size", 0.2);
	ProjectSettings.set_setting("godot_vmf/instances_folder", "res://instances");
	ProjectSettings.set_initial_value("godot_vmf/instances_folder", "res://instances");
	ProjectSettings.set_setting("godot_vmf/entities_folder", "res://entities");
	ProjectSettings.set_initial_value("godot_vmf/entities_folder", "res://entities");
	ProjectSettings.set_setting("godot_vmf/geometry_folder", "res://geometry");
	ProjectSettings.set_initial_value("godot_vmf/geometry_folder", "res://geometry");
	ProjectSettings.set_setting("godot_vmf/entity_aliases", {});
	ProjectSettings.set_initial_value("godot_vmf/entity_aliases", {});

	## Models
	ProjectSettings.set_setting("godot_vmf/models/import", false);
	ProjectSettings.set_initial_value("godot_vmf/models/import", false);
	ProjectSettings.set_setting("godot_vmf/models/target_folder", "res://");
	ProjectSettings.set_initial_value("godot_vmf/models/target_folder", "res://");
	ProjectSettings.set_setting("godot_vmf/models/lightmap_texel_size", 0.4);
	ProjectSettings.set_initial_value("godot_vmf/models/lightmap_texel_size", 0.4);

	## Materials
	ProjectSettings.set_setting("godot_vmf/materials/import_mode", 0);
	ProjectSettings.set_initial_value("godot_vmf/materials/import_mode", 0);
	ProjectSettings.set_setting("godot_vmf/materials/target_folder", "res://materials");
	ProjectSettings.set_initial_value("godot_vmf/materials/target_folder", "res://materials");
	ProjectSettings.set_setting("godot_vmf/materials/ignore", ["tools/toolsnodraw", "tools/toolsskybox", "tools/toolsinvisible"]);
	ProjectSettings.set_initial_value("godot_vmf/materials/ignore", ["tools/toolsnodraw", "tools/toolsskybox", "tools/toolsinvisible"]);
	ProjectSettings.set_setting("godot_vmf/materials/fallback_material", "");
	ProjectSettings.set_initial_value("godot_vmf/materials/fallback_material", "");
	ProjectSettings.set_setting("godot_vmf/materials/default_texture_size", 512);
	ProjectSettings.set_initial_value("godot_vmf/materials/default_texture_size", 512);
	
	ProjectSettings.add_property_info({
		"name": "godot_vmf/gameinfo_path",
		"type": TYPE_STRING,
		"hint": PROPERTY_HINT_GLOBAL_FILE ,
		"hint_string": "gameinfo.txt,GameInfo.txt",
		"default_value": 'res://',
	})

	ProjectSettings.add_property_info({
		"name": "godot_vmf/scale",
		"type": TYPE_FLOAT,
		"hint": PROPERTY_HINT_NONE,
		"default_value": 0.02,
	})

	ProjectSettings.add_property_info({
		"name": "godot_vmf/generate_lightmap_uv2",
		"type": TYPE_BOOL,
		"hint": PROPERTY_HINT_NONE,
		"default_value": true,
	})

	ProjectSettings.add_property_info({
		"name": "godot_vmf/generate_navigation_mesh",
		"type": TYPE_BOOL,
		"hint": PROPERTY_HINT_NONE,
		"default_value": false,
	})

	ProjectSettings.add_property_info({
		"name": "godot_vmf/generate_collision",
		"type": TYPE_BOOL,
		"hint": PROPERTY_HINT_NONE,
		"default_value": false,
	})

	ProjectSettings.add_property_info({
		"name": "godot_vmf/navigation_mesh_preset",
		"type": TYPE_OBJECT,
		"hint": PROPERTY_HINT_RESOURCE_TYPE,
		"hint_string": "NavigationMesh",
		"default_value": "",
	})

	ProjectSettings.add_property_info({
		"name": "godot_vmf/lightmap_texel_size",
		"type": TYPE_FLOAT,
		"hint": PROPERTY_HINT_NONE,
		"default_value": 0.2,
	})

	ProjectSettings.add_property_info({
		"name": "godot_vmf/instances_folder",
		"type": TYPE_STRING,
		"hint": PROPERTY_HINT_DIR,
		"default_value": "res://instances",
	})

	ProjectSettings.add_property_info({
		"name": "godot_vmf/entities_folder",
		"type": TYPE_STRING,
		"hint": PROPERTY_HINT_DIR,
		"default_value": "res://entities",
	})

	ProjectSettings.add_property_info({
		"name": "godot_vmf/geometry_folder",
		"type": TYPE_STRING,
		"hint": PROPERTY_HINT_DIR,
		"default_value": "res://geometry",
	})

	ProjectSettings.add_property_info({
		"name": "godot_vmf/entity_aliases",
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

static func load_config():
	if not Engine.is_editor_hint(): return;
	if not FileAccess.file_exists(CONFIG_FILE_PATH): return;
	var file = FileAccess.open(CONFIG_FILE_PATH, FileAccess.READ);
	var json = JSON.parse_string(file.get_as_text());
	file.close();

	assign(VMFConfig, json);
