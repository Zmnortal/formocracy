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
const UI := preload("res://scripts/ui/bureau_ui.gd")
const STORY_MARKER_NAME := "StoryDebugMarker"
const WAITING_DIALOGUE_PHASES: Array[String] = [
	"waiting_public",
	"waiting_personal",
	"waiting_identity",
	"waiting_story",
]
const IDLE_CHATTER_KEYS: Array[String] = [
	"waiting_public",
	"waiting_personal",
	"waiting_identity",
	"waiting_story",
	"greeting",
	"delivery",
]
const WAITING_LINES_PER_PHASE := 2
const DEFAULT_WAITING_REPEAT_SECONDS := 7.0
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
var waiting_dialogue_index := 0
var waiting_dialogue_seen: Dictionary = {}
var skip_requested := false
var micro_expression_rng := RandomNumberGenerator.new()
var departure_in_progress := false
var promote_after_departure := true
var pending_exit_action := "walk_out_angry"
var story_markers_enabled := false


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
	waiting_dialogue_index = 0
	waiting_dialogue_seen.clear()
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
	_refresh_story_markers()
	animation_player = NpcAnimationPlayer.new(current_actor)
	animation_player.name = "NpcCutoutAnimationPlayer"
	actor_layer.add_child(animation_player)
	animation_player.set_sprite_frames(current_actor.sprite_frames)
	state = "GREETING"
	_play_action("idle")
	var dialogue := WorkdayContext.read_dictionary(case_data, "dialogue")
	await _say_sequence(_case_or_profile_dialogue_lines(dialogue, "greeting", "您好，我来办理事项。"), token)
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
	await _say_sequence(_case_or_profile_dialogue_lines(dialogue, "delivery", "材料都在这里。"), token)
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


# 延迟后按人物台词库的公开身份、私人状态、身份矛盾与剧情暗示阶段循环说话。
func _schedule_waiting_line(token: int) -> void:
	var dialogue := WorkdayContext.read_dictionary(current_case, "dialogue")
	var delay := WorkdayContext.read_float(dialogue, "waiting_delay_seconds", 8.0)
	var repeat_delay := WorkdayContext.read_float(dialogue, "waiting_repeat_seconds", DEFAULT_WAITING_REPEAT_SECONDS)
	while token == performance_token and state == "WAITING" and not skip_requested:
		await root.get_tree().create_timer(delay).timeout
		if token != performance_token or state != "WAITING" or skip_requested:
			return
		var line := _next_waiting_dialogue_line(dialogue)
		if line.is_empty():
			return
		await _say(line, token)
		if token != performance_token or state != "WAITING" or skip_requested:
			return
		waiting_dialogue_index += 1
		delay = repeat_delay


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
	await _say_sequence(_case_or_profile_dialogue_lines(dialogue, line_key, "我知道了。"), token)
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


# 将兼容的单句或多句字段统一整理为可播放序列。
func _dialogue_lines(dialogue: Dictionary, key: String, fallback := "") -> Array[String]:
	var raw_value: Variant = dialogue.get(key, fallback)
	var lines: Array[String] = []
	if raw_value is Array:
		for entry: Variant in raw_value:
			var line := String(entry).strip_edges()
			if not line.is_empty():
				lines.append(line)
		return lines
	var line := String(raw_value).strip_edges()
	if not line.is_empty():
		lines.append(line)
	return lines


# 案件台词优先；普通案件的审批结果追加人物反应，关键剧情保持原节奏，其余人物台词进入日常闲聊池。
func _case_or_profile_dialogue_lines(dialogue: Dictionary, key: String, fallback := "") -> Array[String]:
	var case_lines := _dialogue_lines(dialogue, key)
	var profile_lines := _dialogue_lines(_current_character_dialogue_profile(), key)
	var is_story_case := WorkdayContext.read_string(current_case, "content_kind") == "story"
	if key in ["approved", "rejected"] and not is_story_case:
		var reaction_line := _pick_unseen_dialogue_line(profile_lines)
		if not reaction_line.is_empty():
			case_lines.append(reaction_line)
	if not case_lines.is_empty():
		return case_lines
	return profile_lines if not profile_lines.is_empty() else _dialogue_lines({}, key, fallback)


# 返回当前人物的结构化长期台词库；未配置时返回空字典以兼容旧案件。
func _current_character_dialogue_profile() -> Dictionary:
	var person := WorkdayContext.read_dictionary(current_case, "person")
	var person_id := WorkdayContext.read_string(person, "id")
	if person_id.is_empty():
		return {}
	return ConfigDatabase.get_ontology("character_dialogues", person_id)


# 每两次等待发言推进一层，进入剧情暗示后保持在最后一层。
func _waiting_phase_key(dialogue_index: int) -> String:
	if WAITING_DIALOGUE_PHASES.is_empty():
		return ""
	var phase_index := mini(
		floori(float(maxi(dialogue_index, 0)) / float(WAITING_LINES_PER_PHASE)),
		WAITING_DIALOGUE_PHASES.size() - 1,
	)
	return WAITING_DIALOGUE_PHASES[phase_index]


# 从当前等待层级抽取未说过的台词；之后继续使用问候与递件内容作为日常闲聊，旧案件回退原 waiting 字段。
func _next_waiting_dialogue_line(case_dialogue: Dictionary) -> String:
	var profile := _current_character_dialogue_profile()
	var phase_key := _waiting_phase_key(waiting_dialogue_index)
	var line := _pick_unseen_dialogue_line(_dialogue_lines(profile, phase_key))
	if not line.is_empty():
		return line
	var idle_chatter_lines: Array[String] = []
	for key: String in IDLE_CHATTER_KEYS:
		idle_chatter_lines.append_array(_dialogue_lines(profile, key))
	line = _pick_unseen_dialogue_line(idle_chatter_lines)
	if not line.is_empty():
		return line
	return _pick_unseen_dialogue_line(_dialogue_lines(case_dialogue, "waiting"))


# 在同一案件内随机选择一条未出现台词，并立即登记避免重复。
func _pick_unseen_dialogue_line(lines: Array[String]) -> String:
	var unseen: Array[String] = []
	for line: String in lines:
		if not waiting_dialogue_seen.has(line):
			unseen.append(line)
	if unseen.is_empty():
		return ""
	var selected := unseen[micro_expression_rng.randi_range(0, unseen.size() - 1)]
	waiting_dialogue_seen[selected] = true
	return selected


# 逐句播放一个对白阶段；跳过或案件切换会终止整个剩余序列。
func _say_sequence(lines: Array[String], token: int) -> void:
	for line: String in lines:
		if token != performance_token or skip_requested:
			return
		await _say(line, token)
		if token != performance_token or skip_requested:
			return


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
	_refresh_story_markers()


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
	_refresh_story_markers()


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


# 启用或关闭仅供开发者使用的关键剧情角色标签。
func set_story_markers_enabled(enabled_now: bool) -> void:
	if story_markers_enabled == enabled_now:
		return
	story_markers_enabled = enabled_now
	_refresh_story_markers()


# 根据当前案件与队列案件重新创建剧情角色标签。
func _refresh_story_markers() -> void:
	_clear_story_markers()
	if not story_markers_enabled:
		return
	if is_instance_valid(current_actor):
		var current_case_id := staged_case_id
		if current_case_id.is_empty():
			current_case_id = WorkdayContext.read_string(current_case, "case_id")
		_add_story_marker(current_actor, current_case_id)
	for index in mini(queue_actors.size(), queue_case_ids.size()):
		_add_story_marker(queue_actors[index], queue_case_ids[index])


# 清除当前演员与候场演员上的全部剧情调试标签。
func _clear_story_markers() -> void:
	var actors: Array[AnimatedSprite2D] = []
	if is_instance_valid(current_actor):
		actors.append(current_actor)
	actors.append_array(queue_actors)
	for actor: AnimatedSprite2D in actors:
		if not is_instance_valid(actor):
			continue
		var marker := actor.get_node_or_null(STORY_MARKER_NAME)
		if marker != null:
			actor.remove_child(marker)
			marker.queue_free()


# 若案件属于 story 内容，为对应演员添加固定屏幕尺寸的金色标签。
func _add_story_marker(actor: AnimatedSprite2D, case_id: String) -> void:
	if not is_instance_valid(actor) or case_id.is_empty() or not _case_is_story(case_id):
		return
	var marker := Label.new()
	marker.name = STORY_MARKER_NAME
	marker.text = "◆ 关键剧情"
	marker.size = Vector2(104, 24)
	marker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	marker.z_index = 200
	UI.style_label(marker, 14, true)
	marker.add_theme_color_override("font_color", Color("f4cf58"))
	marker.add_theme_color_override("font_outline_color", Color("211806"))
	marker.add_theme_constant_override("outline_size", 4)
	var inverse_scale := Vector2(
		1.0 / maxf(absf(actor.scale.x), 0.001),
		1.0 / maxf(absf(actor.scale.y), 0.001),
	)
	var texture_height := 720.0
	if actor.sprite_frames != null and actor.sprite_frames.has_animation(actor.animation):
		var texture := actor.sprite_frames.get_frame_texture(actor.animation, actor.frame)
		if texture != null:
			texture_height = texture.get_height()
	marker.scale = inverse_scale
	marker.position = Vector2(-52.0 * inverse_scale.x, -texture_height * 0.5 - 34.0 * inverse_scale.y)
	actor.add_child(marker)


# 案件级识别避免把同一人物参与的普通案件误标为关键剧情。
func _case_is_story(case_id: String) -> bool:
	var case_data: Dictionary = ConfigDatabase.get_gameplay_case(case_id)
	return WorkdayContext.read_string(case_data, "content_kind") == "story"


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
