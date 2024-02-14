extends MarginContainer


# Called when the node enters the scene tree for the first time.
func _enter_tree():
	$ReimportButton.pressed.connect(func():
		print("qweqweqwe");
		var childs = get_tree().get_scene_edited_root().get_children()
		
		for child in childs:
			print(child.name);
			if not child is VMFNode:
				continue;

			child.importMap();
	);
