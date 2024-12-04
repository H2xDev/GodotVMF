class_name VMFUtils extends RefCounted

static func normalize_path(path: String) -> String:
	return path.replace('\\', '/') \
			.replace('//', '/') \
			.replace('res:/', 'res://');
