class_name AniBoneAnimation extends MDLStruct

enum Flags {
	STUDIO_ANIM_RAWPOS = 0x01,
	STUDIO_ANIM_RAWROT	= 0x02,
	STUDIO_ANIM_ANIMPOS	= 0x04,
	STUDIO_ANIM_ANIMROT	= 0x08,
	STUDIO_ANIM_DELTA	= 0x10,
	STUDIO_ANIM_RAWROT2	= 0x20,
}

static func _scheme() -> Dictionary:
	return {
		bone_index = Type.INT,
		flags = Type.INT,
	}

var bone_index: int
var flags: int
