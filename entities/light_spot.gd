@tool
class_name v_light_spot extends v_light

func _apply_entity(e: Dictionary) -> void:
	super._apply_entity(e);
	var spot_light := light as SpotLight3D;

	spot_light.spot_angle = e._cone;
	spot_light.light_energy = e._light.a;
	default_light_energy = light.light_energy;
	e.angles.z = e.get("pitch", -90);
	e.angles.x = 0;

	basis = get_entity_basis(e);
	global_rotation.y -= PI / 2;
