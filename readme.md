# GodotVMF
![Hero](assets/hero.jpg)
**THIS PROJECT STILL IN ACTIVE DEVELOPMENT THERE MIGHT BE BUGS**  
  
An importer of VMF files into Godot.  
Useful instrument for people who used to work with Hammer and finds it most comfortable tool for level geometry creation.  
  
Highly recommend to use [Hammer++](https://ficool2.github.io/HammerPlusPlus-Website/) since it support precised vertex data that allows you use concave brushes.

![Example](assets/example.jpg)

## Why?
We with my friend @Ambiabstract didn't found any comfortable solution of 3D level design for Godot so we decided to create our own :)

## Usage
- [Docs](docs/readme.md)

## Features
- Import geometry (Also with smoothing groups)
- Entities support
- Hammer's I/O  system support
- Model import support
  - Requires 3rd party utility [MDL2OBJ](/mdl2obj) (included in the repository)  
- Material import support
- Instances support
- Displacements with vertex alpha
    - WorldVertexTransition materials (blend textures) will be imported as [`WorldVertexTransitionMaterial`](/addons/godotvmf/shaders/WorldVertexTransitionMaterial.gd)
- Native VTF import
  - Supported VTF formats: DXT1, DXT3, DXT5

## Known issues
- Extraction materials and models from VPKs is not supported
- Entities in instances importing not completely. You'll need to open the instance scene and reimport it.
- Wasn't tested on MacOS
- Some of imported models may have wrong orientation

## GodotVMF elsewhere
* [Reddit](https://www.reddit.com/r/godot/comments/1ax4b7h/godotvmf_use_valve_hammer_editor_for_level/)
* [Asset Library](https://godotengine.org/asset-library/asset/2605)
* [Discord](https://discord.gg/zpytJVvuHm)

## Contribution
If you have some ideas, suggestions regarding to quality or solutions of the problems above, feel free to contribute!

## Additional things
- Source code of MDL2OBJ: https://github.com/H2xDev/mdl2obj
- Demo: https://www.youtube.com/watch?v=5XYfvbIAlJU

## Special thanks
[@Ambiabstract](https://github.com/Ambiabstract) - help and inspiration  
[@Lachrymogenic](https://github.com/Lachrymogenic) - test on linux and performance test  
[@SharkPetro](https://github.com/SharkPetro) - materials test  

## Showcase
|<img src="assets/showcase4.jpg" alt="Project Brutalist" width="100%"/>|<img src="assets/showcase2.jpg" alt="Half-Life 2" width="100%"/>|
|-|-|
|<img src="assets/showcase3.jpg" alt="Project Brutalist" width="100%"/>|<img src="assets/showcase1.jpg" alt="Left 4 Dead" width="100%%"/>|

## License
MIT
