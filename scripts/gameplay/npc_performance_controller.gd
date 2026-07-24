class_name NpcPerformanceController
extends RefCounted

# NPC 排队与窗口演出控制器。
# 前排角色直接在柜台递件，后排以遮暗叠放呈现；审批后角色向左离场并真实提升下一位。

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
const FRONT_POSITION := Vector2(640, 338)
const EXIT_POSITION := Vector2(470, 352)
const MAX_VISIBLE_QUEUE := 3
const QUEUE_POSITIONS := [
	Vector2(614, 330),
	Vector2(590, 323),
	Vector2(568, 317),
]
const QUEUE_SCALE_FACTORS := [0.92, 0.84, 0.76]
const QUEUE_DARKNESS := [0.60, 0.75, 0.75]

var root: Node2D
var actor_layer: Node2D
var current_actor: AnimatedSprite2D
var animation_library: NpcAnimationLibrary
var animation_player: NpcAnimationPlayer
var queue_actors: Array[AnimatedSprite2D] = []
var queue_case_ids: Array[String] = []
var staged_case_id := ""
var speech_bubble: Panel
var speech_label: Label
var state := "IDLE"
var current_case: Dictionary = {}
var performance_token := 0
var waiting_line_shown := false
var skip_requested := false
var micro_expression_rng := RandomNumberGenerator.new()
var departure_in_progress := false
var promote_after_departure := true


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
	departure_in_progress = false
	var case_id := String(case_data.get("case_id", ""))
	if (
		not staged_case_id.is_empty()
		and staged_case_id == case_id
		and is_instance_valid(current_actor)
	):
		_configure_current_actor(current_actor, case_data.get("person", {}))
		staged_case_id = ""
	else:
		_clear_actors()
		current_actor = _make_actor(case_data.get("person", {}))
		current_actor.position = FRONT_POSITION
		current_actor.z_index = 0
		actor_layer.add_child(current_actor)
	_sync_queue(queued_case_ids)
	animation_player = NpcAnimationPlayer.new(current_actor)
	animation_player.name = "NpcCutoutAnimationPlayer"
	actor_layer.add_child(animation_player)
	animation_player.set_sprite_frames(current_actor.sprite_frames)
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
	settle.tween_property(current_actor, "position", FRONT_POSITION, 0.2)
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


func react_and_leave(decision: String, promote_next := true) -> void:
	if departure_in_progress:
		return
	promote_after_departure = promote_next
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
	exit.tween_property(current_actor, "position", EXIT_POSITION, 0.58)
	exit.tween_property(current_actor, "rotation", -0.045, 0.58)
	exit.tween_property(current_actor, "modulate:a", 0.0, 0.48)
	await exit.finished
	Sfx.stop_walking()
	if token != performance_token:
		return
	await _finish_departure(token)


func skip_current_performance() -> void:
	if departure_in_progress or state == "QUEUE_ADVANCING":
		return
	skip_requested = true
	speech_bubble.visible = false
	GameStateSync.speaker_stopped("npc_performance_skipped")
	_stop_audio()
	if state in ["GREETING", "DELIVERING"]:
		performance_token += 1
		state = "WAITING"
		if is_instance_valid(current_actor):
			current_actor.position = FRONT_POSITION
			current_actor.rotation = 0.0
			current_actor.modulate.a = 1.0
			_play_action("idle")
			delivery_finished.emit()
	elif state in ["REACTING", "WALKING_OUT"]:
		performance_token += 1
		_finish_departure(performance_token)


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
	for i in mini(case_ids.size(), MAX_VISIBLE_QUEUE):
		var case_id := case_ids[i]
		var sprite := _make_queue_actor(case_id)
		actor_layer.add_child(sprite)
		queue_actors.append(sprite)
		queue_case_ids.append(case_id)
		_apply_queue_slot(sprite, case_id, i)


func _sync_queue(case_ids: Array[String]) -> void:
	var desired_ids: Array[String] = []
	for i in mini(case_ids.size(), MAX_VISIBLE_QUEUE):
		desired_ids.append(case_ids[i])
	if queue_actors.is_empty():
		_build_queue(desired_ids)
		return

	var remaining_actors: Array[AnimatedSprite2D] = queue_actors.duplicate()
	var remaining_ids: Array[String] = queue_case_ids.duplicate()
	var next_actors: Array[AnimatedSprite2D] = []
	for case_id in desired_ids:
		var existing_index := remaining_ids.find(case_id)
		var actor: AnimatedSprite2D
		if existing_index >= 0:
			actor = remaining_actors[existing_index]
			remaining_actors.remove_at(existing_index)
			remaining_ids.remove_at(existing_index)
		else:
			actor = _make_queue_actor(case_id)
			actor_layer.add_child(actor)
		next_actors.append(actor)
	for actor in remaining_actors:
		if is_instance_valid(actor):
			actor.queue_free()
	queue_actors = next_actors
	queue_case_ids = desired_ids
	for i in queue_actors.size():
		_apply_queue_slot(queue_actors[i], queue_case_ids[i], i)


func _finish_departure(token: int) -> void:
	if departure_in_progress:
		return
	departure_in_progress = true
	state = "QUEUE_ADVANCING"
	_stop_audio()
	speech_bubble.visible = false
	_dispose_animation_player()
	if is_instance_valid(current_actor):
		current_actor.queue_free()
	current_actor = null
	animation_library = null
	if token != performance_token:
		departure_in_progress = false
		return
	if promote_after_departure:
		await _promote_queue(token)
	else:
		_clear_queue()
	if token != performance_token:
		departure_in_progress = false
		return
	departure_in_progress = false
	state = "FRONT_STAGED" if is_instance_valid(current_actor) else "IDLE"
	departure_finished.emit()


func _promote_queue(token: int) -> void:
	if queue_actors.is_empty():
		staged_case_id = ""
		return
	var promoted: AnimatedSprite2D = queue_actors.pop_front()
	staged_case_id = String(queue_case_ids.pop_front())
	current_actor = promoted
	var promoted_person: Dictionary = ConfigDatabase.get_gameplay_case(staged_case_id).get("person", {})
	var promoted_tint := _actor_tint(promoted_person)
	var promoted_scale := float(promoted_person.get("actor_scale", 0.34))
	current_actor.z_index = 0
	var tween := root.create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(current_actor, "position", FRONT_POSITION, 0.34)
	tween.tween_property(current_actor, "scale", Vector2.ONE * promoted_scale, 0.34)
	tween.tween_property(current_actor, "modulate", promoted_tint, 0.34)
	for i in queue_actors.size():
		var actor := queue_actors[i]
		var person: Dictionary = ConfigDatabase.get_gameplay_case(queue_case_ids[i]).get("person", {})
		var target_tint := _actor_tint(person).darkened(QUEUE_DARKNESS[i])
		target_tint.a = 1.0
		actor.z_index = -i - 1
		tween.tween_property(actor, "position", QUEUE_POSITIONS[i], 0.34)
		tween.tween_property(
			actor,
			"scale",
			Vector2.ONE * float(person.get("actor_scale", 0.34)) * QUEUE_SCALE_FACTORS[i],
			0.34
		)
		tween.tween_property(actor, "modulate", target_tint, 0.34)
	await tween.finished
	if token != performance_token:
		return


func _make_queue_actor(case_id: String) -> AnimatedSprite2D:
	var queued_case := ConfigDatabase.get_gameplay_case(case_id)
	var person: Dictionary = queued_case.get("person", {})
	var actor_texture := String(person.get("actor_texture", ""))
	var texture: Texture2D = (
		load(actor_texture)
		if ResourceLoader.exists(actor_texture)
		else load(FRAME_PATHS[0])
	)
	var sprite := AnimatedSprite2D.new()
	sprite.sprite_frames = _single_frame_resource(texture)
	sprite.animation = &"idle"
	sprite.frame = 0
	sprite.centered = true
	return sprite


func _apply_queue_slot(actor: AnimatedSprite2D, case_id: String, depth: int) -> void:
	var person: Dictionary = ConfigDatabase.get_gameplay_case(case_id).get("person", {})
	var tint := _actor_tint(person).darkened(QUEUE_DARKNESS[depth])
	tint.a = 1.0
	actor.position = QUEUE_POSITIONS[depth]
	actor.scale = Vector2.ONE * float(person.get("actor_scale", 0.34)) * QUEUE_SCALE_FACTORS[depth]
	actor.modulate = tint
	actor.z_index = -depth - 1


func _make_actor(person: Dictionary) -> AnimatedSprite2D:
	var sprite := AnimatedSprite2D.new()
	_configure_current_actor(sprite, person)
	return sprite


func _configure_current_actor(sprite: AnimatedSprite2D, person: Dictionary) -> void:
	var actor_texture := String(person.get("actor_texture", ""))
	var animation_table := String(person.get("animation_table", DEFAULT_ANIMATION_TABLE))
	animation_library = NpcAnimationLibrary.new()
	var table_loaded := animation_library.load_animation_table(animation_table, actor_texture)
	if table_loaded and not animation_library.action_metadata.is_empty():
		sprite.sprite_frames = animation_library.get_sprite_frames()
	else:
		var frames := SpriteFrames.new()
		if frames.has_animation(&"default"):
			frames.remove_animation(&"default")
		frames.add_animation("idle")
		frames.set_animation_loop("idle", true)
		frames.set_animation_speed("idle", 4.0)
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
		if fallback_frames.has_animation(&"default"):
			fallback_frames.remove_animation(&"default")
		fallback_frames.add_animation("idle")
		fallback_frames.set_animation_speed("idle", 4.0)
		for path in FRAME_PATHS:
			var texture: Texture2D = load(path)
			if texture != null:
				fallback_frames.add_frame("idle", texture)
		sprite.sprite_frames = fallback_frames
	sprite.centered = true
	var configured_scale := float(person.get("actor_scale", 0.34))
	sprite.scale = Vector2.ONE * configured_scale
	sprite.modulate = _actor_tint(person)
	sprite.position = FRONT_POSITION
	sprite.rotation = 0.0
	sprite.z_index = 0
	micro_expression_rng.seed = hash(String(person.get("id", "DEFAULT-APPLICANT")))


func _actor_tint(person: Dictionary) -> Color:
	var tint := Color(String(person.get("actor_tint", "ffffff")))
	tint.a = 1.0
	return tint


func _clear_actors() -> void:
	_stop_audio()
	speech_bubble.visible = false
	_dispose_animation_player()
	animation_library = null
	if is_instance_valid(current_actor):
		current_actor.queue_free()
	current_actor = null
	staged_case_id = ""
	_clear_queue()


func _clear_queue() -> void:
	for actor in queue_actors:
		if is_instance_valid(actor):
			actor.queue_free()
	queue_actors.clear()
	queue_case_ids.clear()


func _dispose_animation_player() -> void:
	if is_instance_valid(animation_player):
		animation_player.shutdown()
		animation_player.queue_free()
	animation_player = null


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
