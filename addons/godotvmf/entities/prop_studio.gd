@tool
class_name prop_studio extends ValveIONode

## @exposed
## @type studio
var model: String = "":
	get: return entity.get("model", "");

var model_instance: MeshInstance3D:
	get: return get_node_or_null("model") as MeshInstance3D;

func _apply_entity(e: Dictionary) -> void:
	super._apply_entity(e);

	var model_path = (VMFConfig.models.target_folder + "/" + e.get('model')) \
		.replace("\\", "/") \
		.replace("//", "/") \
		.replace("res:/", "res://");

	var model_scene := ResourceLoader.load(model_path) as PackedScene;
	if not model_scene:
		VMFLogger.error("Failed to load model scene: " + model_path);
		return;

	var instance := model_scene.instantiate();
	instance.name = "model";

	add_child(instance);
	model_instance.set_owner(get_owner());
