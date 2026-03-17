class_name VTFFrameReader extends RefCounted


## Base class for reading frames from a VTF file. Each image format should have its own implementation of this class.
static func read(vtf: VTFLoader, frame: int, srgb_conversion_method: VTFLoader.SRGBConversionMethod) -> ImageTexture:
	return null;
