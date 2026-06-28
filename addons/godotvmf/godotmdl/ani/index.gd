class_name ANIReader extends RefCounted

## Animation flags from studio.h
const STUDIO_ANIM_RAWPOS  = 0x01  ## Vector48 — static position for all frames
const STUDIO_ANIM_RAWROT  = 0x02  ## Quaternion48 — static rotation for all frames
const STUDIO_ANIM_ANIMPOS = 0x04  ## mstudioanim_valueptr_t — per-frame position
const STUDIO_ANIM_ANIMROT = 0x08  ## mstudioanim_valueptr_t — per-frame rotation
const STUDIO_ANIM_DELTA   = 0x10  ## values are deltas added to the rest pose
const STUDIO_ANIM_RAWROT2 = 0x20  ## Quaternion64 — static rotation for all frames

const SOURCE_TO_GODOT_DYNAMIC := Basis(
	Vector3( -1, 0, 0),
	Vector3( 0, 0, 1),
	Vector3( 0, 1, 0)
);

const SOURCE_TO_GODOT_STATIC := Basis(
	Vector3( 0, 0,-1),
	Vector3(-1, 0, 0),
	Vector3( 0, 1, 0)
);
var file: FileAccess
var mdl: MDLReader
var library: AnimationLibrary
var _scale: float = 1.0

func _init(filepath: String, _mdl: MDLReader):
	mdl = _mdl;
	if FileAccess.file_exists(filepath):
		file = FileAccess.open(filepath, FileAccess.READ);
	parse_local_animations();

## Returns the coordinate-system conversion basis for this model.
## Mirrors MDLCombiner.get_model_transform_basis() but without PHY dependency.
func get_model_transform_basis() -> Basis:
	return SOURCE_TO_GODOT_DYNAMIC;

## Quaternion from Z-up to Y-up
func _transform_quaternion(q: Quaternion) -> Quaternion:
	return q

func _transform_vector(v: Vector3) -> Vector3:
	return v * _scale;

## Builds an AnimationLibrary from the inline animation descriptors in the MDL file.
## scale: override the model scale (defaults to VMFConfig.import.scale).
func parse_local_animations(scale: float = -1.0) -> AnimationLibrary:
	library = AnimationLibrary.new();
	_scale = scale if scale > 0.0 else VMFConfig.import.scale;

	if not mdl or not mdl.header or not mdl.file:
		return library;

	var anim_count: int = mdl.header.anim_count;
	if anim_count <= 0:
		return library;

	var anim_descs: Array = ByteReader.read_array(mdl.file, mdl.header, "anim_offset", "anim_count", MStudioAnimDesc_t);

	for anim_desc in anim_descs:
		_process_anim_desc(anim_desc);

	return library;

# ── Per-animation processing ───────────────────────────────────────────────

func _process_anim_desc(anim_desc: MStudioAnimDesc_t) -> void:
	var anim_name: String = anim_desc.pszName;
	if anim_name.is_empty():
		return;

	if anim_desc.numframes <= 0:
		push_warning("ANIReader: skipping '%s' — invalid numframes %d" % [anim_name, anim_desc.numframes]);
		return;

	var num_frames: int = min(anim_desc.numframes, 10000);
	if anim_desc.numframes > 10000:
		push_warning("ANIReader: clamping '%s' numframes %d → 10000" % [anim_name, anim_desc.numframes]);

	var bone_count: int = mdl.bones.size();
	var bone_rots: Array = [];   # [bone_idx][frame] = Quaternion
	var bone_poss: Array = [];   # [bone_idx][frame] = Vector3
	bone_rots.resize(bone_count);
	bone_poss.resize(bone_count);

	# Fill each bone with its rest-pose value for every frame
	for bi in range(bone_count):
		var bone: MDLReader.MDLBone = mdl.bones[bi];
		bone_rots[bi] = [];
		bone_poss[bi] = [];
		var rest_q := _transform_quaternion(bone.quat);
		var rest_p := _transform_vector(bone.pos);
		for _f in range(num_frames):
			bone_rots[bi].append(rest_q);
			bone_poss[bi].append(rest_p);

	# Read animation data from MDL file (animblock==0 means inline)
	if anim_desc.animblock == 0 or anim_desc.animblock == -1:
		if anim_desc.sectionindex != 0 and anim_desc.sectionframes > 0:
			_read_sectioned(anim_desc, num_frames, bone_rots, bone_poss);
		elif anim_desc.animindex != 0:
			_read_anim_block(
				mdl.file,
				anim_desc.address + anim_desc.animindex,
				num_frames, 0,
				bone_rots, bone_poss
			);
	# External animblocks (animblock > 0) require the .ani file — skipped for now.

	# Build the Godot Animation resource
	var animation := Animation.new();
	var fps := anim_desc.fps if anim_desc.fps > 0.0 else 30.0;
	animation.length = float(num_frames - 1) / fps;
	animation.loop_mode = Animation.LOOP_LINEAR if (anim_desc.flags & 0x1) else Animation.LOOP_NONE;

	for bi in range(bone_count):
		var bone: MDLReader.MDLBone = mdl.bones[bi];
		var rot_track: int = animation.add_track(Animation.TYPE_ROTATION_3D);
		var pos_track: int = animation.add_track(Animation.TYPE_POSITION_3D);
		animation.track_set_path(rot_track, "skeleton:" + bone.name);
		animation.track_set_path(pos_track, "skeleton:" + bone.name);
		for f in range(num_frames):
			var t := float(f) / fps;
			animation.rotation_track_insert_key(rot_track, t, bone_rots[bi][f]);
			animation.position_track_insert_key(pos_track, t, bone_poss[bi][f]);

	var safe_name: String = anim_name.replace("/", "_").replace("@", "").replace(" ", "_");
	if safe_name.is_empty():
		safe_name = "anim_%d" % anim_desc.address;
	if library.has_animation(safe_name):
		safe_name = safe_name + "_%d" % anim_desc.address;
	library.add_animation(safe_name, animation);

# ── Sectioned animation ────────────────────────────────────────────────────

func _read_sectioned(anim_desc: MStudioAnimDesc_t, num_frames: int, bone_rots: Array, bone_poss: Array) -> void:
	var sectionframes: int = anim_desc.sectionframes;
	# +1 for the terminator section
	var num_sections: int = (num_frames + sectionframes - 1) / sectionframes + 1;

	mdl.file.seek(anim_desc.address + anim_desc.sectionindex);
	var sections: Array = [];
	for _i in range(num_sections):
		sections.append(ByteReader.read_by_structure(mdl.file, MStudioAnimSections_t));

	for si in range(num_sections - 1):  # skip the terminator
		var section: MStudioAnimSections_t = sections[si];
		if section == null:
			continue;
		var frame_start: int = si * sectionframes;
		var frame_count: int = min(sectionframes, num_frames - frame_start);
		if frame_count <= 0:
			break;

		var src_file: FileAccess = _get_source_file(section.animblock);
		if src_file and section.animindex != 0:
			_read_anim_block(src_file, anim_desc.address + section.animindex, frame_count, frame_start, bone_rots, bone_poss);

# ── Bone-linked-list walking ───────────────────────────────────────────────

func _get_source_file(animblock: int) -> FileAccess:
	if animblock == 0 or animblock == -1:
		return mdl.file;
	return file;  # external .ani file

func _read_anim_block(src: FileAccess, start_offset: int, num_frames: int, frame_offset: int, bone_rots: Array, bone_poss: Array) -> void:
	if not src or start_offset <= 0:
		return;

	var bone_count: int = mdl.bones.size();
	var visited: Dictionary = {};
	var max_iters: int = bone_count + 1;

	src.seek(start_offset);

	for _iter in range(max_iters):
		var anim_address: int = src.get_position();
		var anim: MStudioAnim_t = ByteReader.read_by_structure(src, MStudioAnim_t);
		if not anim:
			break;

		var bone_idx: int = anim.bone;
		if bone_idx >= bone_count:
			break;

		if bone_idx in visited:
			push_warning("ANIReader: infinite loop in anim linked list at bone %d" % bone_idx);
			break;
		visited[bone_idx] = true;

		_decode_bone_data(src, anim, anim_address, bone_idx, num_frames, frame_offset, bone_rots, bone_poss);

		if anim.nextoffset == 0:
			break;
		src.seek(anim_address + anim.nextoffset);

# ── Per-bone data decoding ─────────────────────────────────────────────────

func _decode_bone_data(src: FileAccess, anim: MStudioAnim_t, anim_address: int, bone_idx: int, num_frames: int, frame_offset: int, bone_rots: Array, bone_poss: Array) -> void:
	var bone: MDLReader.MDLBone = mdl.bones[bone_idx];
	var flags: int = anim.flags;
	var is_delta: bool = (flags & STUDIO_ANIM_DELTA) != 0;
	# Data begins right after the 4-byte mstudioanim_t header
	var data_start: int = anim_address + 4;

	# ── Rotation ──────────────────────────────────────────────────────────
	var rot_data_size: int = 0;

	if flags & STUDIO_ANIM_RAWROT:
		src.seek(data_start);
		var q := MStudioAnimDecoder.read_quaternion48(src);
		if is_delta:
			q = q * bone.quat;
		var gq := _transform_quaternion(q);
		for f in range(frame_offset, frame_offset + num_frames):
			if f < bone_rots[bone_idx].size():
				bone_rots[bone_idx][f] = gq;
		rot_data_size = 6;

	elif flags & STUDIO_ANIM_RAWROT2:
		src.seek(data_start);
		var q := MStudioAnimDecoder.read_quaternion64(src);
		if is_delta:
			q = q * bone.quat;
		var gq := _transform_quaternion(q);
		for f in range(frame_offset, frame_offset + num_frames):
			if f < bone_rots[bone_idx].size():
				bone_rots[bone_idx][f] = gq;
		rot_data_size = 8;

	elif flags & STUDIO_ANIM_ANIMROT:
		var vptr_addr := data_start;
		src.seek(vptr_addr);
		var vptr: MStudioAnimValuePtr_t = ByteReader.read_by_structure(src, MStudioAnimValuePtr_t);

		var rx := _decode_axis(src, vptr_addr, vptr.offset[0], num_frames);
		var ry := _decode_axis(src, vptr_addr, vptr.offset[1], num_frames);
		var rz := _decode_axis(src, vptr_addr, vptr.offset[2], num_frames);

		for fi in range(num_frames):
			var angles := Vector3(
				_axis_value(rx, fi, bone.rot.x, bone.rot_scale.x),
				_axis_value(ry, fi, bone.rot.y, bone.rot_scale.y),
				_axis_value(rz, fi, bone.rot.z, bone.rot_scale.z)
			);
			var q := MStudioAnimDecoder.angle_quaternion(angles);
			if is_delta:
				q = q * bone.quat;
			var f := frame_offset + fi;
			if f < bone_rots[bone_idx].size():
				bone_rots[bone_idx][f] = _transform_quaternion(q);
		rot_data_size = 6;

	# ── Position ──────────────────────────────────────────────────────────
	var pos_start: int = data_start + rot_data_size;

	if flags & STUDIO_ANIM_RAWPOS:
		src.seek(pos_start);
		var p := MStudioAnimDecoder.read_vector48(src);
		if is_delta:
			p = p + bone.pos;
		var gp := _transform_vector(p);
		for f in range(frame_offset, frame_offset + num_frames):
			if f < bone_poss[bone_idx].size():
				bone_poss[bone_idx][f] = gp;

	elif flags & STUDIO_ANIM_ANIMPOS:
		var vptr_addr := pos_start;
		src.seek(vptr_addr);
		var vptr: MStudioAnimValuePtr_t = ByteReader.read_by_structure(src, MStudioAnimValuePtr_t);

		var px := _decode_axis(src, vptr_addr, vptr.offset[0], num_frames);
		var py := _decode_axis(src, vptr_addr, vptr.offset[1], num_frames);
		var pz := _decode_axis(src, vptr_addr, vptr.offset[2], num_frames);

		for fi in range(num_frames):
			var p := Vector3(
				_axis_value(px, fi, bone.pos.x, bone.pos_scale.x),
				_axis_value(py, fi, bone.pos.y, bone.pos_scale.y),
				_axis_value(pz, fi, bone.pos.z, bone.pos_scale.z)
			);
			if is_delta:
				p = p + bone.pos;
			var f := frame_offset + fi;
			if f < bone_poss[bone_idx].size():
				bone_poss[bone_idx][f] = _transform_vector(p);

# ── Helpers ────────────────────────────────────────────────────────────────

## Decodes animation values for one axis. Returns empty array when offset <= 0 (use rest).
func _decode_axis(src: FileAccess, vptr_addr: int, offset: int, num_frames: int) -> Array[int]:
	if offset <= 0:
		return [];
	return MStudioAnimDecoder.decode_anim_values(src, vptr_addr + offset, num_frames);

## Returns the animated value for a single axis/frame, or the rest-pose value if no data.
func _axis_value(values: Array[int], fi: int, rest: float, scale: float) -> float:
	if values.is_empty():
		return rest;
	var v: int = values[fi] if fi < values.size() else values[-1];
	return float(v) * scale;
