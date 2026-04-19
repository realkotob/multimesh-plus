class_name MMGroup
extends Object

var mm_grid : MMGrid
var buffer_map : Dictionary[AABB, PackedFloat32Array] = {}
var _data_mode : MMDataMode.Mode
var _data_size : int

func duplicate() -> MMGroup:
	var group : MMGroup = MMGroup.new()
	var new_buffer_map : Dictionary[AABB, PackedFloat32Array]
	for aabb in buffer_map:
		new_buffer_map[aabb] = buffer_map[aabb].duplicate()
	group.mm_grid = mm_grid.duplicate()
	group.buffer_map = new_buffer_map
	group._data_mode = _data_mode
	group._data_size = _data_size
	return group

func setup(data : Dictionary[AABB, MultiMesh], grid_size : float, data_mode: MMDataMode.Mode) -> void:
	_data_mode = data_mode
	_data_size = MMDataMode.get_data_mode_size(_data_mode)

	buffer_map = {}

	# Fill mm_grid with buffer transform origins
	mm_grid = MMGrid.new(Vector3.ONE * grid_size)
	for aabb in data:
		buffer_map[aabb] = data[aabb].buffer
		var buffer : PackedFloat32Array = data[aabb].buffer

		var points = []

		for idx in range(0, buffer.size(), _data_size):
			var point = Vector3(
				buffer[idx + 3],
				buffer[idx + 7],
				buffer[idx + 11]
			)
			points.append(point)

		mm_grid.populate(aabb, points)

func setup_from_buffer(buffer : PackedFloat32Array, grid_size : float, data_mode: MMDataMode.Mode):
	_data_mode = data_mode
	_data_size = MMDataMode.get_data_mode_size(_data_mode)
	buffer_map = {}

	mm_grid = MMGrid.new(Vector3.ONE * grid_size)

	for idx in buffer.size() / _data_size:
		var base_position : Vector3 = Vector3(buffer[idx * _data_size + 3], buffer[idx * _data_size + 7], buffer[idx * _data_size + 11])

		var region : AABB = mm_grid.check_region_for_point(base_position)
		if !buffer_map.has(region): buffer_map[region] = PackedFloat32Array()

		var t : Array = []
		t.resize(_data_size)
		for i in t.size():
			t[i] = buffer[idx * t.size() + i]
		buffer_map[region].append_array(t)

		var y : int = buffer_map[region].size() / _data_size - 1
		mm_grid.add_point_in_region(region, y, base_position)

func remove_point_in_sphere(position : Vector3, radius : float = 1.0) -> void:
	var result : Dictionary[AABB, PackedInt64Array] = mm_grid.remove_points_in_sphere(position, radius)
	for aabb in result:
		remove_from_buffer_at_idx_list(aabb, result[aabb])

func set_buffer_color_in_sphere(position : Vector3, radius : float = 1.0, base_color : Color = Color.BLACK, random_color : bool = false):

	var result : Dictionary[AABB, PackedInt64Array] = mm_grid.get_points_in_sphere(position, radius)
	for aabb in result:
		for idx in result[aabb]:
			idx *= _data_size
			var color : Color = Color(randf(), randf(), randf(), randf()) if random_color else base_color
			buffer_map[aabb][idx + 12] = color.r
			buffer_map[aabb][idx + 13] = color.g
			buffer_map[aabb][idx + 14] = color.b
			buffer_map[aabb][idx + 15] = color.a

# Updated: Now accepts base_position separately from transform
# This separation fixes spacing and erase radius issues when offset is used
func add_transform_to_buffer(t : Transform3D, base_position : Vector3) -> void:
	# Use base_position for grid region lookup (logical position)
	var region : AABB = mm_grid.check_region_for_point(base_position)

	if !buffer_map.has(region):
		buffer_map[region] = PackedFloat32Array()

	# Base Transform Array
	var buffer_array : PackedFloat32Array = [t.basis.x.x, t.basis.y.x, t.basis.z.x, t.origin.x, t.basis.x.y, t.basis.y.y, t.basis.z.y, t.origin.y, t.basis.x.z, t.basis.y.z, t.basis.z.z, t.origin.z]

	# Append random color array if DataMode is set to TransformAndVertexColor
	if _data_mode == MMDataMode.Mode.TransformAndVertexColor:
		buffer_array.append_array([randf(), randf(), randf(), 1.0])

	# Buffer stores the visual transform (t) with offset for correct rendering
	buffer_map[region].append_array(buffer_array)
	var idx : int = buffer_map[region].size() / _data_size - 1

	# Grid stores base_position (without offset) for spatial queries
	# This ensures erase/scale/colorize work on logical brush positions
	mm_grid.add_point_in_region(region, idx, base_position)

func remove_from_buffer_at_idx_list(aabb : AABB, idx_list : PackedInt64Array):
	for idx in range(idx_list.size() - 1 , -1, -1):
		remove_from_buffer_at_idx(aabb, idx_list[idx])

func remove_from_buffer_at_idx(aabb : AABB, idx : int):
	var size : int = _data_size
	var idx_offset : int = size * idx
	for i in range(size - 1 + idx_offset, -1 + idx_offset, -1):
		buffer_map[aabb].remove_at(i)

func get_buffer_transform_basis(aabb : AABB, idx : int) -> Basis:
	return Basis(
		Vector3(buffer_map[aabb][idx + 0], buffer_map[aabb][idx + 4], buffer_map[aabb][idx + 8]),
		Vector3(buffer_map[aabb][idx + 1], buffer_map[aabb][idx + 5], buffer_map[aabb][idx + 9]),
		Vector3(buffer_map[aabb][idx + 2], buffer_map[aabb][idx + 6], buffer_map[aabb][idx + 10])
	)

func get_buffer_transform(aabb : AABB, idx : int) -> Transform3D:
	var basis : Basis = get_buffer_transform_basis(aabb, idx)
	return Transform3D(basis, Vector3(idx + 3, idx + 7, idx + 11))

func set_buffer_transform_scale(aabb : AABB, idx : int, scale : float) -> void:
	idx *= _data_size
	var basis : Basis = get_buffer_transform_basis(aabb, idx)
	basis = basis.orthonormalized().scaled_local(Vector3.ONE * scale)
	_apply_basis_to_buffer(aabb, idx, basis)

func increment_buffer_transform_scale(aabb : AABB, idx : int, increment : float = 0.0) -> void:
	idx *= _data_size
	var basis : Basis = get_buffer_transform_basis(aabb, idx)
	var scale : float = basis.get_scale()[0] + increment
	scale = clampf(scale, 0.1, 10.0)
	basis = basis.orthonormalized().scaled_local(Vector3.ONE * scale)
	_apply_basis_to_buffer(aabb, idx, basis)

func _apply_basis_to_buffer(aabb : AABB, idx, basis : Basis) -> void:
	buffer_map[aabb][idx + 0] = basis.x.x
	buffer_map[aabb][idx + 1] = basis.y.x
	buffer_map[aabb][idx + 2] = basis.z.x

	buffer_map[aabb][idx + 4] = basis.x.y
	buffer_map[aabb][idx + 5] = basis.y.y
	buffer_map[aabb][idx + 6] = basis.z.y

	buffer_map[aabb][idx + 8] = basis.x.z
	buffer_map[aabb][idx + 9] = basis.y.z
	buffer_map[aabb][idx + 10] = basis.z.z
