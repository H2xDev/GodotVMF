@tool
class_name FuncDetail extends ValveIONode

func _apply_entity(entityData, vmfNode):
	super._apply_entity(entityData, vmfNode);
	
	$MeshInstance3D.set_mesh(get_mesh());
	$MeshInstance3D/StaticBody3D/CollisionShape3D.shape = get_entity_shape();
