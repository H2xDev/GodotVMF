class_name VMTContextMenu extends EditorContextMenuPlugin

func _popup_menu(paths: PackedStringArray):
	var has_vmts = Array(paths).filter(func(p): return p.ends_with(".vmt")).size() > 0;
	if not has_vmts: return;

	add_context_menu_item("Create editable material", create_editable_material);

func create_editable_material(paths: PackedStringArray):
	var vmts = Array(paths).filter(func(p): return p.ends_with(".vmt"));

	for vmt_file in vmts:
		var target_file = vmt_file.replace(".vmt", ".tres");
		var vmt := load(vmt_file) as Material;
		if not vmt: continue;

		var error := ResourceSaver.save(vmt, target_file);
		if error:
			print("Failed to create editable material: " + target_file);
