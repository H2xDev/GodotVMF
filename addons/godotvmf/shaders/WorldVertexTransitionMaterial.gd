@tool
class_name WorldVertexTransitionMaterial extends ShaderMaterial

@export_category("Albedo")
@export var albedo_texture: Texture = null:
	set(value):
		set_shader_parameter("albedo_texture", value);
		albedo_texture = value;
		emit_changed();

@export var albedo_texture2: Texture = null:
	set(value):
		set_shader_parameter("albedo_texture2", value);
		albedo_texture2 = value;
		emit_changed();

@export_category("Normal")
@export var normal_texture: Texture = null:
	set(value):
		set_shader_parameter("normal_texture", value);
		normal_texture = value;
		emit_changed();

@export var normal_texture2: Texture = null:
	set(value):
		set_shader_parameter("normal_texture2", value);
		normal_texture2 = value;
		emit_changed();

@export_category("Displacement")
@export var displacement_texture: Texture = null:
	set(value):
		set_shader_parameter("displacement_texture", value);
		displacement_texture = value;
		emit_changed();

@export var displacement_texture2: Texture = null:
	set(value):
		set_shader_parameter("displacement_texture2", value);
		displacement_texture2 = value;
		emit_changed();

@export_category("Metallic")

@export_range(0, 1, 0.01) var metallic: float = 0.0:
	set(value):
		set_shader_parameter("metallic", value);
		metallic = value;
		emit_changed();

@export_range(0, 1, 0.01) var specular: float = 0.0:
	set(value):
		set_shader_parameter("specular", value);
		specular = value;
		emit_changed();

@export var metallic_texture: Texture = null:
	set(value):
		set_shader_parameter("metallic_texture", value);
		metallic_texture = value;	
		emit_changed();

@export var metallic_texture2: Texture = null:
	set(value):
		set_shader_parameter("metallic_texture2", value);
		metallic_texture2 = value;
		emit_changed();

@export_category("Roughness")
@export_range(0, 1, 0.01) var roughness: float = 0.0:
	set(value):
		set_shader_parameter("roughness", value);
		roughness = value;
		emit_changed();

@export var roughness_texture1: Texture = null:
	set(value):
		set_shader_parameter("roughness_texture", value);
		roughness_texture1 = value;
		emit_changed();

@export var roughness_texture2: Texture = null:
	set(value):
		set_shader_parameter("roughness_texture2", value);
		roughness_texture2 = value;
		emit_changed();

func _init():
	shader = load("res://addons/godotvmf/shaders/WorldVertexTransitionMaterial.gdshader");
