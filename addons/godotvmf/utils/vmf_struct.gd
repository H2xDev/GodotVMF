class_name VMFStruct extends RefCounted

enum Type {
	BYTE,
	INT_16,
	INT_32,
	UBYTE,
	UINT_16,
	UINT_32,
	FLOAT,
	STRING,
	ARRAY,
}

static func in_case(lambda: Callable) -> Callable:
	return lambda;

static func transform_struct(file: FileAccess, clazz: GDScript, struct_map: Dictionary) -> Variant:
	var result = clazz.new();

	for key in struct_map.keys():
		var type = struct_map[key];

		match type:
			Type.BYTE:
				result.set(key, file.get_8());
			Type.INT_16:
				result.set(key, file.get_buffer(2).decode_s16(0));
			Type.INT_32:
				result.set(key, file.get_buffer(4).decode_s32(0));
			Type.UBYTE:
				result.set(key, file.get_8());
			Type.UINT_16:
				result.set(key, file.get_16());
			Type.UINT_32:
				result.set(key, file.get_32());
			Type.FLOAT:
				result.set(key, file.get_float());
			Type.STRING:
				result.set(key, get_null_terminated_string(file));
			Type.ARRAY:
				result.set(key, []);
	return result;

static func get_null_terminated_string(file: FileAccess) -> String:
	var result = "";
	while true:
		var c = file.get_8();
		if c == 0: break;
		result += char(c);
	return result;
