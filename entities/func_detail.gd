@tool
class_name func_detail extends ValveIONode

func _apply_entity(entity_data: Dictionary) -> void:
	super._apply_entity(entity_data);
	
	var mesh = get_mesh();
	$mesh.cast_shadow = entity_data.get("disableshadows", 0) == 0;

	if !mesh or mesh.get_surface_count() == 0:
		queue_free();
		return;

	mesh.lightmap_unwrap(global_transform, config.import.lightmap_texel_size);
	$mesh.set_mesh(mesh);
	$mesh/body/collision.shape = mesh.create_trimesh_shape();
