@tool
extends Control

const ITEM = preload("./item.tscn")
@onready var item_holder: HFlowContainer = %ItemHolder

signal request_add_item(item: MMPlusMesh)
signal request_delete_item(idx: int)

func _can_drop_data(at_position: Vector2, data: Variant) -> bool:
	data = data as Dictionary
	if data == null: return false
	var data_type: String = data.get("type")
	if data_type == null: return false
	if data_type != "files": return false
	var files: PackedStringArray = data.get("files", []) as PackedStringArray
	var file_path: String = files[0]
	var editor_file_system: EditorFileSystem = EditorInterface.get_resource_filesystem()
	return editor_file_system.get_file_type(file_path) == "Resource"

func _drop_data(at_position: Vector2, data: Variant) -> void:
	var files: PackedStringArray = data.get("files", []) as PackedStringArray
	var file_path = files[0]

	var plus_mesh: MMPlusMesh = load(file_path) as MMPlusMesh
	if plus_mesh == null: return

	request_add_item.emit(plus_mesh)

func load_from_list(plus_mesh_list: Array[MMPlusMesh]) -> Array[MMPlusMeshItem]:
	for child in item_holder.get_children():
		child.queue_free()

	var items: Array[MMPlusMeshItem] = []

	for plus_mesh in plus_mesh_list:
		items.append(add_item(plus_mesh))

	return items

func add_item(plus_mesh: MMPlusMesh) -> MMPlusMeshItem:
	var item: MMPlusMeshItem = ITEM.instantiate()
	item.item_name = plus_mesh.name
	item_holder.add_child(item)
	item.delete_button.pressed.connect(_on_delete_button_pressed.bind(item))
	return item

func remove_item(idx: int) -> void:
	item_holder.get_child(idx).queue_free()

func _on_delete_button_pressed(item: MMPlusMeshItem) -> void:
	request_delete_item.emit(item.get_index())
