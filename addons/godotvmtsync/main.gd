@tool
extends EditorPlugin

var watcher = VMTWatcher.new();
var watcher_thread = null;

func _enter_tree():
	if not is_config_valid(): return;
	watcher_thread = Thread.new();
	watcher_thread.start(watcher._begin_watch.bind(self));

func _exit_tree():
	if watcher_thread: watcher_thread.wait_to_finish();

func is_config_valid():
	VMFConfig.load_config();
	var vtfcmd = VMFConfig.vtfcmd;

	if vtfcmd == "":
		push_error("vtfcmd not set in vmf.config.json");
		return false;

	vtfcmd = ProjectSettings.globalize_path(vtfcmd);
	if not FileAccess.file_exists(vtfcmd):
		push_error("The presented path to vtfcmd is not valid: " + vtfcmd);
		return false;

	return true;
