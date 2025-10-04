@tool
extends EditorPlugin

var dock;
var fileChecksums = {};
var textureChecksums = {};

var mdl_import_plugin;
var vtf_import_plugin;
var vmt_import_plugin;
var vmt_context_plugin: VMTContextMenu;
var vmt_material_conversion_context_plugin: VMFMaterialConversionContextMenu;
var entity_context_plugin: VMFEntityContextMenu;


func _enter_tree() -> void:
	dock = preload("res://addons/godotvmf/plugin.tscn").instantiate();
	
	add_control_to_container(CONTAINER_SPATIAL_EDITOR_MENU, dock);

	dock.get_node('ReimportVMF').pressed.connect(ReimportVMF);
	dock.get_node('ReimportEntities').pressed.connect(ReimportEntities);
	dock.get_node('ReimportGeometry').pressed.connect(ReimportGeometry);
	dock.get_node('Docs').pressed.connect(func(): OS.shell_open("https://github.com/H2xDev/GodotVMF/wiki"));
	dock.get_node('DiscordSupport').pressed.connect(func(): OS.shell_open("https://discord.gg/wtSK94fPxd"));

	mdl_import_plugin = preload("res://addons/godotvmf/godotmdl/import.gd").new();
	vmt_import_plugin = preload("res://addons/godotvmf/godotvmt/vmt_import.gd").new();
	vtf_import_plugin = preload("res://addons/godotvmf/godotvmt/vtf_import.gd").new();

	add_import_plugin(mdl_import_plugin);
	add_import_plugin(vmt_import_plugin);
	add_import_plugin(vtf_import_plugin);
	add_custom_type("VMFNode", "Node3D", preload("res://addons/godotvmf/src/vmf_node.gd"), preload("res://addons/godotvmf/hammer.png"));
	add_custom_type("ValveIONode", "Node3D", preload("res://addons/godotvmf/src/valve_io_node.gd"), preload("res://addons/godotvmf/hammer.png"));
	add_custom_type("VMFEntityNode", "Node3D", preload("res://addons/godotvmf/src/vmf_entity_node.gd"), preload("res://addons/godotvmf/hammer.png"));

	vmt_context_plugin = VMTContextMenu.new();
	add_context_menu_plugin(EditorContextMenuPlugin.CONTEXT_SLOT_FILESYSTEM, vmt_context_plugin);

	entity_context_plugin = VMFEntityContextMenu.new();
	add_context_menu_plugin(EditorContextMenuPlugin.CONTEXT_SLOT_FILESYSTEM, entity_context_plugin);

	vmt_material_conversion_context_plugin = VMFMaterialConversionContextMenu.new();
	add_context_menu_plugin(EditorContextMenuPlugin.CONTEXT_SLOT_FILESYSTEM, vmt_material_conversion_context_plugin);

	VMFConfig.define_project_settings()
	VMFConfig.load_config()

func _exit_tree():
	VMFConfig.detach_signals()
	remove_custom_type("VMFNode");
	remove_custom_type("ValveIONode");
	
	remove_control_from_container(CONTAINER_SPATIAL_EDITOR_MENU, dock);
	dock.free();

	remove_import_plugin(mdl_import_plugin);
	remove_import_plugin(vmt_import_plugin);
	remove_import_plugin(vtf_import_plugin);
	remove_context_menu_plugin(vmt_context_plugin);
	remove_context_menu_plugin(entity_context_plugin);
	remove_context_menu_plugin(vmt_material_conversion_context_plugin);

	mdl_import_plugin = null;
	vmt_import_plugin = null;
	vtf_import_plugin = null;
	vmt_context_plugin = null;
	entity_context_plugin = null;
	vmt_material_conversion_context_plugin = null;

func GetExistingVMFNodes() -> Array[VMFNode]:
	var nodes: Array[VMFNode] = [];

	if !get_tree(): return nodes;
	
	nodes.assign(get_tree().get_nodes_in_group("vmfnode_group"));
	return nodes.filter(func(node): return not node.get_meta("instance", false));

func ReimportVMF():
	var nodes := GetExistingVMFNodes();

	dock.get_node('ProgressBar').show();
	await get_tree().create_timer(0.1).timeout

	for node in nodes:
		node.import_map();
	dock.get_node('ProgressBar').hide();

func ReimportEntities():
	var nodes := GetExistingVMFNodes();

	dock.get_node('ProgressBar').show();
	dock.get_node('ProgressBar').show();
	await get_tree().create_timer(0.1).timeout

	for node in nodes: 
		node.reimport_entities();
	dock.get_node('ProgressBar').hide();

func ReimportGeometry():
	var nodes := GetExistingVMFNodes();

	dock.get_node('ProgressBar').show();
	await get_tree().create_timer(0.1).timeout

	for node in nodes:
		node.reimport_geometry();
	dock.get_node('ProgressBar').hide();
