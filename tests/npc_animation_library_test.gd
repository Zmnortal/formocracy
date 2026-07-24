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
		is_equal_approx(library.get_action_fps("walk_in"), 7.0),
		"each action must preserve its own FPS"
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
			"res://assets/characters/applicants/npc_female_young.png"
		),
		"default table must accept a per-character full-body texture override"
	)
	assert(
		actor_override.sprite_frames.get_frame_texture("walk_in", 0).resource_path
		== "res://assets/characters/applicants/npc_female_young.png",
		"placeholder frame rows must keep each NPC's configured full-body identity"
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
