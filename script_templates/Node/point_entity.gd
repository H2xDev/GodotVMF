# meta-name: Point Entity
# meta-description: Use this in case you need to define a Point Entity
# meta-default: true
# meta-space-indent: 4

@tool
## @entity PointClass
## @base Targetname, Origin, Angles
## @appearance iconsprite('editor/obsolete.vmt')
## Entity's description
class_name _CLASS_ extends ValveIONode

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

## Entity setup method
func _apply_entity(entity: Dictionary) -> void:
	super._apply_entity(entity);

	## Do setup things here

## Inputs
func DoSomething(_void = null): pass;
