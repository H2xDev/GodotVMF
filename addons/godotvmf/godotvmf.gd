@tool
extends EditorPlugin

var dock;
var fileChecksums = {};
var textureChecksums = {};
var watcher = VMFWatcher.new();
var materialWatcherThread = null;

func _enter_tree() -> void:
	add_custom_type("VMFNode", "Node3D", preload("res://addons/godotvmf/utils/VMFNode.gd"), preload("res://addons/godotvmf/hammer.png"));
	add_custom_type("ValveIONode", "Node3D", preload("res://addons/godotvmf/utils/ValveIONode.gd"), preload("res://addons/godotvmf/hammer.png"));
	
	dock = preload("res://addons/godotvmf/plugin.tscn").instantiate();
	
	add_control_to_container(CONTAINER_SPATIAL_EDITOR_MENU, dock);

	dock.get_node('ReimportVMF').pressed.connect(ReimportVMF);
	dock.get_node('ReimportEntities').pressed.connect(ReimportEntities);
	dock.get_node('ReimportGeometry').pressed.connect(ReimportGeometry);

	var isWatcherRequired = VMFConfig.config.material.importMode == VTFTool.TextureImportMode.SYNC\
		if VMFConfig.config else false;

	if (isWatcherRequired):
		materialWatcherThread = Thread.new();
		materialWatcherThread.start(watcher._begin_watch.bind(self));

func GetExistingVMFNodes() -> Array[VMFNode]:
	var nodes: Array[VMFNode] = [];

	if !get_tree(): return nodes;
	
	nodes.assign(get_tree().get_nodes_in_group("vmfnode_group"));
	return nodes.filter(func(node):
		return not node.ignore_global_import;
	);

func ReimportVMF():
	var nodes := GetExistingVMFNodes();

	for node in nodes:
		node.import_map();

func ReimportEntities():
	var nodes := GetExistingVMFNodes();

	for node in nodes: 
		print(node.name);
		node.import_entities(true);

func ReimportGeometry():
	var nodes := GetExistingVMFNodes();

	for node in nodes:
		node.import_geometry(true);

func _exit_tree():
	remove_custom_type("VMFNode");
	remove_custom_type("ValveIONode");
	
	remove_control_from_container(CONTAINER_SPATIAL_EDITOR_MENU, dock);
	dock.free();

	if materialWatcherThread:
		materialWatcherThread.wait_to_finish();
