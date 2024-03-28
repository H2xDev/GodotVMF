@tool
class_name ValveIONode extends Node3D;

static var namedEntities = {};

static func define_alias(name: String, value: Node):
	if name == '!self' or name in aliases:
		VMFLogger.error('The alias "' + name + '" is already defined');
		return;

	aliases[name] = value;

@export var entity = {};
@export var enabled = true;
@export var flags: int = 0;

var config:
	get:
		return VMFConfig.config;

static var aliases: Dictionary = {};

func Toggle(_param = null):
	enabled = !enabled;

func Enable(_param = null):
	enabled = true;

func Disable(_param = null):
	enabled = false;

func Kill(_param = null):
	get_parent().remove_child(self);
	queue_free();

func _entity_ready():
	pass;

func _reparent():
	if not "parentname" in entity:
		return;

	var parentNode = get_target(entity.parentname);

	if parentNode:
		call_deferred("reparent", parentNode, true);

func _ready():
	if Engine.is_editor_hint():
		return;

	parse_connections();
	

	ValveIONode.namedEntities[name] = self;

	if "StartDisabled" in entity and entity.StartDisabled == 1:
		enabled = false;

	_reparent();
	call_deferred("_entity_ready");

func _apply_entity(ent, config):
	self.entity = ent;
	self.flags = ent.get("spawnflags", 0);
	self.basis = get_entity_basis(ent);
	self.global_position = ent.get("origin", Vector3.ZERO);

	assign_name();

func assign_name(i = 0) -> void:
	if not "targetname" in entity:
		self.name = entity.classname + '_' + str(entity.id);
		return;

	if not get_parent().get_node_or_null(entity.targetname):
		self.name = entity.targetname;
	else: if not get_parent().get_node_or_null(entity.targetname + str(i)):
		self.name = entity.targetname + str(i);
	else:
		return assign_name(i + 1);

func call_target_input(target, input, param, delay) -> void:
	if not enabled:
		return;

	var targetNode = null;

	if target in aliases:
		targetNode = aliases[target];

	if target == '!self':
		targetNode = self;

	if targetNode == null:
			targetNode = get_target(target);

	if not targetNode:
		return;

	if not input in targetNode:
		return;

	var targets = get_all_targets(targetNode.name) if not target.begins_with("!") else [targetNode];

	for node in targets:
		if delay > 0.0:
			set_timeout(func():
				node.call(input, param), delay);
		else:
			node.call(input, param);

func get_target(n) -> Node3D:
	if n in ValveIONode.aliases:
		return ValveIONode.aliases[n];

	if not n in ValveIONode.namedEntities:
		return get_parent().get_node_or_null(NodePath(n));

	return ValveIONode.namedEntities[n];

func get_all_targets(name, i = -1, targets: Array[Node3D] = []) -> Array[Node3D]:
	var cname = name + str(i) if i > -1 else name;
	var node = get_target(cname);

	if not node:
		return targets;

	targets.append(node);
	return get_all_targets(name, i + 1, targets);

func set_timeout(callable, delay) -> void:
	var _timer = Timer.new();
	add_child(_timer);

	_timer.connect("timeout", callable);
	_timer.set_wait_time(delay);
	_timer.start();

	_timer.connect("timeout", func():
		_timer.queue_free());

func parse_connections() -> void:
	if not validate_entity(): return;

	if not "connections" in entity:
		return;

	var outputs = entity.connections.keys();

	for output in outputs:
		var connections = entity.connections[output];

		connections = connections if connections is Array else [connections];

		add_user_signal(output);

		for connectionData in connections:
			var arr = connectionData.split(",");
			var target = arr[0];
			var input = arr[1];
			var param = arr[2];
			var delay = float(arr[3]);
			var times = arr[4];

			self.connect(output, func():
				call_target_input(target, input, param, delay));

func validate_entity() -> bool:
	if entity.keys().size() == 0:
		VMFLogger.error('Looks like you forgot to call "super._apply_instance" inside the entity - ' + name);
		return false;

	return true;

# PUBLICS
func has_flag(flag: int) -> bool:
	if not "spawnflags" in entity:
		return false;

	if typeof(entity.spawnflags) != TYPE_INT:
		entity.spawnflags = int(entity.spawnflags);

	return (entity.spawnflags & flag) != 0;

func trigger_output(output) -> void:
	if not enabled:
		return;

	if has_signal(output):
		emit_signal(output);

func get_mesh() -> ArrayMesh:
	if not validate_entity():
		return;

	var solids = entity.solid if entity.solid is Array else [entity.solid];

	var struct = {
		'world': {
			'solid': solids,
		},
	};
	var offset = entity.origin if "origin" in entity else Vector3.ZERO;

	var fallbackMaterial = config.material.fallbackMaterial;

	return VMFTool.createMesh(struct, offset);

static func convert_vector(v) -> Vector3:
	return Vector3(v.x, v.z, -v.y);

static func convert_direction(v) -> Vector3:
	return get_entity_basis({ "angles": v }).get_euler();
	
static func get_entity_basis(ent) -> Basis:
	var angles = ent.get("angles", Vector3.ZERO) / 180 * PI;
	angles = Vector3(angles.z, angles.y, -angles.x);
	
	return Basis.from_euler(angles, 3);

static func get_movement_vector(v):
	var _basis = Basis.from_euler(Vector3(v.x, -v.y, -v.z) / 180.0 * PI);
	var movement = _basis.z;

	return Vector3(movement.z, movement.y, movement.x);

func get_value(field, fallback):
	return entity[field] if field in entity else fallback;

## Returns the shape of the entity that depends on solids that it have
func get_entity_shape():
	var use_convex_shape = entity.solid is Dictionary;

	if use_convex_shape:
		return get_entity_convex_shape();
	else:
		return get_entity_trimesh_shape();

func get_entity_convex_shape():
	if not validate_entity():
		return;

	var solids = entity.solid if entity.solid is Array else [entity.solid];

	var struct = {
		'world': {
			'solid': solids,
		},
	};

	var origin = entity.origin if "origin" in entity else Vector3.ZERO;

	var mesh = VMFTool.createMesh(struct, origin);

	return mesh.create_convex_shape();
	
## Creates optimised trimesh shape of the entity by using CSGCombiner3D
func get_entity_trimesh_shape():
	if not validate_entity():
		return;

	var solids = entity.solid if entity.solid is Array else [entity.solid];

	var combiner = CSGCombiner3D.new();

	for solid in solids:
		var struct = {
			'world': {
				'solid': [solid],
			},
		};
	
		var csgmesh = CSGMesh3D.new();
		var origin = entity.origin if "origin" in entity else Vector3.ZERO;

		csgmesh.mesh = VMFTool.createMesh(struct, origin);

		combiner.add_child(csgmesh);
		
	combiner._update_shape();
	var shape = combiner.get_meshes()[1].create_trimesh_shape();
	
	combiner.queue_free();
	
	return shape;


