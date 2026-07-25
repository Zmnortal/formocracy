class_name AfterWorkProprietorScene
extends Control

const UI := preload("res://scripts/ui/bureau_ui.gd")
const DESIGN_SIZE := Vector2(1280, 720)
const MAP_SCENE := "res://scenes/evening_map.tscn"
const BUTTON_NORMAL := preload("res://assets/ui/after_work_buttons/button_normal.png")
const BUTTON_HOVER := preload("res://assets/ui/after_work_buttons/button_hover.png")
const BUTTON_PRESSED := preload("res://assets/ui/after_work_buttons/button_pressed.png")
const BUTTON_DISABLED := preload("res://assets/ui/after_work_buttons/button_disabled.png")

var background_texture: Texture2D
var proprietor_textures: Dictionary
var proprietor_name := ""
var location_title := ""
var greeting := ""
var idle_lines: Array[String] = []
var actions: Array[Dictionary] = []

var shade: ColorRect
var proprietor: TextureRect
var left_actions: VBoxContainer
var right_actions: VBoxContainer
var dialogue_box: DialogueBox
var balance_label: Label
var focused := true


func _ready() -> void:
	_configure_scene()
	_build_scene()
	_show_focus(greeting, "talk")
	get_viewport().size_changed.connect(_fit_to_window)
	_fit_to_window()


func _configure_scene() -> void:
	push_error("AfterWorkProprietorScene requires _configure_scene()")


func _handle_action(_action_id: String) -> void:
	pass


func _build_scene() -> void:
	custom_minimum_size = DESIGN_SIZE

	var backdrop := TextureRect.new()
	backdrop.name = "LocationBackground"
	backdrop.texture = background_texture
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	backdrop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	backdrop.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)

	shade = ColorRect.new()
	shade.name = "FocusShade"
	shade.color = Color(0.015, 0.025, 0.026, 0.6)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)

	var title := _make_label(location_title, 25, Color("c9b66f"))
	title.position = Vector2(42, 30)
	title.size = Vector2(720, 42)
	add_child(title)

	balance_label = _make_label("", 16, Color("bdb58c"))
	balance_label.position = Vector2(900, 38)
	balance_label.size = Vector2(320, 30)
	balance_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(balance_label)
	_refresh_balance()

	proprietor = TextureRect.new()
	proprietor.name = "Proprietor"
	proprietor.position = Vector2(480, 105)
	proprietor.size = Vector2(320, 440)
	proprietor.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	proprietor.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	proprietor.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	proprietor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(proprietor)

	left_actions = _make_action_column(Vector2(44, 170))
	right_actions = _make_action_column(Vector2(956, 170))
	add_child(left_actions)
	add_child(right_actions)
	_build_actions()

	var chat_button := _make_button("随便聊两句")
	chat_button.position = Vector2(44, 642)
	chat_button.size = Vector2(220, 46)
	chat_button.pressed.connect(_chat)
	add_child(chat_button)

	var map_button := _make_button("返回夜间地图")
	map_button.position = Vector2(1016, 642)
	map_button.size = Vector2(220, 46)
	map_button.pressed.connect(_return_to_map)
	add_child(map_button)

	dialogue_box = DialogueBox.new()
	add_child(dialogue_box)
	dialogue_box.advance_requested.connect(dialogue_box.close)


func _build_actions() -> void:
	for action in actions:
		var side := String(action.get("side", "left"))
		var direction := -1 if side == "right" else 1
		var item := Control.new()
		item.name = "ActionItem"
		item.custom_minimum_size = Vector2(280, 52)
		item.clip_contents = false
		var button := _make_button(String(action.get("label", "未命名操作")))
		button.name = "ActionButton"
		button.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_attach_paper_tag(
			button,
			item,
			String(action.get("description", "按下后办理这项事务")),
			direction
		)
		item.add_child(button)
		var action_id := String(action.get("id", ""))
		button.pressed.connect(func(): _handle_action(action_id))
		if side == "right":
			right_actions.add_child(item)
		else:
			left_actions.add_child(item)


func _make_action_column(at: Vector2) -> VBoxContainer:
	var column := VBoxContainer.new()
	column.position = at
	column.size = Vector2(280, 360)
	column.add_theme_constant_override("separation", 18)
	return column


func _make_button(text_value: String) -> Button:
	var button := Button.new()
	button.text = text_value
	button.clip_contents = false
	button.add_theme_font_override("font", UI.PIXEL_FONT)
	button.add_theme_font_size_override("font_size", 16)
	button.add_theme_color_override("font_color", Color("c9c7b8"))
	button.add_theme_color_override("font_hover_color", Color("e4dfc5"))
	button.add_theme_color_override("font_pressed_color", Color("c7c9ba"))
	button.add_theme_color_override("font_disabled_color", Color("777b76"))
	button.add_theme_color_override("font_outline_color", Color(0.02, 0.025, 0.022, 0.95))
	button.add_theme_constant_override("outline_size", 3)
	button.add_theme_constant_override("h_separation", 10)
	button.add_theme_stylebox_override("normal", _make_button_style(BUTTON_NORMAL))
	button.add_theme_stylebox_override("hover", _make_button_style(BUTTON_HOVER))
	button.add_theme_stylebox_override("focus", _make_button_style(BUTTON_HOVER))
	button.add_theme_stylebox_override("pressed", _make_button_style(BUTTON_PRESSED, 3.0))
	button.add_theme_stylebox_override("disabled", _make_button_style(BUTTON_DISABLED))
	button.pivot_offset = button.size * 0.5
	button.mouse_entered.connect(func(): _animate_button(button, true))
	button.mouse_exited.connect(func(): _animate_button(button, false))
	return button


func _attach_paper_tag(button: Button, host: Control, description: String, direction: int) -> void:
	if description.is_empty():
		return

	var tag := PanelContainer.new()
	tag.name = "PaperTag"
	tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tag.custom_minimum_size = Vector2(190, 42)
	tag.size = Vector2(190, 42)

	var paper := StyleBoxFlat.new()
	paper.bg_color = Color("d8cfad")
	paper.border_color = Color("817858")
	paper.set_border_width_all(2)
	paper.corner_radius_top_left = 2
	paper.corner_radius_top_right = 2
	paper.corner_radius_bottom_left = 2
	paper.corner_radius_bottom_right = 2
	paper.shadow_color = Color(0.02, 0.025, 0.02, 0.42)
	paper.shadow_size = 4
	paper.content_margin_left = 12
	paper.content_margin_right = 12
	paper.content_margin_top = 7
	paper.content_margin_bottom = 6
	tag.add_theme_stylebox_override("panel", paper)

	var note := Label.new()
	note.text = description
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	note.add_theme_font_override("font", UI.PIXEL_FONT)
	note.add_theme_font_size_override("font_size", 11)
	note.add_theme_color_override("font_color", Color("393a30"))
	tag.add_child(note)

	var hidden_x := 82.0 if direction > 0 else 8.0
	var shown_x := 268.0 if direction > 0 else -178.0
	tag.position = Vector2(hidden_x, 5)
	tag.modulate = Color(0.82, 0.8, 0.68, 0.0)
	tag.set_meta("hidden_position", Vector2(hidden_x, 5))
	tag.set_meta("shown_position", Vector2(shown_x, 5))
	button.set_meta("paper_tag", tag)
	host.add_child(tag)


func _make_button_style(texture: Texture2D, pressed_offset := 0.0) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = texture
	style.texture_margin_left = 44.0
	style.texture_margin_top = 18.0
	style.texture_margin_right = 18.0
	style.texture_margin_bottom = 18.0
	style.content_margin_left = 46.0
	style.content_margin_top = 10.0 + pressed_offset
	style.content_margin_right = 18.0
	style.content_margin_bottom = 10.0 - pressed_offset
	style.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	style.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	return style


func _animate_button(button: Button, hovered: bool) -> void:
	if button.disabled:
		return
	button.pivot_offset = button.size * 0.5
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(button, "scale", Vector2(1.012, 1.012) if hovered else Vector2.ONE, 0.08)
	var tag := button.get_meta("paper_tag", null) as PanelContainer
	if tag == null:
		return
	var destination: Vector2 = tag.get_meta("shown_position") if hovered else tag.get_meta("hidden_position")
	var tag_tween := create_tween().set_parallel(true)
	tag_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tag_tween.tween_property(tag, "position", destination, 0.16 if hovered else 0.12)
	tag_tween.tween_property(
		tag,
		"modulate",
		Color(1, 1, 1, 1) if hovered else Color(0.82, 0.8, 0.68, 0.0),
		0.11
	)


func _make_label(text_value: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text_value
	UI.style_label(label, font_size)
	label.add_theme_color_override("font_color", color)
	return label


func _show_focus(text: String, state := "talk", speaker_kind := "npc") -> void:
	focused = true
	shade.visible = true
	left_actions.visible = true
	right_actions.visible = true
	proprietor.position = Vector2(430, 82)
	proprietor.size = Vector2(420, 520)
	_set_proprietor_state(state)
	dialogue_box.show_line(proprietor_name, text, speaker_kind)


func _show_feedback(text: String, success: bool) -> void:
	_show_focus(text, "success" if success else "reject", "npc" if success else "warning")
	_refresh_balance()


func _set_proprietor_state(state: String) -> void:
	proprietor.texture = proprietor_textures.get(state, proprietor_textures.get("idle"))


func _chat() -> void:
	var line := greeting
	if not idle_lines.is_empty():
		line = idle_lines[randi() % idle_lines.size()]
	_show_focus(line, "talk")


func _refresh_balance() -> void:
	balance_label.text = "账户余额  %03d 配给券" % WorkdayState.balance


func _return_to_map() -> void:
	get_tree().change_scene_to_file(MAP_SCENE)


func _fit_to_window() -> void:
	var viewport_size := get_viewport_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return
	scale = Vector2(viewport_size.x / DESIGN_SIZE.x, viewport_size.y / DESIGN_SIZE.y)
	position = Vector2.ZERO
