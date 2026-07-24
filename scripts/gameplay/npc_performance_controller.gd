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
const DEFAULT_ANIMATION_TABLE := "res://data/animations/default_applicant/animation_table.json"

var root: Node2D
var actor_layer: Node2D
var current_actor: AnimatedSprite2D
var animation_library: NpcAnimationLibrary
var animation_player: NpcAnimationPlayer
var queue_actors: Array[Sprite2D] = []
var speech_bubble: Panel
var speech_label: Label
var state := "IDLE"
var current_case: Dictionary = {}
var performance_token := 0
var waiting_line_shown := false
var skip_requested := false
var micro_expression_rng := RandomNumberGenerator.new()


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
	speech_bubble.position = Vector2(730, 112)
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
	current_actor.position = Vector2(520, 355)
	current_actor.scale *= 0.72
	current_actor.modulate.a = 0.42
	actor_layer.add_child(current_actor)
	animation_player = NpcAnimationPlayer.new(current_actor)
	animation_player.name = "NpcCutoutAnimationPlayer"
	actor_layer.add_child(animation_player)
	animation_player.set_sprite_frames(current_actor.sprite_frames)
	_play_action("walk_in")
	state = "WALKING_IN"
	Sfx.start_walking()

	var enter := root.create_tween().set_parallel(true)
	enter.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	enter.tween_property(current_actor, "position", Vector2(640, 338), 0.62)
	enter.tween_property(current_actor, "scale", current_actor.scale / 0.72, 0.62)
	enter.tween_property(current_actor, "modulate:a", 1.0, 0.5)
	await enter.finished
	Sfx.stop_walking()
	if token != performance_token:
		return

	state = "ARRIVING"
	var arrive_duration := _play_action("arrive")
	if arrive_duration > 0.0:
		await root.get_tree().create_timer(arrive_duration).timeout
	if token != performance_token:
		return

	state = "GREETING"
	_play_action("idle")
	await _say(String(case_data.get("dialogue", {}).get("greeting", "您好，我来办理事项。")), token)
	if token != performance_token:
		return
	state = "DELIVERING"
	_play_action("deliver")
	var deliver := root.create_tween().set_parallel(true)
	deliver.tween_property(current_actor, "position", Vector2(654, 348), 0.18)
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
	_play_action("idle")
	var settle := root.create_tween().set_parallel(true)
	settle.tween_property(current_actor, "position", Vector2(640, 338), 0.2)
	settle.tween_property(current_actor, "rotation", 0.0, 0.2)
	_schedule_waiting_line(token)
	_schedule_micro_expressions(token)


func _schedule_waiting_line(token: int) -> void:
	var delay := float(current_case.get("dialogue", {}).get("waiting_delay_seconds", 8.0))
	await root.get_tree().create_timer(delay).timeout
	if token != performance_token or state != "WAITING" or waiting_line_shown:
		return
	waiting_line_shown = true
	await _say(String(current_case.get("dialogue", {}).get("waiting", "")), token)


func _schedule_micro_expressions(token: int) -> void:
	while token == performance_token and state == "WAITING" and not skip_requested:
		var cooldown := Vector2(2.5, 5.0)
		if animation_library != null:
			cooldown = animation_library.micro_expression_cooldown
		await root.get_tree().create_timer(
			micro_expression_rng.randf_range(cooldown.x, cooldown.y)
		).timeout
		if token != performance_token or state != "WAITING" or skip_requested:
			return
		var action := _pick_micro_expression()
		if action.is_empty():
			return
		var duration := _play_action(action)
		if duration > 0.0:
			await root.get_tree().create_timer(duration).timeout
		if token != performance_token or state != "WAITING" or skip_requested:
			return
		_play_action("idle")


func _pick_micro_expression() -> String:
	if animation_library == null or animation_library.micro_expressions.is_empty():
		return ""
	var total_weight := 0
	for entry in animation_library.micro_expressions:
		total_weight += maxi(int(entry.get("weight", 0)), 0)
	if total_weight <= 0:
		return ""
	var roll := micro_expression_rng.randi_range(1, total_weight)
	for entry in animation_library.micro_expressions:
		roll -= maxi(int(entry.get("weight", 0)), 0)
		if roll <= 0:
			return String(entry.get("action", ""))
	return ""


func react_and_leave(decision: String) -> void:
	performance_token += 1
	var token := performance_token
	state = "REACTING"
	speech_bubble.visible = false
	GameStateSync.speaker_stopped("npc_reacting")
	if not is_instance_valid(current_actor):
		departure_finished.emit()
		return
	var approved := decision == "批准"
	var reaction_action := "happy_react" if approved else "angry_react"
	var emotional_idle := "happy_idle" if approved else "angry_idle"
	var exit_action := "walk_out_happy" if approved else "walk_out_angry"
	var reaction_duration := _play_action(reaction_action)
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
	if reaction_duration > 0.22:
		await root.get_tree().create_timer(reaction_duration - 0.22).timeout
	if token != performance_token:
		return
	_play_action(emotional_idle)
	var line_key := "approved" if approved else "rejected"
	await _say(String(current_case.get("dialogue", {}).get(line_key, "我知道了。")), token)
	if token != performance_token:
		return
	state = "WALKING_OUT"
	_play_action(exit_action)
	Sfx.start_walking()
	var exit := root.create_tween().set_parallel(true)
	exit.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	exit.tween_property(current_actor, "position", Vector2(500, 360), 0.58)
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
	GameStateSync.speaker_stopped("npc_performance_skipped")
	_stop_audio()
	if state in ["WALKING_IN", "ARRIVING", "GREETING", "DELIVERING"]:
		performance_token += 1
		state = "WAITING"
		if is_instance_valid(current_actor):
			current_actor.position = Vector2(640, 338)
			current_actor.modulate.a = 1.0
			_play_action("idle")
			delivery_finished.emit()
	elif state in ["REACTING", "WALKING_OUT", "QUEUE_ADVANCING"]:
		performance_token += 1
		state = "IDLE"
		departure_finished.emit()


func shutdown() -> void:
	performance_token += 1
	speech_bubble.visible = false
	GameStateSync.speaker_stopped("scene_exiting")
	_stop_audio()
	if is_instance_valid(animation_player):
		animation_player.shutdown()


func _say(text: String, token: int) -> void:
	if text.strip_edges().is_empty() or skip_requested:
		return
	speech_label.text = text
	var person: Dictionary = current_case.get("person", {})
	_send_line_to_glass(person, text)
	GameStateSync.speaker_started(
		String(person.get("id", "UNKNOWN-NPC")),
		String(person.get("display_name", current_case.get("applicant", "身份受限"))),
		"npc",
		text,
		state.to_lower(),
		{
			"caseId": String(current_case.get("case_id", "")),
			"day": WorkdayState.day_number,
		}
	)
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
		GameStateSync.speaker_stopped(state.to_lower())


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
	var positions := [Vector2(525, 346), Vector2(470, 340), Vector2(425, 334)]
	var scales := [0.105, 0.085, 0.07]
	for i in mini(case_ids.size(), 3):
		var queued_case := ConfigDatabase.get_gameplay_case(case_ids[i])
		var person: Dictionary = queued_case.get("person", {})
		var sprite := Sprite2D.new()
		var actor_texture := String(person.get("actor_texture", ""))
		sprite.texture = load(actor_texture) if ResourceLoader.exists(actor_texture) else load(FRAME_PATHS[0])
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
	var actor_texture := String(person.get("actor_texture", ""))
	var animation_table := String(person.get("animation_table", DEFAULT_ANIMATION_TABLE))
	animation_library = NpcAnimationLibrary.new()
	var table_loaded := animation_library.load_animation_table(animation_table, actor_texture)
	if table_loaded and not animation_library.action_metadata.is_empty():
		sprite.sprite_frames = animation_library.get_sprite_frames()
	else:
		var frames := SpriteFrames.new()
		frames.add_animation("idle")
		frames.set_animation_loop("idle", true)
		frames.set_animation_speed("idle", 5.0)
		if not actor_texture.is_empty() and ResourceLoader.exists(actor_texture):
			frames.add_frame("idle", load(actor_texture))
		else:
			for path in FRAME_PATHS:
				var texture: Texture2D = load(path)
				if texture != null:
					frames.add_frame("idle", texture)
		sprite.sprite_frames = frames
		animation_library = null
	if sprite.sprite_frames == null:
		var fallback_frames := SpriteFrames.new()
		fallback_frames.add_animation("idle")
		for path in FRAME_PATHS:
			var texture: Texture2D = load(path)
			if texture != null:
				fallback_frames.add_frame("idle", texture)
		sprite.sprite_frames = fallback_frames
	sprite.centered = true
	var configured_scale := float(person.get("actor_scale", 0.34))
	sprite.scale = Vector2.ONE * configured_scale
	sprite.modulate = Color(String(person.get("actor_tint", "ffffff")))
	micro_expression_rng.seed = hash(String(person.get("id", "DEFAULT-APPLICANT")))
	return sprite


func _clear_actors() -> void:
	_stop_audio()
	speech_bubble.visible = false
	if is_instance_valid(animation_player):
		animation_player.shutdown()
		animation_player.queue_free()
	animation_player = null
	animation_library = null
	if is_instance_valid(current_actor):
		current_actor.queue_free()
	current_actor = null
	for actor in queue_actors:
		if is_instance_valid(actor):
			actor.queue_free()
	queue_actors.clear()


func _play_action(requested_action: String) -> float:
	if (
		animation_library == null
		or not is_instance_valid(animation_player)
		or not is_instance_valid(current_actor)
	):
		return 0.0
	var resolution := animation_library.resolve_action(requested_action)
	if String(resolution.get("kind", "")) != "animation":
		var fallback_texture: Texture2D = resolution.get("texture")
		if fallback_texture != null:
			current_actor.sprite_frames = _single_frame_resource(fallback_texture)
			animation_player.set_sprite_frames(current_actor.sprite_frames)
			animation_player.play_action(&"idle", NpcAnimationPlayer.PlaybackMode.LOOP)
		return 0.0
	var action := String(resolution.get("action", ""))
	var mode := _playback_mode_for(action)
	var playback_token := animation_player.play_action(StringName(action), mode)
	if playback_token == NpcAnimationPlayer.INVALID_TOKEN:
		return 0.0
	var frames := animation_library.get_sprite_frames()
	var fps := maxf(animation_library.get_action_fps(action), 1.0)
	return float(frames.get_frame_count(action)) / fps


func _playback_mode_for(action: String) -> NpcAnimationPlayer.PlaybackMode:
	match animation_library.get_playback_mode(action):
		NpcAnimationLibrary.PLAYBACK_ONCE:
			return NpcAnimationPlayer.PlaybackMode.ONCE
		NpcAnimationLibrary.PLAYBACK_HOLD:
			return NpcAnimationPlayer.PlaybackMode.HOLD
		_:
			return NpcAnimationPlayer.PlaybackMode.LOOP


func _single_frame_resource(texture: Texture2D) -> SpriteFrames:
	var frames := SpriteFrames.new()
	if frames.has_animation("default"):
		frames.remove_animation("default")
	frames.add_animation("idle")
	frames.set_animation_loop("idle", true)
	frames.set_animation_speed("idle", 1.0)
	frames.add_frame("idle", texture)
	return frames


func _play_voice() -> void:
	var person: Dictionary = current_case.get("person", {})
	Sfx.play_voice(String(person.get("id", "")), String(person.get("voice_sfx", "")))


func _stop_audio() -> void:
	Sfx.stop_voice()
	Sfx.stop_walking()
