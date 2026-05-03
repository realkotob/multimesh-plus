@tool
@icon("../assets/icons/mm_plus_3d_icon.svg")
class_name MmPlus3D
extends Node3D

@export_storage var grid_size : float = 50.0
@export_storage var previous_grid_size : float = 50.0
@export_storage var data : Array[MMPlusData]

var save_path: String = "res://.mmplus_save_dir/"
var rid_references: Array[MMRidRef]

signal data_changed

func _ready() -> void:
	set_notify_transform(true)

func _notification(what: int) -> void:
	match what:
		NOTIFICATION_VISIBILITY_CHANGED:
			_update_visual_instances_visibility()
		NOTIFICATION_TRANSFORM_CHANGED:
			_update_visual_instances_transform()
		NOTIFICATION_EDITOR_PRE_SAVE:
			for data_group in data:
				if !data_group.is_built_in():
					ResourceSaver.save(data_group, data_group.resource_path)
					continue
				var file_name: String = data_group.generate_scene_unique_id() + ".res"
				var path: String = save_path.path_join(file_name)
				var error: Error = ResourceSaver.save(data_group, path)
				data_group.take_over_path(path)


func _update_visual_instances_visibility() -> void:
	for data_group_idx in rid_references.size():
		var data_group : MMRidRef = rid_references[data_group_idx]
		for aabb in data_group.visual_instance_RID_map:
			RenderingServer.instance_set_visible(data_group.visual_instance_RID_map[aabb], visible)

func _update_visual_instances_transform() -> void:
	for data_group_idx in rid_references.size():
		var data_group : MMRidRef = rid_references[data_group_idx]
		for aabb in data_group.visual_instance_RID_map:
			RenderingServer.instance_set_transform(data_group.visual_instance_RID_map[aabb], global_transform)

func add_mesh(plus_mesh: MMPlusMesh, at_idx: int = -1):
	var new_data: MMPlusData = MMPlusData.new()
	new_data.mesh_data = plus_mesh
	if at_idx == -1:
		data.append(new_data)
		rid_references.append(MMRidRef.new())
	else:
		data.insert(at_idx, new_data)
		rid_references.insert(at_idx, MMRidRef.new())
	_update_buffer(data.size(), {})

func remove_mesh(idx: int):
	_delete_group_data(idx)
	data.remove_at(idx)
	rid_references.remove_at(idx)

func _delete_group_data(group_idx: int) -> void:
	var group_data : MMRidRef = rid_references[group_idx]

	for aabb in group_data.visual_instance_RID_map:
		RenderingServer.free_rid(group_data.visual_instance_RID_map[aabb])
	group_data.visual_instance_RID_map = {}

	for aabb in group_data.multimesh_RID_map:
		RenderingServer.free_rid(group_data.multimesh_RID_map[aabb])
	group_data.multimesh_RID_map = {}

	group_data.multimesh_data_map = {}

func delete_all_transforms() -> void:
	for group_idx in data.size():
		_delete_group_data(group_idx)

func load_multimesh() -> void:
	for group_idx in data.size():

		var buffer_map : Dictionary[AABB, PackedFloat32Array]

		for aabb in data[group_idx].multimesh_data_map.keys():
			var multimesh : MultiMesh = data[group_idx].multimesh_data_map[aabb]
			if multimesh.instance_count == 0:
				# This instance can be skipped and deleted before being loaded
				data[group_idx].multimesh_data_map.erase(aabb)
				continue
			buffer_map[aabb] = data[group_idx].multimesh_data_map[aabb].buffer

		_update_buffer(group_idx, buffer_map)

func _add_visual_instance(group_idx : int, aabb : AABB) -> void:
	var mesh_data : MMPlusMesh = data[group_idx].mesh_data
	var mesh : Mesh = mesh_data.mesh
	var m_rid = RenderingServer.multimesh_create()
	var i_rid : RID = RenderingServer.instance_create2(m_rid, get_world_3d().scenario)
	RenderingServer.instance_set_transform(i_rid, global_transform)
	RenderingServer.instance_set_custom_aabb(i_rid, aabb)
	RenderingServer.multimesh_set_mesh(m_rid, mesh.get_rid())
	RenderingServer.instance_geometry_set_cast_shadows_setting(i_rid, mesh_data.cast_shadow)
	RenderingServer.instance_geometry_set_visibility_range(i_rid, 0.0, 100.0 + grid_size / 2.0, 0.0, 0.0, RenderingServer.VISIBILITY_RANGE_FADE_DISABLED)
	RenderingServer.instance_set_visible(i_rid, visible)
	rid_references[group_idx].multimesh_RID_map[aabb] = m_rid
	rid_references[group_idx].visual_instance_RID_map[aabb] = i_rid

func _add_multimesh_data(group_idx : int, aabb : AABB, use_color: bool) -> void:
	var multimesh : MultiMesh = MultiMesh.new()
	multimesh.use_colors = use_color
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	data[group_idx].multimesh_data_map[aabb] = multimesh

func update_group_buffer(data_group_list : Array[MMGroup]):
	for data_group_idx in data_group_list.size():
		var data_group : MMGroup = data_group_list[data_group_idx]
		var buffer_map : Dictionary[AABB, PackedFloat32Array] = data_group.buffer_map
		_update_buffer(data_group_idx, buffer_map)

func _remove_buffer(data_group_idx : int, aabb : AABB):
	var m_rid : RID = rid_references[data_group_idx].multimesh_RID_map[aabb]
	var i_rid : RID = rid_references[data_group_idx].visual_instance_RID_map[aabb]
	RenderingServer.free_rid(i_rid)
	RenderingServer.free_rid(m_rid)
	rid_references[data_group_idx].visual_instance_RID_map.erase(aabb)
	rid_references[data_group_idx].multimesh_RID_map.erase(aabb)
	data[data_group_idx].multimesh_data_map.erase(aabb)

func check_missmatch(data_group_list : Array[MMGroup]):
	for data_group_idx in data.size():
		var local_data : Dictionary[AABB, MultiMesh] = data[data_group_idx].multimesh_data_map
		var external_data : Dictionary[AABB, PackedFloat32Array] = data_group_list[data_group_idx].buffer_map
		
		for aabb in local_data:
			if !external_data.has(aabb):
				_remove_buffer(data_group_idx, aabb)

func _update_buffer(data_group_idx : int, buffer_map : Dictionary[AABB, PackedFloat32Array]) -> void:
	for aabb in buffer_map:

		var data_mode: MMDataMode.Mode = data[data_group_idx].mesh_data.data_mode
		var data_size: int = MMDataMode.get_data_mode_size(data_mode)
		var use_color: bool = data_mode == MMDataMode.Mode.TransformAndVertexColor

		if !rid_references[data_group_idx].multimesh_RID_map.has(aabb):
			_add_visual_instance(data_group_idx, aabb)
		if !data[data_group_idx].multimesh_data_map.has(aabb):
			_add_multimesh_data(data_group_idx, aabb, use_color)

		var m_rid : RID = rid_references[data_group_idx].multimesh_RID_map[aabb]
		var multimesh : MultiMesh = data[data_group_idx].multimesh_data_map[aabb]


		var buffer : PackedFloat32Array = []

		if buffer_map[aabb].size() % data_size == 0:
			buffer = buffer_map[aabb]
		else:
			push_warning("Buffer size doesn't match mesh data mode size, buffer size will be updated but some data might be lost.")
			buffer = _repare_buffer_size_mismatch(buffer_map[aabb], data_size)
			multimesh.instance_count = 0
			multimesh.use_colors = use_color

		RenderingServer.multimesh_allocate_data(m_rid, buffer.size() / data_size, RenderingServer.MULTIMESH_TRANSFORM_3D, use_color, false)

		if !buffer.is_empty():
			RenderingServer.multimesh_set_buffer(m_rid, buffer)
			multimesh.instance_count = buffer.size() / data_size
			multimesh.buffer = buffer
		else:
			_remove_buffer(data_group_idx, aabb)

func _repare_buffer_size_mismatch(buffer : PackedFloat32Array, new_size: int) -> PackedFloat32Array:
	var resized_buffer: PackedFloat32Array = []
	var previous_size: int = MMDataMode.get_data_mode_from_buffer_size(buffer.size())

	if new_size < previous_size:
		for idx in range(0, buffer.size(), previous_size):
			for i in new_size:
				resized_buffer.append(buffer[idx + i])

	if new_size > previous_size:
		for idx in range(0, buffer.size(), new_size):
			for i in previous_size:
				resized_buffer.append(buffer[idx + i])

			if new_size > previous_size:
				var missing_data: PackedFloat32Array = []
				missing_data.resize(new_size - previous_size)
				missing_data.fill(0.0)
				resized_buffer.append_array(missing_data)

	return resized_buffer

func _enter_tree() -> void:
	# Create rid array
	for _i in data.size():
		rid_references.append(MMRidRef.new())
	
	load_multimesh()

func _exit_tree() -> void:
	flush()

func flush() -> void:
	for data_group_idx in rid_references.size():
		for aabb in rid_references[data_group_idx].visual_instance_RID_map:
			RenderingServer.free_rid(rid_references[data_group_idx].visual_instance_RID_map[aabb])
		rid_references[data_group_idx].visual_instance_RID_map = {}

		for aabb in rid_references[data_group_idx].multimesh_RID_map:
			RenderingServer.free_rid(rid_references[data_group_idx].multimesh_RID_map[aabb])
		rid_references[data_group_idx].multimesh_RID_map = {}
