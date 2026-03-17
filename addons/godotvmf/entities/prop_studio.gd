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

## Returns the base path for native .res files for a given model
static func _get_native_res_base(model_key: String) -> String:
	var model_path = VMFUtils.normalize_path(VMFConfig.models.target_folder + "/" + model_key);
	# Strip the .mdl extension to get the base path
	return model_path.get_basename();

## Tries to load native .res files (mesh.res, collision_N.res, skin_meta.res) for a model.
## Returns a resources dictionary if found, or null if not available.
static func _load_native_resources(model_key: String) -> Variant:
	var base_path = _get_native_res_base(model_key);
	var mesh_path = base_path + ".mesh.res";

	if not ResourceLoader.exists(mesh_path):
		return null;

	var mesh = ResourceLoader.load(mesh_path) as ArrayMesh;
	if not mesh:
		return null;

	# Load collision shapes
	var collision_shapes: Array[Shape3D] = [];
	var col_idx = 0;
	while true:
		var col_path = base_path + ".collision_" + str(col_idx) + ".res";
		if not ResourceLoader.exists(col_path):
			break;
		var shape = ResourceLoader.load(col_path) as Shape3D;
		if shape:
			collision_shapes.append(shape);
		col_idx += 1;

	# Load skin metadata
	var skin_meta := {};
	var skin_meta_path = base_path + ".skin_meta.res";
	if ResourceLoader.exists(skin_meta_path):
		var skin_res = ResourceLoader.load(skin_meta_path);
		if skin_res and skin_res is Resource:
			for meta_key in skin_res.get_meta_list():
				if meta_key.begins_with("skin_"):
					skin_meta[meta_key] = skin_res.get_meta(meta_key);

	var resources = {
		"mesh": mesh,
		"collision_shapes": collision_shapes,
		"skin_meta": skin_meta,
	};

	VMFCache.add_model_resources(model_key, resources);
	return resources;

## Extracts shared resources (mesh, collision shapes, skin metadata) from a PackedScene
## and caches them in VMFCache for reuse by all instances of the same model.
static func _extract_and_cache_resources(model_key: String, model_scene: PackedScene) -> Dictionary:
	var temp = model_scene.instantiate()
	if not temp or not (temp is MeshInstance3D):
		if temp: temp.free()
		return {}

	var mesh: ArrayMesh = temp.mesh

	# Extract skin metadata
	var skin_meta := {}
	for meta_key in temp.get_meta_list():
		if meta_key.begins_with("skin_"):
			skin_meta[meta_key] = temp.get_meta(meta_key)

	# Extract collision shapes (walk tree recursively)
	# Duplicate shapes to ensure they survive temp.free()
	var collision_shapes: Array[Shape3D] = []
	var stack = [temp]
	while stack.size() > 0:
		var node = stack.pop_back()
		if node is CollisionShape3D and node.shape:
			collision_shapes.append(node.shape.duplicate())
		for child in node.get_children():
			stack.append(child)

	temp.free()

	var resources = {
		"mesh": mesh,
		"collision_shapes": collision_shapes,
		"skin_meta": skin_meta,
	}

	VMFCache.add_model_resources(model_key, resources)

	return resources

func _entity_setup(_entity: VMFEntity) -> void:
	var model_path = VMFUtils.normalize_path(VMFConfig.models.target_folder + "/" + model);

	# 1. Check in-memory model resource cache
	var resources = VMFCache.get_model_resources(model);

	if not resources:
		# 2. Try loading native .res files (faster than PackedScene extraction)
		resources = _load_native_resources(model);

	if not resources:
		# 3. Fall back to PackedScene extraction
		var model_scene: PackedScene = VMFCache.get_cached(model);
		if not model_scene:
			if not ResourceLoader.exists(model_path):
				if VMFCache.is_file_logged(model): return
				VMFLogger.warn("Model not found: " + model_path);
				VMFCache.add_logged_file(model);
				return;
			model_scene = ResourceLoader.load(model_path) as PackedScene;
			VMFCache.add_cached(model, model_scene);
			if not model_scene:
				VMFLogger.error("Failed to load model scene: " + model_path);
				return;

		# Extract, cache, and save as native .res
		resources = _extract_and_cache_resources(model, model_scene);
		if not resources or resources.is_empty():
			return;

	# 4. Create lightweight MeshInstance3D with SHARED mesh
	var instance := MeshInstance3D.new();
	instance.name = "model";
	instance.mesh = resources.mesh;
	instance.scale *= model_scale;

	# 5. Apply skin via surface overrides (instance-level, doesn't modify shared mesh)
	var skin_key = "skin_" + str(skin);
	if skin_key in resources.skin_meta:
		var materials = resources.skin_meta[skin_key];
		for surface_idx in range(instance.mesh.get_surface_count()):
			if surface_idx < materials.size():
				instance.set_surface_override_material(surface_idx, materials[surface_idx]);

	# 6. Store collision data for runtime PhysicsServer3D creation (no nodes in editor)
	if not resources.collision_shapes.is_empty():
		var vmfnode = get_vmfnode();
		if vmfnode:
			var collision_data: Array = vmfnode.get_meta("prop_collision_data", []);
			for shape in resources.collision_shapes:
				collision_data.append({ "shape": shape, "transform": global_transform });
			vmfnode.set_meta("prop_collision_data", collision_data);

	add_child(instance);
	instance.set_owner(get_owner());
