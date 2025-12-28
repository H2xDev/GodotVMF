class_name VMFEntity extends RefCounted

var id: int = -1;
var data: Dictionary = {};
var has_solid: bool = false;
var solids: Array[VMFSolid] = [];
var vmf: String = "";
var classname: String = "";
var targetname: String;
var parentname: String;
var angles: Vector3 = Vector3.ZERO;
var origin: Vector3 = Vector3.ZERO;

func _init(raw: Dictionary) -> void:
	id = int(raw.get("id", -1));
	classname = raw.get("classname", "");
	data = raw;
	has_solid = "solid" in raw and raw.solid is Dictionary;
	angles = raw.get("angles", Vector3.ZERO);
	origin = raw.get("origin", Vector3.ZERO);

	if has_solid:
		var raw_solids: Variant = raw.get("solid", []);
		if raw_solids is not Array:
			raw_solids = [raw_solids];

		for solid in raw_solids:
			solids.append(VMFSolid.new(solid));

func _to_string() -> String:
	return "VMFEntity(id=%d, has_solid=%s, solids=%d)" % [id, has_solid, solids.size()];
