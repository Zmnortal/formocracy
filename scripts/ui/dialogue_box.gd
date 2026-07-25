class_name DialogueBox
extends Control

# 全场景共用的底部对话框。
# 台词只会经过 TYPING → WAITING_FOR_INPUT，绝不依靠计时器自动进入下一句。

signal line_completed
signal advance_requested

enum DialogueState {
	HIDDEN,
	TYPING,
	WAITING_FOR_INPUT,
}

const DESIGN_SIZE := Vector2(1280.0, 720.0)
const PANEL_POSITION := Vector2(76.0, 532.0)
const PANEL_SIZE := Vector2(1128.0, 156.0)
const DEFAULT_CHARACTERS_PER_SECOND := 28.0
const UI := preload("res://scripts/ui/bureau_ui.gd")

var panel: Panel
var speaker_label: Label
var dialogue_label: Label
var advance_arrow: Label
var state := DialogueState.HIDDEN
var characters_per_second := DEFAULT_CHARACTERS_PER_SECOND
var full_text := ""
var line_id := 0
var resolution_id := 0
var _character_progress := 0.0
var _arrow_time := 0.0


# 构建固定贴底的统一对话框；根节点覆盖设计画布以吞掉对话期间的误操作。
func _ready() -> void:
	name = "DialogueBox"
	position = Vector2.ZERO
	size = DESIGN_SIZE
	mouse_filter = Control.MOUSE_FILTER_STOP
	# 表单、文件袋与场景 HUD 都可能在高层；对话必须始终位于普通场景 UI 最前。
	z_as_relative = false
	z_index = 4090
	_build_panel()
	visible = false
	set_process(true)
	set_process_unhandled_key_input(true)


# 创建说话人、逐字正文与完成箭头。
func _build_panel() -> void:
	panel = Panel.new()
	panel.name = "DialoguePanel"
	panel.position = PANEL_POSITION
	panel.size = PANEL_SIZE
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override(
		"panel",
		UI.make_box(Color(0.018, 0.026, 0.021, 0.985), Color("9a8750"), 3, 4)
	)
	add_child(panel)

	speaker_label = Label.new()
	speaker_label.name = "Speaker"
	speaker_label.position = Vector2(28, 16)
	speaker_label.size = Vector2(840, 30)
	UI.style_label(speaker_label, 19)
	speaker_label.add_theme_color_override("font_color", Color("d7c373"))
	panel.add_child(speaker_label)

	dialogue_label = Label.new()
	dialogue_label.name = "Dialogue"
	dialogue_label.position = Vector2(28, 50)
	dialogue_label.size = Vector2(1010, 78)
	dialogue_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dialogue_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	dialogue_label.visible_characters_behavior = TextServer.VC_CHARS_AFTER_SHAPING
	UI.style_label(dialogue_label, 18)
	dialogue_label.add_theme_color_override("font_color", Color("e2dcc2"))
	panel.add_child(dialogue_label)

	advance_arrow = Label.new()
	advance_arrow.name = "AdvanceArrow"
	advance_arrow.text = "▶"
	advance_arrow.position = Vector2(1048, 102)
	advance_arrow.size = Vector2(48, 34)
	advance_arrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UI.style_label(advance_arrow, 24)
	advance_arrow.add_theme_color_override("font_color", Color("e2c95f"))
	advance_arrow.visible = false
	panel.add_child(advance_arrow)


# 开始显示一句新台词；返回本句 ID，调用者可据此忽略已被替换的旧请求。
func show_line(speaker: String, text: String, speaker_kind := "npc") -> int:
	line_id += 1
	full_text = text
	speaker_label.text = speaker
	speaker_label.add_theme_color_override("font_color", _speaker_color(speaker_kind))
	dialogue_label.text = full_text
	dialogue_label.visible_characters = 0
	advance_arrow.visible = false
	advance_arrow.modulate.a = 1.0
	_character_progress = 0.0
	_arrow_time = 0.0
	state = DialogueState.TYPING
	visible = true
	return line_id


# 显示一句台词并暂停协程，直到玩家在箭头出现后再次按空格或左键。
func play_line(speaker: String, text: String, speaker_kind := "npc") -> void:
	var expected_line := show_line(speaker, text, speaker_kind)
	var expected_resolution := resolution_id
	while state != DialogueState.HIDDEN and line_id == expected_line and resolution_id == expected_resolution:
		await get_tree().process_frame


# 关闭当前台词并使所有旧的等待请求失效。
func close() -> void:
	line_id += 1
	resolution_id += 1
	state = DialogueState.HIDDEN
	full_text = ""
	dialogue_label.text = ""
	advance_arrow.visible = false
	visible = false


# 测试或紧急流程使用：立即补全当前台词，不推进到下一句。
func reveal_current_line() -> void:
	if state != DialogueState.TYPING:
		return
	dialogue_label.visible_characters = -1
	_character_progress = float(full_text.length())
	state = DialogueState.WAITING_FOR_INPUT
	advance_arrow.visible = true
	line_completed.emit()


# 逐帧吐字但不附加逐字电子音；完成后仅显示箭头并等待。
func _process(delta: float) -> void:
	if state == DialogueState.TYPING:
		_character_progress += delta * characters_per_second
		var target_count := mini(full_text.length(), floori(_character_progress))
		var old_count := maxi(dialogue_label.visible_characters, 0)
		if target_count > old_count:
			dialogue_label.visible_characters = target_count
		if target_count >= full_text.length():
			dialogue_label.visible_characters = -1
			state = DialogueState.WAITING_FOR_INPUT
			advance_arrow.visible = true
			line_completed.emit()
	elif state == DialogueState.WAITING_FOR_INPUT:
		_arrow_time += delta
		advance_arrow.modulate.a = lerpf(0.55, 1.0, (sin(_arrow_time * 5.0) + 1.0) * 0.5)


# 对话激活时吞掉左键；打字中先补全，完成后才发出推进信号。
func _gui_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
			accept_event()
			_handle_manual_advance()


# 空格键与左键遵循完全相同的两段式语义。
func _unhandled_key_input(event: InputEvent) -> void:
	if not visible or not event.is_pressed() or event.is_echo():
		return
	if event.is_action("ui_accept") or (event is InputEventKey and event.physical_keycode == KEY_SPACE):
		get_viewport().set_input_as_handled()
		_handle_manual_advance()


# 第一次操作补全本句，第二次操作才允许调用者继续流程。
func _handle_manual_advance() -> void:
	if state == DialogueState.TYPING:
		reveal_current_line()
	elif state == DialogueState.WAITING_FOR_INPUT:
		var sfx := get_node_or_null("/root/Sfx")
		if sfx != null:
			sfx.call("play", "ui_click")
		resolution_id += 1
		advance_requested.emit()


# 不同来源只改变说话人色彩，结构、位置与交互保持完全一致。
func _speaker_color(speaker_kind: String) -> Color:
	match speaker_kind:
		"broadcast", "system", "secretary":
			return Color("9fba74")
		"player":
			return Color("d8d1a8")
		"warning":
			return Color("d98168")
		_:
			return Color("d7c373")
