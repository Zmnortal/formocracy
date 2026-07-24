class_name NpcAnimationLibrary
extends RefCounted

# Loads an NPC's data-authored frame table and builds the SpriteFrames resource
# consumed by AnimatedSprite2D. Source images stay as independent PNG files.

const PLAYBACK_LOOP := "LOOP"
const PLAYBACK_ONCE := "ONCE"
const PLAYBACK_HOLD := "HOLD"
const VALID_PLAYBACK_MODES := [PLAYBACK_LOOP, PLAYBACK_ONCE, PLAYBACK_HOLD]
const MAX_ACTION_FPS := 4.0

var table_path := ""
var character_id := ""
var default_animation := "idle"
var sprite_frames := SpriteFrames.new()
var action_metadata: Dictionary = {}
var emotion_fallbacks: Dictionary = {
	"happy": "happy_idle",
	"angry": "angry_idle",
}
var required_actions: PackedStringArray = []
var optional_actions: PackedStringArray = []
var max_unique_pngs := 0
var micro_expressions: Array[Dictionary] = []
var micro_expression_cooldown := Vector2(2.5, 5.0)
var substitute_frames_with_static_actor := false
var static_actor_texture: Texture2D
var static_actor_texture_path := ""
var warning_messages: PackedStringArray = []
var error_messages: PackedStringArray = []


# 加载并解析 NPC 动画表，构建 SpriteFrames 与元数据。
func load_animation_table(config_path: String, static_actor_texture_override: String = "") -> bool:
	_reset()
	table_path = config_path.simplify_path()
	var table := _read_animation_table()
	if table.is_empty():
		return false

	character_id = WorkdayContext.read_string(table, "character_id")
	default_animation = WorkdayContext.read_string(table, "default_animation", "idle")
	_read_emotion_fallbacks(table.get("emotion_fallbacks", {}))
	_read_action_contract(table.get("action_contract", {}))
	_read_micro_expressions(table.get("micro_expressions", []))
	_read_micro_expression_cooldown(table.get("micro_expression_cooldown", [2.5, 5.0]))
	substitute_frames_with_static_actor = WorkdayContext.read_bool(table, "substitute_frames_with_static_actor")

	var configured_static_path := static_actor_texture_override
	if configured_static_path.is_empty():
		configured_static_path = WorkdayContext.read_string(table, "static_actor_texture")
	_set_static_actor_texture(configured_static_path)

	var actions_value: Variant = table.get("actions", [])
	if actions_value is Array:
		@warning_ignore("unsafe_cast")
		var actions: Array = actions_value
		for action_value: Variant in actions:
			if not action_value is Dictionary:
				_warn("Ignored an action row because it is not an object.")
				continue
			@warning_ignore("unsafe_cast")
			var action: Dictionary = action_value
			_add_action(action)
	elif actions_value is Dictionary:
		@warning_ignore("unsafe_cast")
		var actions: Dictionary = actions_value
		for action_name_value: Variant in actions:
			var action_value: Variant = actions[action_name_value]
			if not action_value is Dictionary:
				_warn("Ignored action '%s' because its row is not an object." % action_name_value)
				continue
			@warning_ignore("unsafe_cast")
			var action_row: Dictionary = action_value
			action_row = action_row.duplicate(true)
			action_row["action"] = WorkdayContext.stringify_value(action_name_value)
			_add_action(action_row)
	else:
		_error("Animation table 'actions' must be an array or object.")
		return false

	_validate_action_contract()
	if not error_messages.is_empty():
		return false
	if action_metadata.is_empty() and static_actor_texture == null:
		_error("Animation table contains no usable action frames or static actor texture.")
		return false
	return true


# 读取并校验动画表根对象；失败信息统一写入 error_messages。
func _read_animation_table() -> Dictionary:
	if not FileAccess.file_exists(table_path):
		_error("Animation table does not exist: %s" % table_path)
		return {}
	var file := FileAccess.open(table_path, FileAccess.READ)
	if file == null:
		_error("Animation table could not be opened: %s" % table_path)
		return {}
	var json := JSON.new()
	var parse_result := json.parse(file.get_as_text())
	if parse_result != OK:
		_error("Animation table JSON is invalid at line %d: %s" % [json.get_error_line(), json.get_error_message()])
		return {}
	if typeof(json.data) != TYPE_DICTIONARY:
		_error("Animation table root must be an object: %s" % table_path)
		return {}
	@warning_ignore("unsafe_cast")
	var table: Dictionary = json.data
	if table.is_empty():
		_error("Animation table root must not be empty: %s" % table_path)
	return table


# 判断指定动作是否已加载。
func has_action(action_name: String) -> bool:
	return action_metadata.has(action_name) and sprite_frames.has_animation(action_name)


# 返回构建好的 SpriteFrames 资源。
func get_sprite_frames() -> SpriteFrames:
	return sprite_frames


# 返回指定动作的元数据副本。
func get_action_metadata(action_name: String) -> Dictionary:
	return WorkdayContext.read_dictionary(action_metadata, action_name)


# 返回指定动作的帧率。
func get_action_fps(action_name: String) -> float:
	return WorkdayContext.read_float(get_action_metadata(action_name), "fps")


# 返回指定动作的播放模式。
func get_playback_mode(action_name: String) -> String:
	return WorkdayContext.read_string(get_action_metadata(action_name), "playback")


# 判断指定动作是否应停在最后一帧。
func should_hold_last_frame(action_name: String) -> bool:
	return get_playback_mode(action_name) == PLAYBACK_HOLD


# 将请求动作解析为实际动画名称；找不到时返回空。
func resolve_action_name(requested_action: String) -> String:
	var result := resolve_action(requested_action)
	if WorkdayContext.read_string(result, "kind") == "animation":
		return WorkdayContext.read_string(result, "action")
	return ""


# 解析请求动作，返回动画、静态纹理或缺失的详细结果。
func resolve_action(requested_action: String) -> Dictionary:
	if has_action(requested_action):
		return _animation_resolution(requested_action, requested_action)

	var emotion := _infer_emotion(requested_action)
	if not emotion.is_empty():
		var emotion_idle := WorkdayContext.read_string(emotion_fallbacks, emotion, "%s_idle" % emotion)
		if has_action(emotion_idle):
			return _animation_resolution(requested_action, emotion_idle)

	if has_action("idle"):
		return _animation_resolution(requested_action, "idle")

	if static_actor_texture != null:
		return {
			"kind": "texture",
			"requested_action": requested_action,
			"action": "",
			"texture": static_actor_texture,
			"texture_path": static_actor_texture_path,
		}

	return {
		"kind": "missing",
		"requested_action": requested_action,
		"action": "",
		"texture": null,
		"texture_path": "",
	}


# 重置所有加载状态与元数据。
func _reset() -> void:
	table_path = ""
	character_id = ""
	default_animation = "idle"
	sprite_frames = SpriteFrames.new()
	if sprite_frames.has_animation("default"):
		sprite_frames.remove_animation("default")
	action_metadata.clear()
	emotion_fallbacks = {
		"happy": "happy_idle",
		"angry": "angry_idle",
	}
	required_actions.clear()
	optional_actions.clear()
	max_unique_pngs = 0
	micro_expressions.clear()
	micro_expression_cooldown = Vector2(2.5, 5.0)
	substitute_frames_with_static_actor = false
	static_actor_texture = null
	static_actor_texture_path = ""
	warning_messages.clear()
	error_messages.clear()


# 读取动作契约，包括必需/可选动作与最大 PNG 数量限制。
func _read_action_contract(value: Variant) -> void:
	if not value is Dictionary:
		if value != null:
			_error("Animation table 'action_contract' must be an object.")
		return
	@warning_ignore("unsafe_cast")
	var contract: Dictionary = value
	required_actions = _read_action_name_list(contract.get("required", []), "required")
	optional_actions = _read_action_name_list(contract.get("optional", []), "optional")
	max_unique_pngs = maxi(WorkdayContext.read_int(contract, "max_unique_pngs"), 0)
	for action in required_actions:
		if action in optional_actions:
			_error("Action '%s' cannot be both required and optional." % action)


# 将数组值解析为动作名列表。
func _read_action_name_list(value: Variant, field_name: String) -> PackedStringArray:
	var result := PackedStringArray()
	if not value is Array:
		_error("Animation contract '%s' must be an array." % field_name)
		return result
	@warning_ignore("unsafe_cast")
	var values: Array = value
	for action_value: Variant in values:
		var action := WorkdayContext.stringify_value(action_value).strip_edges()
		if action.is_empty():
			_error("Animation contract '%s' contains an empty action." % field_name)
		elif action not in result:
			result.append(action)
	return result


# 验证必需动作存在且唯一 PNG 数量未超限。
func _validate_action_contract() -> void:
	for action in required_actions:
		if not has_action(action):
			_error("Animation table is missing required action '%s'." % action)
	if max_unique_pngs <= 0:
		return
	var unique_paths := {}
	for metadata_value: Variant in action_metadata.values():
		if not metadata_value is Dictionary:
			continue
		@warning_ignore("unsafe_cast")
		var metadata: Dictionary = metadata_value
		var frame_paths: PackedStringArray = metadata.get("frame_paths", PackedStringArray())
		for frame_path in frame_paths:
			if String(frame_path).to_lower().ends_with(".png"):
				unique_paths[String(frame_path)] = true
	if unique_paths.size() > max_unique_pngs:
		_error("Animation table uses %d unique PNG files; contract allows at most %d." % [unique_paths.size(), max_unique_pngs])


# 读取情绪到待机动作的降级映射。
func _read_emotion_fallbacks(value: Variant) -> void:
	if typeof(value) != TYPE_DICTIONARY:
		if value != null:
			_warn("Ignored 'emotion_fallbacks' because it is not an object.")
		return
	@warning_ignore("unsafe_cast")
	var fallbacks: Dictionary = value
	for emotion_value: Variant in fallbacks:
		var emotion := WorkdayContext.stringify_value(emotion_value).to_lower()
		var action_name := WorkdayContext.stringify_value(fallbacks[emotion_value])
		if emotion.is_empty() or action_name.is_empty():
			_warn("Ignored an empty emotion fallback entry.")
			continue
		emotion_fallbacks[emotion] = action_name


# 读取微表情动作列表与权重。
func _read_micro_expressions(value: Variant) -> void:
	if not value is Array:
		_warn("Ignored 'micro_expressions' because it is not an array.")
		return
	@warning_ignore("unsafe_cast")
	var entries: Array = value
	for entry_value: Variant in entries:
		if not entry_value is Dictionary:
			_warn("Ignored a micro-expression because it is not an object.")
			continue
		@warning_ignore("unsafe_cast")
		var entry: Dictionary = entry_value
		var action := WorkdayContext.read_string(entry, "action")
		var weight := maxi(WorkdayContext.read_int(entry, "weight"), 0)
		if action.is_empty() or weight <= 0:
			_warn("Ignored a micro-expression with an empty action or non-positive weight.")
			continue
		micro_expressions.append({"action": action, "weight": weight})


# 读取微表情触发冷却时间范围。
func _read_micro_expression_cooldown(value: Variant) -> void:
	if not value is Array:
		_warn("Invalid micro-expression cooldown; using 2.5–5.0 seconds.")
		return
	@warning_ignore("unsafe_cast")
	var cooldown: Array = value
	if cooldown.size() < 2:
		_warn("Invalid micro-expression cooldown; using 2.5–5.0 seconds.")
		return
	var minimum := maxf(WorkdayContext.to_float(cooldown[0]), 0.0)
	var maximum := maxf(WorkdayContext.to_float(cooldown[1], minimum), minimum)
	micro_expression_cooldown = Vector2(minimum, maximum)


# 加载并设置静态演员替代纹理。
func _set_static_actor_texture(configured_path: String) -> void:
	if configured_path.is_empty():
		return
	static_actor_texture_path = _resolve_path(configured_path)
	static_actor_texture = _load_texture(static_actor_texture_path)
	if static_actor_texture == null:
		_warn("Static actor texture could not be loaded: %s" % static_actor_texture_path)


# 解析并添加一个动作到 SpriteFrames 与元数据。
func _add_action(action: Dictionary) -> void:
	var action_name := WorkdayContext.read_string(action, "action", WorkdayContext.read_string(action, "id", WorkdayContext.read_string(action, "name")))
	if action_name.is_empty():
		_warn("Ignored an action row with no 'action' name.")
		return

	var fps := WorkdayContext.read_float(action, "fps", 1.0)
	if fps <= 0.0:
		_warn("Action '%s' has invalid FPS; using 1 FPS." % action_name)
		fps = 1.0
	elif fps > MAX_ACTION_FPS:
		_warn("Action '%s' exceeds the %.0f FPS style limit; using %.0f FPS." % [action_name, MAX_ACTION_FPS, MAX_ACTION_FPS])
		fps = MAX_ACTION_FPS

	var playback := WorkdayContext.read_string(action, "playback", WorkdayContext.read_string(action, "mode", PLAYBACK_LOOP)).to_upper()
	if playback not in VALID_PLAYBACK_MODES:
		_warn("Action '%s' has unknown playback mode '%s'; using LOOP." % [action_name, playback])
		playback = PLAYBACK_LOOP

	var configured_frames: Variant = action.get("frames", [])
	if typeof(configured_frames) != TYPE_ARRAY:
		_warn("Action '%s' has no frame array and was skipped." % action_name)
		return

	var valid_textures: Array[Texture2D] = []
	var valid_paths: PackedStringArray = []
	@warning_ignore("unsafe_cast")
	var configured_frame_list: Array = configured_frames
	for frame_value: Variant in configured_frame_list:
		var configured_frame_path := ""
		if frame_value is String or frame_value is StringName or frame_value is NodePath:
			configured_frame_path = WorkdayContext.stringify_value(frame_value)
		elif frame_value is Dictionary:
			@warning_ignore("unsafe_cast")
			var frame: Dictionary = frame_value
			configured_frame_path = WorkdayContext.read_string(frame, "path")
		if configured_frame_path.is_empty():
			_warn("Action '%s' contains an empty frame entry; the frame was skipped." % action_name)
			continue
		if substitute_frames_with_static_actor and static_actor_texture != null:
			valid_textures.append(static_actor_texture)
			valid_paths.append(static_actor_texture_path)
			continue
		var resolved_frame_path := _resolve_path(configured_frame_path)
		var texture := _load_texture(resolved_frame_path)
		if texture == null:
			_warn("Action '%s' is missing frame: %s" % [action_name, resolved_frame_path])
			continue
		valid_textures.append(texture)
		valid_paths.append(resolved_frame_path)

	if valid_textures.is_empty():
		_warn("Action '%s' has no usable frames and was skipped." % action_name)
		return

	if sprite_frames.has_animation(action_name):
		_warn("Duplicate action '%s' replaced its previous row." % action_name)
		sprite_frames.remove_animation(action_name)
	sprite_frames.add_animation(action_name)
	sprite_frames.set_animation_speed(action_name, fps)
	sprite_frames.set_animation_loop(action_name, playback == PLAYBACK_LOOP)
	for texture in valid_textures:
		sprite_frames.add_frame(action_name, texture)

	action_metadata[action_name] = {
		"fps": fps,
		"playback": playback,
		"loop": playback == PLAYBACK_LOOP,
		"hold_last_frame": playback == PLAYBACK_HOLD,
		"frame_paths": valid_paths,
		"frame_count": valid_textures.size(),
	}


# 将相对路径解析为基于动画表目录的完整路径。
func _resolve_path(configured_path: String) -> String:
	if configured_path.begins_with("res://") or configured_path.begins_with("user://") or configured_path.is_absolute_path():
		return configured_path.simplify_path()
	return table_path.get_base_dir().path_join(configured_path).simplify_path()


# 加载指定路径的纹理资源。
func _load_texture(path: String) -> Texture2D:
	if not ResourceLoader.exists(path, "Texture2D"):
		return null
	var resource := ResourceLoader.load(path, "Texture2D")
	if resource is Texture2D:
		@warning_ignore("unsafe_cast")
		var texture: Texture2D = resource
		return texture
	return null


# 从动作名推断对应情绪关键词。
func _infer_emotion(action_name: String) -> String:
	var normalized := action_name.to_lower()
	for emotion_value: Variant in emotion_fallbacks:
		var emotion := WorkdayContext.stringify_value(emotion_value)
		if normalized.contains(emotion):
			return emotion
	if normalized.contains("approved") or normalized.contains("approve"):
		return "happy"
	if normalized.contains("rejected") or normalized.contains("reject"):
		return "angry"
	return ""


# 构造动画解析结果字典。
func _animation_resolution(requested_action: String, resolved_action: String) -> Dictionary:
	return {
		"kind": "animation",
		"requested_action": requested_action,
		"action": resolved_action,
		"texture": null,
		"texture_path": "",
	}


# 记录警告信息。
func _warn(message: String) -> void:
	warning_messages.append(message)
	push_warning(message)


# 记录错误信息。
func _error(message: String) -> void:
	error_messages.append(message)
	push_error(message)
