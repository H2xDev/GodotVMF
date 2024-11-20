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

	var model: MeshInstance3D = cached_models[cache_key].instantiate();

	add_child(model);
	model.set_owner(get_owner());
	model.scale *= e.get('modelscale', 1.0);
	model.reparent(get_vmfnode().geometry);
	model.name = e.get('model', 'prop_static').get_file().get_basename() + str(model.get_instance_id());

	var fade_min = entity.get('fademindist', 0.0) * VMFConfig.config.import.scale;
	var fade_max = entity.get('fademaxdist', 0.0) * VMFConfig.config.import.scale;
	var fade_margin = fade_max - fade_min;

	model.visibility_range_end = max(0.0, fade_max);
	model.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF \
			if e.get('screenspacefade', 0) == 1 \
			else GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED;

	if model.visibility_range_fade_mode != GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED:
		model.visibility_range_end_margin = fade_margin;

	queue_free();
