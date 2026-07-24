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
	main.start_first_case_for_tests()
	await process_frame

	assert(main.npc_performance.state == "GREETING", "first NPC must begin directly at the counter")
	assert(is_instance_valid(main.npc_performance.current_actor), "current NPC actor must be visible")
	_assert_actor_fps_cap(main.npc_performance.current_actor)
	assert(
		main.npc_performance.animation_player.get_current_action() == &"idle",
		"the counter greeting must use the breathing idle row"
	)
	assert(main.npc_performance.queue_actors.size() == 2, "remaining day-one NPCs must appear in the depth queue")
	assert(
		not (
			main.npc_performance.current_actor.sprite_frames.get_frame_texture(&"idle", 0)
			is AtlasTexture
		),
		"the complete NPC frame must be preserved and hidden by foreground architecture"
	)
	var worktable := main.get_node("WorktableForeground")
	var railing := main.get_node("ServiceRailingForeground")
	assert(
		main.npc_performance.actor_layer.z_index < worktable.z_index
		and worktable.z_index < railing.z_index,
		"NPC, worktable, and railing must form a real back-to-front occlusion stack"
	)
	assert(
		main.npc_performance.actor_layer.get_parent() == main,
		"the renderer must keep the full-body actor uncut and rely on foreground assets"
	)
	assert(
		main.npc_performance.queue_case_ids == ["CASE-002", "CASE-003"],
		"queue actors must retain their gameplay case identities"
	)
	assert(
		main.npc_performance.current_actor.position.is_equal_approx(main.npc_performance.FRONT_POSITION),
		"the active NPC must already occupy the counter position"
	)
	assert(
		is_equal_approx(main.npc_performance.queue_actors[0].modulate.a, 1.0)
		and is_equal_approx(main.npc_performance.queue_actors[1].modulate.a, 1.0),
		"depth must be expressed through blackness rather than transparency"
	)
	assert(
		_brightness(main.npc_performance.queue_actors[0].modulate) > _brightness(
			main.npc_performance.queue_actors[1].modulate
		),
		"the 60-percent dark first queue slot must remain brighter than the 75-percent slot"
	)
	assert(
		is_equal_approx(_brightness(main.npc_performance.queue_actors[0].modulate), 0.4)
		and is_equal_approx(_brightness(main.npc_performance.queue_actors[1].modulate), 0.25),
		"queue slots must apply the configured 60-percent and 75-percent blackness"
	)
	assert(
		main.npc_performance.queue_actors[0].z_index > main.npc_performance.queue_actors[1].z_index,
		"deeper applicants must render behind nearer applicants"
	)
	assert(not main.presenter.envelope.visible, "envelope must remain locked until the delivery performance")
	assert(not sfx.walk_player.playing, "appearing directly at the counter must not start entrance footsteps")

	var before_time: float = state.seconds_remaining
	await create_timer(0.2).timeout
	assert(state.seconds_remaining < before_time, "NPC performance must continue consuming workday time")
	var glass_wait_started := Time.get_ticks_msec()
	while (
		String(bridge.last_emitted_event.get("type", "")) != "npc_line"
		and Time.get_ticks_msec() - glass_wait_started < 2500
	):
		await process_frame
	assert(sfx.last_voice_person_id == "PERSON-LIN", "greeting must play the configured NPC voice")
	assert(sfx.voice_player.stream != null, "configured NPC voice stream must load")
	assert(bridge.last_emitted_event.type == "npc_line", "NPC greeting must be emitted to the glasses")
	assert(bridge.last_emitted_event.title == "林默", "glasses NPC event must include the speaker name")
	assert(bridge.last_emitted_event.text == "您好。我来办理共同居住配额。", "glasses NPC event must include the spoken line")
	assert(bridge.last_emitted_event.gender == "male", "glasses NPC event must include inferred gender")
	assert(bridge.last_emitted_event.age == "young", "glasses NPC event must include inferred age")

	main.npc_performance.skip_current_performance()
	await create_timer(0.4).timeout
	assert(main.npc_performance.state == "WAITING", "skip control must advance greeting or delivery to waiting")
	assert(not sfx.walk_player.playing, "skip control must stop NPC footsteps")
	assert(not sfx.voice_player.playing, "skip control must stop NPC voice")
	assert(main.presenter.envelope.visible, "delivery completion must reveal the interactive envelope")
	assert(main.presenter.envelope.mouse_filter == Control.MOUSE_FILTER_STOP, "delivered envelope must accept input")
	assert(
		main.npc_performance.animation_player.get_current_action() == &"idle",
		"waiting after a skipped entrance must settle into idle"
	)

	main.npc_performance.skip_requested = false
	main.npc_performance.react_and_leave("批准")
	assert(
		main.npc_performance.animation_player.get_current_action() == &"happy_react",
		"approval must immediately enter the happy reaction row"
	)
	assert(
		await _wait_until(
			func() -> bool:
				return main.npc_performance.animation_player.get_current_action() == &"happy_idle",
			2.0
		),
		"approval reaction must persist as happy idle during the result line"
	)
	assert(
		await _wait_until(func() -> bool: return main.call_bell.available, 5.0),
		"approved NPC must finish leaving and unlock the call bell"
	)
	assert(main.call_bell.available, "NPC departure must unlock the call bell")
	assert(main.npc_performance.state == "FRONT_STAGED", "the next queued NPC must remain staged at the front")
	assert(main.npc_performance.staged_case_id == "CASE-002", "the first queued identity must be promoted")
	assert(
		main.npc_performance.current_actor.position.is_equal_approx(main.npc_performance.FRONT_POSITION),
		"the promoted NPC must occupy the exact counter position"
	)
	assert(
		is_equal_approx(main.npc_performance.current_actor.modulate.a, 1.0)
		and _brightness(main.npc_performance.current_actor.modulate) > 0.95,
		"promotion must remove queue blackness without introducing transparency"
	)
	assert(
		main.npc_performance.queue_case_ids == ["CASE-003"],
		"promoting the next NPC must remove it from the rear queue"
	)
	assert(
		"周循" in main.desk.applicant_card_label.text
		and "等待传唤" in main.desk.applicant_card_label.text,
		"staged applicant UI must no longer show the departed person's dossier"
	)
	var staged_actor = main.npc_performance.current_actor
	main.call_bell.trigger(true)
	await process_frame
	assert(main.case_index == 1, "NPC departure must advance the queue to the next case")
	assert(
		main.npc_performance.current_actor == staged_actor,
		"the next case must reuse the staged actor instead of replacing it"
	)
	assert(
		main.npc_performance.state in ["GREETING", "DELIVERING"],
		"next NPC must begin directly with its counter performance"
	)
	assert(not sfx.walk_player.playing, "activating a staged NPC must not replay entrance footsteps")
	main.npc_performance.skip_current_performance()
	await create_timer(0.2).timeout
	main.npc_performance.skip_requested = false
	main.npc_performance.react_and_leave("驳回")
	assert(
		main.npc_performance.animation_player.get_current_action() == &"angry_react",
		"rejection must immediately enter the angry reaction row"
	)
	assert(
		await _wait_until(
			func() -> bool:
				return main.npc_performance.animation_player.get_current_action() == &"angry_idle",
			2.0
		),
		"rejection reaction must persist as angry idle during the result line"
	)
	var second_departures: Array[bool] = []
	main.npc_performance.departure_finished.connect(
		func() -> void: second_departures.append(true)
	)
	main.npc_performance.skip_current_performance()
	main.npc_performance.skip_current_performance()
	assert(
		await _wait_until(func() -> bool: return main.npc_performance.state == "FRONT_STAGED", 2.0),
		"skipping the reaction must still complete queue promotion"
	)
	assert(second_departures.size() == 1, "repeated skip requests must complete departure exactly once")
	assert(main.npc_performance.staged_case_id == "CASE-003", "second departure must promote the final queued identity")
	var final_staged_actor = main.npc_performance.current_actor
	main.call_bell.trigger(true)
	await process_frame
	assert(
		main.npc_performance.current_actor == final_staged_actor,
		"the final staged identity must also be reused without a visual rebuild"
	)
	main.npc_performance.skip_current_performance()
	await create_timer(0.2).timeout
	main.npc_performance.skip_requested = false
	main.npc_performance.react_and_leave("批准", false)
	main.npc_performance.skip_current_performance()
	assert(
		await _wait_until(func() -> bool: return main.npc_performance.state == "IDLE", 2.0),
		"ending reception must finish without promoting another applicant"
	)
	assert(
		not is_instance_valid(main.npc_performance.current_actor)
		and main.npc_performance.queue_actors.is_empty()
		and main.npc_performance.staged_case_id.is_empty(),
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
		assert(
			actor.sprite_frames.get_animation_speed(animation) <= 4.0,
			"NPC animation must never change faster than four frames per second"
		)


func _wait_until(predicate: Callable, timeout_seconds: float) -> bool:
	var deadline := Time.get_ticks_msec() + int(timeout_seconds * 1000.0)
	while not bool(predicate.call()) and Time.get_ticks_msec() < deadline:
		await process_frame
	return bool(predicate.call())
