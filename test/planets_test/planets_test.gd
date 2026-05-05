extends Node3D

@onready var camera_3d: Camera3D = %Camera3D

var near_dist: float = 100.0
var far_dist: float = 250.0

func _ready() -> void:
	Engine.time_scale = 4.0
	camera_3d.position.z = near_dist
	var t : Tween = create_tween()
	t.tween_property(camera_3d, "position:z", far_dist, 5.0).set_delay(5.0)
	t.tween_property(camera_3d, "position:z", near_dist, 5.0).set_delay(5.0)
	t.tween_callback(get_tree().quit).set_delay(5.0)
