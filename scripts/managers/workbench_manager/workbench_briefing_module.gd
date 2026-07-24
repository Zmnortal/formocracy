class_name WorkbenchBriefingModule
extends RefCounted

signal finished

const VOICE_PATH := "res://assets/audio/sfx/people_female_old.wav"

var root: Node2D
var panel: Panel
var label: Label
var token := 0
var playing := false


# 创建内部广播面板并挂载到宿主节点。
func _init(owner_root: Node2D) -> void:
	root = owner_root
	panel = Panel.new()
	panel.name = "SecretaryBroadcast"
	panel.position = Vector2(360, 92)
	panel.size = Vector2(560, 118)
	panel.z_index = 55
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", WorkbenchUI.style_box(Color(0.025, 0.035, 0.03, 0.97), 5, Color("8f9b65"), 2))
	root.add_child(panel)
	WorkbenchUI.add_text(panel, "内部广播 / 来源未登记", 13, Color("8f9b65"), Vector2(18, 12), Vector2(520, 22))
	label = WorkbenchUI.add_text(panel, "", 18, Color("ddd4b7"), Vector2(18, 40), Vector2(524, 62))
	panel.visible = false


# 逐句播报晨间指令台词，完成后隐藏面板并发出结束信号。
func play(lines: Array[String]) -> void:
	token += 1
	var current_token := token
	playing = true
	panel.visible = true
	var bridge := root.get_tree().root.get_node_or_null("RealityBridge")
	if bridge != null and not lines.is_empty():
		bridge.call("morning_briefing", WorkdayState.day_number, lines, "第十二区 · 工作日晨间指令")
	for line in lines:
		if current_token != token:
			return
		label.text = line
		GameStateSync.speaker_started("SECRETARY", "内部广播 / 来源未登记", "secretary", line, "secretary_briefing", {"day": WorkdayState.day_number})
		Sfx.play_voice("SECRETARY", VOICE_PATH)
		await root.get_tree().create_timer(clampf(1.2 + line.length() * 0.045, 2.0, 4.2)).timeout
	if current_token != token:
		return
	playing = false
	panel.visible = false
	GameStateSync.speaker_stopped("waiting_for_call")
	Sfx.stop_voice()
	finished.emit()


# 跳过正在播报的台词并立即发出结束信号。
func skip() -> void:
	if not playing:
		return
	token += 1
	playing = false
	panel.visible = false
	GameStateSync.speaker_stopped("waiting_for_call")
	Sfx.stop_voice()
	finished.emit()


# 停止播报与语音，用于场景退出时的清理。
func shutdown() -> void:
	token += 1
	playing = false
	GameStateSync.speaker_stopped("scene_exiting")
	Sfx.stop_voice()
