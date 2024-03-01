class_name VMFTool

static var vertexCache = [];
static var intersections = {};

## Credit: https://github.com/Dylancyclone/VMF2OBJ/blob/master/src/main/java/com/lathrum/VMF2OBJ/dataStructure/VectorSorter.java;
class VectorSorter:
	var normal: Vector3;
	var center: Vector3;
	var pp: Vector3;
	var qp: Vector3;

	func longer(a, b):
		return a if a.length() > b.length() else b;

	func _init(normal, center):
		self.normal = normal;
		self.center = center;

		var i = normal.cross(Vector3(1, 0, 0));
		var j = normal.cross(Vector3(0, 1, 0));
		var k = normal.cross(Vector3(0, 0, 1));

		self.pp = longer(i, longer(j, k));
		self.qp = normal.cross(self.pp);

	func getOrder(v):
		var normalized = (v - self.center).normalized();
		return atan2(
			self.normal.dot(normalized.cross(self.pp)), 
			self.normal.dot(normalized.cross(self.qp))
		);

	func sort(a, b):
		return getOrder(a) < getOrder(b);

static func getSimilarVertex(vertex):
	vertexCache = vertexCache if vertexCache else [];

	for v in vertexCache:
		if (v - vertex).length() < 0.1:
			return v;

	vertexCache.append(vertex);
	return vertex;

static func clearCaches():
	vertexCache = [];
	intersections = {};

static func getPlanesIntersectionPoint(side, side2, side3):
	var d = [side.id, side2.id, side3.id];
	d.sort();

	var ihash = hash(d);
	var isIntersectionDefined = ihash in intersections;

	if isIntersectionDefined:
		return intersections[ihash];
	else:
		var vertex = side.plane.value.intersect_3(side2.plane.value, side3.plane.value);
		intersections[ihash] = vertex;
		return vertex;

## Returns vertices_plus
static func calculateVertices(side, brush):
	var vertices = [];
	var cache = {};

	if "vertices_plus" in side:
		return side.vertices_plus.v;

	var isVerticeExists = func(vector):
		var hash = hash(Vector3i(vector));
		
		if hash in cache:
			return true;

		cache[hash] = 1;

		return false;

	for side2 in brush.side:
		if side2 == side:
			continue;

		for side3 in brush.side:
			if side2 == side3 or side3 == side:
				continue;

			var vertex = getPlanesIntersectionPoint(side, side2, side3);

			if vertex == null:
				continue;

			if isVerticeExists.call(vertex):
				continue;

			vertex = side.plane.value.project(vertex);
			vertices.append(vertex);

	vertices = vertices.filter(func(vertex):
		return not brush.side.any(func(s):
			return s.plane.value.distance_to(vertex) > 0.5;
		)
	);

	var sideNormal = side.plane.value.normal.normalized();
	var vectorSorter = VectorSorter.new(sideNormal, side.plane.vecsum / 3);

	vertices.sort_custom(vectorSorter.sort);

	return vertices;

static func calculateUVForSide(side, vertex):
	var defaultTextureSize = VMFConfig.getConfig().nodeConfig.defaultTextureSize;

	var ux = side.uaxis.x;
	var uy = side.uaxis.y;
	var uz = side.uaxis.z;
	var ushift = side.uaxis.shift;
	var uscale = side.uaxis.scale;

	var vx = side.vaxis.x;
	var vy = side.vaxis.y;
	var vz = side.vaxis.z;
	var vshift = side.vaxis.shift;
	var vscale = side.vaxis.scale;

	var material = VTFTool.getMaterial(side.material);
	
	if not material:
		return Vector2(1, 1);

	# NOTE In case if material is blend texture we use texture_albedo param
	var texture = material.albedo_texture if material is StandardMaterial3D else material.get_shader_parameter('texture_albedo');

	if not texture:
		return Vector2(1, 1);

	var tsize = Vector2(texture.get_width(), texture.get_height());
	var tscale = material.get_meta("scale", Vector2(1, 1));

	var tsx = 1;
	var tsy = 1;
	var tw = tsize.x if material else defaultTextureSize;
	var th = tsize.y if material else defaultTextureSize;
	var aspect = tw / th;


	if material:
		tsx /= tscale.x;
		tsy /= tscale.y;

	var uv = Vector3(ux, uy, uz);
	var vv = Vector3(vx, vy, vz);
	var v2 = Vector3(vertex.x, vertex.y, vertex.z);

	var u = (v2.dot(uv) + ushift * uscale) / tw / uscale / tsx;
	var v = (v2.dot(vv) + vshift * vscale) / tw / vscale / tsy;
	
	if aspect < 1:
		u *= aspect;
	else:
		v *= aspect;

	return Vector2(u, v);

## Returns MeshInstance3D from parsed VMF structure
static func createMesh(vmfStructure: Dictionary, _offset: Vector3 = Vector3(0, 0, 0)) -> Mesh:
	clearCaches();

	var projectConfig = VMFConfig.getConfig();

	var fbm = projectConfig.nodeConfig.fallbackMaterial;

	var _scale = projectConfig.nodeConfig.importScale;
	var _defaultTextureSize = projectConfig.nodeConfig.defaultTextureSize;
	var _ignoreTextures = projectConfig.nodeConfig.ignoreTextures;
	var _fallbackMaterial = load(fbm) if fbm && ResourceLoader.exists(fbm) else null;
	var _textureImportMode = projectConfig.nodeConfig.textureImportMode;

	var elapsedTime = Time.get_ticks_msec();

	if not "solid" in vmfStructure.world:
		return null;

	var brushes = vmfStructure.world.solid
	var materialSides = {};
	var textureCache = {};
	var mesh = ArrayMesh.new();

	for brush in brushes:
		for side in brush.side:
			var material = side.material.to_upper();

			if _ignoreTextures.has(material):
				continue;

			if not material in materialSides:
				materialSides[material] = [];

			materialSides[material].append({
				"side": side,
				"brush": brush,
			});

	for sides in materialSides.values():
		var surfaceTool = SurfaceTool.new();
		surfaceTool.begin(Mesh.PRIMITIVE_TRIANGLES);

		var index = 0;
		for sideData in sides:
			var side = sideData.side;
			var base_index = index;

			var isDisplacement = "dispinfo" in side;
			var vertices = [];
			var dispData = null;

			if not isDisplacement and VMFDispTool.hasDisplacement(sideData.brush):
				continue;

			if not isDisplacement:
				vertices = calculateVertices(side, sideData.brush);
			else:
				dispData = VMFDispTool.new(side, sideData.brush);
				vertices = dispData.getVertices();
				
			if vertices.size() < 3:
				VMFLogger.error("Side corrupted: " + str(side.id));
				return;

			if not isDisplacement:
				var normal = side.plane.value.normal;
				surfaceTool.set_normal(Vector3(normal.x, normal.z, -normal.y));
	
				for v in vertices:
					var vertex = getSimilarVertex(v);
					var uv = calculateUVForSide(side, vertex);
					surfaceTool.set_uv(uv);
	
					var vt = Vector3(vertex.x, vertex.z, -vertex.y) * _scale - _offset;
					var sg = -1 if side.smoothing_groups == 0 else int(side.smoothing_groups);
					
					surfaceTool.set_smooth_group(sg);
					surfaceTool.add_vertex(vt);
					index += 1;

				for i in range(1, vertices.size() - 1):
					surfaceTool.add_index(base_index);
					surfaceTool.add_index(base_index + i);
					surfaceTool.add_index(base_index + i + 1);
			else:
				var edgesCount = dispData.edgesCount;
				var vertsCount = dispData.vertsCount;
				surfaceTool.set_smooth_group(1);

				for i in range(0, vertices.size()):
					var x = i / int(vertsCount);
					var y = i % int(vertsCount);
					var v = vertices[i];
					var normal = dispData.getNormal(x, y);
					var dist = dispData.getDistance(x, y);
					var offset = dispData.getOffset(x, y);
					var uv = calculateUVForSide(side, v - dist - offset);

					surfaceTool.set_uv(uv);
					surfaceTool.set_normal(Vector3(normal.x, normal.z, -normal.y));
					surfaceTool.set_color(dispData.getColor(x, y));
					surfaceTool.add_vertex(Vector3(v.x, v.z, -v.y) * _scale - _offset);
					index += 1;

				for i in range(0, pow(edgesCount, 2)):
					var x = i / int(edgesCount);
					var y = i % int(edgesCount);
					var normal = dispData.getNormal(x, y);
					var isOdd = (x + y) % 2 == 1;

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

		var ignoreMaterials = VTFTool.TextureImportMode.DO_NOTHING == projectConfig.nodeConfig.textureImportMode;
		var material = VTFTool.getMaterial(sides[0].side.material) if not ignoreMaterials else _fallbackMaterial;
		material = material if material else _fallbackMaterial;

		surfaceTool.set_material(material);
		surfaceTool.generate_normals();
		surfaceTool.generate_tangents();
		surfaceTool.commit(mesh);

	elapsedTime = Time.get_ticks_msec() - elapsedTime;

	if elapsedTime > 100:
		VMFLogger.warn("Mesh generation took " + str(elapsedTime) + "ms");

	return mesh;

