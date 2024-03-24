@tool
class_name FuncInstance extends ValveIONode;

static var cached = {};

func _apply_entity(e, c):
	super._apply_entity(e, c);

	var file = VMFInstanceManager.correctInstancePath(e, c.vmf);
	var basename = file.get_file().get_basename();
	var path = (VMFConfig.config.import.instancesFolder + "/" + basename + ".tscn").replace("//", "/").replace("res:/", "res://");

	if not ResourceLoader.exists(path):
		var struct = ValveFormatParser.parse(file);

		if "entity" in struct:
			struct.entity = [struct.entity] if struct.entity is Dictionary else struct.entity;

			for ent in struct.entity:
				if ent.classname != "func_instance":
					continue;

				var subfile = VMFInstanceManager.correctInstancePath(ent, c.vmf);

				VMFInstanceManager.importInstance(subfile, c);
		VMFInstanceManager.importInstance(file, c);


	var res = cached[basename] if basename in FuncInstance.cached else load(path);

	if not basename in FuncInstance.cached and res:
		cached[basename] = res;

	if not res:
		VMFLogger.warn("Failed to load instance: " + path + "\n EntityID: " + str(e.id));
		return;

	var node = res.instantiate();
	node.name = basename + '_instance';

	node.position = position;
	node.rotation = rotation;
	get_parent().add_child(node);
	node.set_owner(get_owner());

	queue_free();
