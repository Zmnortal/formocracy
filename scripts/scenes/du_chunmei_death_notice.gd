extends Control

const PRE_WORK_SCENE := "res://scenes/pre_work_sequence.tscn"
const PIXEL_FONT := preload("res://assets/fonts/unifont/unifont_ui.tres")
const CINEMATIC_PATH := "res://data/narrative/cinematics/du_chunmei_death.json"
const VIEWPORT_SIZE := Vector2(1280.0, 720.0)

var shots: Array[Dictionary] = []
var cinematic_stage: Control
var frame_image: TextureRect
var fade_layer: ColorRect
var caption_label: Label
var progress_label: Label
var advance_label: Label
var skip_button: Button
var shot_index := 0
var camera_tween: Tween
var transition_tween: Tween
var is_transitioning := false


func _ready() -> void:
	RenderingServer.set_default_clear_color(Color.BLACK)
	_load_cinematic()
	_build_scene()
	_fit_cinematic_stage()
	_show_shot(0, true)


func _load_cinematic() -> void:
	var source := FileAccess.get_file_as_string(CINEMATIC_PATH)
	var parsed: Variant = JSON.parse_string(source)
	if not parsed is Dictionary:
		push_error("Unable to load cinematic configuration: %s" % CINEMATIC_PATH)
		return
	var raw_shots: Variant = (parsed as Dictionary).get("shots", [])
	if not raw_shots is Array:
		push_error("Cinematic shots must be an array: %s" % CINEMATIC_PATH)
		return
	for entry: Variant in raw_shots:
		if entry is Dictionary:
			shots.append((entry as Dictionary).duplicate(true))


func _build_scene() -> void:
	var backdrop := ColorRect.new()
	backdrop.color = Color.BLACK
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)

	cinematic_stage = Control.new()
	cinematic_stage.name = "CinematicStage"
	cinematic_stage.size = VIEWPORT_SIZE
	cinematic_stage.clip_contents = true
	cinematic_stage.mouse_filter = Control.MOUSE_FILTER_STOP
	cinematic_stage.gui_input.connect(_on_stage_gui_input)
	add_child(cinematic_stage)

	frame_image = TextureRect.new()
	frame_image.name = "FrameImage"
	frame_image.position = Vector2.ZERO
	frame_image.size = VIEWPORT_SIZE
	frame_image.pivot_offset = VIEWPORT_SIZE * 0.5
	frame_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	frame_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	frame_image.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	frame_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cinematic_stage.add_child(frame_image)

	var vignette := ColorRect.new()
	vignette.name = "Vignette"
	vignette.color = Color(0.0, 0.0, 0.0, 0.12)
	vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cinematic_stage.add_child(vignette)

	var caption_backdrop := ColorRect.new()
	caption_backdrop.color = Color(0.015, 0.018, 0.016, 0.82)
	caption_backdrop.position = Vector2(0, 578)
	caption_backdrop.size = Vector2(1280, 142)
	caption_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cinematic_stage.add_child(caption_backdrop)

	caption_label = Label.new()
	caption_label.name = "Caption"
	caption_label.position = Vector2(110, 606)
	caption_label.size = Vector2(1060, 48)
	caption_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_style_label(caption_label, 28, Color("#eee7d3"))
	caption_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cinematic_stage.add_child(caption_label)

	progress_label = Label.new()
	progress_label.name = "Progress"
	progress_label.position = Vector2(36, 30)
	progress_label.size = Vector2(210, 24)
	_style_label(progress_label, 13, Color("#d0c5a5"))
	progress_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cinematic_stage.add_child(progress_label)

	advance_label = Label.new()
	advance_label.name = "AdvanceHint"
	advance_label.position = Vector2(960, 672)
	advance_label.size = Vector2(276, 26)
	advance_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_style_label(advance_label, 14, Color("#9e9887"))
	advance_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cinematic_stage.add_child(advance_label)

	skip_button = Button.new()
	skip_button.name = "SkipButton"
	skip_button.text = "跳过  »"
	skip_button.position = Vector2(1132, 24)
	skip_button.size = Vector2(104, 36)
	skip_button.add_theme_font_override("font", PIXEL_FONT)
	skip_button.add_theme_font_size_override("font_size", 14)
	skip_button.add_theme_color_override("font_color", Color("#c8c0aa"))
	skip_button.add_theme_stylebox_override("normal", _panel_style(Color(0.02, 0.025, 0.022, 0.7), Color("#625d4e"), 1))
	skip_button.add_theme_stylebox_override("hover", _panel_style(Color(0.08, 0.085, 0.072, 0.9), Color("#a99a72"), 1))
	skip_button.pressed.connect(skip_cinematic)
	cinematic_stage.add_child(skip_button)

	fade_layer = ColorRect.new()
	fade_layer.name = "FadeLayer"
	fade_layer.color = Color.BLACK
	fade_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fade_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cinematic_stage.add_child(fade_layer)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and is_instance_valid(cinematic_stage):
		_fit_cinematic_stage()


func _fit_cinematic_stage() -> void:
	if not is_instance_valid(cinematic_stage):
		return
	var viewport_size := get_viewport_rect().size
	var fit_scale := minf(
		viewport_size.x / VIEWPORT_SIZE.x,
		viewport_size.y / VIEWPORT_SIZE.y
	)
	cinematic_stage.scale = Vector2.ONE * fit_scale
	cinematic_stage.position = (viewport_size - VIEWPORT_SIZE * fit_scale) * 0.5


func _show_shot(index: int, initial := false) -> void:
	if shots.is_empty():
		_finish_cinematic()
		return
	shot_index = clampi(index, 0, shots.size() - 1)
	var shot := shots[shot_index]
	var image_path := str(shot.get("image", ""))
	frame_image.texture = load(image_path) as Texture2D
	caption_label.text = str(shot.get("caption", ""))
	progress_label.text = "DAY 07  /  %02d—%02d" % [shot_index + 1, shots.size()]
	advance_label.text = "点击继续第 07 工作日" if shot_index == shots.size() - 1 else "点击画面继续"
	_start_camera_move(shot)
	if initial:
		fade_layer.modulate.a = 1.0
		var reveal := create_tween()
		reveal.tween_property(fade_layer, "modulate:a", 0.0, 0.55)


func _start_camera_move(shot: Dictionary) -> void:
	if camera_tween and camera_tween.is_valid():
		camera_tween.kill()
	var start_zoom := float(shot.get("start_zoom", 1.0))
	var end_zoom := float(shot.get("end_zoom", start_zoom))
	var start_offset := _read_vector(shot.get("start_offset", [0, 0]))
	var end_offset := _read_vector(shot.get("end_offset", [0, 0]))
	var duration := float(shot.get("duration", 6.0))
	frame_image.scale = Vector2.ONE * start_zoom
	frame_image.position = start_offset
	camera_tween = create_tween().set_parallel(true)
	camera_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	camera_tween.tween_property(frame_image, "scale", Vector2.ONE * end_zoom, duration)
	camera_tween.tween_property(frame_image, "position", end_offset, duration)


func _read_vector(value: Variant) -> Vector2:
	if value is Array and (value as Array).size() >= 2:
		var values := value as Array
		return Vector2(float(values[0]), float(values[1]))
	return Vector2.ZERO


func advance_cinematic() -> void:
	if is_transitioning:
		return
	if shot_index + 1 >= shots.size():
		_finish_cinematic()
		return
	is_transitioning = true
	if camera_tween and camera_tween.is_valid():
		camera_tween.kill()
	if transition_tween and transition_tween.is_valid():
		transition_tween.kill()
	transition_tween = create_tween()
	transition_tween.tween_property(fade_layer, "modulate:a", 1.0, 0.2)
	transition_tween.tween_callback(_switch_to_next_shot)
	transition_tween.tween_property(fade_layer, "modulate:a", 0.0, 0.28)
	transition_tween.tween_callback(_finish_transition)


func _switch_to_next_shot() -> void:
	_show_shot(shot_index + 1)


func _finish_transition() -> void:
	is_transitioning = false


func skip_cinematic() -> void:
	if is_transitioning:
		return
	_finish_cinematic()


func _finish_cinematic() -> void:
	WorkdayState.narrative_flags["du_chunmei_notice_seen"] = true
	if WorkdayState.persistence_enabled:
		WorkdayState.save_progress()
	Sfx.play("start")
	var error := get_tree().change_scene_to_file(PRE_WORK_SCENE)
	if error != OK:
		caption_label.text = "进入第 07 工作日失败：%s" % error_string(error)


func _on_stage_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
			advance_cinematic()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		advance_cinematic()
		get_viewport().set_input_as_handled()


func _style_label(label: Label, font_size: int, color: Color) -> void:
	label.add_theme_font_override("font", PIXEL_FONT)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)


func _panel_style(fill: Color, border: Color, width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(width)
	return style
