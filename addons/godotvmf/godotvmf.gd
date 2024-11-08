@tool
extends EditorPlugin

var dock;
var fileChecksums = {};
var textureChecksums = {};

var mdl_import_plugin;
var vtf_import_plugin;
var vmt_import_plugin;

func _enter_tree() -> void:
	add_custom_type("VMFNode", "Node3D", preload("res://addons/godotvmf/src/VMFNode.gd"), preload("res://addons/godotvmf/hammer.png"));
	add_custom_type("ValveIONode", "Node3D", preload("res://addons/godotvmf/src/ValveIONode.gd"), preload("res://addons/godotvmf/hammer.png"));
	
	dock = preload("res://addons/godotvmf/plugin.tscn").instantiate();
	
	add_control_to_container(CONTAINER_SPATIAL_EDITOR_MENU, dock);

	dock.get_node('ReimportVMF').pressed.connect(ReimportVMF);
	dock.get_node('ReimportEntities').pressed.connect(ReimportEntities);
	dock.get_node('ReimportGeometry').pressed.connect(ReimportGeometry);

	mdl_import_plugin = preload("res://addons/godotvmf/godotmdl/import.gd").new();
	vmt_import_plugin = preload("res://addons/godotvmf/godotvmt/vmt_import.gd").new();
	vtf_import_plugin = preload("res://addons/godotvmf/godotvmt/vtf_import.gd").new();

	add_import_plugin(mdl_import_plugin);
	add_import_plugin(vmt_import_plugin);
	add_import_plugin(vtf_import_plugin);

func _exit_tree():
	remove_custom_type("VMFNode");
	remove_custom_type("ValveIONode");
	
	remove_control_from_container(CONTAINER_SPATIAL_EDITOR_MENU, dock);
	dock.free();

	remove_import_plugin(mdl_import_plugin);
	remove_import_plugin(vmt_import_plugin);
	remove_import_plugin(vtf_import_plugin);

	mdl_import_plugin = null;
	vmt_import_plugin = null;
	vtf_import_plugin = null;

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
