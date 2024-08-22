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
@export var defaultLightEnergy = 0.0;
@onready var light = $OmniLight3D if has_node("OmniLight3D") else $SpotLight3D;

func _entity_ready():
	light.visible = not has_flag(FLAG_INITIALLY_DARK);

func _process(_delta):
	var newLightEnergy = defaultLightEnergy;

	match style:
		Appearance.NORMAL: pass;
		Appearance.FAST_STROBE:
			newLightEnergy = defaultLightEnergy - randf() * defaultLightEnergy * 0.2;
			pass;
		Appearance.SLOW_STROBE:
			newLightEnergy = defaultLightEnergy - Engine.get_frames_drawn() % 2 * defaultLightEnergy * 0.1;
			pass;
		Appearance.FLUORESCENT_FLICKER:
			newLightEnergy = 0.0 if randf() > 0.05 else defaultLightEnergy;
		_: pass;

	light.light_energy = newLightEnergy;

func TurnOff(_param):
	light.visible = false;

func TurnOn(_param):
	light.visible = true;

func _apply_entity(ent):
	super._apply_entity(ent);

	var color = ent._light;

	if color is Vector3:
		light.set_color(Color(color.x, color.y, color.z));
		light.light_energy = 1.0;
	elif "r" in color:
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
	defaultLightEnergy = light.light_energy;
	style = ent.style if "style" in ent else Appearance.NORMAL;
