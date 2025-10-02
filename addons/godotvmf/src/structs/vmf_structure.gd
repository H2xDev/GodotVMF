class_name VMFStructure extends RefCounted

var solids: Array[VMFSolid] = [];
var entities: Array[VMFEntity] = [];

func _init(raw: Dictionary) -> void:
	var raw_solids: Variant = raw.world.get("solid", []);

	if raw_solids is not Array:
		raw_solids = [raw_solids];

	for solid in raw_solids:
		solids.append(VMFSolid.new(solid));

	var raw_entities: Variant = raw.get("entity", []);
	if raw_entities is not Array:
		raw_entities = [raw_entities];

	for entity in raw_entities:
		entities.append(VMFEntity.new(entity));

func _to_string() -> String:
	var line1 = "VMFStructure(solids=%d, entities=%d)\n" % [solids.size(), entities.size()]
	var line2 = "  Solids:\n"
	for solid in solids:
		line2 += "    %s\n" % solid;

	var line3 = "  Entities:\n"
	for entity in entities:
		line3 += "    %s\n" % entity;

	return line1 + line2 + line3;
