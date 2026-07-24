class_name SecretaryBriefingController
extends RefCounted

signal finished

const VOICE_PATH := "res://assets/audio/sfx/people_female_old.wav"

var root: Node2D
var panel: Panel
var label: Label
var token := 0
var playing := false


func _init(owner_root: Node2D) -> void:
	root = owner_root
	panel = Panel.new()
	panel.name = "SecretaryBroadcast"
	panel.position = Vector2(360, 92)
	panel.size = Vector2(560, 118)
	panel.z_index = 55
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override(
		"panel",
		WorkbenchUI.style_box(Color(0.025, 0.035, 0.03, 0.97), 5, Color("8f9b65"), 2)
	)
	root.add_child(panel)
	WorkbenchUI.add_text(panel, "内部广播 / 来源未登记", 13, Color("8f9b65"), Vector2(18, 12), Vector2(520, 22))
	label = WorkbenchUI.add_text(panel, "", 18, Color("ddd4b7"), Vector2(18, 40), Vector2(524, 62))
	panel.visible = false


func play(lines: Array[String]) -> void:
	token += 1
	var current_token := token
	playing = true
	panel.visible = true
	var bridge := root.get_tree().root.get_node_or_null("RealityBridge")
	if bridge != null and not lines.is_empty():
		bridge.morning_briefing(
			WorkdayState.day_number,
			lines,
			"第十二区 · 工作日晨间指令"
		)
	for line in lines:
		if current_token != token:
			return
		label.text = line
		GameStateSync.speaker_started(
			"SECRETARY",
			"内部广播 / 来源未登记",
			"secretary",
			line,
			"secretary_briefing",
			{"day": WorkdayState.day_number}
		)
		Sfx.play_voice("SECRETARY", VOICE_PATH)
		await root.get_tree().create_timer(clampf(1.2 + line.length() * 0.045, 2.0, 4.2)).timeout
	if current_token != token:
		return
	playing = false
	panel.visible = false
	GameStateSync.speaker_stopped("waiting_for_call")
	Sfx.stop_voice()
	finished.emit()


func skip() -> void:
	if not playing:
		return
	token += 1
	playing = false
	panel.visible = false
	GameStateSync.speaker_stopped("waiting_for_call")
	Sfx.stop_voice()
	finished.emit()


func shutdown() -> void:
	token += 1
	playing = false
	GameStateSync.speaker_stopped("scene_exiting")
	Sfx.stop_voice()
