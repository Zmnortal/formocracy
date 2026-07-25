class_name WorkbenchNpcPerformanceModule
extends RefCounted

# NPC 排队与窗口演出控制器。
# 前排角色直接在柜台递件，后排以遮暗叠放呈现；审批后角色向左离场并真实提升下一位。

signal delivery_finished
signal departure_finished

const FRAME_PATHS: Array[String] = [
	"res://assets/characters/idle_breathing/frame-00.png",
	"res://assets/characters/idle_breathing/frame-01.png",
	"res://assets/characters/idle_breathing/frame-02.png",
	"res://assets/characters/idle_breathing/frame-03.png",
	"res://assets/characters/idle_breathing/frame-04.png",
	"res://assets/characters/idle_breathing/frame-05.png",
]
const DEFAULT_ANIMATION_TABLE := "res://data/animations/default_applicant/animation_table.json"
const NPC_STATIC_BREATHING := preload("res://scripts/ui/npc_static_breathing.gd")
const EXISTING_ACTOR_SCALE_MULTIPLIER := 1.3
const GLOBAL_ACTOR_SCALE_ADJUSTMENT := 1.2
const FRONT_ACTOR_SCALE_MULTIPLIER := EXISTING_ACTOR_SCALE_MULTIPLIER * GLOBAL_ACTOR_SCALE_ADJUSTMENT
# 设计画布通常按实机约 3 倍显示；在原 70 单位基础上再下移 50，约等于 150 px。
const FRONT_ACTOR_VERTICAL_OFFSET := 120.0
const FRONT_POSITION := Vector2(620, 338 + FRONT_ACTOR_VERTICAL_OFFSET)
const DELIVERY_POSITION := Vector2(634, 348 + FRONT_ACTOR_VERTICAL_OFFSET)
const EXIT_MARGIN := 28.0
const EXIT_WALK_SPEED := 520.0
const EXIT_MIN_DURATION := 1.1
const EXIT_MAX_DURATION := 1.8
const QUEUE_CENTER := Vector2(570, 330 + FRONT_ACTOR_VERTICAL_OFFSET)
const QUEUE_ROW_CAPACITY := 4
const QUEUE_X_OFFSETS: Array[float] = [
	-20.0,
	-75.0,
	-130.0,
	-185.0,
]
const QUEUE_NEAR_SCALE_FACTOR := 0.78
const QUEUE_SCALE_STEP := 0.05
const QUEUE_MIN_SCALE_FACTOR := 0.50
const QUEUE_NEAR_DARKNESS := 0.42
const QUEUE_DARKNESS_STEP := 0.10
const QUEUE_MAX_DARKNESS := 0.88

var root: Node2D
var actor_layer: Node2D
var current_actor: AnimatedSprite2D
var animation_library: NpcAnimationLibrary
var animation_player: NpcAnimationPlayer
var queue_actors: Array[AnimatedSprite2D] = []
var queue_case_ids: Array[String] = []
var staged_case_id := ""
var speech_bubble: NpcSpeechBubble
var state := "IDLE"
var current_case: Dictionary = {}
var performance_token := 0
var waiting_line_shown := false
var skip_requested := false
var micro_expression_rng := RandomNumberGenerator.new()
var departure_in_progress := false
var promote_after_departure := true
var pending_exit_action := "walk_out_angry"


# 初始化 NPC 演出控制器并创建人物附近的自动气泡。
func _init(owner_root: Node2D) -> void:
	root = owner_root
	_build_layer()


# 创建 NPC 演出层与位于人物附近的高层气泡。
func _build_layer() -> void:
	actor_layer = Node2D.new()
	actor_layer.name = "NpcPerformanceLayer"
	actor_layer.z_index = 2
	root.add_child(actor_layer)
	speech_bubble = NpcSpeechBubble.new()
	root.add_child(speech_bubble)


# 开始一个案件的入场演出：问候、递件并进入等待状态。
func start_case(case_data: Dictionary, queued_case_ids: Array[String]) -> void:
	performance_token += 1
	var token := performance_token
	_stop_audio()
	current_case = case_data
	waiting_line_shown = false
	skip_requested = false
	departure_in_progress = false
	var case_id := WorkdayContext.read_string(case_data, "case_id")
	var person := WorkdayContext.read_dictionary(case_data, "person")
	if not staged_case_id.is_empty() and staged_case_id == case_id and is_instance_valid(current_actor):
		_configure_current_actor(current_actor, person)
		staged_case_id = ""
	else:
		_clear_actors()
		current_actor = _make_actor(person)
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
	var dialogue := WorkdayContext.read_dictionary(case_data, "dialogue")
	await _say(WorkdayContext.read_string(dialogue, "greeting", "您好，我来办理事项。"), token)
	if token != performance_token:
		return
	state = "DELIVERING"
	_play_action("deliver")
	var deliver := root.create_tween().set_parallel(true)
	deliver.tween_property(current_actor, "position", DELIVERY_POSITION, 0.18)
	deliver.tween_property(current_actor, "rotation", -0.035, 0.18)
	await deliver.finished
	if token != performance_token:
		return
	Sfx.play("ui_switch", -5.0, 0.82)
	await _say(WorkdayContext.read_string(dialogue, "delivery", "材料都在这里。"), token)
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


# 延迟后在等待状态下播放一次催促台词。
func _schedule_waiting_line(token: int) -> void:
	var dialogue := WorkdayContext.read_dictionary(current_case, "dialogue")
	var delay := WorkdayContext.read_float(dialogue, "waiting_delay_seconds", 8.0)
	await root.get_tree().create_timer(delay).timeout
	if token != performance_token or state != "WAITING" or waiting_line_shown:
		return
	waiting_line_shown = true
	await _say(WorkdayContext.read_string(dialogue, "waiting"), token)


# 在等待状态下按随机间隔循环播放微表情动画。
func _schedule_micro_expressions(token: int) -> void:
	while token == performance_token and state == "WAITING" and not skip_requested:
		var cooldown := Vector2(2.5, 5.0)
		if animation_library != null:
			cooldown = animation_library.micro_expression_cooldown
		await root.get_tree().create_timer(micro_expression_rng.randf_range(cooldown.x, cooldown.y)).timeout
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


# 按权重随机抽取一个微表情动作名。
func _pick_micro_expression() -> String:
	if animation_library == null or animation_library.micro_expressions.is_empty():
		return ""
	var total_weight := 0
	for entry: Dictionary in animation_library.micro_expressions:
		total_weight += maxi(WorkdayContext.read_int(entry, "weight"), 0)
	if total_weight <= 0:
		return ""
	var roll := micro_expression_rng.randi_range(1, total_weight)
	for entry: Dictionary in animation_library.micro_expressions:
		roll -= maxi(WorkdayContext.read_int(entry, "weight"), 0)
		if roll <= 0:
			return WorkdayContext.read_string(entry, "action")
	return ""


# 根据审批结果播放情绪反应、告别台词并让角色向左离场。
func react_and_leave(decision: String, promote_next := true) -> void:
	if departure_in_progress:
		return
	promote_after_departure = promote_next
	performance_token += 1
	var token := performance_token
	state = "REACTING"
	speech_bubble.close()
	GameStateSync.speaker_stopped("npc_reacting")
	if not is_instance_valid(current_actor):
		departure_finished.emit()
		return
	var approved := decision == "批准"
	var reaction_action := "happy_react" if approved else "angry_react"
	var emotional_idle := "happy_idle" if approved else "angry_idle"
	var exit_action := "walk_out_happy" if approved else "walk_out_angry"
	pending_exit_action = exit_action
	var reaction_duration := _play_action(reaction_action)
	var reaction := root.create_tween().set_parallel(true)
	reaction.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	reaction.tween_property(current_actor, "position", current_actor.position + (Vector2(0, -8) if approved else Vector2(-12, 13)), 0.22)
	reaction.tween_property(current_actor, "scale", current_actor.scale * (1.025 if approved else 0.95), 0.22)
	await reaction.finished
	if reaction_duration > 0.22:
		await root.get_tree().create_timer(reaction_duration - 0.22).timeout
	if token != performance_token:
		return
	_play_action(emotional_idle)
	var line_key := "approved" if approved else "rejected"
	var dialogue := WorkdayContext.read_dictionary(current_case, "dialogue")
	await _say(WorkdayContext.read_string(dialogue, line_key, "我知道了。"), token)
	if token != performance_token:
		return
	await _walk_current_actor_out(exit_action, token)


# 跳过当前演出，直接切到等待状态或完成离场。
func skip_current_performance() -> void:
	if departure_in_progress or state == "QUEUE_ADVANCING":
		return
	# 退场已经开始后不允许跳切；角色必须保持可见并完整走出画面。
	if state == "WALKING_OUT":
		return
	skip_requested = true
	speech_bubble.close()
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
	elif state == "REACTING":
		performance_token += 1
		_walk_current_actor_out(pending_exit_action, performance_token)


# 保持人物完全不透明，按人物当前帧宽度计算左侧屏幕外终点并播放完整步行退场。
func _walk_current_actor_out(exit_action: String, token: int) -> void:
	if not is_instance_valid(current_actor):
		await _finish_departure(token)
		return
	state = "WALKING_OUT"
	current_actor.modulate.a = 1.0
	_play_action(exit_action)
	Sfx.start_walking()
	var target := _fully_offscreen_exit_position(current_actor)
	var duration := clampf(
		current_actor.position.distance_to(target) / EXIT_WALK_SPEED,
		EXIT_MIN_DURATION,
		EXIT_MAX_DURATION,
	)
	var exit := root.create_tween().set_parallel(true)
	exit.set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN_OUT)
	exit.tween_property(current_actor, "position", target, duration)
	exit.tween_property(current_actor, "rotation", -0.035, duration)
	await exit.finished
	Sfx.stop_walking()
	if token != performance_token:
		return
	await _finish_departure(token)


# 返回确保人物最右侧也越过画布左边界的中心坐标。
func _fully_offscreen_exit_position(actor: AnimatedSprite2D) -> Vector2:
	var frame_width := 512.0
	if actor.sprite_frames != null and actor.sprite_frames.has_animation(actor.animation):
		var frame_count := actor.sprite_frames.get_frame_count(actor.animation)
		if frame_count > 0:
			var frame_texture := actor.sprite_frames.get_frame_texture(actor.animation, mini(actor.frame, frame_count - 1))
			if frame_texture != null:
				frame_width = frame_texture.get_size().x
	var half_visual_width := frame_width * absf(actor.scale.x) * 0.5
	return Vector2(-half_visual_width - EXIT_MARGIN, actor.position.y + 10.0)


# 停止所有演出与音频，用于场景退出时的清理。
func shutdown() -> void:
	performance_token += 1
	speech_bubble.close()
	GameStateSync.speaker_stopped("scene_exiting")
	_stop_audio()
	if is_instance_valid(animation_player):
		animation_player.shutdown()


# 在人物附近气泡逐字显示一句台词，并在约五秒后自动淡出。
func _say(text: String, token: int) -> void:
	if text.strip_edges().is_empty() or skip_requested:
		return
	var person := WorkdayContext.read_dictionary(current_case, "person")
	_send_line_to_glass(person, text)
	(
		GameStateSync
		. speaker_started(
			WorkdayContext.read_string(person, "id", "UNKNOWN-NPC"),
			WorkdayContext.read_string(person, "display_name", WorkdayContext.read_string(current_case, "applicant", "身份受限")),
			"npc",
			text,
			state.to_lower(),
			{
				"caseId": WorkdayContext.read_string(current_case, "case_id"),
				"day": WorkdayState.day_number,
			}
		)
	)
	_play_voice()
	var speaker_name := WorkdayContext.read_string(person, "display_name", WorkdayContext.read_string(current_case, "applicant", "身份受限"))
	await speech_bubble.play_line(speaker_name, text)
	if token != performance_token:
		return
	GameStateSync.speaker_stopped(state.to_lower())


# 从人物资源名推断性别与年龄后将台词转发给 RealityBridge。
func _send_line_to_glass(person: Dictionary, text: String) -> void:
	var bridge := root.get_tree().root.get_node_or_null("RealityBridge")
	if bridge == null:
		return
	var voice_source := WorkdayContext.read_string(person, "voice_sfx").to_lower()
	var visual_source := WorkdayContext.read_string(person, "actor_texture").to_lower()
	var identity_source := voice_source + " " + visual_source
	var gender := ""
	if identity_source.contains("female"):
		gender = "female"
	elif identity_source.contains("male"):
		gender = "male"
	var age := ""
	for source: String in [voice_source, visual_source]:
		for candidate: String in ["young", "average", "old"]:
			if source.contains(candidate):
				age = candidate
				break
		if not age.is_empty():
			break
	bridge.call("npc_line", WorkdayContext.read_string(person, "display_name", WorkdayContext.read_string(current_case, "applicant", "身份受限")), text, gender, age)


# 为队列中的案件创建后排演员并摆放到对应槽位。
func _build_queue(case_ids: Array[String]) -> void:
	for i in case_ids.size():
		var case_id := case_ids[i]
		var sprite := _make_queue_actor(case_id)
		actor_layer.add_child(sprite)
		queue_actors.append(sprite)
		queue_case_ids.append(case_id)
		_apply_queue_slot(sprite, case_id, i)


# 复用现有演员将后排队列同步到目标案件列表。
func _sync_queue(case_ids: Array[String]) -> void:
	var desired_ids: Array[String] = []
	for case_id in case_ids:
		desired_ids.append(case_id)
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


# 清理离场角色并按需提升队列下一位，最后发出离场完成信号。
func _finish_departure(token: int) -> void:
	if departure_in_progress:
		return
	departure_in_progress = true
	state = "QUEUE_ADVANCING"
	_stop_audio()
	speech_bubble.close()
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


# 将队首演员提升到柜台前排并让其余队列前移一位。
func _promote_queue(token: int) -> void:
	if queue_actors.is_empty():
		staged_case_id = ""
		return
	var promoted: AnimatedSprite2D = queue_actors.pop_front()
	staged_case_id = queue_case_ids[0]
	queue_case_ids.remove_at(0)
	current_actor = promoted
	var promoted_person := _person_for_case(staged_case_id)
	var promoted_tint := _actor_tint(promoted_person)
	var promoted_scale := WorkdayContext.read_float(promoted_person, "actor_scale", 0.34) * FRONT_ACTOR_SCALE_MULTIPLIER
	current_actor.z_index = 0
	var tween := root.create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(current_actor, "position", FRONT_POSITION, 0.34)
	tween.tween_property(current_actor, "scale", Vector2.ONE * promoted_scale, 0.34)
	tween.tween_property(current_actor, "modulate", promoted_tint, 0.34)
	for i in queue_actors.size():
		var actor := queue_actors[i]
		var person := _person_for_case(queue_case_ids[i])
		var target_tint := _actor_tint(person).darkened(_queue_darkness(i))
		target_tint.a = 1.0
		actor.z_index = -i - 1
		tween.tween_property(actor, "position", _queue_position(i), 0.34)
		tween.tween_property(
			actor,
			"scale",
			Vector2.ONE * WorkdayContext.read_float(person, "actor_scale", 0.34) * FRONT_ACTOR_SCALE_MULTIPLIER * _queue_scale_factor(i),
			0.34,
		)
		tween.tween_property(actor, "modulate", target_tint, 0.34)
	await tween.finished
	if token != performance_token:
		return


# 根据案件配置创建一个后排队列演员。
func _make_queue_actor(case_id: String) -> AnimatedSprite2D:
	var person := _person_for_case(case_id)
	var sprite := AnimatedSprite2D.new()
	_configure_queue_actor(sprite, person)
	return sprite


# 为队列演员加载排队待机动画，失败时回退到静态单帧。
func _configure_queue_actor(sprite: AnimatedSprite2D, person: Dictionary) -> void:
	var actor_texture := WorkdayContext.read_string(person, "actor_texture")
	var animation_table := WorkdayContext.read_string(person, "animation_table", DEFAULT_ANIMATION_TABLE)
	var actor_id := WorkdayContext.read_string(person, "id", actor_texture)
	NPC_STATIC_BREATHING.apply(sprite, actor_id + "-queue", 1.8, 1.45)
	var queue_library := NpcAnimationLibrary.new()
	if queue_library.load_animation_table(animation_table, actor_texture) and queue_library.has_action("queue_idle"):
		sprite.sprite_frames = queue_library.get_sprite_frames()
		sprite.animation = &"queue_idle"
		sprite.frame = 0
		sprite.centered = true
		sprite.play(&"queue_idle")
		return
	var texture := _load_texture(actor_texture) if ResourceLoader.exists(actor_texture) else _load_texture(FRAME_PATHS[0])
	sprite.sprite_frames = _single_frame_resource(texture)
	sprite.animation = &"idle"
	sprite.frame = 0
	sprite.centered = true


# 按队列深度设置演员的位置、缩放、遮暗与层级。
func _apply_queue_slot(actor: AnimatedSprite2D, case_id: String, depth: int) -> void:
	var person := _person_for_case(case_id)
	var tint := _actor_tint(person).darkened(_queue_darkness(depth))
	tint.a = 1.0
	actor.position = _queue_position(depth)
	actor.scale = (
		Vector2.ONE
		* WorkdayContext.read_float(person, "actor_scale", 0.34)
		* FRONT_ACTOR_SCALE_MULTIPLIER
		* _queue_scale_factor(depth)
	)
	actor.modulate = tint
	actor.z_index = -depth - 1


# 将任意数量的候办人按四人一排向门廊左侧展开，避免任何一位拥挤在前排人物背后。
func _queue_position(depth: int) -> Vector2:
	var row := floori(float(depth) / float(QUEUE_ROW_CAPACITY))
	var slot := posmod(depth, QUEUE_ROW_CAPACITY)
	return QUEUE_CENTER + Vector2(
		QUEUE_X_OFFSETS[slot],
		-float(row) * 18.0 - float(slot) * 2.5,
	)


# 后排继承整体人物倍率，但从第一位起就明显小于前排，并随纵深继续缩小。
func _queue_scale_factor(depth: int) -> float:
	return maxf(QUEUE_MIN_SCALE_FACTOR, QUEUE_NEAR_SCALE_FACTOR - float(depth) * QUEUE_SCALE_STEP)


# 队列越深越接近黑色，但始终保持不透明的人形轮廓。
func _queue_darkness(depth: int) -> float:
	return minf(QUEUE_MAX_DARKNESS, QUEUE_NEAR_DARKNESS + float(depth) * QUEUE_DARKNESS_STEP)


# 创建并配置一个前排主演员精灵。
func _make_actor(person: Dictionary) -> AnimatedSprite2D:
	var sprite := AnimatedSprite2D.new()
	_configure_current_actor(sprite, person)
	return sprite


# 为前排演员加载动画表或回退帧，并应用缩放、着色与位置。
func _configure_current_actor(sprite: AnimatedSprite2D, person: Dictionary) -> void:
	var actor_texture := WorkdayContext.read_string(person, "actor_texture")
	var animation_table := WorkdayContext.read_string(person, "animation_table", DEFAULT_ANIMATION_TABLE)
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
			frames.add_frame("idle", _load_texture(actor_texture))
		else:
			for path: String in FRAME_PATHS:
				var texture := _load_texture(path)
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
		for path: String in FRAME_PATHS:
			var texture := _load_texture(path)
			if texture != null:
				fallback_frames.add_frame("idle", texture)
		sprite.sprite_frames = fallback_frames
	sprite.centered = true
	var configured_scale := WorkdayContext.read_float(person, "actor_scale", 0.34) * FRONT_ACTOR_SCALE_MULTIPLIER
	sprite.scale = Vector2.ONE * configured_scale
	sprite.modulate = _actor_tint(person)
	sprite.position = FRONT_POSITION
	sprite.rotation = 0.0
	sprite.z_index = 0
	var actor_id := WorkdayContext.read_string(person, "id", "DEFAULT-APPLICANT")
	NPC_STATIC_BREATHING.apply(sprite, actor_id, 2.4, 1.55)
	micro_expression_rng.seed = hash(actor_id)


# 解析人物配置的着色并强制不透明。
func _actor_tint(person: Dictionary) -> Color:
	var tint := Color(WorkdayContext.read_string(person, "actor_tint", "ffffff"))
	tint.a = 1.0
	return tint


# 清除前排演员与整个队列，重置演出相关状态。
func _clear_actors() -> void:
	_stop_audio()
	speech_bubble.close()
	_dispose_animation_player()
	animation_library = null
	if is_instance_valid(current_actor):
		current_actor.queue_free()
	current_actor = null
	staged_case_id = ""
	_clear_queue()


# 释放所有后排队列演员并清空记录。
func _clear_queue() -> void:
	for actor in queue_actors:
		if is_instance_valid(actor):
			actor.queue_free()
	queue_actors.clear()
	queue_case_ids.clear()


# 安全地关闭并释放动画播放器。
func _dispose_animation_player() -> void:
	if is_instance_valid(animation_player):
		animation_player.shutdown()
		animation_player.queue_free()
	animation_player = null


# 播放指定动作并返回其时长，无法解析时回退到静态帧。
func _play_action(requested_action: String) -> float:
	if animation_library == null or not is_instance_valid(animation_player) or not is_instance_valid(current_actor):
		return 0.0
	var resolution := animation_library.resolve_action(requested_action)
	if WorkdayContext.read_string(resolution, "kind") != "animation":
		var fallback_texture := _texture_from_value(resolution.get("texture"))
		if fallback_texture != null:
			current_actor.sprite_frames = _single_frame_resource(fallback_texture)
			animation_player.set_sprite_frames(current_actor.sprite_frames)
			animation_player.play_action(&"idle", NpcAnimationPlayer.PlaybackMode.LOOP)
		return 0.0
	var action := WorkdayContext.read_string(resolution, "action")
	var mode := _playback_mode_for(action)
	var playback_token := animation_player.play_action(StringName(action), mode)
	if playback_token == NpcAnimationPlayer.INVALID_TOKEN:
		return 0.0
	var frames := animation_library.get_sprite_frames()
	var fps := maxf(animation_library.get_action_fps(action), 1.0)
	return float(frames.get_frame_count(action)) / fps


# 将动画库的播放模式映射为播放器枚举。
func _playback_mode_for(action: String) -> NpcAnimationPlayer.PlaybackMode:
	match animation_library.get_playback_mode(action):
		NpcAnimationLibrary.PLAYBACK_ONCE:
			return NpcAnimationPlayer.PlaybackMode.ONCE
		NpcAnimationLibrary.PLAYBACK_HOLD:
			return NpcAnimationPlayer.PlaybackMode.HOLD
		_:
			return NpcAnimationPlayer.PlaybackMode.LOOP


# 用单张贴图构造仅含 idle 动画的 SpriteFrames。
func _single_frame_resource(texture: Texture2D) -> SpriteFrames:
	var frames := SpriteFrames.new()
	if frames.has_animation("default"):
		frames.remove_animation("default")
	frames.add_animation("idle")
	frames.set_animation_loop("idle", true)
	frames.set_animation_speed("idle", 1.0)
	frames.add_frame("idle", texture)
	return frames


# 播放当前案件人物的语音音效。
func _play_voice() -> void:
	var person := WorkdayContext.read_dictionary(current_case, "person")
	Sfx.play_voice(WorkdayContext.read_string(person, "id"), WorkdayContext.read_string(person, "voice_sfx"))


# 停止语音与脚步声。
func _stop_audio() -> void:
	Sfx.stop_voice()
	Sfx.stop_walking()


# 返回指定案件的强类型人物配置。
func _person_for_case(case_id: String) -> Dictionary:
	return WorkdayContext.read_dictionary(ConfigDatabase.get_gameplay_case(case_id), "person")


# 加载并收窄 NPC 贴图资源。
func _load_texture(path: String) -> Texture2D:
	if path.is_empty():
		return null
	return _texture_from_value(ResourceLoader.load(path))


# 将动态资源值收窄为 Texture2D。
func _texture_from_value(value: Variant) -> Texture2D:
	if value is Texture2D:
		@warning_ignore("unsafe_cast")
		var texture: Texture2D = value
		return texture
	return null
