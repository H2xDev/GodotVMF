@tool
class_name VLight extends ValveIONode

enum Appearance {
	NORMAL,
	FAST_STROBE = 4,
	SLOW_STROBE = 9,
	FLUORESCENT_FLICKER = 10,
};

const FLAG_INITIALLY_DARK = 1;

@export var style: Appearance = Appearance.NORMAL;
@export var default_light_energy = 0.0;
@onready var light = $OmniLight3D if has_node("OmniLight3D") else $SpotLight3D;

func _entity_ready():
	light.visible = not has_flag(FLAG_INITIALLY_DARK);

func _process(_delta: float):
	var new_light_energy = default_light_energy;

	match style:
		Appearance.NORMAL: pass;
		Appearance.FAST_STROBE:
			new_light_energy = default_light_energy - randf() * default_light_energy * 0.2;
			pass;
		Appearance.SLOW_STROBE:
			new_light_energy = default_light_energy - Engine.get_frames_drawn() % 2 * default_light_energy * 0.1;
			pass;
		Appearance.FLUORESCENT_FLICKER:
			new_light_energy = 0.0 if randf() > 0.05 else default_light_energy;
		_: pass;

	light.light_energy = new_light_energy;

func TurnOff(_param):
	light.visible = false;

func TurnOn(_param):
	light.visible = true;

func _apply_entity(ent):
	super._apply_entity(ent);

	var color = ent._light;

	if ent.get("targetname", null) or ent.get("parentname", null):
		light.light_bake_mode = Light3D.BAKE_DYNAMIC;
	else:
		light.light_bake_mode = Light3D.BAKE_STATIC;

	if color is Vector3:
		light.set_color(Color(color.x, color.y, color.z));
		light.light_energy = 1.0;
	elif color is Color:
		light.set_color(Color(color.r, color.g, color.b));
		light.light_energy = color.a;
	else:
		VMFLogger.error('Invalid light: ' + str(ent.id));
		get_parent().remove_child(self);
		queue_free();
		return;

	if light is OmniLight3D:
		# TODO: implement constant linear quadratic calculation

		var radius = (1 / config.import.scale) * sqrt(light.light_energy);
		var attenuation = 1.44;

		var fiftyPercentDistance = ent.get("_fifty_percent_distance", 0.0);
		var zeroPercentDistance = ent.get("_zero_percent_distance", 0.0);

		if fiftyPercentDistance > 0.0 or zeroPercentDistance > 0.0:
			var dist50 = min(fiftyPercentDistance, zeroPercentDistance) * config.import.scale;
			var dist0 = max(fiftyPercentDistance, zeroPercentDistance) * config.import.scale;

			attenuation = 1 / ((dist0 - dist50) / dist0);

			radius = exp(dist0);

		light.omni_range = radius
		light.omni_attenuation = attenuation;

	light.shadow_enabled = true;
	default_light_energy = light.light_energy;
	style = ent.style if "style" in ent else Appearance.NORMAL;
