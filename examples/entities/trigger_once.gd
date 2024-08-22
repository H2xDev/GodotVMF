@tool
extends ValveIONode

func _entity_ready():
	$Area3D.body_entered.connect(func(_node):
		trigger_output("OnTrigger"));

func _apply_entity(entityData):
	super._apply_entity(entityData);
	
	$Area3D/CollisionShape3D.shape = get_entity_shape();
