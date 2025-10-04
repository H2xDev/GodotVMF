class_name VMFEntity extends RefCounted

var id: int = -1;
var data: Dictionary = {};
var has_solid: bool = false;
var solids: Array[VMFSolid] = [];
var vmf: String = "";
var classname: String = "";
var connections: Array[VMFConnection] = [];
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

	if "connections" in raw:
		_define_connections(raw.connections);

func _to_string() -> String:
	return "VMFEntity(id=%d, has_solid=%s, solids=%d)" % [id, has_solid, solids.size()];

func _define_connections(raw: Dictionary) -> void:
	if not "connections" in raw: return;

	for output in raw.connections.keys():
		var raw_connections: Variant = raw.connections[output];
		if raw_connections is Dictionary:
			raw_connections = [raw_connections];

		for connection in raw_connections:
			connections.append(VMFConnection.new(output, connection));
