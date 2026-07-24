class_name NpcPerformanceController
extends RefCounted

# NPC 排队与窗口演出控制器。
# 使用现有呼吸帧作为首版降级素材，负责进场、自动台词、递交、等待、结果反应与离场。

signal delivery_finished
signal departure_finished

const FRAME_PATHS := [
	"res://assets/characters/idle_breathing/frame-00.png",
	"res://assets/characters/idle_breathing/frame-01.png",
	"res://assets/characters/idle_breathing/frame-02.png",
	"res://assets/characters/idle_breathing/frame-03.png",
	"res://assets/characters/idle_breathing/frame-04.png",
	"res://assets/characters/idle_breathing/frame-05.png",
]

var root: Node2D
var actor_layer: Node2D
var current_actor: AnimatedSprite2D
var queue_actors: Array[Sprite2D] = []
var speech_bubble: Panel
var speech_label: Label
var state := "IDLE"
var current_case: Dictionary = {}
var performance_token := 0
var waiting_line_shown := false
var skip_requested := false


func _init(owner_root: Node2D) -> void:
	root = owner_root
	_build_layer()


func _build_layer() -> void:
	actor_layer = Node2D.new()
	actor_layer.name = "NpcPerformanceLayer"
	actor_layer.z_index = 2
	root.add_child(actor_layer)

	speech_bubble = Panel.new()
	speech_bubble.name = "NpcSpeechBubble"
	speech_bubble.position = Vector2(405, 118)
	speech_bubble.size = Vector2(330, 104)
	speech_bubble.z_index = 34
	speech_bubble.visible = false
	speech_bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	speech_bubble.add_theme_stylebox_override(
		"panel",
		WorkbenchUI.style_box(Color(0.035, 0.04, 0.032, 0.96), 5, Color("a78a52"), 2)
	)
	root.add_child(speech_bubble)
	speech_label = WorkbenchUI.add_text(
		speech_bubble,
		"",
		16,
		Color("e1d5b6"),
		Vector2(18, 14),
		Vector2(294, 76)
	)


func start_case(case_data: Dictionary, queued_case_ids: Array[String]) -> void:
	performance_token += 1
	var token := performance_token
	_stop_audio()
	current_case = case_data
	waiting_line_shown = false
	skip_requested = false
	_clear_actors()
	_build_queue(queued_case_ids)
	current_actor = _make_actor(case_data.get("person", {}))
	current_actor.position = Vector2(245, 330)
	current_actor.scale *= 0.72
	current_actor.modulate.a = 0.42
	actor_layer.add_child(current_actor)
	current_actor.play("idle")
	state = "WALKING_IN"
	Sfx.start_walking()

	var enter := root.create_tween().set_parallel(true)
	enter.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	enter.tween_property(current_actor, "position", Vector2(370, 292), 0.62)
	enter.tween_property(current_actor, "scale", current_actor.scale / 0.72, 0.62)
	enter.tween_property(current_actor, "modulate:a", 1.0, 0.5)
	await enter.finished
	Sfx.stop_walking()
	if token != performance_token:
		return

	state = "GREETING"
	await _say(String(case_data.get("dialogue", {}).get("greeting", "您好，我来办理事项。")), token)
	if token != performance_token:
		return
	state = "DELIVERING"
	var deliver := root.create_tween().set_parallel(true)
	deliver.tween_property(current_actor, "position", Vector2(388, 302), 0.18)
	deliver.tween_property(current_actor, "rotation", -0.035, 0.18)
	await deliver.finished
	if token != performance_token:
		return
	Sfx.play("ui_switch", -5.0, 0.82)
	await _say(String(case_data.get("dialogue", {}).get("delivery", "材料都在这里。")), token)
	if token != performance_token:
		return
	delivery_finished.emit()
	state = "WAITING"
	var settle := root.create_tween().set_parallel(true)
	settle.tween_property(current_actor, "position", Vector2(370, 292), 0.2)
	settle.tween_property(current_actor, "rotation", 0.0, 0.2)
	_schedule_waiting_line(token)


func _schedule_waiting_line(token: int) -> void:
	var delay := float(current_case.get("dialogue", {}).get("waiting_delay_seconds", 8.0))
	await root.get_tree().create_timer(delay).timeout
	if token != performance_token or state != "WAITING" or waiting_line_shown:
		return
	waiting_line_shown = true
	await _say(String(current_case.get("dialogue", {}).get("waiting", "")), token)


func react_and_leave(decision: String) -> void:
	performance_token += 1
	var token := performance_token
	state = "REACTING"
	speech_bubble.visible = false
	if not is_instance_valid(current_actor):
		departure_finished.emit()
		return
	var approved := decision == "批准"
	var reaction := root.create_tween().set_parallel(true)
	reaction.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	reaction.tween_property(
		current_actor,
		"position",
		current_actor.position + (Vector2(0, -8) if approved else Vector2(-12, 13)),
		0.22
	)
	reaction.tween_property(current_actor, "scale", current_actor.scale * (1.025 if approved else 0.95), 0.22)
	await reaction.finished
	var line_key := "approved" if approved else "rejected"
	await _say(String(current_case.get("dialogue", {}).get(line_key, "我知道了。")), token)
	if token != performance_token:
		return
	state = "WALKING_OUT"
	Sfx.start_walking()
	var exit := root.create_tween().set_parallel(true)
	exit.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	exit.tween_property(current_actor, "position", Vector2(205, 335), 0.58)
	exit.tween_property(current_actor, "scale", current_actor.scale * 0.68, 0.58)
	exit.tween_property(current_actor, "modulate:a", 0.0, 0.48)
	await exit.finished
	Sfx.stop_walking()
	if token != performance_token:
		return
	state = "QUEUE_ADVANCING"
	await _advance_queue()
	state = "IDLE"
	departure_finished.emit()


func skip_current_performance() -> void:
	skip_requested = true
	speech_bubble.visible = false
	_stop_audio()
	if state in ["WALKING_IN", "GREETING", "DELIVERING"]:
		performance_token += 1
		state = "WAITING"
		if is_instance_valid(current_actor):
			current_actor.position = Vector2(370, 292)
			current_actor.modulate.a = 1.0
		delivery_finished.emit()
	elif state in ["REACTING", "WALKING_OUT", "QUEUE_ADVANCING"]:
		performance_token += 1
		state = "IDLE"
		departure_finished.emit()


func shutdown() -> void:
	performance_token += 1
	speech_bubble.visible = false
	_stop_audio()


func _say(text: String, token: int) -> void:
	if text.strip_edges().is_empty() or skip_requested:
		return
	speech_label.text = text
	var person: Dictionary = current_case.get("person", {})
	_send_line_to_glass(person, text)
	speech_bubble.modulate.a = 0.0
	speech_bubble.visible = true
	_play_voice()
	var show := root.create_tween()
	show.tween_property(speech_bubble, "modulate:a", 1.0, 0.12)
	await show.finished
	var duration := clampf(1.35 + text.length() * 0.055, 1.8, 3.8)
	await root.get_tree().create_timer(duration).timeout
	if token != performance_token:
		return
	var hide := root.create_tween()
	hide.tween_property(speech_bubble, "modulate:a", 0.0, 0.14)
	await hide.finished
	if token == performance_token:
		speech_bubble.visible = false


func _send_line_to_glass(person: Dictionary, text: String) -> void:
	var bridge := root.get_tree().root.get_node_or_null("RealityBridge")
	if bridge == null:
		return
	var voice_source := String(person.get("voice_sfx", "")).to_lower()
	var visual_source := String(person.get("actor_texture", "")).to_lower()
	var identity_source := voice_source + " " + visual_source
	var gender := ""
	if identity_source.contains("female"):
		gender = "female"
	elif identity_source.contains("male"):
		gender = "male"
	var age := ""
	for source in [voice_source, visual_source]:
		for candidate in ["young", "average", "old"]:
			if source.contains(candidate):
				age = candidate
				break
		if not age.is_empty():
			break
	bridge.npc_line(
		String(person.get("display_name", current_case.get("applicant", "身份受限"))),
		text,
		gender,
		age
	)


func _build_queue(case_ids: Array[String]) -> void:
	var positions := [Vector2(255, 315), Vector2(205, 300), Vector2(165, 287)]
	var scales := [0.18, 0.15, 0.13]
	for i in mini(case_ids.size(), 3):
		var queued_case := ConfigDatabase.get_gameplay_case(case_ids[i])
		var person: Dictionary = queued_case.get("person", {})
		var sprite := Sprite2D.new()
		sprite.texture = load(FRAME_PATHS[0])
		sprite.position = positions[i]
		sprite.scale = Vector2.ONE * scales[i]
		var tint := Color(String(person.get("actor_tint", "8f948b")))
		tint.a = 0.28 - i * 0.05
		sprite.modulate = tint
		sprite.z_index = -i - 1
		actor_layer.add_child(sprite)
		queue_actors.append(sprite)


func _advance_queue() -> void:
	if queue_actors.is_empty():
		return
	var tween := root.create_tween().set_parallel(true)
	for actor in queue_actors:
		tween.tween_property(actor, "position", actor.position + Vector2(38, 8), 0.32)
		tween.tween_property(actor, "modulate:a", minf(actor.modulate.a + 0.08, 0.42), 0.32)
	await tween.finished


func _make_actor(person: Dictionary) -> AnimatedSprite2D:
	var sprite := AnimatedSprite2D.new()
	var frames := SpriteFrames.new()
	frames.add_animation("idle")
	frames.set_animation_loop("idle", true)
	frames.set_animation_speed("idle", 5.0)
	for path in FRAME_PATHS:
		var texture: Texture2D = load(path)
		if texture != null:
			frames.add_frame("idle", texture)
	sprite.sprite_frames = frames
	sprite.centered = true
	var configured_scale := float(person.get("actor_scale", 0.34))
	sprite.scale = Vector2.ONE * configured_scale
	sprite.modulate = Color(String(person.get("actor_tint", "ffffff")))
	return sprite


func _clear_actors() -> void:
	_stop_audio()
	speech_bubble.visible = false
	if is_instance_valid(current_actor):
		current_actor.queue_free()
	current_actor = null
	for actor in queue_actors:
		if is_instance_valid(actor):
			actor.queue_free()
	queue_actors.clear()


func _play_voice() -> void:
	var person: Dictionary = current_case.get("person", {})
	Sfx.play_voice(String(person.get("id", "")), String(person.get("voice_sfx", "")))


func _stop_audio() -> void:
	Sfx.stop_voice()
	Sfx.stop_walking()
