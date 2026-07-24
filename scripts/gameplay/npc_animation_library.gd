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
var micro_expressions: Array[Dictionary] = []
var micro_expression_cooldown := Vector2(2.5, 5.0)
var substitute_frames_with_static_actor := false
var static_actor_texture: Texture2D
var static_actor_texture_path := ""
var warning_messages: PackedStringArray = []
var error_messages: PackedStringArray = []


func load_animation_table(
	config_path: String,
	static_actor_texture_override: String = ""
) -> bool:
	_reset()
	table_path = config_path.simplify_path()
	if not FileAccess.file_exists(table_path):
		_error("Animation table does not exist: %s" % table_path)
		return false

	var file := FileAccess.open(table_path, FileAccess.READ)
	if file == null:
		_error("Animation table could not be opened: %s" % table_path)
		return false

	var json := JSON.new()
	var parse_result := json.parse(file.get_as_text())
	if parse_result != OK:
		_error(
			"Animation table JSON is invalid at line %d: %s"
			% [json.get_error_line(), json.get_error_message()]
		)
		return false
	if typeof(json.data) != TYPE_DICTIONARY:
		_error("Animation table root must be an object: %s" % table_path)
		return false

	var table: Dictionary = json.data
	character_id = String(table.get("character_id", ""))
	default_animation = String(table.get("default_animation", "idle"))
	_read_emotion_fallbacks(table.get("emotion_fallbacks", {}))
	_read_micro_expressions(table.get("micro_expressions", []))
	_read_micro_expression_cooldown(table.get("micro_expression_cooldown", [2.5, 5.0]))
	substitute_frames_with_static_actor = bool(table.get("substitute_frames_with_static_actor", false))

	var configured_static_path := static_actor_texture_override
	if configured_static_path.is_empty():
		configured_static_path = String(table.get("static_actor_texture", ""))
	_set_static_actor_texture(configured_static_path)

	var actions_value: Variant = table.get("actions", [])
	if typeof(actions_value) == TYPE_ARRAY:
		for action_value in actions_value:
			if typeof(action_value) != TYPE_DICTIONARY:
				_warn("Ignored an action row because it is not an object.")
				continue
			_add_action(action_value)
	elif typeof(actions_value) == TYPE_DICTIONARY:
		for action_name_value in actions_value:
			var action_value: Variant = actions_value[action_name_value]
			if typeof(action_value) != TYPE_DICTIONARY:
				_warn("Ignored action '%s' because its row is not an object." % action_name_value)
				continue
			var action_row: Dictionary = action_value.duplicate(true)
			action_row["action"] = String(action_name_value)
			_add_action(action_row)
	else:
		_error("Animation table 'actions' must be an array or object.")
		return false

	if action_metadata.is_empty() and static_actor_texture == null:
		_error("Animation table contains no usable action frames or static actor texture.")
		return false
	return true


func has_action(action_name: String) -> bool:
	return action_metadata.has(action_name) and sprite_frames.has_animation(action_name)


func get_sprite_frames() -> SpriteFrames:
	return sprite_frames


func get_action_metadata(action_name: String) -> Dictionary:
	return action_metadata.get(action_name, {}).duplicate(true)


func get_action_fps(action_name: String) -> float:
	return float(action_metadata.get(action_name, {}).get("fps", 0.0))


func get_playback_mode(action_name: String) -> String:
	return String(action_metadata.get(action_name, {}).get("playback", ""))


func should_hold_last_frame(action_name: String) -> bool:
	return get_playback_mode(action_name) == PLAYBACK_HOLD


func resolve_action_name(requested_action: String) -> String:
	var result := resolve_action(requested_action)
	if result.get("kind", "") == "animation":
		return String(result.get("action", ""))
	return ""


func resolve_action(requested_action: String) -> Dictionary:
	if has_action(requested_action):
		return _animation_resolution(requested_action, requested_action)

	var emotion := _infer_emotion(requested_action)
	if not emotion.is_empty():
		var emotion_idle := String(emotion_fallbacks.get(emotion, "%s_idle" % emotion))
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
	micro_expressions.clear()
	micro_expression_cooldown = Vector2(2.5, 5.0)
	substitute_frames_with_static_actor = false
	static_actor_texture = null
	static_actor_texture_path = ""
	warning_messages.clear()
	error_messages.clear()


func _read_emotion_fallbacks(value: Variant) -> void:
	if typeof(value) != TYPE_DICTIONARY:
		if value != null:
			_warn("Ignored 'emotion_fallbacks' because it is not an object.")
		return
	for emotion_value in value:
		var emotion := String(emotion_value).to_lower()
		var action_name := String(value[emotion_value])
		if emotion.is_empty() or action_name.is_empty():
			_warn("Ignored an empty emotion fallback entry.")
			continue
		emotion_fallbacks[emotion] = action_name


func _read_micro_expressions(value: Variant) -> void:
	if typeof(value) != TYPE_ARRAY:
		_warn("Ignored 'micro_expressions' because it is not an array.")
		return
	for entry_value in value:
		if typeof(entry_value) != TYPE_DICTIONARY:
			_warn("Ignored a micro-expression because it is not an object.")
			continue
		var action := String(entry_value.get("action", ""))
		var weight := maxi(int(entry_value.get("weight", 0)), 0)
		if action.is_empty() or weight <= 0:
			_warn("Ignored a micro-expression with an empty action or non-positive weight.")
			continue
		micro_expressions.append({"action": action, "weight": weight})


func _read_micro_expression_cooldown(value: Variant) -> void:
	if typeof(value) != TYPE_ARRAY or value.size() < 2:
		_warn("Invalid micro-expression cooldown; using 2.5–5.0 seconds.")
		return
	var minimum := maxf(float(value[0]), 0.0)
	var maximum := maxf(float(value[1]), minimum)
	micro_expression_cooldown = Vector2(minimum, maximum)


func _set_static_actor_texture(configured_path: String) -> void:
	if configured_path.is_empty():
		return
	static_actor_texture_path = _resolve_path(configured_path)
	static_actor_texture = _load_texture(static_actor_texture_path)
	if static_actor_texture == null:
		_warn("Static actor texture could not be loaded: %s" % static_actor_texture_path)


func _add_action(action: Dictionary) -> void:
	var action_name := String(action.get("action", action.get("id", action.get("name", ""))))
	if action_name.is_empty():
		_warn("Ignored an action row with no 'action' name.")
		return

	var fps := float(action.get("fps", 1.0))
	if fps <= 0.0:
		_warn("Action '%s' has invalid FPS; using 1 FPS." % action_name)
		fps = 1.0
	elif fps > MAX_ACTION_FPS:
		_warn(
			"Action '%s' exceeds the %.0f FPS style limit; using %.0f FPS."
			% [action_name, MAX_ACTION_FPS, MAX_ACTION_FPS]
		)
		fps = MAX_ACTION_FPS

	var playback := String(action.get("playback", action.get("mode", PLAYBACK_LOOP))).to_upper()
	if playback not in VALID_PLAYBACK_MODES:
		_warn("Action '%s' has unknown playback mode '%s'; using LOOP." % [action_name, playback])
		playback = PLAYBACK_LOOP

	var configured_frames: Variant = action.get("frames", [])
	if typeof(configured_frames) != TYPE_ARRAY:
		_warn("Action '%s' has no frame array and was skipped." % action_name)
		return

	var valid_textures: Array[Texture2D] = []
	var valid_paths: PackedStringArray = []
	for frame_value in configured_frames:
		var configured_frame_path := ""
		if typeof(frame_value) == TYPE_STRING:
			configured_frame_path = String(frame_value)
		elif typeof(frame_value) == TYPE_DICTIONARY:
			configured_frame_path = String(frame_value.get("path", ""))
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


func _resolve_path(configured_path: String) -> String:
	if (
		configured_path.begins_with("res://")
		or configured_path.begins_with("user://")
		or configured_path.is_absolute_path()
	):
		return configured_path.simplify_path()
	return table_path.get_base_dir().path_join(configured_path).simplify_path()


func _load_texture(path: String) -> Texture2D:
	if not ResourceLoader.exists(path, "Texture2D"):
		return null
	var resource := ResourceLoader.load(path, "Texture2D")
	return resource as Texture2D


func _infer_emotion(action_name: String) -> String:
	var normalized := action_name.to_lower()
	for emotion_value in emotion_fallbacks:
		var emotion := String(emotion_value)
		if normalized.contains(emotion):
			return emotion
	if normalized.contains("approved") or normalized.contains("approve"):
		return "happy"
	if normalized.contains("rejected") or normalized.contains("reject"):
		return "angry"
	return ""


func _animation_resolution(requested_action: String, resolved_action: String) -> Dictionary:
	return {
		"kind": "animation",
		"requested_action": requested_action,
		"action": resolved_action,
		"texture": null,
		"texture_path": "",
	}


func _warn(message: String) -> void:
	warning_messages.append(message)
	push_warning(message)


func _error(message: String) -> void:
	error_messages.append(message)
	push_error(message)
