class_name WorkbenchBriefingModule
extends RefCounted

signal finished

var root: Node2D
var dialogue_box: DialogueBox
var token := 0
var playing := false


# 接收工作台唯一的底部对话框；广播不再创建顶部专用面板。
func _init(owner_root: Node2D, shared_dialogue_box: DialogueBox) -> void:
	root = owner_root
	dialogue_box = shared_dialogue_box


# 逐句显示晨间指令；每一句都必须等待玩家补全并再次确认后才继续。
func play(lines: Array[String]) -> void:
	token += 1
	var current_token := token
	playing = true
	var bridge := root.get_tree().root.get_node_or_null("RealityBridge")
	if bridge != null and not lines.is_empty():
		bridge.call("morning_briefing", WorkdayState.day_number, lines, "第十二区 · 工作日晨间指令")
	await Sfx.duck_ambience_for_broadcast()
	if current_token != token:
		return
	Sfx.play("call_intercom")
	for line in lines:
		if current_token != token:
			return
		GameStateSync.speaker_started("SECRETARY", "内部广播 / 来源未登记", "secretary", line, "secretary_briefing", {"day": WorkdayState.day_number})
		await dialogue_box.play_line("内部广播 / 来源未登记", line, "broadcast")
	if current_token != token:
		return
	playing = false
	dialogue_box.close()
	GameStateSync.speaker_stopped("waiting_for_call")
	Sfx.stop_voice()
	Sfx.restore_work_ambience()
	finished.emit()


# 跳过正在播报的台词并立即发出结束信号。
func skip() -> void:
	if not playing:
		return
	token += 1
	playing = false
	dialogue_box.close()
	GameStateSync.speaker_stopped("waiting_for_call")
	Sfx.stop_voice()
	Sfx.restore_work_ambience(0.2)
	finished.emit()


# 停止播报与语音，用于场景退出时的清理。
func shutdown() -> void:
	token += 1
	playing = false
	if dialogue_box != null:
		dialogue_box.close()
	GameStateSync.speaker_stopped("scene_exiting")
	Sfx.stop_voice()
