extends SceneTree


func _init() -> void:
	call_deferred("run")


func run() -> void:
	var library_script = load("res://scripts/gameplay/npc_animation_library.gd")
	var library = library_script.new()
	assert(
		library.load_animation_table(
			"res://data/animations/default_applicant/animation_table.json"
		),
		"default NPC animation table must load"
	)
	assert(library.error_messages.is_empty(), "valid animation table must not report errors")
	assert(library.warning_messages.is_empty(), "valid animation table must not report warnings")
	assert(library.character_id == "DEFAULT-APPLICANT", "character metadata must be exposed")
	assert(
		library.micro_expressions.size() == 3
		and library.micro_expression_cooldown == Vector2(2.5, 5.0),
		"micro-expression weights and cooldown must be exposed to the performance director"
	)
	assert(library.has_action("walk_in"), "configured walk action must be built")
	assert(
		library.sprite_frames.get_frame_count("walk_in") == 5,
		"all five configured walk frames must be built"
	)
	assert(
		is_equal_approx(library.get_action_fps("walk_in"), 4.0),
		"configured actions must respect the four FPS style limit"
	)
	for action_name: StringName in library.sprite_frames.get_animation_names():
		assert(
			library.sprite_frames.get_animation_speed(action_name)
			<= library_script.MAX_ACTION_FPS,
			"no default animation may exceed the global four FPS style limit"
		)
	assert(
		library.sprite_frames.get_animation_loop("walk_in"),
		"LOOP actions must loop in SpriteFrames"
	)
	assert(
		not library.sprite_frames.get_animation_loop("arrive"),
		"ONCE actions must not loop in SpriteFrames"
	)
	assert(
		library.get_playback_mode("angry_react") == "HOLD",
		"HOLD semantics must remain available as metadata"
	)
	assert(
		library.should_hold_last_frame("angry_react"),
		"HOLD actions must tell the player to retain their final frame"
	)

	var actor_override = library_script.new()
	assert(
		actor_override.load_animation_table(
			"res://data/animations/default_applicant/animation_table.json",
			"res://assets/characters/applicants/person_xu/fullbody.png"
		),
		"default table must accept a per-character full-body texture override"
	)
	assert(
		actor_override.sprite_frames.get_frame_texture("walk_in", 0).resource_path
		== "res://assets/characters/applicants/person_xu/fullbody.png",
		"placeholder frame rows must keep each NPC's configured full-body identity"
	)

	var lin_animation = library_script.new()
	assert(
		lin_animation.load_animation_table(
			"res://data/animations/person_lin/animation_table.json"
		),
		"Lin Mo's production animation table must load"
	)
	assert(
		lin_animation.error_messages.is_empty()
		and lin_animation.warning_messages.is_empty(),
		"Lin Mo's production animation table must resolve every real frame"
	)
	assert(
		lin_animation.character_id == "PERSON-LIN"
		and not lin_animation.substitute_frames_with_static_actor,
		"Lin Mo must use his own generated frames instead of the static placeholder"
	)
	var lin_idle_texture: Texture2D = (
		lin_animation.sprite_frames.get_frame_texture("idle", 0)
	)
	assert(
		lin_idle_texture.resource_path
		== (
			"res://assets/characters/applicants/person_lin/fullbody_frames_20/"
			+ "02_idle_neutral_a_fullbody.png"
		),
		"Lin Mo's idle must resolve to a filename explicitly marked as full-body"
	)
	assert(
		lin_idle_texture.get_size() == Vector2(512, 768),
		"production animation frames must share the normalized canvas"
	)
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
		assert(
			lin_animation.sprite_frames.get_frame_count(action_name) == expected_count,
			"Lin Mo action '%s' must use the approved %d-frame budget"
			% [action_name, expected_count]
		)
		var metadata: Dictionary = lin_animation.get_action_metadata(action_name)
		var frame_paths: PackedStringArray = metadata.get("frame_paths", PackedStringArray())
		assert(
			frame_paths.size() == expected_count,
			"Lin Mo action '%s' metadata must match its SpriteFrames count" % action_name
		)
		for frame_path: String in frame_paths:
			assert(
				frame_path.begins_with(
					"res://assets/characters/applicants/person_lin/fullbody_frames_20/"
				),
				"Lin Mo action '%s' must resolve only from the curated 20-frame folder"
				% action_name
			)
			assert(
				frame_path.ends_with("_fullbody.png"),
				"every active Lin Mo frame filename must declare full-body coverage"
			)
			assert(
				ResourceLoader.exists(frame_path, "Texture2D"),
				"Lin Mo production frame must exist as an imported Texture2D: %s" % frame_path
			)
	assert(
		not lin_animation.has_action("walk_in")
		and not lin_animation.has_action("arrive")
		and not lin_animation.has_action("look_aside"),
		"unused entry actions and the partial-body look-aside row must not remain active"
	)
	var active_fullbody_pngs := PackedStringArray()
	for filename in DirAccess.get_files_at(
		"res://assets/characters/applicants/person_lin/fullbody_frames_20"
	):
		if filename.ends_with(".png"):
			active_fullbody_pngs.append(filename)
	assert(
		active_fullbody_pngs.size() == 20,
		"Lin Mo's active animation asset budget must be exactly 20 PNG files"
	)
	for filename in active_fullbody_pngs:
		assert(
			filename.ends_with("_fullbody.png"),
			"the 20-file budget must contain only explicitly marked full-body images"
		)
	for action_name: StringName in lin_animation.sprite_frames.get_animation_names():
		assert(
			lin_animation.get_action_fps(action_name) <= library_script.MAX_ACTION_FPS,
			"no production animation may exceed the global four FPS style limit"
		)

	var exact: Dictionary = library.resolve_action("blink")
	assert(
		exact.get("kind") == "animation" and exact.get("action") == "blink",
		"an available requested action must resolve to itself"
	)
	var emotional: Dictionary = library.resolve_action("unmade_happy_departure")
	assert(
		emotional.get("action") == "happy_idle",
		"a missing emotional action must fall back to its emotion idle"
	)
	var neutral: Dictionary = library.resolve_action("unmade_neutral_action")
	assert(
		neutral.get("action") == "idle",
		"a missing neutral action must fall back to idle"
	)

	var partial = library_script.new()
	assert(
		partial.load_animation_table(
			"res://tests/fixtures/npc_animation_missing_frame.json"
		),
		"a table with some missing optional frames must still load"
	)
	assert(
		partial.sprite_frames.get_frame_count("partial_once") == 2,
		"missing frames must be skipped without discarding valid frames"
	)
	assert(
		is_equal_approx(
			partial.get_action_fps("partial_once"),
			library_script.MAX_ACTION_FPS
		),
		"the loader must cap an out-of-policy configuration at four FPS"
	)
	assert(
		not partial.has_action("empty_action"),
		"an action with no usable frames must not be registered"
	)
	assert(
		partial.warning_messages.size() >= 3,
		"missing frames and empty actions must produce configuration warnings"
	)
	var static_fallback: Dictionary = partial.resolve_action("unknown")
	assert(
		static_fallback.get("kind") == "texture"
		and static_fallback.get("texture") != null,
		"resolution must fall back to the configured static actor texture when idle is absent"
	)

	print("FORMOCRACY_NPC_ANIMATION_LIBRARY_TEST_OK")
	quit(0)
