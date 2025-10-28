class_name VMFMaterialConversionContextMenu extends EditorContextMenuPlugin

func is_resource(p: String) -> bool: 
	return p.ends_with(".tres");

func _popup_menu(paths: PackedStringArray):
	var has_resources = Array(paths).filter(is_resource).size() > 0;
	if not has_resources: return;

	add_context_menu_item("Convert to VMT", convert_resource_to_vmt);

func convert_resource_to_vmt(paths: PackedStringArray):
	var resources := Array(paths).filter(is_resource);

	for res_file in resources:
		var resource = load(res_file);
		if not resource: continue;
		if resource is not BaseMaterial3D: 
			VMFLogger.warn("Resource is not a BaseMaterial3D: " + res_file);
			continue;

		create_vmt_file(resource);
	
	EditorInterface.get_resource_filesystem().scan();

func create_vmt_file(material: BaseMaterial3D):
	var base_texture := material.albedo_texture;
	var vmt_path := material.resource_path.replace(".tres", ".vmt");
	var vtf_path := base_texture.resource_path.get_basename() + ".vtf" if base_texture else "";

	if ResourceLoader.exists(vmt_path):
		VMFLogger.warn("VMT file already exists, skipping: " + vmt_path);
		return;

	var base_texture_path := vtf_path.replace(VMFConfig.materials.target_folder, "").replace(".vtf", "");

	if base_texture_path.begins_with("/"):
		base_texture_path = base_texture_path.substr(1, base_texture_path.length());

	var vmt_string := ("\"LightmappedGeneric\" {\n"\
		+ "\t\"$basetexture\" \"%s\" \n" \
		+ "}") % base_texture_path;

	var file := FileAccess.open(vmt_path, FileAccess.WRITE);
	file.store_string(vmt_string);
	file.close();

	if ResourceLoader.exists(vtf_path):
		VMFLogger.warn("VTF file already exists, skipping: " + vtf_path);
		return;

	var bytes = generate_vtf_file(base_texture);
	var vtf_file = FileAccess.open(vtf_path, FileAccess.WRITE);
	vtf_file.store_buffer(bytes);
	vtf_file.close();

func error_when(condition: bool, message: String) -> bool:
	if condition:
		VMFLogger.error(message);
	return condition;

func int_to_int32(value: int) -> PackedByteArray:
	var bytes := PackedByteArray();
	bytes.append(value & 0xFF);
	bytes.append((value >> 8) & 0xFF);
	bytes.append((value >> 16) & 0xFF);
	bytes.append((value >> 24) & 0xFF);
	return bytes;

func int_to_short(value: int) -> PackedByteArray:
	var bytes := PackedByteArray();
	bytes.append(value & 0xFF);
	bytes.append((value >> 8) & 0xFF);
	return bytes;

func int_to_byte(value: int) -> PackedByteArray:
	var bytes := PackedByteArray();
	bytes.append(value & 0xFF);
	return bytes;

func float_to_bytes(value: float) -> PackedByteArray:
	var bytes := PackedByteArray();
	var int_value := int(value);
	bytes.append(int_value & 0xFF);
	bytes.append((int_value >> 8) & 0xFF);
	bytes.append((int_value >> 16) & 0xFF);
	bytes.append((int_value >> 24) & 0xFF);
	return bytes;

func generate_vtf_file(texture: Texture2D) -> PackedByteArray:
	var image := texture.get_image().duplicate() as Image;
	var aspect_ratio := float(image.get_width()) / float(image.get_height());
	var bytes := PackedByteArray();

	var is_dxt: bool = image.get_format() == Image.FORMAT_DXT1 or image.get_format() == Image.FORMAT_DXT5 or image.get_format() == Image.FORMAT_DXT3;

	if not is_dxt:
		image.decompress();
		image.compress(Image.COMPRESS_S3TC);
		image.convert(Image.FORMAT_DXT5);

	image.clear_mipmaps();

	bytes += "VTF".to_utf8_buffer(); # signature
	bytes.append(0);

	bytes += int_to_int32(7); # version major
	bytes += int_to_int32(1); # version minor
	bytes += int_to_int32(64); # header size for version 7.1

	bytes += int_to_short(image.get_width()); # width
	bytes += int_to_short(image.get_height()); # height

	bytes += int_to_int32(VTFLoader.Flags.TEXTUREFLAGS_SRGB | VTFLoader.Flags.TEXTUREFLAGS_NOMIP);
	bytes += int_to_short(1); # frames
	bytes += int_to_short(0); # first frame
	bytes += PackedByteArray([0, 0, 0, 0]); # padding

	bytes += float_to_bytes(0.0); # reflectivity x
	bytes += float_to_bytes(0.0); # reflectivity y
	bytes += float_to_bytes(0.0); # reflectivity z

	bytes += PackedByteArray([0, 0, 0, 0]); # padding
	bytes += float_to_bytes(1.0); # bump scale

	var format = 13 if image.get_format() == Image.FORMAT_DXT1 \
		else 14 if image.get_format() == Image.FORMAT_DXT3 \
		else 15;

	bytes += int_to_int32(format); # high res image format
	bytes += int_to_byte(1) # mipmap count
	bytes += int_to_int32(13) # low res image format
	bytes += PackedByteArray([0]); # padding

	var lowres_image := image.duplicate() as Image;
	var lowres_width := 16;
	var lowres_height := int(16 / aspect_ratio);

	lowres_image.decompress();
	lowres_image.resize(lowres_width, lowres_height, Image.INTERPOLATE_BILINEAR);
	lowres_image.compress(Image.COMPRESS_S3TC);

	if lowres_image.get_format() != Image.FORMAT_DXT1:
		lowres_image.convert(Image.FORMAT_DXT1);

	bytes += int_to_byte(lowres_width); # low res image width
	bytes += int_to_byte(lowres_height); # low res image height

	bytes += lowres_image.get_data(); # low res image data
	bytes += image.get_data()

	return bytes;
