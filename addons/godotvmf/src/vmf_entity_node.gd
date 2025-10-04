@tool
class_name VMFEntityNode extends Node3D

static var named_entities := {};
static var aliases: Dictionary = {};
static var scene_instance: Node = null;

## Assigns global targetname for the node
static func define_alias(name: String, value: Node):
	if name == '!self':
		VMFLogger.error('The alias "' + name + '" is already defined');
		return;

	aliases[name] = value;

static func remove_alias(name: String):
	if name in aliases:
		aliases.erase(name);

@export var entity := {};
@export var enabled := true;
@export var flags: int = 0;

var has_solid: bool:
	get: return "solid" in entity;

var config := VMFConfig;
var reference: VMFEntity;

var is_runtime = false;
var activator = null;
var targetname: String:
	get: return entity.get("targetname", "") if entity else "";

func Toggle(_param = null):
	enabled = !enabled;

func Enable(_param = null):
	enabled = true;

func Disable(_param = null):
	enabled = false;

func Kill(_param = null):
	if entity.get("targetname", "") in VMFEntityNode.named_entities:
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
	if is_runtime:
		_entity_pre_setup(reference);

		## Workaround to support deprecated method
		if _apply_entity(reference.data) == -1:
			_entity_setup(reference);
	else:
		set_process(false);
		set_physics_process(false);

	if Engine.is_editor_hint():
		return;

	if entity.get("targetname", null): add_named_entity(entity.targetname, self);

	parse_connections(self);

	set_process(true);
	set_physics_process(true);

	call_deferred("_reparent");
	call_deferred("_entity_ready");
	scene_instance = get_tree().current_scene;

func _apply_entity(entity_structure: Dictionary):
	return -1;

## Called during import process to setup the entity
func _entity_setup(vmf_entity: VMFEntity) -> void: pass;

func _entity_pre_setup(ent: VMFEntity) -> void:
	self.reference = ent;
	self.entity = ent.data;
	self.flags = ent.data.get("spawnflags", 0);
	self.transform = get_entity_transform(ent);
	self.enabled = ent.data.get("StartDisabled", 0) == 0;

	if ent.data.get("targetname", null):
		add_named_entity(ent.data.targetname, self);

	assign_name();
	_entity_setup(ent);

func assign_name() -> void:
	self.name = str(entity.get("id", "no_name"));

	if not "targetname" in entity:
		self.name = entity.classname + '_' + str(entity.get("id", "no-id"));
		return;

	self.name = entity.targetname + '_' + str(entity.get("id", "no-id"));

static func add_named_entity(_name: String, node: Node):
	node.add_to_group.call_deferred(_name, true);

	if not _name in VMFEntityNode.named_entities:
		VMFEntityNode.named_entities[_name] = [];

	VMFEntityNode.named_entities[_name].append(node);

static func call_target_input(target, input, param, delay, caller) -> void:
	if "enabled" in caller and not caller.enabled:
		return;

	var targets = get_all_targets(target) \
			if not target.begins_with("!") \
			else [get_target(target)];

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
static func get_target(n) -> Node3D:
	if n in VMFEntityNode.aliases:
		return VMFEntityNode.aliases[n];

	var nodes = get_all_targets(n);
	var node = nodes[0] if nodes.size() > 0 else null;

	if node == null: return null;
	if not is_instance_valid(node):
		VMFEntityNode.named_entities[n].erase(node);
		return get_target(n);

	return node;

## Returns all nodes with the targetname
static func get_all_targets(target_name: String) -> Array:
	if scene_instance and scene_instance.get_tree().has_group(target_name):
		return scene_instance.get_tree().get_nodes_in_group(target_name);

	return VMFEntityNode.named_entities.get(target_name, []);

static func parse_connections(caller: Node) -> void:
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
			var input = arr[1] if arr.size() > 1 else "";
			var param = arr[2] if arr.size() > 2 else "";
			var delay = float(arr[3]) if arr.size() > 3 else 0.0;
			var _times = arr[4] if arr.size() > 4 else 1;

			if not input or not target: continue;

			caller.connect(output, func(): call_target_input(target, input, param, delay, caller));

## Returns the VMFNode where the entity placed
func get_vmfnode():
	var p = get_parent();

	while p:
		if p is VMFNode: return p;
		p = p.get_parent();

	return null;

## Returns true if the entity has enabled specified flag
func has_flag(flag: int) -> bool:
	if not "spawnflags" in entity:
		return false;

	if typeof(entity.spawnflags) != TYPE_INT:
		entity.spawnflags = int(entity.spawnflags);

	return (entity.spawnflags & flag) != 0;

## Triggers entity's specified output
func trigger_output(output) -> void:
	if output is Signal:
		output = output.get_name();

	if not enabled: return;

	if has_signal(output):
		emit_signal(output);

## Returns mesh of the entity
func get_mesh(cleanup = true, lods = true) -> ArrayMesh:
	if not has_solid: return null;

	var solids = entity.solid if entity.solid is Array else [entity.solid];

	var struct := VMFStructure.new({
		'source': entity.classname + '_' + str(entity.id),
		'world': { 'solid': solids },
	});
	
	var mesh = VMFTool.cleanup_mesh(VMFTool.create_mesh(struct, global_position)) \
			if cleanup \
			else VMFTool.create_mesh(struct, global_position);

	if not mesh: return null;

	return VMFTool.generate_lods(mesh) if lods else mesh;

## Converts the vector from Z-up to Y-up
static func convert_vector(vector: Vector3) -> Vector3:
	return Vector3(vector.x, vector.z, -vector.y);

## Converts Source's angles to Godot's Euler angles
static func convert_direction(vector: Vector3) -> Vector3:
	vector = vector / 180 * PI;
	return Basis.from_euler(Vector3(vector.z, vector.y, -vector.x), 3).get_euler();

## Returns Transform3D based on the entity parameters
static func get_entity_transform(ent: VMFEntity):
	var angles = ent.angles / 180 * PI;
	angles = Vector3(angles.z, angles.y, -angles.x);
	
	var basis := Basis.from_euler(angles, 3);
	var pos: Vector3 = ent.origin * VMFConfig.import.scale;
	pos = Vector3(pos.x, pos.z, -pos.y);
	return Transform3D(basis, pos);
	
## Returns Basis based on the entity parameters
static func get_entity_basis(ent: VMFEntity) -> Basis:
	return get_entity_transform(ent).basis;

## Converts angle vector into directional vector
static func get_movement_vector(v) -> Vector3:
	var _basis = Basis.from_euler(Vector3(v.x, -v.y, -v.z) / 180.0 * PI);
	var movement = _basis.z;

	return Vector3(movement.z, movement.y, movement.x);

## Returns the shape of the entity that depends on solids that it have
func get_entity_shape() -> Shape3D:
	var use_convex_shape = entity.solid is Dictionary or entity.solid.size() == 1;

	if use_convex_shape:
		return get_entity_convex_shape();
	else:
		return get_entity_trimesh_shape();

## Returns convex collision shape of the entity's solids
func get_entity_convex_shape() -> ConvexPolygonShape3D:
	if not has_solid: return null;

	var solids = entity.solid if entity.solid is Array else [entity.solid];
	var struct := VMFStructure.new({
		'world': {
			'solid': solids,
		},
	});

	var mesh = VMFTool.create_mesh(struct, global_position);

	if (not mesh or mesh.get_surface_count() == 0): return;
	return mesh.create_convex_shape();
	
## Creates optimised trimesh shape of the entity by using CSGCombiner3D
func get_entity_trimesh_shape() -> ConcavePolygonShape3D:
	if not has_solid: return null;

	var solids = entity.solid if entity.solid is Array else [entity.solid];
	var combiner = CSGCombiner3D.new();

	for solid in solids:
		var struct = VMFStructure.new({ 'world': { 'solid': [solid] } });
		var csgmesh = CSGMesh3D.new();
		var mesh = VMFTool.create_mesh(struct, global_position);

		if not mesh or mesh.get_surface_count() == 0: continue;

		csgmesh.mesh = mesh;
		combiner.add_child(csgmesh);
		
	combiner._update_shape();
	var shape = combiner.get_meshes()[1].create_trimesh_shape();
	
	combiner.queue_free();
	
	return shape;

## Returns per-brush collision shapes
func get_separated_collisions() -> Array[CollisionShape3D]:
	var collisions: Array[CollisionShape3D] = [];

	var solids = entity.solid if entity.solid is Array else [entity.solid];
	for solid in solids:
		var struct = { 'world': { 'solid': [solid] } };
		var mesh = VMFTool.create_mesh(struct, global_position);
		var collision_shape := CollisionShape3D.new();
		collision_shape.shape = mesh.create_convex_shape(true);
		collisions.append(collision_shape);

	return collisions;
