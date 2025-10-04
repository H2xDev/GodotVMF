@tool
class_name prop_static
extends prop_studio

var model_scale: float = 1.0:
	get: return entity.get('modelscale', 1.0)

var skin: int = 0:
	get: return entity.get('skin', 0)

var screen_space_fade: bool = false:
	get: return entity.get('screenspacefade', 0) == 1

var fade_min: float = 0.0:
	get: return entity.get('fademindist', 0.0) * VMFConfig.import.scale

var fade_max: float = 0.0:
	get: return entity.get('fademaxdist', 0.0) * VMFConfig.import.scale

func _entity_setup(e: VMFEntity):
	super._entity_setup(e);

	if not model_instance:
		VMFLogger.error("Corrupted prop_static: " + str(model));
		return;

	model_instance.set_owner(get_owner());
	model_instance.scale *= model_scale;
	MDLCombiner.apply_skin(model_instance, skin);

	var fade_margin = fade_max - fade_min;

	model_instance.visibility_range_end = max(0.0, fade_max);
	model_instance.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF \
		if screen_space_fade \
		else GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED;

	if model_instance.visibility_range_fade_mode != GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED:
		model_instance.visibility_range_end_margin = fade_margin;
	
	var geometry_node = get_vmfnode().geometry;

	if geometry_node: 
		var node = model_instance;
		node.name = model_name + str(node.get_instance_id());
		node.reparent(geometry_node)
		queue_free();
