class_name ByteReader extends RefCounted

enum Type {
	INT 						= 1,
	STRING 						= 2,
	FLOAT 						= 3,
	UNSIGNED_SHORT 				= 4,
	UNSIGNED_CHAR 				= 5,
	CHAR 						= 6,
	BYTE 						= 7,
	VECTOR3 					= 8,
	VECTOR2 					= 9,
	TANGENT 					= 10,
	LONG 						= 11,
	SHORT 						= 12,
	STRING_NULL_TERMINATED 		= 13,
	QUATERNION 					= 14,
	MAT3X4 						= 15,
	EULER_VECTOR 				= 16,
	VECTOR4 					= 17,
	INLINE_STRING 				= 18,
}

static func read_array(file: FileAccess, root_structure, offset_field: String, count_field: String, Clazz):
	var address = root_structure.address if "address" in root_structure else 0;
	var count = root_structure[count_field] if count_field in root_structure else 0;
	var offset = root_structure[offset_field] if offset_field in root_structure else 0;

	file.seek(address + offset);
	var result = [];

	for i in range(count):
		result.append(read_by_structure(file, Clazz));

	return result;

static func read_inline_string(file: FileAccess, address: int):
	var offset = read_signed_int(file);
	var result = "";

	if offset == 0:
		result = "";
	else:
		var pos = file.get_position();
		result = read_string(file, address + offset);
		file.seek(pos);
	
	return result;

static func read_by_structure(file: FileAccess, Clazz, read_from = -1):
	var result = Clazz.new();

	if read_from > -1:
		file.seek(read_from);

	if "scheme" not in Clazz:
		push_error("ByteReader: Scheme not found in class: " + Clazz.name);
		return null;

	var address = file.get_position();
	if "address" in result:
		result.address = address;

	for key in Clazz.scheme.keys():
		var type = Clazz.scheme[key];
		var elements_count = -1;

		if type is Array:
			elements_count = type[1];
			type = type[0];

		if not (key in result):
			print("Key not found: " + key);
			continue;

		if elements_count < 0:
			if type == Type.INLINE_STRING:
				result[key] = read_inline_string(file, address);
			else:
				result[key] = _read_data(file, type);
		else:
			var buffer = "";
			for i in range(elements_count):
				if type != Type.STRING:
					if type == Type.INLINE_STRING:
						result[key] = read_inline_string(file, address);
					else:
						result[key].append(_read_data(file, type));
				else:
					buffer += _read_data(file, type);

			if type == Type.STRING:
				result[key] = buffer;

	if "_on_read" in result:
		result._on_read();

	return result;

static func read_char(file: FileAccess):
	var byte = file.get_8();
	return char(byte) if byte != 0 else "";

static func _read_data(file: FileAccess, type: Type):
	match type:
		Type.FLOAT: 					return file.get_float();
		Type.BYTE: 						return file.get_8();
		Type.INT: 						return read_signed_int(file);
		Type.SHORT: 					return read_signed_short(file);
		Type.LONG: 						return file.get_64() - 0x80000000;
		Type.UNSIGNED_SHORT: 			return file.get_16();
		Type.UNSIGNED_CHAR: 			return read_char(file);

		Type.STRING: 					return read_char(file);
		Type.CHAR: 						return read_char(file);
		Type.VECTOR2: 					return Vector2(file.get_float(), file.get_float());
		Type.VECTOR3: 					return Vector3(file.get_float(), file.get_float(), file.get_float());
		Type.VECTOR4: 					return Vector4(file.get_float(), file.get_float(), file.get_float(), file.get_float());
		Type.TANGENT: 					return Plane(file.get_float(), file.get_float(), file.get_float(), file.get_float());
		Type.QUATERNION: 				return Quaternion(file.get_float(), file.get_float(), file.get_float(), file.get_float());

		Type.STRING_NULL_TERMINATED: 	return read_string(file);
		Type.MAT3X4: 					return read_transform_3d(file);
		Type.EULER_VECTOR: 				return read_euler_vector(file);
		_: return type;

static func read_signed_short(file: FileAccess) -> int:
	var value = file.get_16();
	if value > 32767:
		value -= 65536;
	return value;

static func read_signed_int(file: FileAccess) -> int:
	var value = file.get_32();
	if value > 2147483647:
		value -= 4294967296;
	return value;

## Matrix 3x4 to Transform3D
static func read_transform_3d(file: FileAccess) -> Transform3D:
	var transform := Transform3D();

	var source := [
		[file.get_float(), file.get_float(), file.get_float(), file.get_float()],
		[file.get_float(), file.get_float(), file.get_float(), file.get_float()],
		[file.get_float(), file.get_float(), file.get_float(), file.get_float()],
	];

	var basis := Basis(
		Vector3(source[0][0], source[0][1], source[0][2]),
		Vector3(source[1][0], source[1][1], source[1][2]),
		Vector3(source[2][0], source[2][1], source[2][2])
	);

	var origin := Vector3(source[0][3], source[1][3], source[2][3]);

	return Transform3D(basis, origin);

static func read_euler_vector(file: FileAccess) -> Vector3:
	return Vector3(file.get_float(), file.get_float(), file.get_float());

static func read_plane(file: FileAccess) -> Plane:
	return Plane(file.get_float(), file.get_float(), file.get_float(), file.get_float());

static func read_vector(file: FileAccess) -> Vector3:
	return Vector3(file.get_float(), file.get_float(), file.get_float());

static func read_quaternion(file: FileAccess) -> Quaternion:
	return Quaternion(file.get_float(), file.get_float(), file.get_float(), file.get_float());

## Reads string of the file till null character
static func read_string(file: FileAccess, offset: int = -1):
	if offset > -1:
		file.seek(offset);

	var index = 0;
	var result = "";
	var char = file.get_8();

	while char != 0:
		result += char(char);
		char = file.get_8();
		index += 1;

		if index > 100: break;
	return result;

static func get_structure_string(name: String, class_instance, additional_fields = []):
	if "scheme" not in class_instance:
		push_error("ByteReader: Scheme not found in class: " + class_instance.name);
		return;

	var string = ""

	string += name + ": {\n";

	for field in additional_fields:
		string += "\t" + field + ": " + str(class_instance[field]) + ",\n";

	for key in class_instance.scheme.keys():
		string += "\t" + key + ": " + str(class_instance[key]) + ",\n";
	
	string += "}";

	return string;
	
