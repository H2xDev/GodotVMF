class_name AniMovement extends MDLStruct

static func _scheme() -> Dictionary: return {
	end_frame = Type.INT,
	motion_flags = Type.INT,
	v0 = Type.FLOAT,
	v1 = Type.FLOAT,
	angle = Type.FLOAT,
	vector = Type.VECTOR3,
	position = Type.VECTOR3,
}

var end_frame: int;
var motion_flags: int;
var v0: float;
var v1: float;
var angle: float;
var vector: Vector3;
var position: Vector3;
