@tool
class_name FuncInstance extends ValveIONode;

static var cached = {};

func _apply_entity(e):
	super._apply_entity(e);
	
	cached = cached if cached != null else {};
	
	var instance_name = e.file.get_basename().split("/")[-1];
	FuncInstance.cached[instance_name] = FuncInstance.cached[instance_name] \
		if instance_name in FuncInstance.cached and FuncInstance.cached[instance_name] \
		else VMFInstanceManager.import_instance(e);

	assign_instance(instance_name);

func assign_instance(instance_name):
	var instance_scene = cached[instance_name];

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
