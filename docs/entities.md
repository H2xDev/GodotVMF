# Entities
You'll need to create your own entities for your game. If you want to use entities from Half-Life 2 then you should implement entities logic on your own.
All entities should be in `@tool` mode, extended from [`ValveIONode`](#valveionode) and placed in the folder that you assigned in the config (`entitiesFolder`).

1. Create script of an entity.
2. Create a 3d scene with the same name and assign the script.
3. Try to import your map with entity.

> Inputs of entities are just methods with a single parameter that passed from outputs  

> Outputs should be called by method `trigger_output` (from signal for example)

## Example
```gdscript
## func_button.gd
@tool
extends ValveIONode

signal interact();

const FLAG_ONCE = 2;
const FLAG_STARTS_LOCKED = 2048;

var isLocked = false;
var isUsed = false;

var sound = null;
var lockedSound = null;

## Use this instead _ready
func _entity_ready():
	isLocked = has_flag(FLAG_STARTS_LOCKED);

	# Once we trigger this signal we triggering the entity's outputs.
	interact.connect(func ():
		if isLocked:
			if lockedSound:
				SoundManager.PlaySound(global_position, lockedSound, 0.05);
			trigger_output("OnUseLocked")
		else:
			if has_flag(FLAG_ONCE) and isUsed:
				return;

			if sound:
				SoundManager.PlaySound(global_position, sound, 0.05);
			trigger_output("OnPressed")
			isUsed = true);

	if "sound" in entity:
		sound = load("res://Assets/Sounds/" + entity.sound);

	if "locked_sound" in entity:
		lockedSound = load("res://Assets/Sounds/" + entity.locked_sound);

# This method will be called during import
func _apply_entity(entityInfo: Dictionary):
	super._apply_entity(entityInfo, vmfNode);

	# Getting entity's brush geometry and assigning it
	var mesh = get_mesh();
	$MeshInstance3D.set_mesh(mesh);

	# Generating collision for the assigned mesh.
	$MeshInstance3D/StaticBody3D/CollisionShape3D.shape = mesh.create_convex_shape();

## INPUTS
func Lock(_param = null):
	isLocked = true;

func Unlock(_param = null):
	isLocked = false;
```

## ValveIONode
The Base of all entities. Contains I/O logic and some useful methods for entities.  

All entities extends from this node will always have these inputs so you don't need to define it.
- Toggle - toggles `enabled` field of the entity
- Enable - enable the entity
- Disable - disables and blocks outputs for the entity
- Kill - removes the node from tree

Reference:
* [_entity_ready](#_entity_ready)
* [_apply_entity](#_apply_entity)
* [has_flag](#has_flagflag-int---bool)
* [trigger_output](#trigger_outputoutputname-string)
* [get_mesh](#get_mesh---arraymesh)
* [get_entity_shape](#get_entity_shape---shape)
* [get_entity_convex_shape](#get_entity_convex_shape---shape)
* [get_entity_trimesh_shape](#get_entity_trimesh_shape---shape)
* [get_entity_basis](#get_entity_basisentity-dictionary---basis-static)
* [get_movement_vector](#get_movement_vectorvec-vector3---vector3-static)
* [convert_vector](#convert_vectorv-vector3---vector3-static)
* [convert_direction](#convert_directionv-vector3---vector3-static)
* [define_alias (static)](#define_aliasname-string-value-valveionode-static)
* [get_target](#get_targettargetname-string---valveionode)
* [get_all_targets](#get_all_targetstargetname-string---valveionode)

### _entity_ready()
Means that all outputs and reparents are ready to use. Use this method instead of `_ready`.

### _apply_entity(entityData: Dictionary, vmfNode: VMFNode)
This method called by VMFNode during import entities and needs to make some setup for entities,
such as assigning brushes, generation collisions and so on.  

Don't forget to call `super._apply_entity` before making any changes in the node.

#### Example
```gdscript
func _apply_entity(entityInfo: Dictionary):
	super._apply_entity(entityInfo, vmfNode);

	# Getting a mesh from the solid data of the entity and assigning
	var mesh = get_mesh();
	$MeshInstance3D.set_mesh(mesh);

	# Generating a collision shape for the mesh
	$MeshInstance3D/StaticBody3D/CollisionShape3D.shape = mesh.create_convex_shape();

```

### has_flag(flag: int) -> bool
Checks the `spawnflags` field of the entity.

#### Example
```gdscript
const FLAG_STARTS_LOCKED = 2048;
var isLocked = false;

func _entity_ready():
	if has_flag(FLAG_STARTS_LOCKED):
		isLocked = true;
```

### trigger_output(outputName: string):
Triggers outputs that defined in the entity.

#### Example
```gdscript
interact.connect(func():
	if isLocked:
		trigger_output("OnUseLocked");
	else:
		trigger_output("OnPressed"));
```

### get_mesh() -> ArrayMesh
Returns entity's solids as ArrayMesh.

### get_entity_shape() -> Shape:
Returns optimized collision shape for the entity's solids (trimesh or convex. Depends of brushes count inside of entity). 
Uses CSGMesh for shape generation

### get_entity_convex_shape() -> Shape
Returns a convex shape for the entity's brushes

### get_entity_trimesh_shape() -> Shape
Returns optimized trimesh shape for the entity's brushes

### get_entity_basis(entity: Dictionary) -> Basis [static]
Returns rotation state for specified entity.

### get_movement_vector(vec: Vector3) -> Vector3 [static]
Returns directional vector from specified vector. If an entity has movement direction property (i.e. func_door, func_button) use this function to convert the direction.

### convert_vector(v: Vector3) -> Vector3 [static]
Converts Vector3 of position from Z-up to Y-up.

### convert_direction(v: Vector3) -> Vector3 [static]
Converts Vector3 of rotation from Z-up to Y-up.

### define_alias(name: string, value: ValveIONode) [static]
Defines global alias to node for using in I/O. 
#### Example
```gdscript
# player.gd

func _entity_ready():
	ValveIONode.define_alias('!player', self);
```

### get_target(targetName: string) -> ValveIONode
Returns first node by target name assigned in entity.

### get_all_targets(targetName: string) -> ValveIONode[]
Returns all nodes by target name assigned in entities.
