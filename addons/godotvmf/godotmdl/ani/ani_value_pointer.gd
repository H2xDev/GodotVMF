class_name AniValuePointer extends MDLStruct

static func _scheme() -> Dictionary:
	return {
		offsets = [Type.UNSIGNED_SHORT, 3],
	}

var offsets: Array[int] = [];

func _init(file: FileAccess, address_: int = 0):
	super._init(file, address_)

	for i in range(3):
		if offsets[i] == 0: continue;
		values[i] = AniValue.new(file, address_ + offsets[i]);

