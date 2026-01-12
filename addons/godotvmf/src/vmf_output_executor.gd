class_name VMFOutputExecutor extends VMFEntityNode

var target: String;
var input: String;
var param: String;
var delay: float;
var times: int;
var caller: VMFEntityNode;

func _init(
	_target: String = "", 
	_input: String = "",
	_param: String = "",
	_delay: float = 0.0,
	_times: int = 1
):
	target = _target;
	input = _input;
	param = _param;
	delay = _delay;
	times = _times;

func _ready():
	if delay <= 0.0:
		_execute_target_input();
	else: get_tree().create_timer(delay).timeout.connect(_execute_target_input);

func _execute_target_input() -> void:
	var targets = get_all_targets(target) \
		if not target.begins_with("!") \
		else [get_target(target)];

	for node in targets:
		if not is_instance_valid(node): continue;
		if input not in node: continue;

		node.set("activator", caller);
		node.call(input, param);

	queue_free();
