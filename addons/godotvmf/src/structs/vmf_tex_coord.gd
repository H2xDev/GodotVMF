class_name VMFTexCoord extends RefCounted
var x: float = 0.0;
var y: float = 0.0;
var z: float = 0.0;
var shift: float = 0.0;
var scale: float = 0.0;

func _init(raw: Dictionary):
	x = raw.get("x", 0.0);
	y = raw.get("y", 0.0);
	z = raw.get("z", 0.0);
	shift = raw.get("shift", 0.0);
	scale = raw.get("scale", 0.0);
