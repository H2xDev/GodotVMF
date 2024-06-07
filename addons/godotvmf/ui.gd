extends MarginContainer


# Called when the node enters the scene tree for the first time.
func _enter_tree():
	$ReimportButton.pressed.connect(func():
		var childs = get_tree().get_scene_edited_root().get_children()
		
		for child in childs:
			if not child is VMFNode:
				continue;

			child.importMap();
	);
