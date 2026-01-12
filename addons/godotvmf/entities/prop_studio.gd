@tool
class_name prop_studio extends VMFEntityNode

## @exposed
## @type studio
var model: String = "":
	get: return entity.get("model", "");

var model_instance: MeshInstance3D:
	get: return get_node_or_null("model") as MeshInstance3D;

var model_name: String = "":
	get: return entity.get('model', 'prop_static').get_file().get_basename();

var model_scale: float = 1.0:
	get: return entity.get("modelscale", 1.0);

var skin: int = 0:
	get: return entity.get('skin', 0)

func _entity_setup(_entity: VMFEntity) -> void:
	var model_path = VMFUtils.normalize_path(VMFConfig.models.target_folder + "/" + model);
	var model_scene: PackedScene = VMFCache.get_cached(model);

	if not model_scene:
		if not ResourceLoader.exists(model_path):
			if VMFCache.is_file_logged(model): return

			VMFLogger.warn("Model not found: " + model_path);
			VMFCache.add_logged_file(model);

		model_scene = ResourceLoader.load(model_path) as PackedScene;
		VMFCache.add_cached(model, model_scene);

		if not model_scene:
			VMFLogger.error("Failed to load model scene: " + model_path);
			return;

	var instance := model_scene.instantiate(PackedScene.GEN_EDIT_STATE_MAIN_INHERITED);
	instance.name = "model";
	instance.scale *= model_scale;

	MDLCombiner.apply_skin(instance, skin);

	add_child(instance);
	model_instance.set_owner(get_owner());
