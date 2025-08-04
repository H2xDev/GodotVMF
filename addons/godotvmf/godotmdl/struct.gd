class_name MDLStruct extends RefCounted

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
}

const SIZES = {
	Type.INT: 4,
	Type.STRING: 1,
	Type.FLOAT: 4,
	Type.UNSIGNED_SHORT: 2,
	Type.UNSIGNED_CHAR: 1,
	Type.CHAR: 1,
	Type.BYTE: 1,
	Type.VECTOR3: 12,
	Type.VECTOR2: 8,
	Type.TANGENT: 16,
	Type.LONG: 8,
	Type.SHORT: 2,
	Type.STRING_NULL_TERMINATED: 0,  # Variable size
	Type.QUATERNION: 16,
	Type.MAT3X4: 48,
	Type.EULER_VECTOR: 12,
	Type.VECTOR4: 16,
}

static func size_of(struct: Variant) -> int:
	var result = 0;
	var scheme = struct._scheme();
	for key in scheme.keys():
		var is_array = scheme[key] is Array;
		var type = scheme[key] if not is_array else scheme[key][0];
		var length = 1 if not is_array else scheme[key][1];

		if type == Type.STRING and not is_array:
			return -1;

		result += MDLStruct.SIZES[type] * length;
	return result;

static func _scheme() -> Dictionary: return {};

## Address of this structure in the file.
var address: int = 0;

## Name of this structure, used for debugging.
var name: String = "unnamed";

## The file this structure belongs to.
var file: FileAccess = null;

## @virtual
func _post_read(): pass;

func _init(file: FileAccess, address: int = file.get_position()):
	self.file = file;
	self.address = address;
	file.seek(address);
	read_structure();
	_post_read();

func read_structure():
	var scheme = _scheme();
	for key in scheme.keys():
		var is_array = scheme[key] is Array;
		var type = scheme[key] if not is_array else scheme[key][0];
		var length = 1 if not is_array else scheme[key][1];

		warn_if(not key in self, "Key {0} not found in scheme.".format([key]));
		assert(!is_array or (is_array and self[key] is Array), instance_message("Key {0} should be an array.".format([key])));

		if is_array:
			self[key].resize(length);

		for i in range(0, length):
			var value = read_field(type);
			if is_array: self[key][i] = value;
			else: self[key] = value;

func read_field(type: Type):
	match type:
		Type.FLOAT: 					return file.get_float();
		Type.BYTE: 						return file.get_8();
		Type.INT: 						return read_signed_int(file);
		Type.SHORT: 					return read_signed_short(file);
		Type.LONG: 						return file.get_64() - 0x80000000;
		Type.UNSIGNED_SHORT: 			return file.get_16();
		Type.UNSIGNED_CHAR: 			return file.get_8();

		Type.STRING: 					return char(file.get_8());
		Type.CHAR: 						return char(file.get_8());
		Type.VECTOR2: 					return Vector2(file.get_float(), file.get_float());
		Type.VECTOR4: 					return Vector4(file.get_float(), file.get_float(), file.get_float(), file.get_float());

		Type.STRING_NULL_TERMINATED: 	return read_string(file);
		Type.QUATERNION: 				return read_quaternion(file);
		Type.VECTOR3: 					return read_vector(file);
		Type.TANGENT: 					return read_plane(file);
		Type.MAT3X4: 					return read_transform_3d(file);
		Type.EULER_VECTOR: 				return read_euler_vector(file);
		_: return type;

func instance_message(message: String) -> String:
	return get_class().get_basename() + ": " + message;

func warn_if(condition: bool, message: String):
	if condition:
		push_warning(instance_message(message));

func _to_string() -> String:
	var scheme = _scheme();
	var result = get_script().get_global_name() + " {0} {";
	for key in scheme.keys():
		if key in self:
			result += "\n  " + key + ": " + str(self[key]) + ",";
		else:
			result += "\n  " + key + ": <not set>,";
	result += "\n}";
	return result.format([name]);

## STATIC DEFINITIONS =========================
static func read_signed_short(file: FileAccess):
	var value = file.get_16();
	if value > 32767:
		value -= 65536;
	return value;

static func read_signed_int(file: FileAccess):
	var value = file.get_32();
	if value > 2147483647:
		value -= 4294967296;
	return value;

## Matrix 3x4 to Transform3D
static func read_transform_3d(file: FileAccess):
	var transform = Transform3D();
	var yup_transform = Transform3D(Vector3(1, 0, 0), Vector3(0, 0, 1), Vector3(0, -1, 0), Vector3(0, 0, 0));

	var x = Vector3(file.get_float(), file.get_float(), file.get_float());
	var y = Vector3(file.get_float(), file.get_float(), file.get_float());
	var z = Vector3(file.get_float(), file.get_float(), file.get_float());
	var t = Vector3(file.get_float(), file.get_float(), file.get_float());

	transform.basis = Basis(
		Vector3(x.x, x.y, x.z),
		Vector3(y.x, y.y, y.z),
		Vector3(z.x, z.y, z.z)
	);

	transform.origin = Vector3(t.x, t.y, t.z);

	return (transform * yup_transform).orthonormalized();

## Converts euler vector from z-up to y-up
static func read_euler_vector(file: FileAccess):
	return Vector3(file.get_float(), file.get_float(), file.get_float());

## Converts plane from z-up to y-up
static func read_plane(file: FileAccess):
	var plane = Plane(file.get_float(), file.get_float(), file.get_float(), file.get_float());
	return Plane(plane.normal.x, plane.normal.z, plane.normal.y, plane.d);

static func read_vector(file: FileAccess):
	var vector = Vector3(file.get_float(), file.get_float(), file.get_float());

	return Vector3(vector.x, vector.z, -vector.y);

static func read_quaternion(file: FileAccess):
	var q = Quaternion(file.get_float(), file.get_float(), file.get_float(), file.get_float());

	# Convert quaternion from z-up to y-up
	return Quaternion(q.x, q.z, -q.y, q.w);

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
