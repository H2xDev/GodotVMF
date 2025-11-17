@static_unload
class_name VMFCache extends RefCounted

static var cache: Dictionary = {}
static var logs: Array[String] = []

static func get_cached(path: String) -> Variant:
	if cache.has(path):
		return cache[path]
	return null;

static func add_cached(path: String, resource: Variant) -> void:
	cache[path] = resource;

static func is_file_logged(path: String) -> bool:
	return logs.has(path);

static func add_logged_file(path: String) -> void:
	if not logs.has(path):
		logs.append(path)

static func clear() -> void:
	cache.clear()
	logs.clear()

