@tool
class_name ValveIONode extends VMFEntityNode

func _ready():
	super._ready();
	VMFLogger.warn("ValveIONode is deprecated class. Use VMFEntityNode instead: %s" % get_script().resource_path);
