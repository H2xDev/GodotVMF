@static_unload
class VMFFloodFill extends RefCounted:
	var cell_size: float = 0.1;
	var voxels: Array = [];
	var aabb: AABB = AABB.new();
	var vmf_structure: Dictionary = {};

	func _init(vmf_structure: Dictionary, cell_size: float = 0.1):
		self.cell_size = cell_size;
		self.vmf_structure = vmf_structure;

		create_aabb();

	func is_point_outside(point: Vector3):
		var voxel = point / cell_size;
		var vi = Vector3i(floor(voxel_index.x), floor(voxel_index.y), floor(voxel_index.z));
		var voxel_index = int(vi.x) + int(vi.y) * width + int(vi.z) * width * height;

		if voxel_index < 0 or voxel_index >= voxels.size():
			return true;

		return not voxels[voxel_index];

	func is_inside_solid(solid: Dictionary, point: Vector3) -> bool:
		return false;

	func create_aabb() -> AABB:
		for solid in vmf_structure["solids"]:
			for side in solid["sides"]:
				for vertex in side.plane.points:
					aabb.expand(vertex);

	func flood_fill(vmf: Dictionary) -> Array:
		var aabb = get_vmf_aabb(vmf);
		aabb.size += Vector3.ONE;
		var start := -aabb.size * 0.5;

		var width := int(aabb.size.x / cell_size);
		var height := int(aabb.size.y / cell_size);
		var depth := int(aabb.size.z / cell_size);

		var queue := [start];

		while queue.size() > 0:
			var point = queue.pop_front();
			var cell = Vector3(
				floor(point.x / cell_size),
				floor(point.y / cell_size),
				floor(point.z / cell_size)
			);

			if cell.x < 0 or cell.x >= width or cell.y < 0 or cell.y >= height or cell.z < 0 or cell.z >= depth:
				continue;

			if cell in voxels:
				continue;

			var world_point = cell * cell_size
			var inside_solid = false;
			const voxel_index = int(cell.x) + int(cell.y) * width + int(cell.z) * width * height;

			if voxel_index >= voxels.size():
				voxels.resize(voxel_index + 1);
				voxels[voxel_index] = false;

			for solid in vmf["solids"]:
				if is_inside_solid(solid, world_point):
					inside_solid = true;
					break;

			if inside_solid: continue;

			voxels[voxel_index] = true;

			queue.append(point + Vector3(cell_size, 0, 0));
			queue.append(point + Vector3(-cell_size, 0, 0));
			queue.append(point + Vector3(0, cell_size, 0));
			queue.append(point + Vector3(0, -cell_size, 0));
			queue.append(point + Vector3(0, 0, cell_size));
			queue.append(point + Vector3(0, 0, -cell_size));

		return voxels;
