class_name VMFLogger;

static func log(msg: String):
	print('[GodotVMF] ' + msg);

static func error(msg: String):
	push_error('[GodotVMF] ' + msg);

static func warn(msg: String):
	push_warning('[GodotVMF] ' + msg);

static func measure_call(breakpoint_time: float, message: String, function: Callable) -> Variant:
	var start_time = Time.get_ticks_msec();
	var result = function.call();
	var elapsed_time = Time.get_ticks_msec() - start_time;

	if elapsed_time > breakpoint_time:
		warn(message % elapsed_time);

	return result;
