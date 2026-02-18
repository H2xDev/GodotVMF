class_name VTFRGBA extends VTFFrameReader

static func read(vtf: VTFLoader, frame: int, srgb_conversion_method: VTFLoader.SRGBConversionMethod) -> ImageTexture:
	var data := PackedByteArray(); 
	var bytes_read := 0;
	var use_mipmaps := not (vtf.flags & vtf.Flags.TEXTUREFLAGS_NOMIP);
	var is_abgr := vtf.hires_image_format == vtf.ImageFormat.ABGR8888 || vtf.hires_image_format == vtf.ImageFormat.BGR888;
	var is_no_alpha := vtf.hires_image_format >= vtf.ImageFormat.RGB888;
	var channels_count := 3 if is_no_alpha else 4;
	var output_format := Image.FORMAT_RGB8 if is_no_alpha else Image.FORMAT_RGBA8;


	frame = vtf.frames - 1 - frame;

	for i in range(vtf.mipmap_count):
		var mip_width = max(1, vtf.width >> i);
		var mip_height = max(1, vtf.height >> i);
		var mip_size = mip_width * mip_height * channels_count; # RGBA8888 has 4 bytes per pixel

		vtf.file.seek(vtf.file.get_length() - bytes_read - mip_size - mip_size * frame);
		var chunk := vtf.file.get_buffer(mip_size);

		if is_abgr: chunk.reverse();

		data += chunk;
		bytes_read += mip_size + mip_size * (vtf.frames - 1);

	var img := Image.create_from_data(vtf.width, vtf.height, use_mipmaps, output_format, data);

	if is_abgr:
		img.flip_x();
		img.flip_y();

	if not img: return null;

	return ImageTexture.create_from_image(img);
