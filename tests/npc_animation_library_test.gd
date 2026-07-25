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

	var he_animation = library_script.new()
	assert(he_animation.load_animation_table("res://data/animations/person_he/animation_table.json"), "He Yun's production animation table must load")
	assert(he_animation.error_messages.is_empty() and he_animation.warning_messages.is_empty(), "He Yun's production animation table must resolve every generated frame")
	assert(he_animation.character_id == "PERSON-HE" and not he_animation.substitute_frames_with_static_actor, "He Yun must use her own generated frames instead of the retired placeholder")
	assert(
		he_animation.required_actions == library.required_actions and he_animation.optional_actions == library.optional_actions and he_animation.max_unique_pngs == 20,
		"He Yun must implement the formal eight-core plus three-optional contract"
	)
	var he_unique_frame_paths := {}
	for action_name: String in expected_lin_frame_counts:
		var expected_count: int = expected_lin_frame_counts[action_name]
		assert(he_animation.sprite_frames.get_frame_count(action_name) == expected_count, "He Yun action '%s' must use the approved %d-frame budget" % [action_name, expected_count])
		var metadata: Dictionary = he_animation.get_action_metadata(action_name)
		var frame_paths: PackedStringArray = metadata.get("frame_paths", PackedStringArray())
		for frame_path: String in frame_paths:
			assert(
				frame_path.begins_with("res://assets/characters/applicants/person_he/fullbody_frames_20/") and frame_path.ends_with("_fullbody.png"),
				"every He Yun action must resolve only to marked full-body production frames"
			)
			assert(ResourceLoader.exists(frame_path, "Texture2D"), "He Yun production frame must import as Texture2D: %s" % frame_path)
			he_unique_frame_paths[frame_path] = true
	assert(he_unique_frame_paths.size() == 20, "He Yun's eleven actions must collectively use exactly twenty unique PNG files")
	var active_he_pngs := PackedStringArray()
	for filename in DirAccess.get_files_at("res://assets/characters/applicants/person_he/fullbody_frames_20"):
		if filename.ends_with(".png"):
			active_he_pngs.append(filename)
	assert(active_he_pngs.size() == 20, "He Yun's active animation directory must contain exactly twenty PNG files")
	for filename in active_he_pngs:
		assert(filename.ends_with("_fullbody.png"), "every active He Yun filename must declare full-body coverage")
	assert(not he_animation.has_action("walk_in") and not he_animation.has_action("arrive") and not he_animation.has_action("look_aside"), "He Yun must not reintroduce retired animation actions")
	for action_name: StringName in he_animation.sprite_frames.get_animation_names():
		assert(he_animation.get_action_fps(action_name) <= library_script.MAX_ACTION_FPS, "no He Yun animation may exceed the global four FPS style limit")

	var du_animation = library_script.new()
	assert(du_animation.load_animation_table("res://data/animations/person_du/animation_table.json"), "Du Chunmei's production animation table must load")
	assert(du_animation.error_messages.is_empty() and du_animation.warning_messages.is_empty(), "Du Chunmei's production animation table must resolve every generated frame")
	assert(du_animation.character_id == "PERSON-DU" and not du_animation.substitute_frames_with_static_actor, "Du Chunmei must use her own generated frames instead of the static placeholder")
	assert(
		du_animation.required_actions == library.required_actions and du_animation.optional_actions == library.optional_actions and du_animation.max_unique_pngs == 20,
		"Du Chunmei must implement the formal eight-core plus three-optional contract"
	)
	var du_unique_frame_paths := {}
	for action_name: String in expected_lin_frame_counts:
		var expected_count: int = expected_lin_frame_counts[action_name]
		assert(du_animation.sprite_frames.get_frame_count(action_name) == expected_count, "Du Chunmei action '%s' must use the approved %d-frame budget" % [action_name, expected_count])
		var metadata: Dictionary = du_animation.get_action_metadata(action_name)
		var frame_paths: PackedStringArray = metadata.get("frame_paths", PackedStringArray())
		for frame_path: String in frame_paths:
			assert(
				frame_path.begins_with("res://assets/characters/applicants/person_du/fullbody_frames_20/") and frame_path.ends_with("_fullbody.png"),
				"every Du Chunmei action must resolve only to marked full-body production frames"
			)
			assert(ResourceLoader.exists(frame_path, "Texture2D"), "Du Chunmei production frame must import as Texture2D: %s" % frame_path)
			du_unique_frame_paths[frame_path] = true
	assert(du_unique_frame_paths.size() == 20, "Du Chunmei's eleven actions must collectively use exactly twenty unique PNG files")
	var active_du_pngs := PackedStringArray()
	for filename in DirAccess.get_files_at("res://assets/characters/applicants/person_du/fullbody_frames_20"):
		if filename.ends_with(".png"):
			active_du_pngs.append(filename)
	assert(active_du_pngs.size() == 20, "Du Chunmei's active animation directory must contain exactly twenty PNG files")
	for filename in active_du_pngs:
		assert(filename.ends_with("_fullbody.png"), "every active Du Chunmei filename must declare full-body coverage")
	assert(
		not du_animation.has_action("walk_in") and not du_animation.has_action("arrive") and not du_animation.has_action("look_aside"),
		"Du Chunmei must not reintroduce retired animation actions"
	)
	for action_name: StringName in du_animation.sprite_frames.get_animation_names():
		assert(du_animation.get_action_fps(action_name) <= library_script.MAX_ACTION_FPS, "no Du Chunmei animation may exceed the global four FPS style limit")

	var gu_animation = library_script.new()
	assert(gu_animation.load_animation_table("res://data/animations/person_gu/animation_table.json"), "Gu Yuan's production animation table must load")
	assert(gu_animation.error_messages.is_empty() and gu_animation.warning_messages.is_empty(), "Gu Yuan's production animation table must resolve every generated frame")
	assert(gu_animation.character_id == "PERSON-GU" and not gu_animation.substitute_frames_with_static_actor, "Gu Yuan must use his own generated frames instead of the static placeholder")
	assert(
		gu_animation.required_actions == library.required_actions and gu_animation.optional_actions == library.optional_actions and gu_animation.max_unique_pngs == 20,
		"Gu Yuan must implement the formal eight-core plus three-optional contract"
	)
	var gu_unique_frame_paths := {}
	for action_name: String in expected_lin_frame_counts:
		var expected_count: int = expected_lin_frame_counts[action_name]
		assert(gu_animation.sprite_frames.get_frame_count(action_name) == expected_count, "Gu Yuan action '%s' must use the approved %d-frame budget" % [action_name, expected_count])
		var metadata: Dictionary = gu_animation.get_action_metadata(action_name)
		var frame_paths: PackedStringArray = metadata.get("frame_paths", PackedStringArray())
		for frame_path: String in frame_paths:
			assert(
				frame_path.begins_with("res://assets/characters/applicants/person_gu/fullbody_frames_20/") and frame_path.ends_with("_fullbody.png"),
				"every Gu Yuan action must resolve only to marked full-body production frames"
			)
			assert(ResourceLoader.exists(frame_path, "Texture2D"), "Gu Yuan production frame must import as Texture2D: %s" % frame_path)
			gu_unique_frame_paths[frame_path] = true
	assert(gu_unique_frame_paths.size() == 20, "Gu Yuan's eleven actions must collectively use exactly twenty unique PNG files")
	var active_gu_pngs := PackedStringArray()
	for filename in DirAccess.get_files_at("res://assets/characters/applicants/person_gu/fullbody_frames_20"):
		if filename.ends_with(".png"):
			active_gu_pngs.append(filename)
	assert(active_gu_pngs.size() == 20, "Gu Yuan's active animation directory must contain exactly twenty PNG files")
	for filename in active_gu_pngs:
		assert(filename.ends_with("_fullbody.png"), "every active Gu Yuan filename must declare full-body coverage")
	assert(
		not gu_animation.has_action("walk_in") and not gu_animation.has_action("arrive") and not gu_animation.has_action("look_aside"),
		"Gu Yuan must not reintroduce retired animation actions"
	)
	for action_name: StringName in gu_animation.sprite_frames.get_animation_names():
		assert(gu_animation.get_action_fps(action_name) <= library_script.MAX_ACTION_FPS, "no Gu Yuan animation may exceed the global four FPS style limit")

	var shen_animation = library_script.new()
	assert(shen_animation.load_animation_table("res://data/animations/person_shen/animation_table.json"), "Shen Qinghe's production animation table must load")
	assert(shen_animation.error_messages.is_empty() and shen_animation.warning_messages.is_empty(), "Shen Qinghe's production animation table must resolve every generated frame")
	assert(shen_animation.character_id == "PERSON-SHEN" and not shen_animation.substitute_frames_with_static_actor, "Shen Qinghe must use her own generated frames instead of the static placeholder")
	assert(
		shen_animation.required_actions == library.required_actions and shen_animation.optional_actions == library.optional_actions and shen_animation.max_unique_pngs == 20,
		"Shen Qinghe must implement the formal eight-core plus three-optional contract"
	)
	var shen_unique_frame_paths := {}
	for action_name: String in expected_lin_frame_counts:
		var expected_count: int = expected_lin_frame_counts[action_name]
		assert(shen_animation.sprite_frames.get_frame_count(action_name) == expected_count, "Shen Qinghe action '%s' must use the approved %d-frame budget" % [action_name, expected_count])
		var metadata: Dictionary = shen_animation.get_action_metadata(action_name)
		var frame_paths: PackedStringArray = metadata.get("frame_paths", PackedStringArray())
		for frame_path: String in frame_paths:
			assert(
				frame_path.begins_with("res://assets/characters/applicants/person_shen/fullbody_frames_20/") and frame_path.ends_with("_fullbody.png"),
				"every Shen Qinghe action must resolve only to marked full-body production frames"
			)
			assert(ResourceLoader.exists(frame_path, "Texture2D"), "Shen Qinghe production frame must import as Texture2D: %s" % frame_path)
			shen_unique_frame_paths[frame_path] = true
	assert(shen_unique_frame_paths.size() == 20, "Shen Qinghe's eleven actions must collectively use exactly twenty unique PNG files")
	var shen_deliver_paths: PackedStringArray = shen_animation.get_action_metadata("deliver").get("frame_paths", PackedStringArray())
	assert(shen_deliver_paths.size() == 3, "Shen Qinghe's delivery action must use exactly three frames")
	for deliver_path: String in shen_deliver_paths:
		assert(
			"_document_bag_fullbody.png" in deliver_path,
			"Shen Qinghe's delivery action must use only frames explicitly audited against the new document bag"
		)
	var active_shen_pngs := PackedStringArray()
	for filename in DirAccess.get_files_at("res://assets/characters/applicants/person_shen/fullbody_frames_20"):
		if filename.ends_with(".png"):
			active_shen_pngs.append(filename)
	assert(active_shen_pngs.size() == 20, "Shen Qinghe's active animation directory must contain exactly twenty PNG files")
	for filename in active_shen_pngs:
		assert(filename.ends_with("_fullbody.png"), "every active Shen Qinghe filename must declare full-body coverage")
	assert(
		not shen_animation.has_action("walk_in") and not shen_animation.has_action("arrive") and not shen_animation.has_action("look_aside"),
		"Shen Qinghe must not reintroduce retired animation actions"
	)
	for action_name: StringName in shen_animation.sprite_frames.get_animation_names():
		assert(shen_animation.get_action_fps(action_name) <= library_script.MAX_ACTION_FPS, "no Shen Qinghe animation may exceed the global four FPS style limit")

	var tang_animation = library_script.new()
	assert(tang_animation.load_animation_table("res://data/animations/person_tang/animation_table.json"), "Tang Ji's production animation table must load")
	assert(tang_animation.error_messages.is_empty() and tang_animation.warning_messages.is_empty(), "Tang Ji's production animation table must resolve every generated frame")
	assert(tang_animation.character_id == "PERSON-TANG" and not tang_animation.substitute_frames_with_static_actor, "Tang Ji must use his own generated frames instead of the static placeholder")
	assert(
		tang_animation.required_actions == library.required_actions and tang_animation.optional_actions == library.optional_actions and tang_animation.max_unique_pngs == 20,
		"Tang Ji must implement the formal eight-core plus three-optional contract"
	)
	var tang_unique_frame_paths := {}
	for action_name: String in expected_lin_frame_counts:
		var expected_count: int = expected_lin_frame_counts[action_name]
		assert(tang_animation.sprite_frames.get_frame_count(action_name) == expected_count, "Tang Ji action '%s' must use the approved %d-frame budget" % [action_name, expected_count])
		var metadata: Dictionary = tang_animation.get_action_metadata(action_name)
		var frame_paths: PackedStringArray = metadata.get("frame_paths", PackedStringArray())
		for frame_path: String in frame_paths:
			assert(
				frame_path.begins_with("res://assets/characters/applicants/person_tang/fullbody_frames_20/") and frame_path.ends_with("_fullbody.png"),
				"every Tang Ji action must resolve only to marked full-body production frames"
			)
			assert(ResourceLoader.exists(frame_path, "Texture2D"), "Tang Ji production frame must import as Texture2D: %s" % frame_path)
			if action_name == "deliver":
				assert("_document_bag_fullbody.png" in frame_path, "Tang Ji's delivery action must use only the three audited golden document-bag frames")
			else:
				assert("_document_bag_fullbody.png" not in frame_path, "Tang Ji must leave the golden document bag on the player's desk after delivery")
			tang_unique_frame_paths[frame_path] = true
	assert(tang_unique_frame_paths.size() == 20, "Tang Ji's eleven actions must collectively use exactly twenty unique PNG files")
	var active_tang_pngs := PackedStringArray()
	for filename in DirAccess.get_files_at("res://assets/characters/applicants/person_tang/fullbody_frames_20"):
		if filename.ends_with(".png"):
			active_tang_pngs.append(filename)
	assert(active_tang_pngs.size() == 20, "Tang Ji's active animation directory must contain exactly twenty PNG files")
	for filename in active_tang_pngs:
		assert(filename.ends_with("_fullbody.png"), "every active Tang Ji filename must declare full-body coverage")
	assert(
		not tang_animation.has_action("walk_in") and not tang_animation.has_action("arrive") and not tang_animation.has_action("look_aside"),
		"Tang Ji must not reintroduce retired animation actions"
	)
	for action_name: StringName in tang_animation.sprite_frames.get_animation_names():
		assert(tang_animation.get_action_fps(action_name) <= library_script.MAX_ACTION_FPS, "no Tang Ji animation may exceed the global four FPS style limit")

	var luo_animation = library_script.new()
	assert(luo_animation.load_animation_table("res://data/animations/person_luo/animation_table.json"), "Luo Yutang's production animation table must load")
	assert(luo_animation.error_messages.is_empty() and luo_animation.warning_messages.is_empty(), "Luo Yutang's production animation table must resolve every generated frame")
	assert(luo_animation.character_id == "PERSON-LUO" and not luo_animation.substitute_frames_with_static_actor, "Luo Yutang must use her own generated frames instead of the static placeholder")
	assert(
		luo_animation.required_actions == library.required_actions and luo_animation.optional_actions == library.optional_actions and luo_animation.max_unique_pngs == 20,
		"Luo Yutang must implement the formal eight-core plus three-optional contract"
	)
	var luo_unique_frame_paths := {}
	for action_name: String in expected_lin_frame_counts:
		var expected_count: int = expected_lin_frame_counts[action_name]
		assert(luo_animation.sprite_frames.get_frame_count(action_name) == expected_count, "Luo Yutang action '%s' must use the approved %d-frame budget" % [action_name, expected_count])
		var metadata: Dictionary = luo_animation.get_action_metadata(action_name)
		var frame_paths: PackedStringArray = metadata.get("frame_paths", PackedStringArray())
		for frame_path: String in frame_paths:
			assert(
				frame_path.begins_with("res://assets/characters/applicants/person_luo/fullbody_frames_20/") and frame_path.ends_with("_fullbody.png"),
				"every Luo Yutang action must resolve only to marked full-body production frames"
			)
			assert(ResourceLoader.exists(frame_path, "Texture2D"), "Luo Yutang production frame must import as Texture2D: %s" % frame_path)
			if action_name == "deliver":
				assert("_document_bag_fullbody.png" in frame_path, "Luo Yutang's delivery action must use only the three audited golden document-bag frames")
			else:
				assert("_document_bag_fullbody.png" not in frame_path, "Luo Yutang must leave the golden document bag on the player's desk after delivery")
			luo_unique_frame_paths[frame_path] = true
	assert(luo_unique_frame_paths.size() == 20, "Luo Yutang's eleven actions must collectively use exactly twenty unique PNG files")
	var active_luo_pngs := PackedStringArray()
	for filename in DirAccess.get_files_at("res://assets/characters/applicants/person_luo/fullbody_frames_20"):
		if filename.ends_with(".png"):
			active_luo_pngs.append(filename)
	assert(active_luo_pngs.size() == 20, "Luo Yutang's active animation directory must contain exactly twenty PNG files")
	for filename in active_luo_pngs:
		assert(filename.ends_with("_fullbody.png"), "every active Luo Yutang filename must declare full-body coverage")
	assert(
		not luo_animation.has_action("walk_in") and not luo_animation.has_action("arrive") and not luo_animation.has_action("look_aside"),
		"Luo Yutang must not reintroduce retired animation actions"
	)
	for action_name: StringName in luo_animation.sprite_frames.get_animation_names():
		assert(luo_animation.get_action_fps(action_name) <= library_script.MAX_ACTION_FPS, "no Luo Yutang animation may exceed the global four FPS style limit")

	var aunt_zhou_animation = library_script.new()
	assert(aunt_zhou_animation.load_animation_table("res://data/animations/proprietor_zhou/animation_table.json"), "Aunt Zhou's production animation table must load")
	assert(aunt_zhou_animation.error_messages.is_empty() and aunt_zhou_animation.warning_messages.is_empty(), "Aunt Zhou's production animation table must resolve every generated frame")
	assert(
		aunt_zhou_animation.character_id == "PROPRIETOR-ZHOU" and not aunt_zhou_animation.substitute_frames_with_static_actor,
		"Aunt Zhou must use her own generated frames instead of the static placeholder"
	)
	assert(
		aunt_zhou_animation.required_actions == library.required_actions and aunt_zhou_animation.optional_actions == library.optional_actions and aunt_zhou_animation.max_unique_pngs == 20,
		"Aunt Zhou must implement the formal eight-core plus three-optional contract"
	)
	var aunt_zhou_unique_frame_paths := {}
	for action_name: String in expected_lin_frame_counts:
		var expected_count: int = expected_lin_frame_counts[action_name]
		assert(aunt_zhou_animation.sprite_frames.get_frame_count(action_name) == expected_count, "Aunt Zhou action '%s' must use the approved %d-frame budget" % [action_name, expected_count])
		var metadata: Dictionary = aunt_zhou_animation.get_action_metadata(action_name)
		var frame_paths: PackedStringArray = metadata.get("frame_paths", PackedStringArray())
		for frame_path: String in frame_paths:
			assert(
				frame_path.begins_with("res://assets/characters/applicants/proprietor_zhou/fullbody_frames_20/") and frame_path.ends_with("_fullbody.png"),
				"every Aunt Zhou action must resolve only to marked full-body production frames"
			)
			assert(ResourceLoader.exists(frame_path, "Texture2D"), "Aunt Zhou production frame must import as Texture2D: %s" % frame_path)
			if action_name == "deliver":
				assert("_document_bag_fullbody.png" in frame_path, "Aunt Zhou's delivery action must use only the three audited golden document-bag frames")
			else:
				assert("_document_bag_fullbody.png" not in frame_path, "Aunt Zhou must leave the golden document bag on the player's desk after delivery")
			aunt_zhou_unique_frame_paths[frame_path] = true
	assert(aunt_zhou_unique_frame_paths.size() == 20, "Aunt Zhou's eleven actions must collectively use exactly twenty unique PNG files")
	var active_aunt_zhou_pngs := PackedStringArray()
	for filename in DirAccess.get_files_at("res://assets/characters/applicants/proprietor_zhou/fullbody_frames_20"):
		if filename.ends_with(".png"):
			active_aunt_zhou_pngs.append(filename)
	assert(active_aunt_zhou_pngs.size() == 20, "Aunt Zhou's active animation directory must contain exactly twenty PNG files")
	for filename in active_aunt_zhou_pngs:
		assert(filename.ends_with("_fullbody.png"), "every active Aunt Zhou filename must declare full-body coverage")
	assert(
		not aunt_zhou_animation.has_action("walk_in") and not aunt_zhou_animation.has_action("arrive") and not aunt_zhou_animation.has_action("look_aside"),
		"Aunt Zhou must not reintroduce retired animation actions"
	)
	for action_name: StringName in aunt_zhou_animation.sprite_frames.get_animation_names():
		assert(aunt_zhou_animation.get_action_fps(action_name) <= library_script.MAX_ACTION_FPS, "no Aunt Zhou animation may exceed the global four FPS style limit")

	var old_he_animation = library_script.new()
	assert(old_he_animation.load_animation_table("res://data/animations/proprietor_he/animation_table.json"), "Old He's production animation table must load")
	assert(old_he_animation.error_messages.is_empty() and old_he_animation.warning_messages.is_empty(), "Old He's production animation table must resolve every generated frame")
	assert(
		old_he_animation.character_id == "PROPRIETOR-HE" and not old_he_animation.substitute_frames_with_static_actor,
		"Old He must use his own generated frames instead of the static placeholder"
	)
	assert(
		old_he_animation.required_actions == library.required_actions and old_he_animation.optional_actions == library.optional_actions and old_he_animation.max_unique_pngs == 20,
		"Old He must implement the formal eight-core plus three-optional contract"
	)
	var old_he_unique_frame_paths := {}
	for action_name: String in expected_lin_frame_counts:
		var expected_count: int = expected_lin_frame_counts[action_name]
		assert(old_he_animation.sprite_frames.get_frame_count(action_name) == expected_count, "Old He action '%s' must use the approved %d-frame budget" % [action_name, expected_count])
		var metadata: Dictionary = old_he_animation.get_action_metadata(action_name)
		var frame_paths: PackedStringArray = metadata.get("frame_paths", PackedStringArray())
		for frame_path: String in frame_paths:
			assert(
				frame_path.begins_with("res://assets/characters/applicants/proprietor_he/fullbody_frames_20/") and frame_path.ends_with("_fullbody.png"),
				"every Old He action must resolve only to marked full-body production frames"
			)
			assert(ResourceLoader.exists(frame_path, "Texture2D"), "Old He production frame must import as Texture2D: %s" % frame_path)
			if action_name == "deliver":
				assert("_document_bag_fullbody.png" in frame_path, "Old He's delivery action must use only the three audited golden document-bag frames")
			else:
				assert("_document_bag_fullbody.png" not in frame_path, "Old He must leave the golden document bag on the player's desk after delivery")
			old_he_unique_frame_paths[frame_path] = true
	assert(old_he_unique_frame_paths.size() == 20, "Old He's eleven actions must collectively use exactly twenty unique PNG files")
	var active_old_he_pngs := PackedStringArray()
	for filename in DirAccess.get_files_at("res://assets/characters/applicants/proprietor_he/fullbody_frames_20"):
		if filename.ends_with(".png"):
			active_old_he_pngs.append(filename)
	assert(active_old_he_pngs.size() == 20, "Old He's active animation directory must contain exactly twenty PNG files")
	for filename in active_old_he_pngs:
		assert(filename.ends_with("_fullbody.png"), "every active Old He filename must declare full-body coverage")
	assert(
		not old_he_animation.has_action("walk_in") and not old_he_animation.has_action("arrive") and not old_he_animation.has_action("look_aside"),
		"Old He must not reintroduce retired animation actions"
	)
	for action_name: StringName in old_he_animation.sprite_frames.get_animation_names():
		assert(old_he_animation.get_action_fps(action_name) <= library_script.MAX_ACTION_FPS, "no Old He animation may exceed the global four FPS style limit")

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
