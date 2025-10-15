class_name VMFConnection extends RefCounted

var target: String = "";
var input: String = "";
var parameter: Variant = "";
var delay: float = 0.0;
var times_to_fire: int = 1;
var output: String = "";

func _init(output: String, raw: String) -> void:
	var arr = raw.split(",");
	self.output = output;
	target = arr[0];
	input = arr[1] if arr.size() > 1 else "";
	parameter = arr[2] if arr.size() > 2 else "";
	delay = float(arr[3]) if arr.size() > 3 else 0.0;
	times_to_fire = int(arr[4]) if arr.size() > 4 else 1;

func assign_signal(target_node: Node) -> void:
	if not target_node.has_signal(input):
		target_node.add_user_signal(input);
	
	target_node.connect(output, func(): call_target_input(target, input, parameter, delay, target));

func call_target_input(target: String, input: String, param: Variant, delay: float, node= null) -> void:
	if "enabled" in node and not node.enabled:
		return;

	var targets = VMFEntityNode.get_all_targets(target) \
		if not target.begins_with("!") \
		else [VMFEntityNode.get_target(target)];


	if delay > 0.0:
		node.get_tree().create_timer(delay).timeout.connect(func():
			if "activator" in node:
				node.activator = node;

			node.call(input, param);
		);
	else:
		if "activator" in node:
			node.activator = node;
		node.call(input, param);
