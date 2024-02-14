@tool
extends Node;

## Returns MeshInstance3D from parsed VMF structure
func createMesh(
	vmfStructure: Dictionary,
	_scale = 0.1,
	_defaultTextureSize = 512,
	_textureImportMode: VMTManager.TextureImportMode = 0,
	_ignoreTextures = [],
	_fallbackMaterial: Material = null,
	_offset: Vector3 = Vector3(0, 0, 0),
) -> Mesh:
	var elapsedTime = Time.get_ticks_msec();

	if not "solid" in vmfStructure.world:
		return null;

	var brushes = vmfStructure.world.solid
	var materialSides = {};
	var textureCache = {};
	var mesh = ArrayMesh.new();

	## TODO Add displacement support
	##		I'm too dumb for this logic :'C

	for brush in brushes:
		for side in brush.side:
			var material = side.material
			
			if _ignoreTextures.has(material):
				continue;

			if not material in materialSides:
				materialSides[material] = [];
			materialSides[material].append(side);

	var index = 0;
	for sides in materialSides.values():
		var verts = [];
		var uvs = [];
		var normals = [];
		var indices = [];

		for side in sides:
			var vertex_count = side.vertices_plus.v.size()
			if vertex_count < 3:
				continue;

			var base_index = verts.size()

			for vertex in side.vertices_plus.v:
				var vt = Vector3(vertex.x * _scale, vertex.z * _scale, -vertex.y * _scale) - _offset;
				verts.append(vt);

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

				var texture = VMTManager.getTextureInfo(side.material);

				var tsx = 1;
				var tsy = 1;
				var tw = texture.width if texture else _defaultTextureSize;
				var th = texture.height if texture else _defaultTextureSize;
				var aspect = tw / th;

				if texture and texture.transform:
					tsx /= texture.transform.scale.x;
					tsy /= texture.transform.scale.y;

				var uv = Vector3(ux, uy, uz);
				var vv = Vector3(vx, vy, vz);
				var v2 = Vector3(vertex.x, vertex.y, vertex.z);

				var u = (v2.dot(uv) + ushift * uscale) / tw / uscale / tsx;
				var v = (v2.dot(vv) + vshift * vscale) / tw / vscale / tsy;
				
				if aspect < 1:
					u *= aspect;
				else:
					v *= aspect;

				uvs.append(Vector2(u, v));
				
				var ab = side.plane[0] - side.plane[1];
				var ac = side.plane[2] - side.plane[1];
				var normal = ab.cross(ac).normalized();

				normals.append(normal);
				
				# TODO вот тут должна быть генерация вертексных нормалей из скуф групп

			for i in range(1, vertex_count - 1):
				indices.append(base_index)
				indices.append(base_index + i)
				indices.append(base_index + i + 1)

		var surface = []
		surface.resize(Mesh.ARRAY_MAX);
		surface[Mesh.ARRAY_VERTEX] = PackedVector3Array(verts)
		surface[Mesh.ARRAY_TEX_UV] = PackedVector2Array(uvs)
		surface[Mesh.ARRAY_TEX_UV2] = PackedVector2Array(uvs)
		surface[Mesh.ARRAY_NORMAL] = PackedVector3Array(normals)
		surface[Mesh.ARRAY_INDEX] = PackedInt32Array(indices)

		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, surface)

		if _textureImportMode == VMTManager.TextureImportMode.COLLATE_BY_NAME:
			var godotMaterial = VMTManager.getMaterialFromProject(sides[0].material);

			if godotMaterial:
				mesh.surface_set_material(index, godotMaterial);
			else: if _fallbackMaterial:
				mesh.surface_set_material(index, _fallbackMaterial);
		else: if _textureImportMode == VMTManager.TextureImportMode.IMPORT_DIRECTLY:
			var material = VMTManager.importMaterial(sides[0].material);
			if material:
				mesh.surface_set_material(index, material);

		index += 1;
	elapsedTime = Time.get_ticks_msec() - elapsedTime;

	if elapsedTime > 100:
		VMFLogger.warn("Mesh generation took " + str(elapsedTime) + "ms");

	return mesh;
