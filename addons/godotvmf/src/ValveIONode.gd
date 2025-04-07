@tool
class_name ValveIONode extends Node3D;

static var named_entities = {};
static var scene_instance: Node = null;

## Assigns global targetname for the node
static func define_alias(name: String, value: Node):
	if name == '!self' or name in aliases:
		VMFLogger.error('The alias "' + name + '" is already defined');
		return;

	aliases[name] = value;

@export var entity := {};
@export var enabled := true;
@export var flags: int = 0;

var config:
	get: return VMFConfig;

static var aliases: Dictionary = {};

var is_runtime = false;
var activator = null;

func Toggle(_param = null):
	enabled = !enabled;

func Enable(_param = null):
	enabled = true;

func Disable(_param = null):
	enabled = false;

func Kill(_param = null):
	if entity.get("targetname", "") in ValveIONode.named_entities:
		named_entities.erase(entity.targetname);

	get_parent().remove_child(self);
	queue_free();

func _entity_ready():
	pass;

func _reparent():
	if not "parentname" in entity:
		return;

	var parentNode = get_target(entity.parentname);

	if parentNode: reparent(parentNode, true);

func _ready():
	var ename = entity.get("targetname", "");
	if ename: add_to_group(entity.targetname);

	if is_runtime:
		_apply_entity(entity);
	else:
		set_process(false);
		set_physics_process(false);

	if Engine.is_editor_hint():
		return;

	if ename: add_named_entity(ename, self);

	parse_connections(self);

	set_process(true);
	set_physics_process(true);

	call_deferred("_reparent");
	call_deferred("_entity_ready");
	scene_instance = get_tree().current_scene;

func _apply_entity(ent) -> void:
	self.entity = ent;
	self.flags = ent.get("spawnflags", 0);
	self.transform = get_entity_transform(ent);
	self.enabled = ent.get("StartDisabled", 0) == 0;

	assign_name();

func assign_name() -> void:
	self.name = str(entity.get("id", "no_name"));

	if not "targetname" in entity:
		self.name = entity.classname + '_' + str(entity.get("id", "no-id"));
		return;

	self.name = entity.targetname + '_' + str(entity.get("id", "no-id"));

static func add_named_entity(name: String, node: Node):
	node.add_to_group(name);
	if not name in ValveIONode.named_entities:
		ValveIONode.named_entities[name] = [];

	ValveIONode.named_entities[name].append(node);

static func call_target_input(target, input, param, delay, caller) -> void:
	if "enabled" in caller and not caller.enabled:
		return;

	var targets = get_all_targets(target, caller) \
			if not target.begins_with("!") \
			else [get_target(target, caller)];

	for node in targets:
		if not is_instance_valid(node): continue;
		if input not in node: continue;

		if delay > 0.0:
			caller.get_tree().create_timer(delay).timeout.connect(func():
				node.set("activator", caller);
				node.call(input, param)
			);
		else:
			node.set("activator", caller);
			node.call(input, param);

## Returns the first node with the targetname
static func get_target(n, caller = null) -> Node3D:
	if n in ValveIONode.aliases:
		return ValveIONode.aliases[n];

	var nodes = get_all_targets(n, caller);
	var node = nodes[0] if nodes.size() > 0 else null;

	if node == null: return null;
	if not is_instance_valid(node):
		ValveIONode.named_entities[n].erase(node);
		return get_target(n, caller);

	return node;

## Returns all nodes with the targetname
static func get_all_targets(target_name: String, caller = null) -> Array:
	if scene_instance.get_tree().has_group(target_name):
		return scene_instance.get_tree().get_nodes_in_group(target_name);

	return ValveIONode.named_entities.get(target_name, []);

static func parse_connections(caller: Node) -> void:
	if "validate_entity" in caller and not caller.validate_entity(): return;
	if not "entity" in caller or not "connections" in caller.entity: return;

	var outputs = caller.entity.connections.keys();

	for output in outputs:
		var connections = caller.entity.connections[output];
		connections = connections if connections is Array else [connections];

		if not caller.has_signal(output):
			caller.add_user_signal(output);

		for connectionData in connections:
			var arr = connectionData.split(",");
			var target = arr[0];
			var input = arr[1];
			var param = arr[2];
			var delay = float(arr[3]);
			var times = arr[4];

			caller.connect(output, func(): call_target_input(target, input, param, delay, caller));

## Returns the VMFNode where the entity placed
func get_vmfnode():
	var p = get_parent();

	while p:
		if p is VMFNode: return p;
		p = p.get_parent();

	return null;

func validate_entity() -> bool:
	if entity.keys().size() == 0:
		VMFLogger.error('Looks like you forgot to call "super._apply_entity" inside the entity - ' + name);
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
	if output is Signal:
		output = output.get_name();

	if not enabled: return;

	if has_signal(output):
		emit_signal(output);

## Returns mesh of the entity
func get_mesh(cleanup = true, lods = true) -> ArrayMesh:
	if not validate_entity(): return;

	var solids = entity.solid if entity.solid is Array else [entity.solid];

	var struct := {
		'source': entity.classname + '_' + str(entity.id),
		'world': { 'solid': solids },
	};
	
	var mesh = VMFTool.cleanup_mesh(VMFTool.create_mesh(struct, global_position)) \
			if cleanup \
			else VMFTool.create_mesh(struct, global_position);
	return VMFTool.generate_lods(mesh) if lods else mesh;

## Converts the vector from Z-up to Y-up
static func convert_vector(v) -> Vector3:
	return Vector3(v.x, v.z, -v.y);

## Converts Source's angles to Godot's Euler angles
static func convert_direction(v) -> Vector3:
	return get_entity_basis({ "angles": v }).get_euler();

## Returns Transform3D based on the entity parameters
static func get_entity_transform(ent):
	var angles = ent.get("angles", Vector3.ZERO) / 180 * PI;
	angles = Vector3(angles.z, angles.y, -angles.x);
	
	var basis = Basis.from_euler(angles, 3);
	var pos = ent.get("origin", Vector3.ZERO) * VMFConfig.import.scale;
	pos = Vector3(pos.x, pos.z, -pos.y);
	return Transform3D(basis, pos);
	
## Returns Basis based on the entity parameters
static func get_entity_basis(ent) -> Basis:
	return get_entity_transform(ent).basis;

static func get_movement_vector(v):
	var _basis = Basis.from_euler(Vector3(v.x, -v.y, -v.z) / 180.0 * PI);
	var movement = _basis.z;

	return Vector3(movement.z, movement.y, movement.x);

## Returns the shape of the entity that depends on solids that it have
func get_entity_shape():
	var use_convex_shape = entity.solid is Dictionary or entity.solid.size() == 1;

	if use_convex_shape:
		return get_entity_convex_shape();
	else:
		return get_entity_trimesh_shape();

func get_entity_convex_shape():
	if not validate_entity():
		return;

	var solids = entity.solid if entity.solid is Array else [entity.solid];
	var struct := {
		'world': {
			'solid': solids,
		},
	};

	var mesh = VMFTool.create_mesh(struct, global_position);
	return mesh.create_convex_shape();
	
## Creates optimised trimesh shape of the entity by using CSGCombiner3D
func get_entity_trimesh_shape():
	if not validate_entity():
		return;

	var solids = entity.solid if entity.solid is Array else [entity.solid];

	var combiner = CSGCombiner3D.new();

	for solid in solids:
		var struct = { 'world': { 'solid': [solid] } };
		var csgmesh = CSGMesh3D.new();

		csgmesh.mesh = VMFTool.create_mesh(struct, global_position);
		combiner.add_child(csgmesh);
		
	combiner._update_shape();
	var shape = combiner.get_meshes()[1].create_trimesh_shape();
	
	combiner.queue_free();
	
	return shape;

func get_separated_collisions() -> Array[CollisionShape3D]:
	var collisions: Array[CollisionShape3D] = [];

	var solids = entity.solid if entity.solid is Array else [entity.solid];
	for solid in solids:
		var struct = { 'world': { 'solid': [solid] } };
		var mesh = VMFTool.create_mesh(struct, global_position);
		var collision_shape = CollisionShape3D.new();
		collision_shape.shape = mesh.create_convex_shape(true);
		collisions.append(collision_shape);

	return collisions;
