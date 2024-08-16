@tool
class_name FuncInstance extends ValveIONode;

func _apply_entity(e):
	super._apply_entity(e);
	
	var instance_scene = VMFInstanceManager.import_instance(e);

	assign_instance(instance_scene);

func assign_instance(instance_scene):

	if not instance_scene: 
		VMFLogger.error("Failed to load instance: %s" % name);
		queue_free();
		return;

	var node = instance_scene.instantiate() as VMFNode;

	var i = 1
	for child: Node in get_parent().get_children():
		if child.name.begins_with(node.name):
			i += 1;
	node.name = "%s_%s" % [node.name, i]
	node.ignore_global_import = true;
	add_child(node);
	node.set_owner(get_owner());
