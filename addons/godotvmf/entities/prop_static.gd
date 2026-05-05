@tool
class_name prop_static
extends prop_studio

var screen_space_fade: bool = false:
	get: return entity.get('screenspacefade', 0) == 1

var fade_min: float = 0.0:
	get: return entity.get('fademindist', 0.0) * VMFConfig.import.scale

var fade_max: float = 0.0:
	get: return entity.get('fademaxdist', 0.0) * VMFConfig.import.scale

func _get_static_props_node() -> Node3D:
	var geometry_node := get_vmfnode().geometry as MeshInstance3D;
	if not geometry_node:
		geometry_node = MeshInstance3D.new();
		geometry_node.name = "Geometry";
		get_vmfnode().add_child(geometry_node);
		geometry_node.set_owner(get_vmfnode().owner);
	
	var static_props_node := geometry_node.get_node_or_null("StaticProps");

	if not static_props_node:
		static_props_node = Node3D.new();
		static_props_node.name = "StaticProps";
		geometry_node.add_child(static_props_node);
		static_props_node.set_owner(geometry_node.owner);
	
	return static_props_node;

func assign_model_properties() -> void:
	model_instance.set_owner(get_owner());
	model_instance.scale *= model_scale;
	model_instance.gi_mode = GeometryInstance3D.GI_MODE_STATIC;

	var fade_margin = fade_max - fade_min;

	model_instance.visibility_range_end = max(0.0, fade_max);
	model_instance.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF \
		if screen_space_fade \
		else GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED;

	if model_instance.visibility_range_fade_mode != GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED:
		model_instance.visibility_range_end_margin = fade_margin;

func check_solid_state() -> void:
	var is_solid: bool = entity.get("solid", 6) != 0; # NOTE: Use VPhysics is 6 - default
	if is_solid: return;

	owner.set_editable_instance(model_instance, true);

	for child in model_instance.get_children():
		if child is not StaticBody3D: continue;
		child.free();

func reparent_to_static_props() -> void:
	var static_props_node := _get_static_props_node();
	var node := model_instance;
	node.name = model_name + str(node.get_instance_id());
	node.reparent(static_props_node);

func _entity_setup(e: VMFEntity):
	super(e);

	if not model_instance: return;
	
	assign_model_properties();
	check_solid_state();
	reparent_to_static_props();
	queue_free();
