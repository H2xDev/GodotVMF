<p align="center">
<img src="https://github.com/user-attachments/assets/e1959708-fc5a-4245-aed4-5b7f3044aada" width="10%" />
</p>

<h2 align="center"> GodotVMF </h2>

<p align="center">
<a href="https://discord.gg/wtSK94fPxd" target="_blank">
<img src="https://img.shields.io/badge/Get%20Support%20in%20Discord-%235865F2?style=for-the-badge&logo=discord&logoColor=white&text=get-support" alt="Discord"></a>

<a href="https://godotengine.org/asset-library/asset/2605" target="_blank">
<img src="https://img.shields.io/badge/asset_library-%23EEEEEE.svg?style=for-the-badge&logo=godot-engine" alt="Godot Asset Library"></a>

<a href="https://store-beta.godotengine.org/asset/h2xdev/godotvmf" target="_blank">
<img src="https://img.shields.io/badge/asset_store-%23333333.svg?style=for-the-badge&logo=godot-engine&logoColor=%23ffffff" alt="Godot Asset Store"></a>
</p>

## Description
An importer of [VMF files](https://developer.valvesoftware.com/wiki/VMF_(Valve_Map_Format)) into [Godot Engine](https://godotengine.org/) or [Redot Engine](https://redotengine.org/).  

Highly recommended to use [Hammer++](https://ficool2.github.io/HammerPlusPlus-Website/) since it supports precised vertex data.

<img src="https://github.com/user-attachments/assets/21084c3e-3530-45e5-8e05-d669d2a3ecf1" width="100%" />

## Why?
We with my friend [Ambiabstract](https://github.com/Ambiabstract) did not find a convenient plugin for us to create levels for Godot and so we decided to use our favorite and familiar editor :)

A useful tool for those who like making levels in Hammer and are making a project on the Godot.
Or for those who just want to port their map from Source Engine to Godot and see what happens.

## Installation and Usage
- [Installation Guide](https://github.com/H2xDev/GodotVMF/wiki/Installation-guide)
- [Documentation](https://github.com/H2xDev/GodotVMF/wiki)

## Video demonstration
[![Click to open Youtube video](https://github.com/user-attachments/assets/d9b421e6-69c0-499e-8ccf-0390ddb1f548)](https://www.youtube.com/watch?v=5XYfvbIAlJU)

## Features
- Brushes geometry import (including UVs, materials IDs and smoothing groups)
- Instances support
- Native MDL support
- Native VMT support
- Native VTF support (only DXT1, DXT3, DXT5 supported)
- Displacements import (with vertex data)
	- WorldVertexTransition materials (blend textures) will be imported as [`WorldVertexTransitionMaterial`](/addons/godotvmf/shaders/WorldVertexTransitionMaterial.gd)
- Entities support
- Hammer's Input/Output  system support
- Automatically generates SteamAudioGeometry in case [godot-steam-audio](https://github.com/stechyo/godot-steam-audio) plugin detected
- Surface props support
- Material's compile properties support
- FGD generator that compiles a FGD file based on source code of implemented entities in GDScript (see [here](https://github.com/H2xDev/GodotVMF/wiki/FGD-Generation))

## Made with this tool
- [Echo Point](https://www.youtube.com/watch?v=z7LcKb0XRzY) by Lazy
- [Vampire Bloodlines map example](https://www.youtube.com/watch?v=dV3nllCZYNM)  by Rendara
- [SurfsUp](https://store.steampowered.com/app/3454830/SurfsUp) by [@bearlikelion](https://github.com/bearlikelion)

## Known issues
- Extraction of materials and models from VPKs is not supported
- Some of imported models may have wrong orientation
    - Use `Additional Rotation` property in the MDL import options
- Avoid importing a big bunch of models/materials at once it may cause the engine crash or import freeze. There's some issues with threaded import in the engine.

## Legality of use
If you are going to use Hammer Editor for commercial purpose it's worth to asking Valve for permission to use their tool. There shouldn't be any problems if you are using this tool for non-commercial projects.

## Contribution
If you have some ideas, suggestions regarding to quality or solutions of the problems above, feel free to contribute!
- If you've added a new feature please add the relevant documentation.
- Follow the common Godot codestyle (yea-yea i'll fix the existing code in upcoming updates).

### How to test the addon after adding new features or fixing some bugs
1. Install any of Source Engine Games (L4D, HL2, TF2)
2. Unpack all textures and models from VPKs
3. Decompile most complex maps
4. Try to import decompiled maps in Godot
5. Check for errors if they appear


## Credits
[H2xDev](https://github.com/H2xDev) - main contributor  
[Ambiabstract](https://github.com/Ambiabstract) - tech help and inspiration  
[MyCbEH](https://github.com/MyCbEH) - level design for [example project](https://github.com/H2xDev/GodotVMF-Project-Template), UAZ model  
[Lachrymogenic](https://github.com/Lachrymogenic) - Linux test, performance test  
[SharkPetro](https://github.com/SharkPetro) - materials test  

## License
MIT
