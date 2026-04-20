class_name MMDataMode

enum Mode {
	TransformOnly,
	TransformAndVertexColor
}

static func get_data_mode_size(mode: Mode) -> int:
	match mode:
		Mode.TransformOnly:
			return 12
		Mode.TransformAndVertexColor:
			return 16
	return 12

static func get_data_mode_from_buffer_size(buffer_size) -> int:
	if buffer_size % MMDataMode.get_data_mode_size(MMDataMode.Mode.TransformOnly) == 0:
		return 12
	if buffer_size % MMDataMode.get_data_mode_size(MMDataMode.Mode.TransformAndVertexColor) == 0:
		return 16
	return 12
