@tool
extends ValveIONode

static var cached_models = {};
static var last_cache_changed = 0;

func _apply_entity(e):
	super._apply_entity(e);
	cached_models = cached_models if cached_models else {};

	if last_cache_changed == null:
		last_cache_changed = 0;

	assert("models" in VMFConfig.config, "Missing 'models' in VMFConfig.config");

	var cache_key = e.get('model');
	var model_path = (VMFConfig.config.models.targetFolder + "/" + e.get('model')).replace("\\", "/").replace("//", "/").replace("res:/", "res://");

	if Time.get_ticks_msec() - last_cache_changed > 10000:
		cached_models = {};

	if cache_key not in cached_models:
		if not ResourceLoader.exists(model_path):
			push_warning("[prop_static]: Model not found: {0}".format([model_path]));
			queue_free();
			return

		cached_models[cache_key] = ResourceLoader.load(model_path);
		last_cache_changed = Time.get_ticks_msec();

	var model: Node3D = cached_models[cache_key].instantiate();

	add_child(model);
	model.set_owner(get_owner());
	model.scale *= e.get('modelscale', 1.0);
	model.reparent(get_vmfnode().geometry);
	queue_free();
