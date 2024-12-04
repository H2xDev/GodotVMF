class_name VMFUtils extends RefCounted

static func normalize_path(path: String) -> String:
	return path.replace('\\', '/') \
			.replace('//', '/') \
			.replace('//', '/') \
			.replace('res:/', 'res://');

static func get_children_recursive(node: Node3D) -> Array:
	var children = [];
	for child in node.get_children():
		children.append(child);
		children.append_array(get_children_recursive(child));
	return children;
