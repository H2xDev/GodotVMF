# meta-name: Brush Entity
# meta-description: Use this in case you need to define a Brush Entity
# meta-default: true
# meta-space-indent: 4

@tool
## @entity SolidClass
## @base Targetname, Origin
## Entity's description
class_name _CLASS_ extends VMFEntityNode

# Use @exposed tag to make them appear in the FGD file

## @exposed
var float_property: float = 1.0:
	get: return entity.get("float_property", 1.0);

## @exposed
## @type target_destination
var target_node: Node:
	get: return get_target(entity.get("target_node", ""));

## @exposed
## @type angles
var angles_property: Vector3 = Vector3.ZERO:
	get: return convert_direction(entity.get("angles_property", Vector3.ZERO));

## This will be identified as Output
signal OnSomeHappened();

## Use this method instead _ready
func _entity_ready() -> void:
	pass;


## This method is called during the import process
func _entity_setup(_e: VMFEntity) -> void:
	# Applying mesh and collision shape for this entity
	var mesh := MeshInstance3D.new();
	mesh.mesh = get_mesh();

	var collision := StaticBody3D.new();

	var collision_shape := CollisionShape3D.new();
	collision_shape.shape = get_entity_shape();

	add_child(collision);
	collision.add_child(collision_shape);
	collision.add_child(mesh);

	collision.set_owner(owner);
	collision_shape.set_owner(owner);
	mesh.set_owner(owner);

	collision.name = "collision";
	collision_shape.name = "shape";
	mesh.name = "mesh";

	## Do additional setup things here

## Inputs
func DoSomething(_void = null): pass;
