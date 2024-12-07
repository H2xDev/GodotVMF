@tool
class_name FuncDetail extends ValveIONode

func _apply_entity(entityData):
	super._apply_entity(entityData);
	
	$MeshInstance3D.cast_shadow = entityData.get("disableshadows", 0) == 0;
	$MeshInstance3D.set_mesh(get_mesh());
	$MeshInstance3D/StaticBody3D/CollisionShape3D.shape = $MeshInstance3D.mesh.create_trimesh_shape();
