extends SceneTree

# NPC 演出测试：验证柜台直出、遮暗叠放、真实补位、情绪离场和幂等跳过。


func _init() -> void:
	call_deferred("run")


func run() -> void:
	var state = root.get_node("WorkdayState")
	var sfx = root.get_node("Sfx")
	var bridge = root.get_node("RealityBridge")
	bridge.last_emitted_event.clear()
	state.reset_for_tests()
	var packed: PackedScene = load("res://main.tscn")
	var main = packed.instantiate()
	root.add_child(main)
	await process_frame
	main.manager.start_first_case_for_tests()
	await process_frame

	assert(main.manager.npc_performance.state == "GREETING", "first NPC must begin directly at the counter")
	assert(is_instance_valid(main.manager.npc_performance.current_actor), "current NPC actor must be visible")
	_assert_actor_fps_cap(main.manager.npc_performance.current_actor)
	assert(main.manager.npc_performance.animation_player.get_current_action() == &"idle", "the counter greeting must use the breathing idle row")
	var expected_visible_queue: int = state.target_case_count - 1
	assert(main.manager.npc_performance.queue_actors.size() == expected_visible_queue, "every remaining applicant for the day must appear in the visible crowd")
	for queue_index in main.manager.npc_performance.queue_actors.size():
		var queue_actor = main.manager.npc_performance.queue_actors[queue_index]
		assert(
			queue_actor.animation == &"queue_idle" and queue_actor.is_playing() and queue_actor.sprite_frames.get_frame_count(&"queue_idle") == 3,
			"every queued NPC with the standard table must run the optional queue_idle loop"
		)
		assert(queue_actor.sprite_frames.get_animation_speed(&"queue_idle") <= 4.0, "queued playback must obey the global four FPS limit")
		assert(
			queue_actor.position.is_equal_approx(main.manager.npc_performance._queue_position(queue_index)),
			"every queued NPC must occupy its procedural porch crowd slot",
		)
		var queue_person: Dictionary = main.manager.npc_performance._person_for_case(main.manager.npc_performance.queue_case_ids[queue_index])
		var queue_configured_scale := WorkdayContext.read_float(queue_person, "actor_scale", 0.34)
		assert(
			queue_actor.scale.is_equal_approx(
				Vector2.ONE
				* queue_configured_scale
				* main.manager.npc_performance.FRONT_ACTOR_SCALE_MULTIPLIER
				* main.manager.npc_performance._queue_scale_factor(queue_index)
			),
			"every queued NPC must inherit the 1.3 crowd enlargement before perspective scaling",
		)
	var static_queue_fallback := AnimatedSprite2D.new()
	(
		main
		. manager
		. npc_performance
		. _configure_queue_actor(
			static_queue_fallback,
			{
				"actor_texture": "res://assets/characters/applicants/person_meng/fullbody.png",
				"animation_table": "res://tests/fixtures/npc_animation_missing_frame.json",
			}
		)
	)
	assert(
		static_queue_fallback.animation == &"idle" and static_queue_fallback.sprite_frames.get_frame_count(&"idle") == 1 and not static_queue_fallback.is_playing(),
		"a character without optional queue_idle must safely fall back to one full-body frame"
	)
	static_queue_fallback.free()
	assert(
		not (main.manager.npc_performance.current_actor.sprite_frames.get_frame_texture(&"idle", 0) is AtlasTexture), "the complete NPC frame must be preserved and hidden by foreground architecture"
	)
	var worktable := main.get_node("WorktableForeground")
	var railing := main.get_node("ServiceRailingForeground")
	assert(main.manager.npc_performance.actor_layer.z_index < railing.z_index and railing.z_index < worktable.z_index, "NPC, railing, and worktable must form the requested back-to-front stack")
	assert(main.manager.npc_performance.actor_layer.get_parent() == main, "the renderer must keep the full-body actor uncut and rely on foreground assets")
	assert(main.manager.npc_performance.queue_case_ids.slice(0, 2) == ["CASE-002", "CASE-003"], "queue actors must retain the fixed day-one gameplay identities")
	assert(main.manager.npc_performance.current_actor.position.is_equal_approx(main.manager.npc_performance.FRONT_POSITION), "the active NPC must already occupy the counter position")
	var configured_scale := WorkdayContext.read_float(main.manager.current_case.person, "actor_scale", 0.34)
	assert(
		main.manager.npc_performance.current_actor.scale.is_equal_approx(Vector2.ONE * configured_scale * main.manager.npc_performance.FRONT_ACTOR_SCALE_MULTIPLIER),
		"the active NPC must use the enlarged foreground scale",
	)
	assert(
		main.manager.npc_performance._queue_scale_factor(0) <= 0.8,
		"even the nearest queued NPC must remain clearly smaller than the active foreground NPC",
	)
	assert(
		main.manager.npc_performance._queue_position(0).x < main.manager.npc_performance.FRONT_POSITION.x
		and main.manager.npc_performance._queue_position(2).x < main.manager.npc_performance._queue_position(0).x,
		"the queue must fan out toward the left instead of stacking behind the foreground NPC",
	)
	assert(
		is_equal_approx(main.manager.npc_performance.queue_actors[0].modulate.a, 1.0) and is_equal_approx(main.manager.npc_performance.queue_actors[1].modulate.a, 1.0),
		"depth must be expressed through blackness rather than transparency"
	)
	assert(
		_brightness(main.manager.npc_performance.queue_actors[0].modulate) > _brightness(main.manager.npc_performance.queue_actors[1].modulate),
		"each deeper applicant must render darker than the person before them"
	)
	assert(
		_brightness(main.manager.npc_performance.queue_actors[1].modulate) > _brightness(main.manager.npc_performance.queue_actors[2].modulate)
		and _brightness(main.manager.npc_performance.queue_actors[2].modulate) > _brightness(main.manager.npc_performance.queue_actors[3].modulate),
		"the entire visible crowd must become progressively darker with depth"
	)
	assert(main.manager.npc_performance.queue_actors[0].z_index > main.manager.npc_performance.queue_actors[1].z_index, "deeper applicants must render behind nearer applicants")
	assert(not main.manager.presenter.envelope.visible, "envelope must remain locked until the delivery performance")
	assert(not sfx.walk_player.playing, "appearing directly at the counter must not start entrance footsteps")

	var before_time: float = state.seconds_remaining
	await create_timer(0.2).timeout
	assert(state.seconds_remaining < before_time, "NPC performance must continue consuming workday time")
	assert(main.manager.npc_performance.speech_bubble.visible, "NPC dialogue must stay in a character speech bubble")
	assert(main.manager.npc_performance.speech_bubble.position.y < DialogueBox.PANEL_POSITION.y, "NPC speech must not use the bottom form dialogue layout")
	assert(main.manager.npc_performance.speech_bubble.z_index >= 4000, "NPC speech bubble must remain above workbench documents")
	assert(main.manager.npc_performance.speech_bubble.dialogue_label.visible_characters > 0, "NPC speech must reveal with the typewriter effect")
	var glass_wait_started := Time.get_ticks_msec()
	while String(bridge.last_emitted_event.get("type", "")) != "npc_line" and Time.get_ticks_msec() - glass_wait_started < 2500:
		await process_frame
	assert(sfx.last_voice_person_id == "PERSON-LIN", "greeting must play the configured NPC voice")
	assert(sfx.voice_player.stream != null, "configured NPC voice stream must load")
	assert(bridge.last_emitted_event.type == "npc_line", "NPC greeting must be emitted to the glasses")
	assert(bridge.last_emitted_event.title == "林默", "glasses NPC event must include the speaker name")
	assert(bridge.last_emitted_event.text == "您好。我来办理共同居住配额。", "glasses NPC event must include the spoken line")
	assert(bridge.last_emitted_event.gender == "male", "glasses NPC event must include inferred gender")
	assert(bridge.last_emitted_event.age == "young", "glasses NPC event must include inferred age")

	main.manager.npc_performance.skip_current_performance()
	await create_timer(0.4).timeout
	assert(main.manager.npc_performance.state == "WAITING", "skip control must advance greeting or delivery to waiting")
	assert(not sfx.walk_player.playing, "skip control must stop NPC footsteps")
	assert(not sfx.voice_player.playing, "skip control must stop NPC voice")
	assert(main.manager.presenter.envelope.visible, "delivery completion must reveal the interactive envelope")
	assert(main.manager.presenter.envelope.mouse_filter == Control.MOUSE_FILTER_STOP, "delivered envelope must accept input")
	assert(main.manager.npc_performance.animation_player.get_current_action() == &"idle", "waiting after a skipped entrance must settle into idle")

	main.manager.npc_performance.skip_requested = false
	main.manager.npc_performance.react_and_leave("批准")
	assert(main.manager.npc_performance.animation_player.get_current_action() == &"happy_react", "approval must immediately enter the happy reaction row")
	assert(
		await _wait_until(func() -> bool: return main.manager.npc_performance.animation_player.get_current_action() == &"happy_idle", 2.0),
		"approval reaction must persist as happy idle during the result line"
	)
	assert(await _wait_until(func() -> bool: return main.manager.call_bell.available, 7.0), "approved NPC bubble must auto-hide after about five seconds and unlock the call bell")
	assert(main.manager.call_bell.available, "NPC departure must unlock the call bell")
	assert(main.manager.npc_performance.state == "FRONT_STAGED", "the next queued NPC must remain staged at the front")
	assert(main.manager.npc_performance.staged_case_id == "CASE-002", "the first queued identity must be promoted")
	assert(main.manager.npc_performance.current_actor.position.is_equal_approx(main.manager.npc_performance.FRONT_POSITION), "the promoted NPC must occupy the exact counter position")
	assert(
		is_equal_approx(main.manager.npc_performance.current_actor.modulate.a, 1.0) and _brightness(main.manager.npc_performance.current_actor.modulate) > 0.95,
		"promotion must remove queue blackness without introducing transparency"
	)
	assert(
		main.manager.npc_performance.current_actor.animation == &"queue_idle" and main.manager.npc_performance.current_actor.is_playing(),
		"a promoted applicant must keep breathing while staged before the bell"
	)
	assert(main.manager.npc_performance.queue_case_ids[0] == "CASE-003", "promoting the next NPC must move the following fixed identity to the front of the queue")
	assert("周循" in main.manager.desk.applicant_card_label.text and "等待传唤" in main.manager.desk.applicant_card_label.text, "staged applicant UI must no longer show the departed person's dossier")
	var staged_actor = main.manager.npc_performance.current_actor
	main.manager.call_bell.trigger(true)
	main.manager.dialogue_box.reveal_current_line()
	main.manager.dialogue_box._handle_manual_advance()
	await process_frame
	assert(main.manager.case_index == 1, "NPC departure must advance the queue to the next case")
	assert(main.manager.npc_performance.current_actor == staged_actor, "the next case must reuse the staged actor instead of replacing it")
	var zhou_idle_path := String(main.manager.npc_performance.current_actor.sprite_frames.get_frame_texture(&"idle", 0).resource_path)
	assert(
		zhou_idle_path.begins_with("res://assets/characters/applicants/person_zhou/fullbody_frames_20/"),
		"the promoted second applicant must switch from the placeholder to Zhou Xun's production frames"
	)
	assert(main.manager.npc_performance.state in ["GREETING", "DELIVERING"], "next NPC must begin directly with its counter performance")
	assert(not sfx.walk_player.playing, "activating a staged NPC must not replay entrance footsteps")
	main.manager.npc_performance.skip_current_performance()
	await create_timer(0.2).timeout
	main.manager.npc_performance.skip_requested = false
	main.manager.npc_performance.react_and_leave("驳回")
	assert(main.manager.npc_performance.animation_player.get_current_action() == &"angry_react", "rejection must immediately enter the angry reaction row")
	assert(
		await _wait_until(func() -> bool: return main.manager.npc_performance.animation_player.get_current_action() == &"angry_idle", 2.0),
		"rejection reaction must persist as angry idle during the result line"
	)
	var second_departures: Array[bool] = []
	main.manager.npc_performance.departure_finished.connect(func() -> void: second_departures.append(true))
	main.manager.npc_performance.skip_current_performance()
	main.manager.npc_performance.skip_current_performance()
	assert(await _wait_until(func() -> bool: return main.manager.npc_performance.state == "FRONT_STAGED", 2.0), "skipping the reaction must still complete queue promotion")
	assert(second_departures.size() == 1, "repeated skip requests must complete departure exactly once")
	assert(main.manager.npc_performance.staged_case_id == "CASE-003", "second departure must promote the final queued identity")
	var final_staged_actor = main.manager.npc_performance.current_actor
	main.manager.call_bell.trigger(true)
	main.manager.dialogue_box.reveal_current_line()
	main.manager.dialogue_box._handle_manual_advance()
	await process_frame
	assert(main.manager.npc_performance.current_actor == final_staged_actor, "the final staged identity must also be reused without a visual rebuild")
	var xu_idle_path := String(main.manager.npc_performance.current_actor.sprite_frames.get_frame_texture(&"idle", 0).resource_path)
	assert(xu_idle_path.begins_with("res://assets/characters/applicants/person_xu/fullbody_frames_20/"), "the promoted final applicant must switch from the placeholder to Xu Qiao's production frames")
	main.manager.npc_performance.skip_current_performance()
	await create_timer(0.2).timeout
	main.manager.npc_performance.skip_requested = false
	main.manager.npc_performance.react_and_leave("批准", false)
	main.manager.npc_performance.skip_current_performance()
	assert(await _wait_until(func() -> bool: return main.manager.npc_performance.state == "IDLE", 2.0), "ending reception must finish without promoting another applicant")
	assert(
		not is_instance_valid(main.manager.npc_performance.current_actor) and main.manager.npc_performance.queue_actors.is_empty() and main.manager.npc_performance.staged_case_id.is_empty(),
		"ending reception must not leave a staged ghost actor"
	)
	main.queue_free()
	await process_frame
	assert(not sfx.walk_player.playing, "leaving the workbench must stop NPC footsteps")
	assert(not sfx.voice_player.playing, "leaving the workbench must stop NPC voice")

	print("FORMOCRACY_NPC_PERFORMANCE_TEST_OK")
	quit(0)


func _brightness(color: Color) -> float:
	return maxf(color.r, maxf(color.g, color.b))


func _assert_actor_fps_cap(actor: AnimatedSprite2D) -> void:
	for animation in actor.sprite_frames.get_animation_names():
		assert(actor.sprite_frames.get_animation_speed(animation) <= 4.0, "NPC animation must never change faster than four frames per second")


func _wait_until(predicate: Callable, timeout_seconds: float) -> bool:
	var deadline := Time.get_ticks_msec() + int(timeout_seconds * 1000.0)
	while not bool(predicate.call()) and Time.get_ticks_msec() < deadline:
		await process_frame
	return bool(predicate.call())
