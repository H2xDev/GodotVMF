
# GodotVMF
An importer of VMF files into Godot.

## Features
- Import geometry
- Entities support
- Hammer's I/O  system support
- Model import support*
- Material import support**
- Instances support

\* - Requires 3rd party utility MDL2OBJ (included in the repository)
\** - Requires 3rd party utility VTFLib.exe

## Docs
### Installation
Move the `addons/godotvmf` folder into the same folder of your project and activate it in your project settings.

### Config file
Before work with the plugin create in the root of the project a file `vmf.config.json`.
Default config:

    {
    	"gameInfoPath": "C:/Steam/steamapps/sourcemods/mymod",
    	"vtflib": "C:/Steam/steamapps/sourcemods/mymod/tools/vtflib",
    	"mdl2obj": "C:/Steam/steamapps/sourcemods/mymod/tools/mdl2obj",
    	"modelsFolder": "res://Assets/Models",
    	"materialsFolder": "res://Assets/Materials",
    	"instancesFolder": "res://Assets/Instances",
    	"entitiesFolder": "res://Assets/Entities",
    	"nodeConfig": {
    		"importScale": 0.025,
    		"defaultTextureSize": 512,
    		"generateCollision": true,
    		"fallbackMaterial": null,
    		"ignoreTextures": ['TOOLS/TOOLSNODRAW'],
    		"textureImportMode": 0,
    		"importModels": true,
    		"generateCollisionForModel": true,
    		"overrideModels": true,
    	},
    };
- `gameInfoPath` - The source mod path where resources placed to work with hammer.
> One advice for game development by using Hammer. Create a blank mod for Source, place all resources you need (basically it will be models and materials) for your game and setup Hammer. Yea, you will need to convert all textures into VTF format to get it visible inside Hammer.
- `vtflib` - Path to VTFLib tool. Used in case you need to copy textures from the mod's folder.
- `mdl2obj` - Path to MDL2OBJ utility. Used in case you need to move models from the mod's folder.
- `modelsFolder` - Path inside the project where copied models be placed.
- `materialsFolder` - Path inside the project where copied materials be placed.
- `instancesFolder` - Path inside the project where imported instances be placed.
- `entitiesFolder` - Path inside the project where importer will grab entities during import.
- `nodeConfig` - Global configuration of `VMFNode`
	- `importScale` - In case you need to convert Valve's metrics to yours.
	- `defaultTextureSize` - This value will be used in case a texture of some face wasn't found in the mod's folder. Texture size is used in calculation of brushes UV during import.
	- `generateCollision` - If `true` then generates `CollisionShape3D` for imported geometry (except brush entities) by using trimesh shape. 
	- `fallbackMaterial` - Path to a default material in the project folder. This material will be used in case the target material wasn't found.
	- `ignoreTextures` - Array of material names. Faces with these materials will be ignored during import.
	- `generateCollisionForModel` - If `true` then imported models will be with collision.
	- `overrideModels` - During import in case the model is already exists then it will be overridden.

### Importing a map
1. Create a scene and create a new node with class `VMFNode`. 
2. Click `import` in the inspector or click `Full` in the 3D scene view at the top tool bar.
3. Wait a while...
4. Done!
If you found that something going wrong, check the Output panel first. In some cases you can see in the Output panel messages tagged with `[Godot VMF]`. 

### Entities
You'll need to create your own entities for your game. If you want to use entities from Half-Life 2 then you should implement entities logic on your own.
All entities should be in `@tool` mode, extended from `ValveIONode` and placed in the folder that you assigned in the config (`entitiesFolder`).
1. Create script of an entity.
2. Create a 3d scene with the same name and assign the script.
3. Try to import your map with entity.

Example of an entity:
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

func Lock(_param = null):
	isLocked = true;

func Unlock(_paran = null):
	isLocked = false;

func _entity_ready():
	isLocked = have_flag(FLAG_STARTS_LOCKED);

	interact.connect(func ():

		if isLocked:
			if lockedSound:
				SoundManager.PlaySound(global_position, lockedSound, 0.05);
			trigger_output("OnUseLocked")
		else:
			if have_flag(FLAG_ONCE) and isUsed:
				return;

			if sound:
				SoundManager.PlaySound(global_position, sound, 0.05);
			trigger_output("OnPressed")
			isUsed = true);

	if "sound" in entity:
		sound = load("res://Assets/Sounds/" + entity.sound);

	if "locked_sound" in entity:
		lockedSound = load("res://Assets/Sounds/" + entity.locked_sound);


func _apply_entity(e, c):
	super._apply_entity(e, c);

	var mesh = get_mesh();
	$MeshInstance3D.set_mesh(mesh);
	$MeshInstance3D/StaticBody3D/CollisionShape3D.shape = mesh.create_convex_shape();
```
 

## Known issues
- Displacements are not supported
- Smoothing groups are not supported
- Extraction materials and models from VPKs
- Wasn't tested on Linux and MacOS
- Entities in instances importing not completely. You'll need to open the instance scene and reimport it.

