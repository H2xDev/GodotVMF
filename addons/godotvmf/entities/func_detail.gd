@tool
class_name func_detail extends VMFEntityNode

func _entity_setup(entity: VMFEntity):
	var mesh = get_mesh();
	mesh.lightmap_unwrap(global_transform, config.import.lightmap_texel_size);

	$MeshInstance3D.cast_shadow = entity.data.get("disableshadows", 0) == 0;

	if !mesh or mesh.get_surface_count() == 0:
		queue_free();
		return;

	$MeshInstance3D.set_mesh(mesh);
	$MeshInstance3D/StaticBody3D/CollisionShape3D.shape = $MeshInstance3D.mesh.create_trimesh_shape();
