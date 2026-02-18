class_name VTFDXT extends VTFFrameReader

static func read(vtf: VTFLoader, frame: int, srgb_conversion_method: VTFLoader.SRGBConversionMethod) -> ImageTexture:
	var data = PackedByteArray();
	var bytes_read := 0;
	var is_dxt_1 := vtf.hires_image_format == vtf.ImageFormat.DXT1;
	var multiplier = 8 if is_dxt_1 else 16;
	var format := vtf.format_map[str(vtf.hires_image_format)] as Image.Format;
	var use_mipmaps := not (vtf.flags & vtf.Flags.TEXTUREFLAGS_NOMIP);

	frame = vtf.frames - 1 - frame;

	for i in range(vtf.mipmap_count):
		var mipWidth = max(1, vtf.width >> i);
		var mipHeight = max(1, vtf.height >> i);

		var mip_size = max(1, mipWidth / 4) * max(1, mipHeight / 4) * multiplier;

		vtf.file.seek(vtf.file.get_length() - bytes_read - mip_size - mip_size * frame);
		data += vtf.file.get_buffer(mip_size);

		bytes_read += mip_size + mip_size * (vtf.frames - 1);

	var img := Image.create_from_data(vtf.width, vtf.height, use_mipmaps, format, data);
	if not img: return null;
	
	if srgb_conversion_method == vtf.SRGBConversionMethod.DURING_IMPORT:
		img.decompress();
		img.compress(Image.COMPRESS_S3TC);

	vtf.alpha = vtf.flags & vtf.Flags.TEXTUREFLAGS_ONEBITALPHA or vtf.flags & vtf.Flags.TEXTUREFLAGS_EIGHTBITALPHA;

	return ImageTexture.create_from_image(img);
