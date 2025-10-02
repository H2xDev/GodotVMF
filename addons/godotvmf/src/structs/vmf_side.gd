class_name VMFSide extends RefCounted

var id: int = -1;
var material: String = "";
var rotation: float = 0.0;
var lightmap_scale: float = 16.0;
var smoothing_groups: int = 0;

var plane: Plane;
var vaxis: VMFTexCoord;
var uaxis: VMFTexCoord;
var plane_points: PackedVector3Array;
var vertices: PackedVector3Array;
var is_displacement: bool = false;
var dispinfo: VMFDisplacementInfo;
var solid: VMFSolid;
var uv: Vector2 = Vector2.ZERO;

static var texture_size_cache: Dictionary = {};

func _to_string() -> String:
	return "VMFSide(id=%d, material=%s, is_displacement=%s, vertices=%d)" % [id, material, is_displacement, vertices.size()];

func _init(raw: Dictionary, _solid: VMFSolid) -> void:
	id = raw.get("id", -1);
	material = raw.get("material", "");
	is_displacement = "dispinfo" in raw;
	solid = _solid;
	plane = raw.plane.value;

	vaxis = VMFTexCoord.new(raw.vaxis);
	uaxis = VMFTexCoord.new(raw.uaxis);
	plane_points = PackedVector3Array(raw.plane.points);

	if "vertices_plus" in raw:
		vertices = PackedVector3Array(raw.vertices_plus.v);
	else:
		_define_vertices_plus();

	if is_displacement:
		dispinfo = VMFDisplacementInfo.new(raw.dispinfo, self, solid);

func _define_vertices_plus() -> void:
	vertices = PackedVector3Array(solid.calculate_vertices(self));

func get_uv(vertex: Vector3) -> Vector2:
	var uscale: float = uaxis.scale;
	var ushift: float = uaxis.shift * uscale;

	var vscale: float = vaxis.scale;
	var vshift: float = vaxis.shift * vscale;

	var tscale = Vector2.ONE;
	var tsize := VMTLoader.get_texture_size(material);

	var aspect := tsize.x / tsize.y;

	var uv := Vector3(uaxis.x, uaxis.y, uaxis.z);
	var vv := Vector3(vaxis.x, vaxis.y, vaxis.z);
	var v2 := Vector3(vertex.x, vertex.y, vertex.z);
	var normal = plane.normal;

	var u := (v2.dot(uv) + ushift) / tsize.x / uscale;
	var v := (v2.dot(vv) + vshift) / tsize.y / vscale;

	return Vector2(u, v);
