class_name VMFGeometryCorrector extends RefCounted

const norender = [
	'compileclip',
	'compilenodraw',
	'compilesky',
	'npcclip',
	'compileplayerclip',
	'compilenpcclip',
];

const nocollision = [
	'compilesky',
];

func compileplayerclip(solid: StaticBody3D):
	solid.collision_layer = 1 << 1
	solid.collision_mask = 1 << 1

func compilenpcclip(solid: StaticBody3D):
	solid.collision_layer = 1 << 2
	solid.collision_mask = 1 << 2
