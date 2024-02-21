# GodotVMF
**THIS PROJECT STILL IN ACTIVE DEVELOPMENT THERE MIGHT BE BUGS**  
  
An importer of VMF files into Godot.  
Useful instrument for people who used to work with Hammer and finds it most comfortable tool for level geometry creation.  
  
For now this importer supports only the [Hammer++](https://ficool2.github.io/HammerPlusPlus-Website/) VMF format.

![Example](assets/example.jpg)

## Why?
We with my friend @Ambiabstract didn't found any comfortable solution of 3D level design for Godot so we decided to create our own :)

## Usage
- [Docs](docs/readme.md)

## Features
- Import geometry
- Entities support
- Hammer's I/O  system support
- Model import support*
- Material import support**
- Instances support

\* - Requires 3rd party utility [MDL2OBJ](/mdl2obj) (included in the repository)  
\** - Requires 3rd party utility [VTFLib](https://nemstools.github.io/subpages/Comments/VTFLib_v1.3.2_Full.html)

## Known issues
- Displacements are not supported
- Smoothing groups are not supported
- Extraction materials and models from VPKs is not supported
- Entities in instances importing not completely. You'll need to open the instance scene and reimport it.
- There might be some problems with materials with displacement map that requires some texture manipulation in Hammer (usually rotate texture by 90 degrees solves the problem)
- Wasn't tested on Linux and MacOS
- Tested only on 4.1+
- Supports only Hammer++ VMFs

## Contribution
If you have some ideas, suggestions regarding to quality or solutions of the problems above, feel free to contribute!

## Special thanks
[@Ambiabstract](https://github.com/Ambiabstract) - for help and inspiration

## License
MIT
