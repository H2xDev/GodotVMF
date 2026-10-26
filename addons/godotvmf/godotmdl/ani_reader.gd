## Decodes skeletal animations stored inside an MDL file and inside its companion ANI file.
##
## Source supports two completely different storage formats:
##   * the classic per-bone linked list of [code]mstudioanim_t[/code] records (all versions);
##   * [code]STUDIO_FRAMEANIM[/code], a frame-major layout introduced with MDL v49.
##
## Both are implemented here, including sectioned animations and animation blocks
## that live in an external [code].ani[/code] file.
class_name ANIReader extends RefCounted

#region constants
## mstudioanimdesc_t::flags
const STUDIO_LOOPING := 0x0001;
const STUDIO_DELTA := 0x0004;
const STUDIO_ALLZEROS := 0x0020;
const STUDIO_FRAMEANIM := 0x0040;

## mstudioanim_t::flags (classic format)
const STUDIO_ANIM_RAWPOS := 0x01;
const STUDIO_ANIM_RAWROT := 0x02;
const STUDIO_ANIM_ANIMPOS := 0x04;
const STUDIO_ANIM_ANIMROT := 0x08;
const STUDIO_ANIM_DELTA := 0x10;
const STUDIO_ANIM_RAWROT2 := 0x20;

## Per-bone flags of the frame animation format
const STUDIO_FRAME_CONST_POS := 0x01;
const STUDIO_FRAME_CONST_ROT := 0x02;
const STUDIO_FRAME_ANIM_POS := 0x04;
const STUDIO_FRAME_ANIM_ROT := 0x08;
const STUDIO_FRAME_ANIM_POS2 := 0x10;
const STUDIO_FRAME_CONST_POS2 := 0x20;
const STUDIO_FRAME_CONST_ROT2 := 0x40;
const STUDIO_FRAME_ANIM_ROT2 := 0x80;

const CLASSIC_POS_MASK := STUDIO_ANIM_RAWPOS | STUDIO_ANIM_ANIMPOS | STUDIO_ANIM_DELTA;
const CLASSIC_ROT_MASK := STUDIO_ANIM_RAWROT | STUDIO_ANIM_RAWROT2 | STUDIO_ANIM_ANIMROT | STUDIO_ANIM_DELTA;
const FRAME_POS_MASK := STUDIO_FRAME_CONST_POS | STUDIO_FRAME_ANIM_POS | STUDIO_FRAME_ANIM_POS2 | STUDIO_FRAME_CONST_POS2;
const FRAME_ROT_MASK := STUDIO_FRAME_CONST_ROT | STUDIO_FRAME_ANIM_ROT | STUDIO_FRAME_CONST_ROT2 | STUDIO_FRAME_ANIM_ROT2;

## Quaternion48S ("smallest three") decoding constants
const QUAT48S_SCALE := 23168.0;
const QUAT48S_SHIFT := 16384;

const BUFFER_MDL := 0;
const BUFFER_ANI := 1;
#endregion

var mdl: MDLReader;
var ani_path: String = "";

var _mdl_bytes := PackedByteArray();
var _ani_bytes := PackedByteArray();

## Raw (Source space) per-bone scale values, indexed as [x, y, z]
var _pos_scales: Array[Vector3] = [];
var _rot_scales: Array[Vector3] = [];

var _classic_chains: Dictionary = {};
var _frameanim_layouts: Dictionary = {};

func _init(mdl: MDLReader) -> void:
	self.mdl = mdl;
	if mdl == null or mdl.source_path == "": return;

	_mdl_bytes = FileAccess.get_file_as_bytes(mdl.source_path);

	ani_path = _resolve_ani_path();
	if ani_path != "":
		_ani_bytes = FileAccess.get_file_as_bytes(ani_path);

	for bone in mdl.bones:
		_pos_scales.append(_to_source_vector(bone.pos_scale));
		_rot_scales.append(_to_source_vector(bone.rot_scale));

## True when at least one decodable animation is available
func has_animations() -> bool:
	return not _mdl_bytes.is_empty() and mdl.anim_descs.size() > 0 and mdl.bones.size() > 0;

func _resolve_ani_path() -> String:
	var candidates: Array[String] = [mdl.source_path.get_basename() + ".ani"];

	if mdl.anim_block_name != "":
		candidates.append(mdl.source_path.get_base_dir().path_join(mdl.anim_block_name.get_file()));

	for candidate in candidates:
		if FileAccess.file_exists(candidate): return candidate;

	return "";

#region conversion helpers
## Source is z-up, Godot is y-up. Matches ByteReader.read_vector.
static func _to_godot_vector(v: Vector3) -> Vector3:
	return Vector3(v.x, v.z, -v.y);

## Matches ByteReader.read_quaternion.
static func _to_godot_quaternion(q: Quaternion) -> Quaternion:
	return Quaternion(q.x, q.z, -q.y, q.w);

## Inverse of _to_godot_vector. MDLBone scale fields are stored already converted,
## but animation channels are indexed in Source axis order, so they have to be restored.
static func _to_source_vector(v: Vector3) -> Vector3:
	return Vector3(v.x, -v.z, v.y);

## Source's AngleQuaternion(RadianEuler) - produces a quaternion in Source space.
static func _angle_quaternion(angles: Vector3) -> Quaternion:
	var sy := sin(angles.z * 0.5);
	var cy := cos(angles.z * 0.5);
	var sp := sin(angles.y * 0.5);
	var cp := cos(angles.y * 0.5);
	var sr := sin(angles.x * 0.5);
	var cr := cos(angles.x * 0.5);

	return Quaternion(
		sr * cp * cy - cr * sp * sy,
		cr * sp * cy + sr * cp * sy,
		cr * cp * sy - sr * sp * cy,
		cr * cp * cy + sr * sp * sy
	);
#endregion

#region primitive decoders
static func _read_vector48(buffer: PackedByteArray, offset: int) -> Vector3:
	if offset < 0 or offset + 6 > buffer.size(): return Vector3.ZERO;
	return Vector3(buffer.decode_half(offset), buffer.decode_half(offset + 2), buffer.decode_half(offset + 4));

static func _read_vector(buffer: PackedByteArray, offset: int) -> Vector3:
	if offset < 0 or offset + 12 > buffer.size(): return Vector3.ZERO;
	return Vector3(buffer.decode_float(offset), buffer.decode_float(offset + 4), buffer.decode_float(offset + 8));

static func _read_quaternion48(buffer: PackedByteArray, offset: int) -> Quaternion:
	if offset < 0 or offset + 6 > buffer.size(): return Quaternion.IDENTITY;

	var x := buffer.decode_u16(offset);
	var y := buffer.decode_u16(offset + 2);
	var zw := buffer.decode_u16(offset + 4);

	var qx := (x - 32768) / 32768.0;
	var qy := (y - 32768) / 32768.0;
	var qz := ((zw & 0x7FFF) - 16384) / 16384.0;
	var t := 1.0 - qx * qx - qy * qy - qz * qz;
	var qw := sqrt(t) if t > 0.0 else 0.0;

	if zw & 0x8000: qw = -qw;

	return Quaternion(qx, qy, qz, qw);

static func _read_quaternion64(buffer: PackedByteArray, offset: int) -> Quaternion:
	if offset < 0 or offset + 8 > buffer.size(): return Quaternion.IDENTITY;

	var lo := buffer.decode_u32(offset);
	var hi := buffer.decode_u32(offset + 4);

	var x := lo & 0x1FFFFF;
	var y := ((lo >> 21) | ((hi & 0x3FF) << 11)) & 0x1FFFFF;
	var z := (hi >> 10) & 0x1FFFFF;

	var qx := (x - 1048576) / 1048576.5;
	var qy := (y - 1048576) / 1048576.5;
	var qz := (z - 1048576) / 1048576.5;
	var t := 1.0 - qx * qx - qy * qy - qz * qz;
	var qw := sqrt(t) if t > 0.0 else 0.0;

	if (hi >> 31) & 1: qw = -qw;

	return Quaternion(qx, qy, qz, qw);

## "Smallest three" quaternion used by the frame animation format
static func _read_quaternion48s(buffer: PackedByteArray, offset: int) -> Quaternion:
	if offset < 0 or offset + 6 > buffer.size(): return Quaternion.IDENTITY;

	var w0 := buffer.decode_u16(offset);
	var w1 := buffer.decode_u16(offset + 2);
	var w2 := buffer.decode_u16(offset + 4);

	var index_a := (w1 >> 15) + (w0 >> 15) * 2;
	var values := [0.0, 0.0, 0.0, 0.0];

	values[index_a] = ((w0 & 0x7FFF) - QUAT48S_SHIFT) / QUAT48S_SCALE;
	values[(index_a + 1) % 4] = ((w1 & 0x7FFF) - QUAT48S_SHIFT) / QUAT48S_SCALE;
	values[(index_a + 2) % 4] = ((w2 & 0x7FFF) - QUAT48S_SHIFT) / QUAT48S_SCALE;

	var t: float = 1.0 - values[index_a] * values[index_a] \
			- values[(index_a + 1) % 4] * values[(index_a + 1) % 4] \
			- values[(index_a + 2) % 4] * values[(index_a + 2) % 4];

	var missing := sqrt(t) if t > 0.0 else 0.0;
	values[(index_a + 3) % 4] = -missing if (w2 >> 15) else missing;

	return Quaternion(values[0], values[1], values[2], values[3]);

## Source's Studio_ExtractAnimValue over a run-length encoded mstudioanimvalue_t array
static func _extract_anim_value(buffer: PackedByteArray, base: int, frame: int, scale: float) -> float:
	if base <= 0 or base + 2 > buffer.size(): return 0.0;

	var pointer := base;
	var remaining := frame;
	var valid := buffer[pointer];
	var total := buffer[pointer + 1];

	if total < 1: return 0.0;

	var guard := 0;
	while total <= remaining:
		remaining -= total;
		pointer += (valid + 1) * 2;
		guard += 1;

		if guard > 0xFFFF or pointer + 2 > buffer.size(): return 0.0;

		valid = buffer[pointer];
		total = buffer[pointer + 1];

		if total < 1: return 0.0;

	var value_offset := pointer + ((remaining + 1) * 2 if valid > remaining else valid * 2);
	if value_offset + 2 > buffer.size(): return 0.0;

	return buffer.decode_s16(value_offset) * scale;
#endregion

#region animation data resolving
func _get_buffer(buffer_id: int) -> PackedByteArray:
	return _ani_bytes if buffer_id == BUFFER_ANI else _mdl_bytes;

## Resolves which buffer, base offset and local frame index hold the data of [param frame].
## Returns an empty dictionary when the data is unreachable.
func _resolve_frame_source(anim_desc, frame: int) -> Dictionary:
	var block: int = anim_desc.anim_block;
	var index: int = anim_desc.anim_offset;
	var local_frame := frame;

	if anim_desc.section_frame_count != 0 and anim_desc.sections.size() > 0:
		var section_index := 0;

		if anim_desc.frame_count > anim_desc.section_frame_count and frame == anim_desc.frame_count - 1:
			section_index = int(anim_desc.frame_count / anim_desc.section_frame_count) + 1;
			local_frame = 0;
		else:
			section_index = int(frame / anim_desc.section_frame_count);
			local_frame = frame - section_index * anim_desc.section_frame_count;

		if section_index >= anim_desc.sections.size(): return {};

		var section = anim_desc.sections[section_index];
		block = section.anim_block;
		index = section.anim_offset;

	if block == 0 and index == 0: return {};

	var buffer_id := BUFFER_MDL;
	var base := 0;

	if block == 0:
		base = anim_desc.address + index;
	else:
		if block >= mdl.anim_blocks.size() or _ani_bytes.is_empty(): return {};
		buffer_id = BUFFER_ANI;
		base = mdl.anim_blocks[block].data_start + index;

	var buffer := _get_buffer(buffer_id);
	if base < 0 or base + 4 > buffer.size(): return {};

	return { "buffer_id": buffer_id, "base": base, "frame": local_frame };

## Walks the mstudioanim_t linked list once and caches the result
func _get_classic_chain(buffer_id: int, base: int) -> Array:
	var key := "%d:%d" % [buffer_id, base];
	if key in _classic_chains: return _classic_chains[key];

	var buffer := _get_buffer(buffer_id);
	var bone_count := mdl.bones.size();
	var chain: Array = [];
	var visited := {};
	var cursor := base;

	while cursor > 0 and cursor + 4 <= buffer.size() and chain.size() <= bone_count:
		var bone := buffer[cursor];
		var flags := buffer[cursor + 1];
		var next_offset := buffer.decode_s16(cursor + 2);

		if bone >= bone_count or bone in visited: break;

		visited[bone] = true;
		chain.append({ "bone": bone, "flags": flags, "data": cursor + 4 });

		if next_offset == 0: break;
		cursor += next_offset;

	_classic_chains[key] = chain;
	return chain;

## Parses the mstudio_frame_anim_t header, the constant pose and the per-bone frame offsets
func _get_frameanim_layout(buffer_id: int, base: int) -> Dictionary:
	var key := "%d:%d" % [buffer_id, base];
	if key in _frameanim_layouts: return _frameanim_layouts[key];

	var buffer := _get_buffer(buffer_id);
	var bone_count := mdl.bones.size();
	var layout := { "valid": false };

	if base + 24 + bone_count > buffer.size():
		_frameanim_layouts[key] = layout;
		return layout;

	var constants_offset := buffer.decode_s32(base);
	var frame_offset := buffer.decode_s32(base + 4);
	var frame_length := buffer.decode_s32(base + 8);

	var bone_flags := PackedByteArray();
	bone_flags.resize(bone_count);
	for i in range(bone_count):
		bone_flags[i] = buffer[base + 24 + i];

	# Constants are stored per bone, interleaved, in a fixed field order.
	var constant_positions: Array[Vector3] = [];
	var constant_rotations: Array[Quaternion] = [];
	constant_positions.resize(bone_count);
	constant_rotations.resize(bone_count);

	var cursor := base + constants_offset;

	for i in range(bone_count):
		var flags := bone_flags[i];
		var position: Vector3 = mdl.bones[i].pos;
		var rotation: Quaternion = mdl.bones[i].quat;

		if flags & STUDIO_FRAME_CONST_ROT2:
			rotation = _to_godot_quaternion(_read_quaternion48s(buffer, cursor));
			cursor += 6;
		if flags & STUDIO_FRAME_CONST_POS2:
			position = _to_godot_vector(_read_vector(buffer, cursor));
			cursor += 12;
		if flags & STUDIO_FRAME_CONST_ROT:
			rotation = _to_godot_quaternion(_read_quaternion48(buffer, cursor));
			cursor += 6;
		if flags & STUDIO_FRAME_CONST_POS:
			position = _to_godot_vector(_read_vector48(buffer, cursor));
			cursor += 6;

		constant_positions[i] = position;
		constant_rotations[i] = rotation;

	# Animated fields live at a fixed offset inside every frame record.
	var frame_fields: Array = [];
	var field_offset := 0;

	for i in range(bone_count):
		var flags := bone_flags[i];
		var field := { "rot_type": 0, "rot_offset": -1, "pos_type": 0, "pos_offset": -1 };

		if flags & STUDIO_FRAME_ANIM_ROT2:
			field.rot_type = 2;
			field.rot_offset = field_offset;
			field_offset += 6;
		if flags & STUDIO_FRAME_ANIM_ROT:
			field.rot_type = 1;
			field.rot_offset = field_offset;
			field_offset += 6;
		if flags & STUDIO_FRAME_ANIM_POS:
			field.pos_type = 1;
			field.pos_offset = field_offset;
			field_offset += 6;
		if flags & STUDIO_FRAME_ANIM_POS2:
			field.pos_type = 2;
			field.pos_offset = field_offset;
			field_offset += 12;

		frame_fields.append(field);

	layout = {
		"valid": true,
		"bone_flags": bone_flags,
		"constant_positions": constant_positions,
		"constant_rotations": constant_rotations,
		"frame_fields": frame_fields,
		"frame_base": base + frame_offset,
		"frame_length": frame_length,
	};

	_frameanim_layouts[key] = layout;
	return layout;
#endregion

#region decoding
func _ensure_track(tracks: Dictionary, bone: int, frame_count: int) -> Dictionary:
	if bone in tracks: return tracks[bone];

	var positions: Array[Vector3] = [];
	var rotations: Array[Quaternion] = [];
	positions.resize(frame_count);
	rotations.resize(frame_count);

	var track := {
		"positions": positions,
		"rotations": rotations,
		"has_position": false,
		"has_rotation": false,
	};

	tracks[bone] = track;
	return track;

func _decode_classic_frame(buffer_id: int, base: int, local_frame: int, frame: int, frame_count: int, tracks: Dictionary) -> void:
	var buffer := _get_buffer(buffer_id);

	for link in _get_classic_chain(buffer_id, base):
		var bone: int = link.bone;
		var flags: int = link.flags;
		var data: int = link.data;
		var mdl_bone = mdl.bones[bone];

		var track := _ensure_track(tracks, bone, frame_count);
		track.has_position = track.has_position or (flags & CLASSIC_POS_MASK) != 0;
		track.has_rotation = track.has_rotation or (flags & CLASSIC_ROT_MASK) != 0;

		var rotation: Quaternion = mdl_bone.quat;

		if flags & STUDIO_ANIM_RAWROT:
			rotation = _to_godot_quaternion(_read_quaternion48(buffer, data));
		elif flags & STUDIO_ANIM_RAWROT2:
			rotation = _to_godot_quaternion(_read_quaternion64(buffer, data));
		elif flags & STUDIO_ANIM_ANIMROT:
			var scales: Vector3 = _rot_scales[bone];
			var angles := Vector3.ZERO;

			for axis in range(3):
				var channel := buffer.decode_s16(data + axis * 2);
				angles[axis] = _extract_anim_value(buffer, data + channel if channel > 0 else 0, local_frame, scales[axis]);

			if not (flags & STUDIO_ANIM_DELTA):
				angles += mdl_bone.rot;

			rotation = _to_godot_quaternion(_angle_quaternion(angles));
		elif flags & STUDIO_ANIM_DELTA:
			rotation = Quaternion.IDENTITY;

		var position: Vector3 = mdl_bone.pos;
		var position_data := data;

		if flags & STUDIO_ANIM_RAWROT: position_data += 6;
		if flags & STUDIO_ANIM_RAWROT2: position_data += 8;

		if flags & STUDIO_ANIM_RAWPOS:
			position = _to_godot_vector(_read_vector48(buffer, position_data));
		elif flags & STUDIO_ANIM_ANIMPOS:
			var value_pointer := data + (6 if (flags & STUDIO_ANIM_ANIMROT) else 0);
			var scales: Vector3 = _pos_scales[bone];
			var offset := Vector3.ZERO;

			for axis in range(3):
				var channel := buffer.decode_s16(value_pointer + axis * 2);
				offset[axis] = _extract_anim_value(buffer, value_pointer + channel if channel > 0 else 0, local_frame, scales[axis]);

			position = _to_godot_vector(offset);
			if not (flags & STUDIO_ANIM_DELTA):
				position += mdl_bone.pos;
		elif flags & STUDIO_ANIM_DELTA:
			position = Vector3.ZERO;

		track.positions[frame] = position;
		track.rotations[frame] = rotation;

func _decode_frameanim_frame(buffer_id: int, base: int, local_frame: int, frame: int, frame_count: int, tracks: Dictionary) -> bool:
	var layout := _get_frameanim_layout(buffer_id, base);
	if not layout.valid: return false;

	var buffer := _get_buffer(buffer_id);
	var bone_flags: PackedByteArray = layout.bone_flags;
	var frame_base: int = layout.frame_base + local_frame * layout.frame_length;

	for bone in range(bone_flags.size()):
		var flags := bone_flags[bone];
		if flags == 0: continue;

		var track := _ensure_track(tracks, bone, frame_count);
		track.has_position = track.has_position or (flags & FRAME_POS_MASK) != 0;
		track.has_rotation = track.has_rotation or (flags & FRAME_ROT_MASK) != 0;

		var field: Dictionary = layout.frame_fields[bone];
		var position: Vector3 = layout.constant_positions[bone];
		var rotation: Quaternion = layout.constant_rotations[bone];

		if field.rot_type == 2:
			rotation = _to_godot_quaternion(_read_quaternion48s(buffer, frame_base + field.rot_offset));
		elif field.rot_type == 1:
			rotation = _to_godot_quaternion(_read_quaternion48(buffer, frame_base + field.rot_offset));

		if field.pos_type == 1:
			position = _to_godot_vector(_read_vector48(buffer, frame_base + field.pos_offset));
		elif field.pos_type == 2:
			position = _to_godot_vector(_read_vector(buffer, frame_base + field.pos_offset));

		track.positions[frame] = position;
		track.rotations[frame] = rotation;

	return true;

## Decodes every frame of [param anim_desc] into { bone_id: { positions, rotations, ... } }
func decode(anim_desc) -> Dictionary:
	var frame_count: int = max(1, anim_desc.frame_count);
	var tracks := {};

	if anim_desc.flags & STUDIO_ALLZEROS: return tracks;

	for frame in range(frame_count):
		var source := _resolve_frame_source(anim_desc, frame);
		if source.is_empty(): return {};

		if anim_desc.flags & STUDIO_FRAMEANIM:
			if not _decode_frameanim_frame(source.buffer_id, source.base, source.frame, frame, frame_count, tracks):
				return {};
		else:
			_decode_classic_frame(source.buffer_id, source.base, source.frame, frame, frame_count, tracks);

	return tracks;
#endregion

#region animation library
## Picks a readable name for every animation. Sequences are preferred since they
## carry the names used by the game, raw animations are used as a fallback.
func _collect_animations() -> Array:
	var result: Array = [];
	var used_names := {};

	var entries: Array = [];

	for seq_desc in mdl.seq_descs:
		if seq_desc.anim_indices.is_empty(): continue;
		var anim_index: int = seq_desc.anim_indices[0];
		if anim_index < 0 or anim_index >= mdl.anim_descs.size(): continue;
		entries.append({ "name": seq_desc.label, "anim_desc": mdl.anim_descs[anim_index] });

	if entries.is_empty():
		for anim_desc in mdl.anim_descs:
			entries.append({ "name": anim_desc.name, "anim_desc": anim_desc });

	for entry in entries:
		var anim_name: String = entry.name;
		if anim_name.begins_with("@"): anim_name = anim_name.substr(1);

		# AnimationLibrary rejects names containing / : , [
		anim_name = anim_name.validate_node_name().replace(",", "_").replace("[", "_").strip_edges();
		if anim_name == "": anim_name = "animation";

		if anim_name in used_names:
			used_names[anim_name] += 1;
			anim_name = "%s_%d" % [anim_name, used_names[anim_name]];
		else:
			used_names[anim_name] = 0;

		result.append({ "name": anim_name, "anim_desc": entry.anim_desc });

	return result;

## Builds an AnimationLibrary with tracks addressed as "<skeleton_name>:<bone_name>".
func build_library(scale: float, skeleton_name: String = "skeleton") -> AnimationLibrary:
	var library := AnimationLibrary.new();
	if not has_animations(): return library;

	for entry in _collect_animations():
		var anim_desc = entry.anim_desc;
		var tracks := decode(anim_desc);
		if tracks.is_empty(): continue;

		var fps: float = anim_desc.fps if anim_desc.fps > 0.0 else 30.0;
		var frame_count: int = max(1, anim_desc.frame_count);
		var step := 1.0 / fps;

		var animation := Animation.new();
		animation.length = max(float(frame_count - 1) * step, step);
		animation.loop_mode = Animation.LOOP_LINEAR if (anim_desc.flags & STUDIO_LOOPING) else Animation.LOOP_NONE;
		animation.step = step;

		for bone in tracks.keys():
			var track: Dictionary = tracks[bone];
			var path := "%s:%s" % [skeleton_name, mdl.bones[bone].name];

			if track.has_position:
				var position_track := animation.add_track(Animation.TYPE_POSITION_3D);
				animation.track_set_path(position_track, NodePath(path));
				animation.track_set_imported(position_track, true);

				for frame in range(frame_count):
					animation.position_track_insert_key(position_track, frame * step, track.positions[frame] * scale);

			if track.has_rotation:
				var rotation_track := animation.add_track(Animation.TYPE_ROTATION_3D);
				animation.track_set_path(rotation_track, NodePath(path));
				animation.track_set_imported(rotation_track, true);

				for frame in range(frame_count):
					animation.rotation_track_insert_key(rotation_track, frame * step, track.rotations[frame].normalized());

		if animation.get_track_count() == 0: continue;

		library.add_animation(entry.name, animation);

	return library;
#endregion
