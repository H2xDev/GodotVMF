@tool
class_name light_environment extends ValveIONode

func _apply_entity(e: Dictionary) -> void:
	super._apply_entity(e);
	
	if get_parent().get_node_or_null("light_environment"):
		queue_free();
		return;
	
	var d: DirectionalLight3D = $DirectionalLight3D;
	var color: Color = e._light;

	d.light_color = Color(color.r, color.g, color.b);
	d.light_energy = color.a;
	global_rotation_degrees.x = e.get("pitch", 0);
	global_rotation.y -= PI / 2;
	
	name = "light_environment"
	
