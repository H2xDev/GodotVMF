<p align="center">
<img src="https://github.com/user-attachments/assets/e1959708-fc5a-4245-aed4-5b7f3044aada" />
</p>

<h1 align="center"> GodotVMF </h1>

<p align="center">
<a href="https://discord.gg/wtSK94fPxd" target="_blank">
<img src="https://img.shields.io/badge/Discord-%235865F2.svg?style=for-the-badge&logo=discord&logoColor=white" alt="Discord"></a>

<a href="https://www.reddit.com/r/godot/comments/1ax4b7h/godotvmf_use_valve_hammer_editor_for_level/" target="_blank">
<img src="https://img.shields.io/badge/Reddit-FF4500?style=for-the-badge&logo=reddit&logoColor=white" alt="Reddit"></a>

<a href="https://godotengine.org/asset-library/asset/2605" target="_blank">
<img src="https://img.shields.io/badge/asset_library-%23EEEEEE.svg?style=for-the-badge&logo=godot-engine" alt="Godot Asset Library"></a>
</p>

An importer of VMF files into Godot.  
Useful instrument for people who used to work with Hammer and finds it most comfortable tool for level geometry creation.  
  
Highly recommend to use [Hammer++](https://ficool2.github.io/HammerPlusPlus-Website/) since it support precised vertex data that allows you use concave brushes.

<img src="https://github.com/user-attachments/assets/6e100e46-b4a9-4138-83d5-87a88bc8f2ad" width="100%" />


## Why?
We with my friend @Ambiabstract didn't found any comfortable solution of 3D level design for Godot so we decided to create our own :)

## Usage
- [Docs](https://github.com/H2xDev/GodotVMF/wiki/Installation)
- [Project Template](https://github.com/H2xDev/GodotVMF-Project-Template)
- [Import Source Games Maps](https://youtu.be/uTBzx0bwizU)

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
- Some of imported models may have wrong orientation

## Contribution
If you have some ideas, suggestions regarding to quality or solutions of the problems above, feel free to contribute!
- If you've added a new feature please add the relevant documentation.
- Follow the common godot codestyle (yea-yea i'll fix the existing code in upcoming updates)

### How to test
1. Install any of Source Engine Games (L4D, HL2, TF2)
2. Unpack all textures and models from VPKs
3. Decompile most complex maps
4. Try to import decompiled maps in Godot.
5. Check for errors if they appear.

## Additional things
- Source code of MDL2OBJ: https://github.com/H2xDev/mdl2obj
- Demo: https://www.youtube.com/watch?v=5XYfvbIAlJU

## Special thanks
[@Ambiabstract](https://github.com/Ambiabstract) - help and inspiration  
[@Lachrymogenic](https://github.com/Lachrymogenic) - test on linux and performance test  
[@SharkPetro](https://github.com/SharkPetro) - materials test  
|<img src="assets/showcase3.jpg" alt="Project Brutalist" width="100%"/>|<img src="assets/showcase1.jpg" alt="Left 4 Dead" width="100%%"/>|

## License
MIT
