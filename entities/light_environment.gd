@tool
class_name LightEnv extends ValveIONode

func _apply_entity(e):
	super._apply_entity(e);
	
	if get_parent().get_node_or_null("light_environment"):
		queue_free();
		return;
	
	var d = $DirectionalLight3D;
	d.light_color = Color(e._light.r, e._light.g, e._light.b);
	d.light_energy = e._light.a;
	global_rotation_degrees.x = e.get("pitch", 0);
	global_rotation.y -= PI / 2;
	
	name = "light_environment"
	
