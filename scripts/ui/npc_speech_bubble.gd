class_name NpcSpeechBubble
extends Panel

# 主玩法 NPC 专用气泡。
# 与底部对话框共享逐字节奏与击键音，但不阻塞操作，并在约五秒后自动淡出。

signal finished

const AUTO_HIDE_SECONDS := 5.0
const CHARACTERS_PER_SECOND := 28.0
const BUBBLE_POSITION := Vector2(535, 112)
const BUBBLE_SIZE := Vector2(310, 98)
const UI := preload("res://scripts/ui/bureau_ui.gd")

var speaker_label: Label
var dialogue_label: Label
var full_text := ""
var character_progress := 0.0
var typing := false
var playback_token := 0
var line_active := false


# 创建位于 NPC 人物附近的高层气泡。
func _ready() -> void:
	name = "NpcSpeechBubble"
	position = BUBBLE_POSITION
	size = BUBBLE_SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_as_relative = false
	z_index = 4080
	add_theme_stylebox_override(
		"panel",
		UI.make_box(Color(0.025, 0.032, 0.025, 0.97), Color("a78a52"), 3, 5)
	)
	var tail := Polygon2D.new()
	tail.name = "SpeechTail"
	tail.position = Vector2(90, 94)
	tail.polygon = PackedVector2Array([Vector2(0, 0), Vector2(40, 0), Vector2(16, 26)])
	tail.color = Color(0.025, 0.032, 0.025, 0.97)
	tail.z_index = -1
	add_child(tail)

	speaker_label = Label.new()
	speaker_label.position = Vector2(16, 9)
	speaker_label.size = Vector2(278, 24)
	UI.style_label(speaker_label, 15)
	speaker_label.add_theme_color_override("font_color", Color("d7c373"))
	add_child(speaker_label)

	dialogue_label = Label.new()
	dialogue_label.position = Vector2(16, 35)
	dialogue_label.size = Vector2(278, 54)
	dialogue_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dialogue_label.visible_characters_behavior = TextServer.VC_CHARS_AFTER_SHAPING
	UI.style_label(dialogue_label, 15)
	dialogue_label.add_theme_color_override("font_color", Color("e1d5b6"))
	add_child(dialogue_label)
	visible = false


# 逐字显示一条 NPC 台词；玩家可点击补全或关闭，无操作时约五秒自动淡出。
func play_line(speaker: String, text: String) -> void:
	if line_active:
		close()
	playback_token += 1
	var expected_token := playback_token
	speaker_label.text = speaker
	full_text = text
	dialogue_label.text = full_text
	dialogue_label.visible_characters = 0
	character_progress = 0.0
	typing = true
	line_active = true
	modulate.a = 0.0
	visible = true
	var reveal := create_tween()
	reveal.tween_property(self, "modulate:a", 1.0, 0.12)
	_schedule_auto_hide(expected_token)
	await finished


# 当前台词无人操作时，维持约五秒后自动淡出。
func _schedule_auto_hide(expected_token: int) -> void:
	await get_tree().create_timer(AUTO_HIDE_SECONDS).timeout
	if expected_token != playback_token or not line_active:
		return
	typing = false
	var hide := create_tween()
	hide.tween_property(self, "modulate:a", 0.0, 0.18)
	await hide.finished
	if expected_token == playback_token:
		line_active = false
		visible = false
		finished.emit()


# 立即关闭气泡、解除等待者并取消旧台词的自动收束。
func close() -> void:
	playback_token += 1
	typing = false
	visible = false
	if line_active:
		line_active = false
		finished.emit()


# 第一次点击补全正在打印的台词；完整显示后的下一次点击立即关闭气泡。
func _handle_pointer_advance() -> void:
	if not line_active:
		return
	if typing:
		character_progress = float(full_text.length())
		dialogue_label.visible_characters = -1
		typing = false
		return
	close()


# 捕获屏幕任意位置的点击，让 NPC 台词无需等待自动消失。
func _input(event: InputEvent) -> void:
	if not visible or not line_active:
		return
	var pointer_pressed: bool = false
	if event is InputEventMouseButton:
		pointer_pressed = event.button_index == MOUSE_BUTTON_LEFT and event.pressed
	if event is InputEventScreenTouch:
		pointer_pressed = event.pressed
	if not pointer_pressed:
		return
	_handle_pointer_advance()
	get_viewport().set_input_as_handled()


# 按统一速度逐字显示，并为每个非空白字符播放短促击键音。
func _process(delta: float) -> void:
	if not typing or not visible:
		return
	character_progress += delta * CHARACTERS_PER_SECOND
	var target_count := mini(full_text.length(), floori(character_progress))
	var old_count := maxi(dialogue_label.visible_characters, 0)
	if target_count <= old_count:
		return
	dialogue_label.visible_characters = target_count
	for index in range(old_count, target_count):
		if not full_text[index].strip_edges().is_empty():
			var sfx := get_node_or_null("/root/Sfx")
			if sfx != null:
				sfx.call("dialogue_tick")
	if target_count >= full_text.length():
		dialogue_label.visible_characters = -1
		typing = false
