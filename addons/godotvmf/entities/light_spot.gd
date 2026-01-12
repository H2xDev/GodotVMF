@tool
class_name v_light_spot extends v_light

func _entity_setup(entity: VMFEntity) -> void:
	super._entity_setup(entity);
	var entity_data := v_light.LightType.new(entity);
	var spot_light := light as SpotLight3D;
	var radius := (1 / config.import.scale) * sqrt(light.light_energy * config.import.scale);
	var attenuation := 1.44;

	spot_light.spot_angle = entity_data._cone;
	spot_light.light_energy = entity_data._light.a;

	spot_light.spot_range = radius;
	spot_light.spot_angle_attenuation = attenuation;
	spot_light.spot_range = entity.data.get("distance", spot_light.spot_range / config.import.scale) * config.import.scale;

	default_light_energy = light.light_energy;
	entity.angles.z = entity_data.pitch;
	entity.angles.x = 0;

	basis = get_entity_basis(entity);
	global_rotation.y -= PI / 2;
