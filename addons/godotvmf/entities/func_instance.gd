@tool
class_name FuncInstance extends ValveIONode;

static var cached = {};

func _apply_entity(e):
	super._apply_entity(e);

	VMFInstanceManager.import_instance(e);

	assign_instance.call_deferred(e);

func assign_instance(e):
	var name = e.file.get_basename().split("/")[-1];

	if not cached.has(name):
		cached[name] = VMFInstanceManager.load_instance(name);

	var instance_scene = cached[name];

	if not instance_scene: 
		VMFLogger.error("Failed to load instance: %s" % name);
		queue_free();
		return;

	var node = instance_scene.instantiate();

	var i = 1
	for child: Node in get_parent().get_children():
		if child.name.begins_with(node.name):
			i += 1
	
	node.name = "%s_%s" % [node.name, i]

	get_parent().add_child(node);
	node.owner = get_owner();
	node.position = position;
	node.rotation = rotation;
	node.add_to_group(&"vmfnode_ignore-rebuild");

	get_parent().set_editable_instance(node, true);

	queue_free();
