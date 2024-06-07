class_name VMFTool

static var vertexCache: Array = [];
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

	func getOrder(v: Vector3) -> float:
		var normalized: Vector3 = (v - self.center).normalized();
		return atan2(
			self.normal.dot(normalized.cross(self.pp)), 
			self.normal.dot(normalized.cross(self.qp))
		);

	func sort(a: Vector3, b: Vector3) -> bool:
		return getOrder(a) < getOrder(b);

static func getSimilarVertex(vertex: Vector3) -> Vector3:
	vertexCache = vertexCache if vertexCache else [];

	for v: Vector3 in vertexCache:
		if (v - vertex).length() < 0.1:
			return v;

	vertexCache.append(vertex);
	return vertex;

static func clearCaches() -> void:
	vertexCache = [];
	intersections = {};

static func getPlanesIntersectionPoint(side, side2, side3) -> Variant:
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
static func calculateVertices(side, brush) -> Array[Vector3]:
	var vertices: Array[Vector3] = [];
	var cache = {};

	if "vertices_plus" in side:
		vertices.assign(side.vertices_plus.v)
		return vertices;

	var isVerticeExists = func(vector: Vector3):
		var hashValue: int = hash(Vector3i(vector));
		
		if hashValue in cache:
			return true;

		cache[hashValue] = 1;

		return false;

	for side2 in brush.side:
		if side2 == side:
			continue;

		for side3 in brush.side:
			if side2 == side3 or side3 == side:
				continue;

			var vertex := getPlanesIntersectionPoint(side, side2, side3);
			if vertex == null:
				continue;

			if isVerticeExists.call(vertex):
				continue;

			vertices.append(vertex as Vector3);

	vertices = vertices.filter(func(vertex):
		return not brush.side.any(func(s):
			return s.plane.value.distance_to(vertex) > 0.2;
		)
	);

	var sideNormal: Vector3 = side.plane.value.normal.normalized();
	var vectorSorter: VectorSorter = VectorSorter.new(sideNormal, side.plane.vecsum / 3);

	vertices.sort_custom(vectorSorter.sort);

	return vertices;

static func calculateUVForSide(side: Dictionary, vertex: Vector3) -> Vector2:
	var defaultTextureSize: int = VMFConfig.config.material.defaultTextureSize;

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

	var material = VTFTool.getMaterial(side.material);
	
	if not material:
		return Vector2(1, 1);

	# NOTE In case if material is blend texture we use texture_albedo param
	var texture = material.albedo_texture if material is StandardMaterial3D else material.get_shader_parameter('texture_albedo');

	var tsize: Vector2 = texture.get_size() if texture else Vector2(defaultTextureSize, defaultTextureSize);
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
static func createMesh(vmfStructure: Dictionary, _offset: Vector3 = Vector3(0, 0, 0)) -> ArrayMesh:
	clearCaches();

	var _scale: float = VMFConfig.config.import.scale;
	var _defaultTextureSize: float = VMFConfig.config.material.defaultTextureSize;
	var _ignoreTextures: Array[String];
	_ignoreTextures.assign(VMFConfig.config.material.ignore);
	var _textureImportMode: int = VMFConfig.config.material.importMode;

	var elapsedTime := Time.get_ticks_msec();

	if not "solid" in vmfStructure.world:
		return null;

	var brushes = vmfStructure.world.solid
	var materialSides = {};
	var textureCache = {};
	var mesh := ArrayMesh.new();

	for brush in brushes:
		for side in brush.side:
			var material: String = side.material.to_upper();
			var isIgnored = _ignoreTextures.any(func(rx: String) -> bool: return material.match(rx));

			if isIgnored:
				continue;

			if not material in materialSides:
				materialSides[material] = [];

			materialSides[material].append({
				"side": side,
				"brush": brush,
			});

	for sides in materialSides.values():
		var surfaceTool := SurfaceTool.new();
		surfaceTool.begin(Mesh.PRIMITIVE_TRIANGLES);

		var index: int = 0;
		for sideData in sides:
			var side: Dictionary = sideData.side;
			var base_index := index;

			var isDisplacement: bool = "dispinfo" in side;
			var vertices: Array[Vector3] = [];
			var dispData: VMFDispTool = null;

			if not isDisplacement and VMFDispTool.hasDisplacement(sideData.brush):
				continue;

			if not isDisplacement:
				vertices.assign(calculateVertices(side, sideData.brush));
			else:
				dispData = VMFDispTool.new(side, sideData.brush);
				vertices.assign(dispData.getVertices());
				
			if vertices.size() < 3:
				VMFLogger.error("Side corrupted: " + str(side.id));
				continue;

			if not isDisplacement:
				var normal = side.plane.value.normal;
				surfaceTool.set_normal(Vector3(normal.x, normal.z, -normal.y));
	
				for v: Vector3 in vertices:
					var vertex := getSimilarVertex(v);
					var uv: Vector2 = calculateUVForSide(side, vertex);
					surfaceTool.set_uv(uv);
	
					var vt := Vector3(vertex.x, vertex.z, -vertex.y) * _scale - _offset;
					var sg := -1 if side.smoothing_groups == 0 else int(side.smoothing_groups);
					
					surfaceTool.set_smooth_group(sg);
					surfaceTool.set_color(Color8(0, 0, 0));
					surfaceTool.add_vertex(vt);
					index += 1;

				for i: int in range(1, vertices.size() - 1):
					surfaceTool.add_index(base_index);
					surfaceTool.add_index(base_index + i);
					surfaceTool.add_index(base_index + i + 1);
			else:
				var edgesCount = dispData.edgesCount;
				var vertsCount = dispData.vertsCount;
				surfaceTool.set_smooth_group(1);

				for i: int in range(0, vertices.size()):
					var x := i / int(vertsCount);
					var y := i % int(vertsCount);
					var v = vertices[i];
					var normal = dispData.getNormal(x, y);
					var dist = dispData.getDistance(x, y);
					var offset = dispData.getOffset(x, y);
					var uv := calculateUVForSide(side, v - dist - offset);

					surfaceTool.set_uv(uv);
					surfaceTool.set_color(dispData.getColor(x, y));
					surfaceTool.set_normal(Vector3(normal.x, normal.z, -normal.y));
					surfaceTool.add_vertex(Vector3(v.x, v.z, -v.y) * _scale - _offset);
					index += 1;

				for i: int in range(0, pow(edgesCount, 2)):
					var x := i / int(edgesCount);
					var y := i % int(edgesCount);
					var normal = dispData.getNormal(x, y);
					var isOdd := (x + y) % 2 == 1;

					if isOdd:
						surfaceTool.add_index(base_index + x + 1 + y * vertsCount);
						surfaceTool.add_index(base_index + x + (y + 1) * vertsCount);
						surfaceTool.add_index(base_index + x + 1 + (y + 1) * vertsCount);

						surfaceTool.add_index(base_index + x + y * vertsCount);
						surfaceTool.add_index(base_index + x + (y + 1) * vertsCount);
						surfaceTool.add_index(base_index + x + 1 + y * vertsCount);
					else:
						surfaceTool.add_index(base_index + x + y * vertsCount);
						surfaceTool.add_index(base_index + x + (y + 1) * vertsCount);
						surfaceTool.add_index(base_index + x + 1 + (y + 1) * vertsCount);

						surfaceTool.add_index(base_index + x + y * vertsCount);
						surfaceTool.add_index(base_index + x + 1 + (y + 1) * vertsCount);
						surfaceTool.add_index(base_index + x + 1 + y * vertsCount);

		var ignoreMaterials: bool = VTFTool.TextureImportMode.DO_NOTHING == VMFConfig.config.material.importMode;

		if not ignoreMaterials:
			var material = VTFTool.getMaterial(sides[0].side.material);

			if material:
				surfaceTool.set_material(material);
				
		surfaceTool.optimize_indices_for_cache();
		surfaceTool.generate_normals();
		surfaceTool.generate_tangents();
		surfaceTool.commit(mesh);

	elapsedTime = Time.get_ticks_msec() - elapsedTime;

	if elapsedTime > 100:
		VMFLogger.warn("Mesh generation took " + str(elapsedTime) + "ms");

	return mesh;
