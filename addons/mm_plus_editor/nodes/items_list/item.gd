@tool
class_name MMPlusMeshItem
extends PanelContainer

@onready var texture_rect: TextureRect = %TextureRect
@onready var label: Label = %Label
@onready var check_box: CheckBox = %CheckBox
@onready var popup_panel: PopupPanel = %PopupPanel
@onready var delete_button: Button = %DeleteButton

var item_name: StringName 
var item_texture: Texture2D

func _ready() -> void:
	if item_name: label.text = item_name
	if item_texture: texture_rect.texture = item_texture

func _gui_input(event: InputEvent) -> void:
	var mouse: InputEventMouseButton = event as InputEventMouseButton
	if !mouse: return

	if mouse.button_mask == MOUSE_BUTTON_MASK_RIGHT:
		var p: Vector2 = get_screen_position() + mouse.position
		popup_panel.popup(Rect2(p.x, p.y, 0.0, 0.0))
