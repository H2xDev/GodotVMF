<p align="center">
<img src="https://github.com/user-attachments/assets/e1959708-fc5a-4245-aed4-5b7f3044aada" width="10%" />
</p>

<h2 align="center"> GodotVMF </h2>

<p align="center">
<a href="https://discord.gg/wtSK94fPxd" target="_blank">
<img src="https://img.shields.io/badge/Get%20Support%20in%20Discord-%235865F2?style=for-the-badge&logo=discord&logoColor=white&text=get-support" alt="Discord"></a>

<a href="https://www.reddit.com/r/godot/comments/1ax4b7h/godotvmf_use_valve_hammer_editor_for_level/" target="_blank">
<img src="https://img.shields.io/badge/Reddit-FF4500?style=for-the-badge&logo=reddit&logoColor=white" alt="Reddit"></a>

<a href="https://godotengine.org/asset-library/asset/2605" target="_blank">
<img src="https://img.shields.io/badge/asset_library-%23EEEEEE.svg?style=for-the-badge&logo=godot-engine" alt="Godot Asset Library"></a>
</p>

## Description
An importer of [VMF files](https://developer.valvesoftware.com/wiki/VMF_(Valve_Map_Format)) into [Godot Engine](https://godotengine.org/).  

Highly recommended to use [Hammer++](https://ficool2.github.io/HammerPlusPlus-Website/) since it supports precised vertex data.

<img src="https://github.com/user-attachments/assets/21084c3e-3530-45e5-8e05-d669d2a3ecf1" width="100%" />

## Why?
We with my friend [Ambiabstract](https://github.com/Ambiabstract) did not find a convenient plugin for us to create levels for Godot and so we decided to use our favorite and familiar editor :)

A useful tool for those who like making levels in Hammer and are making a project on the Godot.
Or for those who just want to port their map from Source Engine to Godot and see what happens.

## Usage
- [Installation instruction and other documents](https://github.com/H2xDev/GodotVMF/wiki)
- [Project Template](https://github.com/H2xDev/GodotVMF-Project-Template) (example project)
- [How to import VMF (video tutorial)](https://youtu.be/uTBzx0bwizU)

## Features
- Brushes geometry import (including UVs, materials IDs and smoothing groups)
- Instances support
- Models import (requires 3rd party utility [MDL2OBJ](/mdl2obj), included in the repository)
- Materials import
- Displacements import (with vertex data)
	- WorldVertexTransition materials (blend textures) will be imported as [`WorldVertexTransitionMaterial`](/addons/godotvmf/shaders/WorldVertexTransitionMaterial.gd)
- Entities support
- Hammer's Input/Output  system support
- Native VTF import (supported VTF formats: DXT1, DXT3, DXT5)

## Known issues
- Extraction of materials and models from VPKs is not supported
- Some of imported models may have wrong orientation
- New MDLs (from CS:GO an so on) is not supported

## Contribution
If you have some ideas, suggestions regarding to quality or solutions of the problems above, feel free to contribute!
- If you've added a new feature please add the relevant documentation.
- Follow the common Godot codestyle (yea-yea i'll fix the existing code in upcoming updates).

### How to take part in testing
1. Install any of Source Engine Games (L4D, HL2, TF2)
2. Unpack all textures and models from VPKs
3. Decompile most complex maps
4. Try to import decompiled maps in Godot
5. Check for errors if they appear

## Additional things
- Source code of MDL2OBJ: https://github.com/H2xDev/mdl2obj
- Demo (video): https://www.youtube.com/watch?v=5XYfvbIAlJU

## Credits
[H2xDev](https://github.com/H2xDev) - main contributor  
[Ambiabstract](https://github.com/Ambiabstract) - tech help and inspiration  
[MyCbEH](https://github.com/MyCbEH) - level design for [example project](https://github.com/H2xDev/GodotVMF-Project-Template)  
[Lachrymogenic](https://github.com/Lachrymogenic) - Linux test, performance test  
[SharkPetro](https://github.com/SharkPetro) - materials test  

## License
MIT
