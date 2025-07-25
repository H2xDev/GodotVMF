@tool
class_name prop_static
extends prop_studio


func _apply_entity(e):
	super._apply_entity(e);

	if not model_instance:
		VMFLogger.error("Corrupted prop_static: " + str(model));
		return;

	model_instance.set_owner(get_owner());
	model_instance.scale *= e.get('modelscale', 1.0);
	MDLCombiner.apply_skin(model_instance, e.get("skin", 0));

	var fade_min = entity.get('fademindist', 0.0) * VMFConfig.import.scale;
	var fade_max = entity.get('fademaxdist', 0.0) * VMFConfig.import.scale;
	var fade_margin = fade_max - fade_min;

	model_instance.visibility_range_end = max(0.0, fade_max);
	model_instance.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF \
			if e.get('screenspacefade', 0) == 1 \
			else GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED;

	if model_instance.visibility_range_fade_mode != GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED:
		model_instance.visibility_range_end_margin = fade_margin;
	
	var geometry_node = get_vmfnode().geometry;

	if geometry_node: 
		var node = model_instance;
		node.name = e.get('model', 'prop_static').get_file().get_basename() + str(node.get_instance_id());
		node.reparent(geometry_node)
		queue_free();
