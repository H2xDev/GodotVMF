class_name ANIReader extends MDLStruct

var mdl_header: MDLReader.MDLHeader

func _init(source_file: String, mdl_header: MDLReader.MDLHeader):
	self.mdl_header = mdl_header;
	file = FileAccess.open(source_file, FileAccess.READ);
	prints("MDL Version: ", mdl_header.version);
	prints("MDL Animations: ", mdl_header.local_anim_count);
	read_animations();
	file.close();

func read_animations():
	file.seek(mdl_header.local_anim_offset);
	var anim = AniAnimationDescription.new(file);
	print(anim);
