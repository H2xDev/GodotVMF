@tool
class_name trigger_once
extends ValveIONode

func _entity_ready():
	$area.body_entered.connect.call_deferred(func(_node):
		if ValveIONode.aliases.get("!player") == _node: 
			trigger_output("OnTrigger");
			queue_free();
	);

func _apply_entity(e):
	super._apply_entity(e);
	
	$area/collision.shape = get_entity_shape();
