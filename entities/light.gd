@tool
class_name v_light extends ValveIONode

enum Appearance {
	NORMAL,
	FLICKER_A,
	SLOW_STRONG_PULSE,
	CANDLE_A,
	FAST_STROBE,
	GENTLE_PULSE,
	FLICKER_B,
	CANDLE_B,
	CANDLE_C,
	SLOW_STROBE,
	FLUORESCENT_FLICKER,
	SLOW_PULSE,
};

const FLAG_INITIALLY_DARK = 1;
const PATTERNS = {
	Appearance.NORMAL: "m",
	Appearance.FLICKER_A: "mmnmmommommnonmmonqnmmo",
	Appearance.SLOW_STRONG_PULSE: "abcdefghijklmnopqrstuvwxyzyxwvutsrqponmlkjihgfedcba",
	Appearance.CANDLE_A: "mmmmmaaaaammmmmaaaaaabcdefgabcdefg",
	Appearance.FAST_STROBE: "mamamamama",
	Appearance.GENTLE_PULSE: "jklmnopqrstuvwxyzyxwvutsrqponmlkj",
	Appearance.FLICKER_B: "nmonqnmomnmomomno",
	Appearance.CANDLE_B: "mmmaaaabcdefgmmmmaaaammmaamm",
	Appearance.CANDLE_C: "mmmaaammmaaabcdefgmmmaaaammmmmaaaa",
	Appearance.SLOW_STROBE: "aaaaaaaazzzzzzzz",
	Appearance.FLUORESCENT_FLICKER: "mmamammmmammamamaaamammma",
	Appearance.SLOW_PULSE: "abcdefghijklmnoonmlkjihgfedcba",
}

const MAX_PATTERN_VALUE = float(ord('m') - ord('a'));
const CHAR_A = ord('a');

@export var style: Appearance = Appearance.NORMAL;
@export var default_light_energy: float = 0.0;

@onready var light: Light3D = $OmniLight3D if has_node("OmniLight3D") else $SpotLight3D;

var time_passed: float = 0.0;

func _entity_ready() -> void:
	light.visible = not has_flag(FLAG_INITIALLY_DARK);


func ease_in_out_circ(x: float) -> float:
	if x < 0.5:
		return (1 - sqrt(1 - pow(2 * x, 2))) / 2;
	else:
		return (sqrt(1 - pow(-2 * x + 2, 2)) + 1) / 2;

func animate_light(delta: float) -> void:
	time_passed += delta;

	var pattern: String = PATTERNS.get(style, "m");

	if pattern == "m":
		light.light_energy = default_light_energy;
		return;

	var pattern_length: int = pattern.length();
	var current_index: int = int((time_passed * 10)) % pattern_length;
	var previous_index: int = (current_index - 1 + pattern_length) % pattern_length;

	var current_char: String = pattern[current_index];
	var interpolation: float = (time_passed * 10) - floor(time_passed * 10);
	var current_brightness: float = (ord(current_char) - CHAR_A) / MAX_PATTERN_VALUE;
	var previous_brightness: float = (ord(pattern[previous_index]) - CHAR_A) / MAX_PATTERN_VALUE;

	var brightness = lerp(previous_brightness, current_brightness, ease_in_out_circ(interpolation));

	light.light_energy = default_light_energy * brightness;

func _process(_delta: float) -> void:
	animate_light(_delta);

func _apply_entity(ent: Dictionary) -> void:
	super._apply_entity(ent);

	var color: Color = ent._light;
	var color_vec3: Vector3 = ent._light if ent._light is Vector3 else Vector3.ZERO;

	if ent.get("targetname", null) or ent.get("parentname", null):
		light.light_bake_mode = Light3D.BAKE_DYNAMIC;
	else:
		light.light_bake_mode = Light3D.BAKE_STATIC;

	if ent._light is Vector3:
		light.set_color(Color(color_vec3.x, color_vec3.y, color_vec3.z));
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
		var omni_light: OmniLight3D = light; # To avoid further warnings

		# TODO: implement constant linear quadratic calculation the right way
		var radius := (1 / config.import.scale) * sqrt(light.light_energy);
		var attenuation := 1.44;

		var fifty_percent_distance: float = ent.get("_fifty_percent_distance", 0.0);
		var zero_percent_distance: float = ent.get("_zero_percent_distance", 0.0);

		if fifty_percent_distance > 0.0 or zero_percent_distance> 0.0:
			var dist50: float = min(fifty_percent_distance , zero_percent_distance) * config.import.scale;
			var dist0: float = max(fifty_percent_distance , zero_percent_distance) * config.import.scale;

			attenuation = 1 / ((dist0 - dist50) / dist0);

			radius = exp(dist0);

		omni_light.omni_range = radius
		omni_light.omni_attenuation = attenuation;

	light.shadow_enabled = true;
	default_light_energy = light.light_energy;
	style = ent.style if "style" in ent else Appearance.NORMAL;

func TurnOff(_param: Variant) -> void:
	light.visible = false;

func TurnOn(_param: Variant) -> void:
	light.visible = true;
