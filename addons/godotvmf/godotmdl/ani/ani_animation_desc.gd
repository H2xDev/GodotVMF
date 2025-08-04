class_name AniAnimationDescription extends MDLStruct

static func _scheme() -> Dictionary:
	return {
		base_pointer 				= Type.INT,
		name_offset 				= Type.INT,
		framerate 					= Type.FLOAT,
		flags 						= Type.INT,
		frame_count 				= Type.INT,

		movement_count 				= Type.INT,
		movement_offset 			= Type.INT,

		unused1 					= [Type.INT, 6],

		anim_block 					= Type.INT,
		anim_offset 				= Type.INT,

		ik_rules_count 				= Type.INT,
		ik_rule_offset 				= Type.INT,
		animblock_ik_rule_offset 	= Type.INT,

		local_hierarchy_count 		= Type.INT,
		local_hierarchy_offset 		= Type.INT,

		section_offset 				= Type.INT,
		section_frame_count 		= Type.INT,

		span_frame_count 			= Type.SHORT,
		span_count 					= Type.SHORT,
		span_offset 				= Type.INT,
		span_stall_time				= Type.FLOAT,
	}

var base_pointer: int;
var name_offset: int;
var framerate: float;
var flags: int;
var frame_count: int;
var movement_count: int;
var movement_offset: int;
var unused1: Array[int] = [];
var anim_block: int;
var anim_offset: int;
var ik_rules_count: int;
var ik_rule_offset: int;
var animblock_ik_rule_offset: int;
var local_hierarchy_count: int;
var local_hierarchy_offset: int;
var section_offset: int;
var section_frame_count: int;
var span_frame_count: int;
var span_count: int;
var span_offset: int;
var span_stall_time: float;


func _post_read():
	name = read_string(file, address + name_offset);
