@tool
class_name func_instance extends VMFEntityNode

func _entity_setup(entity: VMFEntity):
	var instance_scene = VMFInstanceManager.import_instance(entity.data);
	assign_instance(instance_scene);

func assign_instance(instance_scene):

	if not instance_scene: 
		VMFLogger.error("Failed to load instance: %s" % name);
		queue_free();
		return;

	var node = instance_scene.instantiate(PackedScene.GEN_EDIT_STATE_MAIN_INHERITED) as VMFNode;

	var i = 1
	for child: Node in get_parent().get_children():
		if child.name.begins_with(node.name):
			i += 1;
	node.name = "%s_%s" % [node.name, i]
	add_child(node);
	node.set_owner(get_owner());
