class_name VMFTool

static var vertex_cache: Array = [];
static var intersections: Dictionary = {};

## Credit: https://github.com/Dylancyclone/VMF2OBJ/blob/master/src/main/java/com/lathrum/VMF2OBJ/dataStructure/VectorSorter.java;
class VectorSorter:
	var normal: Vector3;
	var center: Vector3;
	var pp: Vector3;
	var qp: Vector3;

	func longer(a: Vector3, b: Vector3) -> Vector3:
		return a if a.length() > b.length() else b;

	func _init(normal, center) -> void:
		self.normal = normal;
		self.center = center;

		var i: Vector3 = normal.cross(Vector3(1, 0, 0));
		var j: Vector3 = normal.cross(Vector3(0, 1, 0));
		var k: Vector3 = normal.cross(Vector3(0, 0, 1));

		self.pp = longer(i, longer(j, k));
		self.qp = normal.cross(self.pp);

	func get_order(v: Vector3) -> float:
		var normalized: Vector3 = (v - self.center).normalized();
		return atan2(
			self.normal.dot(normalized.cross(self.pp)), 
			self.normal.dot(normalized.cross(self.qp))
		);

	func sort(a: Vector3, b: Vector3) -> bool:
		return get_order(a) < get_order(b);

static func get_similar_vertex(vertex: Vector3) -> Vector3:
	vertex_cache = vertex_cache if vertex_cache else [];

	for v: Vector3 in vertex_cache:
		if (v - vertex).length() < 0.1:
			return v;

	vertex_cache.append(vertex);
	return vertex;

static func clear_caches() -> void:
	vertex_cache = [];
	intersections = {};

static func get_planes_intersection_point(side, side2, side3) -> Variant:
	var d: Array[int] = [side.id, side2.id, side3.id];
	d.sort();

	var ihash := hash(d);
	var isIntersectionDefined: bool = ihash in intersections;

	if isIntersectionDefined:
		return intersections[ihash];
	else:
		var vertex: Variant = side.plane.value.intersect_3(side2.plane.value, side3.plane.value);
		intersections[ihash] = vertex;
		return vertex;

## Returns vertices_plus
static func calculate_vertices(side, brush) -> Array[Vector3]:
	var vertices: Array[Vector3] = [];
	var cache = {};

	if "vertices_plus" in side:
		vertices.assign(side.vertices_plus.v)
		return vertices;

	var is_vertice_exists = func(vector: Vector3):
		var hash_value: int = hash(Vector3i(vector));
		
		if hash_value in cache:
			return true;

		cache[hash_value] = 1;

		return false;

	for side2 in brush.side:
		if side2 == side:
			continue;

		for side3 in brush.side:
			if side2 == side3 or side3 == side:
				continue;

			var vertex := get_planes_intersection_point(side, side2, side3);
			if vertex == null:
				continue;

			if is_vertice_exists.call(vertex):
				continue;

			vertices.append(vertex as Vector3);

	vertices = vertices.filter(func(vertex):
		return not brush.side.any(func(s):
			return s.plane.value.distance_to(vertex) > 0.2;
		)
	);

	var size_normal: Vector3 = side.plane.value.normal.normalized();
	var vectorSorter: VectorSorter = VectorSorter.new(size_normal, side.plane.vecsum / 3);

	vertices.sort_custom(vectorSorter.sort);

	return vertices;

static func calculate_uv_for_size(side: Dictionary, vertex: Vector3) -> Vector2:
	var default_texture_size: int = VMFConfig.config.material.defaultTextureSize;

	var ux: float = side.uaxis.x;
	var uy: float = side.uaxis.y;
	var uz: float = side.uaxis.z;
	var ushift: float = side.uaxis.shift;
	var uscale: float = side.uaxis.scale;
	
	var vx: float = side.vaxis.x;
	var vy: float = side.vaxis.y;
	var vz: float = side.vaxis.z;
	var vshift: float = side.vaxis.shift;
	var vscale: float = side.vaxis.scale;

	var material = VTFTool.get_material(side.material);
	
	if not material:
		return Vector2(1, 1);

	# NOTE In case if material is blend texture we use texture_albedo param
	var texture = material.albedo_texture if material is StandardMaterial3D else material.get_shader_parameter('texture_albedo');

	var tsize: Vector2 = texture.get_size() if texture else Vector2(default_texture_size, default_texture_size);
	var tscale = material.get_meta("scale", Vector2(1, 1));

	var tsx: float = 1;
	var tsy: float = 1;
	var tw := tsize.x;
	var th := tsize.y;
	var aspect := tw / th;

	if material:
		tsx /= tscale.x;
		tsy /= tscale.y;

	var uv := Vector3(ux, uy, uz);
	var vv := Vector3(vx, vy, vz);
	var v2 := Vector3(vertex.x, vertex.y, vertex.z);

	var u := (v2.dot(uv) + ushift * uscale) / tw / uscale / tsx;
	var v := (v2.dot(vv) + vshift * vscale) / th / vscale / tsy;
	
	return Vector2(u, v);

## Returns MeshInstance3D from parsed VMF structure
static func create_mesh(vmf_structure: Dictionary, _offset: Vector3 = Vector3(0, 0, 0)) -> ArrayMesh:
	clear_caches();

	var _scale: float = VMFConfig.config.import.scale;
	var _default_texture_size: float = VMFConfig.config.material.defaultTextureSize;
	var _ignore_textures: Array[String];
	_ignore_textures.assign(VMFConfig.config.material.ignore);
	var _texture_import_mode: int = VMFConfig.config.material.importMode;

	var elapsed_time := Time.get_ticks_msec();

	if not "solid" in vmf_structure.world:
		return null;

	var brushes = vmf_structure.world.solid;
	var material_sides = {};
	var texture_cache = {};
	var mesh := ArrayMesh.new();

	for brush in brushes:
		for side in brush.side:
			var material: String = side.material.to_upper();
			var isIgnored = _ignore_textures.any(func(rx: String) -> bool: return material.match(rx));

			if isIgnored:
				continue;

			if not material in material_sides:
				material_sides[material] = [];

			material_sides[material].append({
				"side": side,
				"brush": brush,
			});

	for sides in material_sides.values():
		var sf := SurfaceTool.new();
		sf.begin(Mesh.PRIMITIVE_TRIANGLES);

		var index: int = 0;
		for side_data in sides:
			var side: Dictionary = side_data.side;
			var base_index := index;

			var is_displacement: bool = "dispinfo" in side;
			var vertices: Array[Vector3] = [];
			var disp_data: VMFDispTool = null;

			if not is_displacement and VMFDispTool.has_displacement(side_data.brush):
				continue;

			if not is_displacement:
				vertices.assign(calculate_vertices(side, side_data.brush));
			else:
				disp_data = VMFDispTool.new(side, side_data.brush);
				vertices.assign(disp_data.get_vertices());
				
			if vertices.size() < 3:
				VMFLogger.error("Side corrupted: " + str(side.id));
				continue;

			if not is_displacement:
				var normal = side.plane.value.normal;
				sf.set_normal(Vector3(normal.x, normal.z, -normal.y));
	
				for v: Vector3 in vertices:
					var vertex := get_similar_vertex(v);
					var uv: Vector2 = calculate_uv_for_size(side, vertex);
					sf.set_uv(uv);
	
					var vt := Vector3(vertex.x, vertex.z, -vertex.y) * _scale - _offset;
					var sg := -1 if side.smoothing_groups == 0 else int(side.smoothing_groups);
					
					sf.set_smooth_group(sg);
					sf.set_color(Color8(0, 0, 0));
					sf.add_vertex(vt);
					index += 1;

				for i: int in range(1, vertices.size() - 1):
					sf.add_index(base_index);
					sf.add_index(base_index + i);
					sf.add_index(base_index + i + 1);
			else:
				var edges_count = disp_data.edges_count;
				var verts_count = disp_data.verts_count;
				sf.set_smooth_group(1);

				for i: int in range(0, vertices.size()):
					var x := i / int(verts_count);
					var y := i % int(verts_count);
					var v = vertices[i];
					var normal = disp_data.get_normal(x, y);
					var dist = disp_data.get_distance(x, y);
					var offset = disp_data.get_offset(x, y);
					var uv := calculate_uv_for_size(side, v - dist - offset);

					sf.set_uv(uv);
					sf.set_color(disp_data.get_color(x, y));
					sf.set_normal(Vector3(normal.x, normal.z, -normal.y));
					sf.add_vertex(Vector3(v.x, v.z, -v.y) * _scale - _offset);
					index += 1;

				for i: int in range(0, pow(edges_count, 2)):
					var x := i / int(edges_count);
					var y := i % int(edges_count);
					var normal = disp_data.get_normal(x, y);
					var isOdd := (x + y) % 2 == 1;

					if isOdd:
						sf.add_index(base_index + x + 1 + y * verts_count);
						sf.add_index(base_index + x + (y + 1) * verts_count);
						sf.add_index(base_index + x + 1 + (y + 1) * verts_count);

						sf.add_index(base_index + x + y * verts_count);
						sf.add_index(base_index + x + (y + 1) * verts_count);
						sf.add_index(base_index + x + 1 + y * verts_count);
					else:
						sf.add_index(base_index + x + y * verts_count);
						sf.add_index(base_index + x + (y + 1) * verts_count);
						sf.add_index(base_index + x + 1 + (y + 1) * verts_count);

						sf.add_index(base_index + x + y * verts_count);
						sf.add_index(base_index + x + 1 + (y + 1) * verts_count);
						sf.add_index(base_index + x + 1 + y * verts_count);

		var ignore_materials: bool = VTFTool.TextureImportMode.DO_NOTHING == VMFConfig.config.material.importMode;

		if not ignore_materials:
			var material = VTFTool.get_material(sides[0].side.material);

			if material:
				sf.set_material(material);
				
		sf.optimize_indices_for_cache();
		sf.generate_normals();
		sf.generate_tangents();
		sf.commit(mesh);

	elapsed_time = Time.get_ticks_msec() - elapsed_time;

	if elapsed_time > 100:
		if "source" in vmf_structure: VMFLogger.warn(vmf_structure.source);
		VMFLogger.warn("Mesh generation took " + str(elapsed_time) + "ms");

	return mesh;
