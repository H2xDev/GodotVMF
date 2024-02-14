# Installation
Move the `addons/godotvmf` folder into the same folder of your project and activate it in your project settings.

## Config file
Before work with the plugin create in the root of the project a file `vmf.config.json`.  
Default config:  
```json
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
		"ignoreTextures": ["TOOLS/TOOLSNODRAW"],
		"textureImportMode": 0,
		"importModels": false,
		"generateCollisionForModel": true,
		"overrideModels": true
	}
}
```

- `gameInfoPath` - The source mod path where resources placed to work with hammer.
> One advice for game development by using Hammer. Create a blank mod for Source, place all resources you need (basically it will be models and materials) for your game and setup Hammer. Yea, you will need to convert all textures into VTF format to get it visible inside Hammer.
- `vtflib` - Path to [VTFLib](https://nemstools.github.io/pages/VTFLib-Download.html) tool. Used in case you need to copy textures from the mod's folder.
- `mdl2obj` - Path to [MDL2OBJ](/mdl2obj) utility. Used in case you need to move models from the mod's folder.
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
    - `importModels` - If `true`, the importer will try to import all models with materials into the project
	- `overrideModels` - During import in case the model is already exists then it will be overridden.
    - `textureImportMode` - The mode of importing materials
    - - 0 - Do nothing
    - - 1 - Collate by name - Importer looking into the project's materials and trying to find material by name
    - - 2 - Import directly from mod folder. Already imported materials will be ignored
