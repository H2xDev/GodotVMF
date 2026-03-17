@static_unload
class_name VMFCache extends RefCounted

static var cache: Dictionary = {}
static var logs: Array[String] = []
## Shared model resources keyed by model path
## Structure: model_path -> { "mesh": ArrayMesh, "collision_shapes": Array[Shape3D], "skin_meta": Dictionary }
static var model_resources: Dictionary = {}

static func get_cached(path: String) -> Variant:
	if cache.has(path):
		return cache[path]
	return null;

static func add_cached(path: String, resource: Variant) -> void:
	cache[path] = resource;

static func get_model_resources(path: String) -> Variant:
	if model_resources.has(path):
		return model_resources[path]
	return null;

static func add_model_resources(path: String, resources: Dictionary) -> void:
	model_resources[path] = resources;

static func is_file_logged(path: String) -> bool:
	return logs.has(path);

static func add_logged_file(path: String) -> void:
	if not logs.has(path):
		logs.append(path)

static func clear() -> void:
	cache.clear()
	logs.clear()
	model_resources.clear()

