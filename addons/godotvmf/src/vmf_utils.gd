class_name VMFUtils extends RefCounted

static func normalize_path(path: String) -> String:
	return path.replace('\\', '/') \
			.replace('//', '/') \
			.replace('//', '/') \
			.replace('res:/', 'res://') \
			.replace('res:///', 'res://');

static func get_children_recursive(node: Node3D) -> Array:
	var children = [];
	for child in node.get_children():
		children.append(child);
		children.append_array(get_children_recursive(child));
	return children;

static func set_owner_recursive(node: Node, owner: Node):
	node.set_owner(owner);
	for child in node.get_children():
		set_owner_recursive(child, owner);

static func object_assign(target: Object, source: Dictionary) -> void:
	for key in source.keys():
		if key in target:
			target[key] = source[key];
