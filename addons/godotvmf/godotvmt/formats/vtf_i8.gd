class_name VTFI8 extends VTFFrameReader

static func read(vtf: VTFLoader, frame: int, srgb_conversion_method: VTFLoader.SRGBConversionMethod) -> ImageTexture:
	var data := PackedByteArray(); 
	var bytes_read := 0;
	var use_mipmaps := not (vtf.flags & vtf.Flags.TEXTUREFLAGS_NOMIP);
	var multiplier := 1 if vtf.hires_image_format == vtf.ImageFormat.I8 else 2;
	var output_format := Image.FORMAT_L8 if vtf.hires_image_format == vtf.ImageFormat.I8 else Image.FORMAT_LA8;
	
	frame = vtf.frames - 1 - frame;

	for i in range(vtf.mipmap_count):
		var mip_width = max(1, vtf.width >> i);
		var mip_height = max(1, vtf.height >> i);
		var mip_size = mip_width * mip_height * multiplier; # I8 has 1 byte per pixel

		vtf.file.seek(vtf.file.get_length() - bytes_read - mip_size - mip_size * frame);
		var chunk := vtf.file.get_buffer(mip_size);

		data += chunk;
		bytes_read += mip_size + mip_size * (vtf.frames - 1);

	var img := Image.create_from_data(vtf.width, vtf.height, use_mipmaps, output_format, data);

	if not img: return null;

	return ImageTexture.create_from_image(img);
