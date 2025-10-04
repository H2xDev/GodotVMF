# map.gd
@tool
class_name VMFRuntimeController extends Node3D;

@export var default_map_name: String = "";
@export_dir var maps_folder: String = "res://maps";

const IMPORTANT_MESSAGE = "In hammer do following steps:
	1. Open Tools -> Options -> Build programs tab. In the \"Game Executable\" specify path to the Godot Engine launcher.
	2. Open Run Map window (F9).
	3. Click \"Edit\" and add new configuration.
	4. Select the created configuration in Configurations field
	5. Click \"New\" and add into \"Command\" field this - $game_exe
	6. Add into \"Parameters\" field this
	 --path $gamedir {scene_path} --vmf $file";

@export_multiline var hammer_setup: String;

const PROCESS_FILE = ".current_process";

static var instance: VMFRuntimeController;

func kill_existing_process():
	var pid = FileAccess.open(PROCESS_FILE, FileAccess.READ);
	if pid:
		var processToKill = int(pid.get_line());

		if processToKill:
			print("Killing existing process: {0}".format([pid.get_line()]));
			OS.kill(processToKill);

		pid.close();

	var file = FileAccess.open(PROCESS_FILE, FileAccess.WRITE);
	file.store_string(str(OS.get_process_id()));
	file.close();

func launch_map():
	var args = OS.get_cmdline_args();
	var vmf_arg = args.find("--vmf");
	var map_name = default_map_name;

	if vmf_arg != -1:
		map_name = args[vmf_arg + 1];
	
	var map_path = (maps_folder + "/{0}.vmf").format([map_name]);

	if not FileAccess.file_exists(map_path):
		push_error("Map file not found: {0}".format([map_path]));
		return;

	print("Loading map: {0}".format([map_path]));

	var vmf = VMFNode.new();
	var scene = get_tree().current_scene;

	scene.add_child(vmf);

	vmf.vmf = map_path;
	vmf.name = map_name;
	vmf.save_geometry = false;
	vmf.save_collision = false;
	vmf.is_runtime = true;
	vmf.import_map();
	vmf.set_owner(scene);

func _ready():
	if Engine.is_editor_hint(): 
		hammer_setup = IMPORTANT_MESSAGE.format({
			scene_path = get_tree().edited_scene_root.scene_file_path.replace("res://", ""),
		});
		return;
	instance = self;

	kill_existing_process();
	launch_map();

func _process(_delta):
	if Input.is_action_just_pressed("ui_cancel"):
		DirAccess.remove_absolute(PROCESS_FILE);
		get_tree().quit();
