class_name VMFGeometryCorrector extends RefCounted

const SHADOW_MESH_KEYS = [
	'compilenodraw',
]

const NO_COLLISION_KEYS = [
	'compilesky',
	'compilenonsolid'
]

const NO_RENDER_KEYS = [
	'compileclip',
	'compilenodraw',
	'compilesky',
	'npcclip',
	'compileplayerclip',
	'compilenpcclip',
]

func _get_norender_keys(): return NO_RENDER_KEYS;
func _get_nocollision_keys(): return NO_COLLISION_KEYS;
func _get_shadowmesh_keys(): return SHADOW_MESH_KEYS;

func compileplayerclip(solid: StaticBody3D):
	solid.collision_layer = 1 << 1
	solid.collision_mask = 1 << 1

func compilenpcclip(solid: StaticBody3D):
	solid.collision_layer = 1 << 2
	solid.collision_mask = 1 << 2
