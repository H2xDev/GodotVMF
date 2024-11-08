@tool
extends ValveIONode

func _apply_entity(e):
	super._apply_entity(e);

	assert("models" in VMFConfig.config, "Missing 'models' in VMFConfig.config");

	var model_path = (VMFConfig.config.models.targetFolder + "/" + e.get('model')).replace("\\", "/").replace("//", "/").replace("res:/", "res://");
	if not ResourceLoader.exists(model_path):
		push_warning("[prop_static]: Model not found: {0}".format([model_path]));
		queue_free();
		return

	var packed_scene = ResourceLoader.load(model_path);
	var model: Node3D = packed_scene.instantiate();

	add_child(model);
	model.set_owner(get_owner());
	model.scale *= e.get('modelscale', 1.0);
	model.reparent(get_parent());
	queue_free();
