@tool
extends EditorPlugin

var dock;
var fileChecksums = {};
var textureChecksums = {};
var watcher = VMFWatcher.new();

func _enter_tree():
	add_custom_type("VMFNode", "Node3D", preload("res://addons/godotvmf/utils/VMFNode.gd"), preload("res://addons/godotvmf/hammer.png"));
	add_custom_type("ValveIONode", "Node3D", preload("res://addons/godotvmf/utils/ValveIONode.gd"), preload("res://addons/godotvmf/hammer.png"));
	
	dock = preload("res://addons/godotvmf/plugin.tscn").instantiate();
	
	add_control_to_container(CONTAINER_SPATIAL_EDITOR_MENU, dock);

	dock.get_node('ReimportVMF').pressed.connect(ReimportVMF);
	dock.get_node('ReimportEntities').pressed.connect(ReimportEntities);
	dock.get_node('ReimportGeometry').pressed.connect(ReimportGeometry);

	watcher._begin_watch(self);

func GetExistingVMFNodes():
	var root = get_tree().get_edited_scene_root();

	if root is VMFNode:
		return [root];

	var childs = root.get_children();
	var nodes = [];

	for child in childs:
		if child is VMFNode:
			nodes.append(child);

	return nodes;

func ReimportVMF():
	var nodes = GetExistingVMFNodes();

	for node in nodes:
		node.importMap();

func ReimportEntities():
	var nodes = GetExistingVMFNodes();

	for node in nodes:
		node._importEntities(true);

func ReimportGeometry():
	var nodes = GetExistingVMFNodes();

	for node in nodes:
		node.importGeometryOnly();

func _exit_tree():
	remove_custom_type("VMFNode");
	remove_custom_type("ValveIONode");
	
	remove_control_from_container(CONTAINER_SPATIAL_EDITOR_MENU, dock);
	dock.free();
	watcher._stop_watch(self);
