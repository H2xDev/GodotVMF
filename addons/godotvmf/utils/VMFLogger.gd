class_name VMFLogger;

static func log(msg: String):
	print('[GodotVMF] ' + msg);

static func error(msg: String):
	push_error('[GodotVMF] ' + msg);

static func warn(msg: String):
	push_warning('[GodotVMF] ' + msg);

