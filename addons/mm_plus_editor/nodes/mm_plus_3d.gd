@tool
@icon("../assets/icons/mm_plus_3d_icon.svg")
class_name MmPlus3D
extends Node3D

@export_storage var grid_size : float = 50.0
@export_storage var previous_grid_size : float = 50.0
@export var data : Array[MMPlusData]

var save_path: String = "res://.mmplus_save_dir/"

signal data_changed

func _ready() -> void:
	load_multimesh()
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
	for data_group_idx in data.size():
		var data_group : MMPlusData = data[data_group_idx]
		for aabb in data_group.visual_instance_RID_map:
			RenderingServer.instance_set_visible(data_group.visual_instance_RID_map[aabb], visible)

func _update_visual_instances_transform() -> void:
	for data_group_idx in data.size():
		var data_group : MMPlusData = data[data_group_idx]
		for aabb in data_group.visual_instance_RID_map:
			RenderingServer.instance_set_transform(data_group.visual_instance_RID_map[aabb], global_transform)

func add_mesh(plus_mesh: MMPlusMesh, at_idx: int = -1):
	var new_data: MMPlusData = MMPlusData.new()
	new_data.mesh_data = plus_mesh
	if at_idx == -1:
		data.append(new_data)
	else:
		data.insert(at_idx, new_data)
	_update_buffer(data.size(), {})

func remove_mesh(idx: int):
	_delete_group_data(idx)
	data.remove_at(idx)

func _delete_group_data(group_idx: int) -> void:
	var group_data : MMPlusData = data[group_idx]

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
	data[group_idx].multimesh_RID_map[aabb] = m_rid
	data[group_idx].visual_instance_RID_map[aabb] = i_rid

func _add_multimesh_data(group_idx : int, aabb : AABB) -> void:
	var multimesh : MultiMesh = MultiMesh.new()
	multimesh.use_colors = true
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	data[group_idx].multimesh_data_map[aabb] = multimesh

func update_group_buffer(data_group_list : Array[MMGroup]):
	for data_group_idx in data_group_list.size():
		var data_group : MMGroup = data_group_list[data_group_idx]
		var buffer_map : Dictionary[AABB, PackedFloat32Array] = data_group.buffer_map
		_update_buffer(data_group_idx, buffer_map)

func _remove_buffer(data_group_idx : int, aabb : AABB):
	var m_rid : RID = data[data_group_idx].multimesh_RID_map[aabb]
	var i_rid : RID = data[data_group_idx].visual_instance_RID_map[aabb]
	RenderingServer.free_rid(i_rid)
	RenderingServer.free_rid(m_rid)
	data[data_group_idx].visual_instance_RID_map.erase(aabb)
	data[data_group_idx].multimesh_RID_map.erase(aabb)
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
		var buffer : PackedFloat32Array = buffer_map[aabb]

		if !data[data_group_idx].multimesh_RID_map.has(aabb):
			_add_visual_instance(data_group_idx, aabb)
		if !data[data_group_idx].multimesh_data_map.has(aabb):
			_add_multimesh_data(data_group_idx, aabb)

		var m_rid : RID = data[data_group_idx].multimesh_RID_map[aabb]
		var multimesh : MultiMesh = data[data_group_idx].multimesh_data_map[aabb]

		RenderingServer.multimesh_allocate_data(m_rid, buffer.size() / 16, RenderingServer.MULTIMESH_TRANSFORM_3D, true)

		if !buffer.is_empty():
			RenderingServer.multimesh_set_buffer(m_rid, buffer)
			multimesh.instance_count = buffer.size() / 16
			multimesh.buffer = buffer
		else:
			_remove_buffer(data_group_idx, aabb)

func _enter_tree() -> void:
	load_multimesh()

func _exit_tree() -> void:
	flush()

func flush() -> void:
	for data_group_idx in data.size():
		for aabb in data[data_group_idx].visual_instance_RID_map:
			RenderingServer.free_rid(data[data_group_idx].visual_instance_RID_map[aabb])
		data[data_group_idx].visual_instance_RID_map = {}

		for aabb in data[data_group_idx].multimesh_RID_map:
			RenderingServer.free_rid(data[data_group_idx].multimesh_RID_map[aabb])
		data[data_group_idx].multimesh_RID_map = {}
