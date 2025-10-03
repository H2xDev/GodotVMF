@tool
class_name v_light_spot extends v_light

func _entity_setup(entity: VMFEntity) -> void:
	super._entity_setup(entity);
	var entity_data := v_light.LightType.new(entity);
	var spot_light := light as SpotLight3D;

	spot_light.spot_angle = entity_data._cone;
	spot_light.light_energy = entity_data._light.a;
	default_light_energy = light.light_energy;
	entity.angles.z = entity_data.pitch;
	entity.angles.x = 0;

	basis = get_entity_basis(entity);
	global_rotation.y -= PI / 2;
