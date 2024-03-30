# Installation
Move the `addons/godotvmf` folder into the same folder of your project and activate it in your project settings.

## Config file
Before work with the plugin create in the root of the project a file `vmf.config.json`.

Default config:  
```json
{
	"gameInfoPath": "C:/Steam/steamapps/sourcemods/mymod",
	"mdl2obj": "res://mdl2obj/mdl2obj.exe",

	"import": {
		"scale": 0.025,
		"generateCollision": true,
		"instancesFolder": "res://examples/instances",
		"entitiesFolder": "res://examples/entities"
	},

	"models": {
		"import": true,
		"generateCollision": true,
		"targetFolder": "res://examples/models"
	},

	"material": {
		"importMode": 1,
		"ignore": [
			"TOOLS/*",
			"light/white",
            "*/water_*"
		],
		"fallbackMaterial": null,
		"defaultTextureSize": 512,
		"targetFolder": "res://examples/materials"
	}
}
```

- `gameInfoPath` - The source mod path where resources placed to work with hammer.
> One advice for game development by using Hammer. Create a blank mod for Source, place all resources you need (basically it will be models and materials) for your game and setup Hammer. Yea, you will need to convert all textures into VTF format to get it visible inside Hammer.

The blank mod folder you can download here: [Google Drive](https://drive.google.com/drive/folders/1Vitm-praILoZvS5oDnv6yxtsW7pLSBtq)

- `mdl2obj` - Path to [MDL2OBJ](/mdl2obj) utility. Used in case you need to move models from the mod's folder. Required in case of `models.import` is `true`.

- `import'
    - `scale` - In case you need to convert Valve's metrics to yours.
    - `generateCollision` - If `true` then generates `CollisionShape3D` for imported geometry (except brush entities) by using trimesh shape.
    - `instancesFolder` - Path inside the project where imported instances be placed.
    - `entitiesFolder` - Path inside the project where importer will grab entities during import.
- `models (optional)`
    - `import` - If `true` then importer will try to import models from the mod's folder.
    - `generateCollision` - If `true` then generates `CollisionShape3D` for imported geometry.
    - `targetFolder` - Path inside the project where imported models be placed.
- `material`
    - `importMode` - The mode of importing materials
        - 0 - Do nothing
        - 1 - Collate by name - Use materials that already exists in the project. Otherwise the fallback material will be used.
        - 2 - Import directly from mod folder. Already imported materials will be ignored.
    - `ignore` - List of materials that should be ignored during import.
    - `fallbackMaterial` - Path to the material *.tres that will be used as a fallback for ignored materials.
    - `defaultTextureSize` - The size of the texture that will be used in case of missing texture.
    - `targetFolder` - Path inside the project where imported materials be placed.


