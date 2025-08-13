class_name VMFEntityContextMenu extends EditorContextMenuPlugin

func is_entity_script(p: String) -> bool: 
	return p.ends_with(".gd") and p.begins_with(VMFConfig.import.entities_folder);

func _popup_menu(paths: PackedStringArray):
	var has_scripts = Array(paths).filter(is_entity_script).size() > 0;
	if not has_scripts: return;

	add_context_menu_item("Create entity scene", create_entity_scene);

func create_entity_scene(paths: PackedStringArray):
	var scripts := Array(paths).filter(is_entity_script);

	for script_file in scripts:
		var target_file := script_file.replace(".gd", ".tscn") as String;
		var entity_class := load(script_file) as GDScript;
		if not entity_class: continue;

		var scene := PackedScene.new();
		var node := entity_class.new();
		node.name = entity_class.get_global_name();
		scene.pack(node);

		var error := ResourceSaver.save(scene, target_file);
		if error:
			print("Failed to create entity scene: " + target_file);

		node.queue_free();
