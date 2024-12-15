class_name ANIReader extends RefCounted;

class ANIAnimation:
  static var scheme:
    get: return {
      base_pointer = ByteReader.Type.INT,
      name_offset = ByteReader.Type.INT,
      framerate = ByteReader.Type.FLOAT,
      flags = ByteReader.Type.INT,
      frame_count = ByteReader.Type.INT,
      movement_count = ByteReader.Type.INT,
      movement_offset = ByteReader.Type.INT,
      unused1 = [ByteReader.Type.INT, 6],
      anim_block = ByteReader.Type.INT,
      anim_offset = ByteReader.Type.INT,

      ik_rules_count = ByteReader.Type.INT,
      ik_rule_offset = ByteReader.Type.INT,
      animblock_ik_rule_offset = ByteReader.Type.INT,

      local_hierarchy_count = ByteReader.Type.INT,
      local_hierarchy_offset = ByteReader.Type.INT,

      section_offset = ByteReader.Type.INT,
      section_frame_count = ByteReader.Type.INT,

      span_frame_count = ByteReader.Type.SHORT,
      span_count = ByteReader.Type.SHORT,
      span_offset = ByteReader.Type.INT,
      span_stall_time = ByteReader.Type.FLOAT,
    }

  var base_pointer: int;
  var name_offset: int;
  var framerate: float;
  var flags: int;
  var frame_count: int;
  var movement_count: int;
  var movement_offset: int;
  var unused1: Array[int];
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

  var address: int = 0;
  var name: String = "";
  var blocks: Array = [];
  var movements: Array = [];

  func _to_string():
    return ByteReader.get_structure_string("ANIAnimation", self, ["name"]);

class ANIMovement:
  static var scheme:
    get: return {
      endframe = ByteReader.Type.INT,
      motion_flags = ByteReader.Type.INT,
      v0 = ByteReader.Type.FLOAT,
      v1 = ByteReader.Type.FLOAT,
      angle = ByteReader.Type.FLOAT,
      vector = ByteReader.Type.VECTOR3,
      position = ByteReader.Type.VECTOR3,
    }


  var endframe: int;
  var motion_flags: int;
  var v0: float;
  var v1: float;
  var angle: float;
  var vector: Vector3;
  var position: Vector3;

  var address: int = 0;

  func _to_string():
    return ByteReader.get_structure_string("ANIMovement", self);

# mstudioanim_t
class ANIAnimBlock:
  static var scheme:
    get: return {
      bone = ByteReader.Type.BYTE,
      flags = ByteReader.Type.BYTE,
    }

  var bone_index: int;
  var bone: int;
  var flags: int;
  var next_offset: int;
  var offsets: Array[int] = [];

  var address: int = 0;

  func _to_string():
    return ByteReader.get_structure_string("ANIAnimBlock", self);

var header: MDLReader.MDLHeader;
var file: FileAccess;
var anims: Array = [];


func _init(source_file: String, mdl_header: MDLReader.MDLHeader):
  file = FileAccess.open(source_file, FileAccess.READ);
  header = mdl_header;

  file.seek(header.local_anim_offset);

  _read_animations();

  file.close();

# TODO: Implement animation reading
func _read_animations():
  anims = ByteReader.read_array(file, header, "anim_offset", "anim_count", ANIAnimation);

  for anim in anims:
    anim.name = ByteReader.read_string(file, anim.address + anim.name_offset);

  # NOTE: Stuck here :c
  for anim in anims:
    var old_adress = anim.address;
    anim.blocks = ByteReader.read_array(file, anim, "anim_offset", "anim_block", ANIAnimBlock);

