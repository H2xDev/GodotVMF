class_name PHYReader extends RefCounted

class PHYHeader:
	static var scheme:
		get: return {
		size 											= ByteReader.Type.INT,
		id 												= ByteReader.Type.INT,
		solid_count 									= ByteReader.Type.INT,
		checksum 										= ByteReader.Type.INT,
	};

	var size: int;
	var id: int;
	var solid_count: int;
	var checksum: int;

	var address: int = 0;

	func _to_string():
		return ByteReader.get_structure_string("PHYHeader", self);

class PHYSurfaceHeader:
	static var scheme:
		get: return {
		size 											= ByteReader.Type.INT,
		id 												= [ByteReader.Type.STRING, 4],
		version 										= ByteReader.Type.SHORT,
		model_type 										= ByteReader.Type.SHORT,
		surface_size 									= ByteReader.Type.INT,
		drag_axis_areas 								= ByteReader.Type.VECTOR3,
		axis_map_size 									= ByteReader.Type.INT,
		unused1 										= [ByteReader.Type.INT, 11],
		ivps 											= [ByteReader.Type.STRING, 4],
	};	

	var size: int;
	var id: String;
	var version: int;
	var surface_size: int;
	var model_type: int;
	var drag_axis_areas: Vector3;
	var axis_map_size: int;
	var unused1: Array[int] = [];
	var ivps: String;

	var solids: Array[PHYSolidHeader] = [];
	var vertices: Array[Vector3] = [];

	var address = 0;

	func _to_string():
		return ByteReader.get_structure_string("PHYSurfaceHeader", self);

class PHYLegacySurfaceHeader:
	static var scheme:
		get: return {
		mass_center 									= ByteReader.Type.VECTOR3,
		rotation_inertia 								= ByteReader.Type.VECTOR3,
		upper_limit_radius 								= ByteReader.Type.FLOAT,
		max_deviation 									= ByteReader.Type.INT,
		byte_size 										= ByteReader.Type.INT,
		dummy 											= [ByteReader.Type.INT, 2],
		ivps 											= [ByteReader.Type.STRING, 4],
	};

	var mass_center: Vector3;
	var rotation_inertia: Vector3;
	var upper_limit_radius: float;
	var max_deviation: int;
	var byte_size: int;
	var offset_ledgetree_root: int;
	var dummy: Array[int] = [];
	var ivps: String;

	var address = 0;

	func _to_string():
		return ByteReader.get_structure_string("PHYLegacySurfaceHeader", self);

class PHYSolidHeader:
	static var scheme:
		get: return {
		vertices_offset 								= ByteReader.Type.INT,
		bone_index 										= ByteReader.Type.INT,
		flags 											= ByteReader.Type.INT,
		face_count 										= ByteReader.Type.INT,
	};

	var vertices_offset: int;
	var flags: int;
	var bone_index: int;
	var face_count: int;
	var unused1: int;
	var unused2: int;
	var unused3: int;

	var faces: Array[PHYTriangleData] = [];

	var address = 0;

	func _to_string():
		return ByteReader.get_structure_string("PHYSolidHeader", self);

class PHYTriangleData:
	static var scheme:
		get: return {
		vertex_index 									= ByteReader.Type.BYTE,
		unused1 										= ByteReader.Type.BYTE,
		unused2 										= ByteReader.Type.UNSIGNED_SHORT,
		v1 												= ByteReader.Type.SHORT,
		unused3 										= ByteReader.Type.SHORT,
		v2 												= ByteReader.Type.SHORT,
		unused4 										= ByteReader.Type.SHORT,
		v3 												= ByteReader.Type.SHORT,
		unused5 										= ByteReader.Type.SHORT,
	};

	var vertex_index: int;
	var v1: int;
	var v2: int;
	var v3: int;

	var unused1: int;
	var unused2: int;
	var unused3: int;
	var unused4: int;
	var unused5: int;

	var address = 0;

	func _to_string():
		return ByteReader.get_structure_string("PHYFaceData", self);


var header: PHYHeader;
var surfaces: Array[PHYSurfaceHeader] = [];
var legacy_surfaces: Array[PHYLegacySurfaceHeader] = [];

func _init(source_file: String):
	var file = FileAccess.open(source_file, FileAccess.READ);
	if file == null: return;

	header = ByteReader.read_by_structure(file, PHYHeader);

	var vertices_start = INF;

	for i in range(header.solid_count):
		var surface_header = ByteReader.read_by_structure(file, PHYSurfaceHeader);
		surfaces.append(surface_header);

		if surface_header.id != "VPHY":
			file.seek(surface_header.address);

			var legacy_surface_header = ByteReader.read_by_structure(file, PHYLegacySurfaceHeader);
			legacy_surfaces.append(legacy_surface_header);

		var vertices_count = 0;

		while file.get_position() < vertices_start:
			var solid_header = ByteReader.read_by_structure(file, PHYSolidHeader) as PHYSolidHeader;
			vertices_start = min(solid_header.address + solid_header.vertices_offset, vertices_start);

			surface_header.solids.append(solid_header);
	
			for j in range(solid_header.face_count):
				var triangle_data = ByteReader.read_by_structure(file, PHYTriangleData) as PHYTriangleData;
				solid_header.faces.append(triangle_data);

				vertices_count = max(vertices_count, triangle_data.v1, triangle_data.v2, triangle_data.v3);

		for j in range(vertices_count + 1):
			var vertex = ByteReader._read_data(file, ByteReader.Type.VECTOR3);
			var w = ByteReader._read_data(file, ByteReader.Type.FLOAT);

			# NOTE: For some reason all collision solids are converted from inch to m. Converting them back to inch
			vertex = Vector3(vertex.x, vertex.z, -vertex.y) / 0.0254;

			surface_header.vertices.append(vertex);

		vertices_start = INF;

		# NOTE: +4 means that size of header starts after the size byte
		file.seek((surface_header.address + 4) + surface_header.size);

