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

func _ready():
	if Engine.is_editor_hint():
		return;

	parse_connections();
	
	if "parentname" in entity:
		var parentNode = get_target(entity.parentname);

		if parentNode:
			var posDiff = parentNode.global_position - position;
			call_deferred("reparent", parentNode, false);
			position = -posDiff;

	ValveIONode.namedEntities[name] = self;

	if "StartDisabled" in entity and entity.StartDisabled == 1:
		enabled = false;

	_entity_ready();

func _apply_entity(ent, config):
	self.entity = ent;
	self.global_position = ent.origin if "origin" in ent else Vector3(0, 0, 0);
	self.flags = ent.spawnflags if "spawnflags" in ent else 0;

	assign_name();

func assign_name(i = 0):
	if not "targetname" in entity:
		self.name = entity.classname + '_' + str(entity.id);
		return;

	if not get_parent().get_node_or_null(entity.targetname):
		self.name = entity.targetname;
	else: if not get_parent().get_node_or_null(entity.targetname + str(i)):
		self.name = entity.targetname + str(i);
	else:
		return assign_name(i + 1);

func call_target_input(target, input, param, delay):
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

func get_target(n):
	if n in ValveIONode.aliases:
		return ValveIONode.aliases[n];

	if not n in ValveIONode.namedEntities:
		return get_parent().get_node_or_null(NodePath(n));

	return ValveIONode.namedEntities[n];

func get_all_targets(name, i = -1, targets = []):
	var cname = name + str(i) if i > -1 else name;
	var node = get_target(cname);

	if not node:
		return targets;

	targets.append(node);
	return get_all_targets(name, i + 1, targets);

func set_timeout(callable, delay):
	var _timer = Timer.new();
	add_child(_timer);

	_timer.connect("timeout", callable);
	_timer.set_wait_time(delay);
	_timer.start();

	_timer.connect("timeout", func():
		_timer.queue_free());

func parse_connections():
	if not validateEntity():
		return;

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

func validateEntity():
	if entity.keys().size() == 0:
		VMFLogger.error('Looks like you forgot to call "super._apply_instance" inside the entity - ' + name);
		return false;

	return true;

# PUBLICS
func have_flag(flag: int):
	if not "spawnflags" in entity:
		return false;

	if typeof(entity.spawnflags) != TYPE_INT:
		entity.spawnflags = int(entity.spawnflags);

	return (entity.spawnflags & flag) != 0;

func trigger_output(output):
	if not enabled:
		return;

	if has_signal(output):
		emit_signal(output);

func get_mesh() -> ArrayMesh:
	if not validateEntity():
		return;

	var solids = entity.solid if entity.solid is Array else [entity.solid];

	var struct = {
		'world': {
			'solid': solids,
		},
	};

	var offset = entity.origin if "origin" in entity else Vector3.ZERO;

	return VMFTool.createMesh(struct, offset);

func convert_vector(v):
	return Vector3(v.x, v.z, -v.y);

func convert_direction(v):
	return Vector3(v.z, v.y, -v.x) / 180.0 * PI;

## Returns the shape of the entity that depends on solids that it have
func get_entity_shape():
	var use_convex_shape = entity.solid is Dictionary;

	if use_convex_shape:
		return get_entity_convex_shape();
	else:
		return get_entity_trimesh_shape();

func get_entity_convex_shape():
	if not validateEntity():
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
	if not validateEntity():
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


