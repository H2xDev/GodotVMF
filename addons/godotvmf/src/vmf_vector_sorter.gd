class_name VMFVectorSorter extends RefCounted

var normal: Vector3;
var center: Vector3;
var pp: Vector3;
var qp: Vector3;

func longer(a: Vector3, b: Vector3) -> Vector3:
	return a if a.length() > b.length() else b;

func _init(normal, center) -> void:
	self.normal = normal;
	self.center = center;

	var i: Vector3 = normal.cross(Vector3(1, 0, 0));
	var j: Vector3 = normal.cross(Vector3(0, 1, 0));
	var k: Vector3 = normal.cross(Vector3(0, 0, 1));

	self.pp = longer(i, longer(j, k));
	self.qp = normal.cross(self.pp);

func get_order(v: Vector3) -> float:
	var normalized: Vector3 = (v - self.center).normalized();
	return atan2(
		self.normal.dot(normalized.cross(self.pp)), 
		self.normal.dot(normalized.cross(self.qp))
	);

func sort(a: Vector3, b: Vector3) -> bool:
	return get_order(a) < get_order(b);
