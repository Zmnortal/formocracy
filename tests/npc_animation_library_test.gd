extends SceneTree


func _init() -> void:
	call_deferred("run")


func run() -> void:
	var library_script = load("res://scripts/gameplay/npc_animation_library.gd")
	var library = library_script.new()
	assert(library.load_animation_table("res://data/animations/default_applicant/animation_table.json"), "default NPC animation table must load")
	assert(library.error_messages.is_empty(), "valid animation table must not report errors")
	assert(library.warning_messages.is_empty(), "valid animation table must not report warnings")
	assert(library.character_id == "DEFAULT-APPLICANT", "character metadata must be exposed")
	assert(library.micro_expressions.size() == 2 and library.micro_expression_cooldown == Vector2(2.5, 5.0), "the simplified micro-expression pool and cooldown must be exposed")
	assert(
		library.required_actions.size() == 8 and library.optional_actions == PackedStringArray(["queue_idle", "blink", "nervous"]) and library.max_unique_pngs == 20,
		"the formal eight-core plus three-optional action contract must load"
	)
	assert(library.sprite_frames.get_frame_count("queue_idle") == 3, "the optional queue breathing action must use the simplified three-frame budget")
	assert(is_equal_approx(library.get_action_fps("queue_idle"), 2.0), "queue breathing must keep the deliberately slow two FPS timing")
	assert(
		not library.has_action("walk_in") and not library.has_action("arrive") and not library.has_action("look_aside"),
		"legacy entrance and partial look-aside actions must not remain in the default contract"
	)
	for action_name: StringName in library.sprite_frames.get_animation_names():
		assert(library.sprite_frames.get_animation_speed(action_name) <= library_script.MAX_ACTION_FPS, "no default animation may exceed the global four FPS style limit")
	assert(library.sprite_frames.get_animation_loop("queue_idle"), "queue_idle must loop in SpriteFrames")
	assert(library.get_playback_mode("angry_react") == "HOLD", "HOLD semantics must remain available as metadata")
	assert(library.should_hold_last_frame("angry_react"), "HOLD actions must tell the player to retain their final frame")

	var actor_override = library_script.new()
	assert(
		actor_override.load_animation_table("res://data/animations/default_applicant/animation_table.json", "res://assets/characters/applicants/person_meng/fullbody.png"),
		"default table must accept a per-character full-body texture override"
	)
	assert(
		actor_override.sprite_frames.get_frame_texture("queue_idle", 0).resource_path == "res://assets/characters/applicants/person_meng/fullbody.png",
		"placeholder queue frames must keep each NPC's configured full-body identity"
	)

	var lin_animation = library_script.new()
	assert(lin_animation.load_animation_table("res://data/animations/person_lin/animation_table.json"), "Lin Mo's production animation table must load")
	assert(lin_animation.error_messages.is_empty() and lin_animation.warning_messages.is_empty(), "Lin Mo's production animation table must resolve every real frame")
	assert(lin_animation.character_id == "PERSON-LIN" and not lin_animation.substitute_frames_with_static_actor, "Lin Mo must use his own generated frames instead of the static placeholder")
	assert(
		lin_animation.required_actions == library.required_actions and lin_animation.optional_actions == library.optional_actions and lin_animation.max_unique_pngs == 20,
		"production and default characters must implement the same formal action contract"
	)
	var lin_idle_texture: Texture2D = lin_animation.sprite_frames.get_frame_texture("idle", 0)
	assert(
		lin_idle_texture.resource_path == ("res://assets/characters/applicants/person_lin/fullbody_frames_20/" + "02_idle_neutral_a_fullbody.png"),
		"Lin Mo's idle must resolve to a filename explicitly marked as full-body"
	)
	assert(lin_idle_texture.get_size() == Vector2(512, 768), "production animation frames must share the normalized canvas")
	var expected_lin_frame_counts := {
		"queue_idle": 3,
		"idle": 2,
		"blink": 3,
		"nervous": 3,
		"deliver": 3,
		"happy_react": 4,
		"happy_idle": 2,
		"angry_react": 4,
		"angry_idle": 2,
		"walk_out_happy": 3,
		"walk_out_angry": 3,
	}
	for action_name: String in expected_lin_frame_counts:
		var expected_count: int = expected_lin_frame_counts[action_name]
		assert(lin_animation.sprite_frames.get_frame_count(action_name) == expected_count, "Lin Mo action '%s' must use the approved %d-frame budget" % [action_name, expected_count])
		var metadata: Dictionary = lin_animation.get_action_metadata(action_name)
		var frame_paths: PackedStringArray = metadata.get("frame_paths", PackedStringArray())
		assert(frame_paths.size() == expected_count, "Lin Mo action '%s' metadata must match its SpriteFrames count" % action_name)
		for frame_path: String in frame_paths:
			assert(frame_path.begins_with("res://assets/characters/applicants/person_lin/fullbody_frames_20/"), "Lin Mo action '%s' must resolve only from the curated 20-frame folder" % action_name)
			assert(frame_path.ends_with("_fullbody.png"), "every active Lin Mo frame filename must declare full-body coverage")
			assert(ResourceLoader.exists(frame_path, "Texture2D"), "Lin Mo production frame must exist as an imported Texture2D: %s" % frame_path)
	assert(
		not lin_animation.has_action("walk_in") and not lin_animation.has_action("arrive") and not lin_animation.has_action("look_aside"),
		"unused entry actions and the partial-body look-aside row must not remain active"
	)
	var active_fullbody_pngs := PackedStringArray()
	for filename in DirAccess.get_files_at("res://assets/characters/applicants/person_lin/fullbody_frames_20"):
		if filename.ends_with(".png"):
			active_fullbody_pngs.append(filename)
	assert(active_fullbody_pngs.size() == 20, "Lin Mo's active animation asset budget must be exactly 20 PNG files")
	for filename in active_fullbody_pngs:
		assert(filename.ends_with("_fullbody.png"), "the 20-file budget must contain only explicitly marked full-body images")
	for action_name: StringName in lin_animation.sprite_frames.get_animation_names():
		assert(lin_animation.get_action_fps(action_name) <= library_script.MAX_ACTION_FPS, "no production animation may exceed the global four FPS style limit")

	var zhou_animation = library_script.new()
	assert(zhou_animation.load_animation_table("res://data/animations/person_zhou/animation_table.json"), "Zhou Xun's production animation table must load")
	assert(zhou_animation.error_messages.is_empty() and zhou_animation.warning_messages.is_empty(), "Zhou Xun's production animation table must resolve every generated frame")
	assert(zhou_animation.character_id == "PERSON-ZHOU" and not zhou_animation.substitute_frames_with_static_actor, "Zhou Xun must use his own generated frames instead of the static placeholder")
	assert(
		zhou_animation.required_actions == library.required_actions and zhou_animation.optional_actions == library.optional_actions and zhou_animation.max_unique_pngs == 20,
		"Zhou Xun must implement the formal eight-core plus three-optional contract"
	)
	var zhou_unique_frame_paths := {}
	for action_name: String in expected_lin_frame_counts:
		var expected_count: int = expected_lin_frame_counts[action_name]
		assert(zhou_animation.sprite_frames.get_frame_count(action_name) == expected_count, "Zhou Xun action '%s' must use the approved %d-frame budget" % [action_name, expected_count])
		var metadata: Dictionary = zhou_animation.get_action_metadata(action_name)
		var frame_paths: PackedStringArray = metadata.get("frame_paths", PackedStringArray())
		for frame_path: String in frame_paths:
			assert(
				frame_path.begins_with("res://assets/characters/applicants/person_zhou/fullbody_frames_20/") and frame_path.ends_with("_fullbody.png"),
				"every Zhou Xun action must resolve only to marked full-body production frames"
			)
			assert(ResourceLoader.exists(frame_path, "Texture2D"), "Zhou Xun production frame must import as Texture2D: %s" % frame_path)
			zhou_unique_frame_paths[frame_path] = true
	assert(zhou_unique_frame_paths.size() == 20, "Zhou Xun's eleven actions must collectively use exactly twenty unique PNG files")
	var active_zhou_pngs := PackedStringArray()
	for filename in DirAccess.get_files_at("res://assets/characters/applicants/person_zhou/fullbody_frames_20"):
		if filename.ends_with(".png"):
			active_zhou_pngs.append(filename)
	assert(active_zhou_pngs.size() == 20, "Zhou Xun's active animation directory must contain exactly twenty PNG files")
	for filename in active_zhou_pngs:
		assert(filename.ends_with("_fullbody.png"), "every active Zhou Xun filename must declare full-body coverage")
	assert(
		not zhou_animation.has_action("walk_in") and not zhou_animation.has_action("arrive") and not zhou_animation.has_action("look_aside"), "Zhou Xun must not reintroduce retired animation actions"
	)
	for action_name: StringName in zhou_animation.sprite_frames.get_animation_names():
		assert(zhou_animation.get_action_fps(action_name) <= library_script.MAX_ACTION_FPS, "no Zhou Xun animation may exceed the global four FPS style limit")

	var xu_animation = library_script.new()
	assert(xu_animation.load_animation_table("res://data/animations/person_xu/animation_table.json"), "Xu Qiao's production animation table must load")
	assert(xu_animation.error_messages.is_empty() and xu_animation.warning_messages.is_empty(), "Xu Qiao's production animation table must resolve every generated frame")
	assert(xu_animation.character_id == "PERSON-XU" and not xu_animation.substitute_frames_with_static_actor, "Xu Qiao must use her own generated frames instead of the static placeholder")
	assert(
		xu_animation.required_actions == library.required_actions and xu_animation.optional_actions == library.optional_actions and xu_animation.max_unique_pngs == 20,
		"Xu Qiao must implement the formal eight-core plus three-optional contract"
	)
	var xu_unique_frame_paths := {}
	for action_name: String in expected_lin_frame_counts:
		var expected_count: int = expected_lin_frame_counts[action_name]
		assert(xu_animation.sprite_frames.get_frame_count(action_name) == expected_count, "Xu Qiao action '%s' must use the approved %d-frame budget" % [action_name, expected_count])
		var metadata: Dictionary = xu_animation.get_action_metadata(action_name)
		var frame_paths: PackedStringArray = metadata.get("frame_paths", PackedStringArray())
		for frame_path: String in frame_paths:
			assert(
				frame_path.begins_with("res://assets/characters/applicants/person_xu/fullbody_frames_20/") and frame_path.ends_with("_fullbody.png"),
				"every Xu Qiao action must resolve only to marked full-body production frames"
			)
			assert(ResourceLoader.exists(frame_path, "Texture2D"), "Xu Qiao production frame must import as Texture2D: %s" % frame_path)
			xu_unique_frame_paths[frame_path] = true
	assert(xu_unique_frame_paths.size() == 20, "Xu Qiao's eleven actions must collectively use exactly twenty unique PNG files")
	var active_xu_pngs := PackedStringArray()
	for filename in DirAccess.get_files_at("res://assets/characters/applicants/person_xu/fullbody_frames_20"):
		if filename.ends_with(".png"):
			active_xu_pngs.append(filename)
	assert(active_xu_pngs.size() == 20, "Xu Qiao's active animation directory must contain exactly twenty PNG files")
	for filename in active_xu_pngs:
		assert(filename.ends_with("_fullbody.png"), "every active Xu Qiao filename must declare full-body coverage")
	assert(not xu_animation.has_action("walk_in") and not xu_animation.has_action("arrive") and not xu_animation.has_action("look_aside"), "Xu Qiao must not reintroduce retired animation actions")
	for action_name: StringName in xu_animation.sprite_frames.get_animation_names():
		assert(xu_animation.get_action_fps(action_name) <= library_script.MAX_ACTION_FPS, "no Xu Qiao animation may exceed the global four FPS style limit")

	var meng_animation = library_script.new()
	assert(meng_animation.load_animation_table("res://data/animations/person_meng/animation_table.json"), "Meng Qiulan's production animation table must load")
	assert(meng_animation.error_messages.is_empty() and meng_animation.warning_messages.is_empty(), "Meng Qiulan's production animation table must resolve every generated frame")
	assert(meng_animation.character_id == "PERSON-MENG" and not meng_animation.substitute_frames_with_static_actor, "Meng Qiulan must use her own generated frames instead of the static placeholder")
	assert(
		meng_animation.required_actions == library.required_actions and meng_animation.optional_actions == library.optional_actions and meng_animation.max_unique_pngs == 20,
		"Meng Qiulan must implement the formal eight-core plus three-optional contract"
	)
	var meng_unique_frame_paths := {}
	for action_name: String in expected_lin_frame_counts:
		var expected_count: int = expected_lin_frame_counts[action_name]
		assert(meng_animation.sprite_frames.get_frame_count(action_name) == expected_count, "Meng Qiulan action '%s' must use the approved %d-frame budget" % [action_name, expected_count])
		var metadata: Dictionary = meng_animation.get_action_metadata(action_name)
		var frame_paths: PackedStringArray = metadata.get("frame_paths", PackedStringArray())
		for frame_path: String in frame_paths:
			assert(
				frame_path.begins_with("res://assets/characters/applicants/person_meng/fullbody_frames_20/") and frame_path.ends_with("_fullbody.png"),
				"every Meng Qiulan action must resolve only to marked full-body production frames"
			)
			assert(ResourceLoader.exists(frame_path, "Texture2D"), "Meng Qiulan production frame must import as Texture2D: %s" % frame_path)
			meng_unique_frame_paths[frame_path] = true
	assert(meng_unique_frame_paths.size() == 20, "Meng Qiulan's eleven actions must collectively use exactly twenty unique PNG files")
	var active_meng_pngs := PackedStringArray()
	for filename in DirAccess.get_files_at("res://assets/characters/applicants/person_meng/fullbody_frames_20"):
		if filename.ends_with(".png"):
			active_meng_pngs.append(filename)
	assert(active_meng_pngs.size() == 20, "Meng Qiulan's active animation directory must contain exactly twenty PNG files")
	for filename in active_meng_pngs:
		assert(filename.ends_with("_fullbody.png"), "every active Meng Qiulan filename must declare full-body coverage")
	assert(
		not meng_animation.has_action("walk_in") and not meng_animation.has_action("arrive") and not meng_animation.has_action("look_aside"),
		"Meng Qiulan must not reintroduce retired animation actions"
	)
	for action_name: StringName in meng_animation.sprite_frames.get_animation_names():
		assert(meng_animation.get_action_fps(action_name) <= library_script.MAX_ACTION_FPS, "no Meng Qiulan animation may exceed the global four FPS style limit")

	var exact: Dictionary = library.resolve_action("blink")
	assert(exact.get("kind") == "animation" and exact.get("action") == "blink", "an available requested action must resolve to itself")
	var emotional: Dictionary = library.resolve_action("unmade_happy_departure")
	assert(emotional.get("action") == "happy_idle", "a missing emotional action must fall back to its emotion idle")
	var neutral: Dictionary = library.resolve_action("unmade_neutral_action")
	assert(neutral.get("action") == "idle", "a missing neutral action must fall back to idle")

	var partial = library_script.new()
	assert(partial.load_animation_table("res://tests/fixtures/npc_animation_missing_frame.json"), "a table with some missing optional frames must still load")
	assert(partial.sprite_frames.get_frame_count("partial_once") == 2, "missing frames must be skipped without discarding valid frames")
	assert(is_equal_approx(partial.get_action_fps("partial_once"), library_script.MAX_ACTION_FPS), "the loader must cap an out-of-policy configuration at four FPS")
	assert(not partial.has_action("empty_action"), "an action with no usable frames must not be registered")
	assert(partial.warning_messages.size() >= 3, "missing frames and empty actions must produce configuration warnings")
	var static_fallback: Dictionary = partial.resolve_action("unknown")
	assert(static_fallback.get("kind") == "texture" and static_fallback.get("texture") != null, "resolution must fall back to the configured static actor texture when idle is absent")

	var invalid_contract = library_script.new()
	assert(not invalid_contract.load_animation_table("res://tests/fixtures/npc_animation_missing_required_action.json"), "a table that declares but omits a required action must be rejected")
	assert(not invalid_contract.error_messages.is_empty() and "deliver" in invalid_contract.error_messages[-1], "the rejected contract must identify its missing required action")

	print("FORMOCRACY_NPC_ANIMATION_LIBRARY_TEST_OK")
	quit(0)
