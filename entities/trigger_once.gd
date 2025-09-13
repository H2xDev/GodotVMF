@tool
class_name trigger_once extends ValveIONode

@onready var area: Area3D = $area;

func on_body_entered(_body: Node) -> void:
	if ValveIONode.aliases.get("!player") == _body: 
		trigger_output("OnTrigger");
		queue_free();

func _entity_ready() -> void:
	area.body_entered.connect.call_deferred(on_body_entered);

func _apply_entity(e: Dictionary) -> void:
	super._apply_entity(e);
	
	($area/collision as CollisionShape3D).shape = get_entity_shape();
