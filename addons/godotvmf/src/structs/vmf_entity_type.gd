class_name VMFEntityType extends RefCounted

func _init(entity: VMFEntity):
	for field in get_property_list():
		if not field.name in entity.data: continue;
		self[field.name] = entity.data[field.name];
