extends SceneTree

# NPC 演出测试：验证纵深队列、进场计时、跳过演出和递交解锁。


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
	assert(bridge.last_emitted_event.type == "secretary_line", "calling the next applicant must send the internal broadcast to the glasses")
	assert(bridge.last_emitted_event.text == "下一位。", "glasses call-bell broadcast must preserve its spoken text")

	assert(main.npc_performance.state == "WALKING_IN", "first NPC must begin with an entrance performance")
	assert(is_instance_valid(main.npc_performance.current_actor), "current NPC actor must be visible")
	assert(
		main.npc_performance.animation_player.get_current_action() == &"walk_in",
		"entrance movement must use the configured walk-in frame row"
	)
	assert(
		is_equal_approx(main.npc_performance.animation_library.get_action_fps("walk_in"), 7.0),
		"the performance must preserve the action row's independent FPS"
	)
	assert(main.npc_performance.queue_actors.size() == 2, "remaining day-one NPCs must appear in the depth queue")
	assert(not main.presenter.envelope.visible, "envelope must remain locked until the delivery performance")
	assert(sfx.walk_player.playing, "NPC entrance must start footsteps")

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
	assert(main.npc_performance.state == "WAITING", "skip control must advance entrance to waiting")
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
	await create_timer(0.9).timeout
	assert(
		main.npc_performance.animation_player.get_current_action() == &"happy_idle",
		"approval reaction must persist as happy idle during the result line"
	)
	await create_timer(3.6).timeout
	assert(main.call_bell.available, "NPC departure must unlock the call bell")
	main.call_bell.trigger(true)
	await process_frame
	assert(main.case_index == 1, "NPC departure must advance the queue to the next case")
	assert(
		main.npc_performance.state in ["WALKING_IN", "ARRIVING", "GREETING", "DELIVERING"],
		"next NPC must begin its entrance and delivery performance"
	)
	main.npc_performance.skip_current_performance()
	await create_timer(0.2).timeout
	main.npc_performance.skip_requested = false
	main.npc_performance.react_and_leave("驳回")
	assert(
		main.npc_performance.animation_player.get_current_action() == &"angry_react",
		"rejection must immediately enter the angry reaction row"
	)
	await create_timer(0.9).timeout
	assert(
		main.npc_performance.animation_player.get_current_action() == &"angry_idle",
		"rejection reaction must persist as angry idle during the result line"
	)
	main.queue_free()
	await process_frame
	assert(not sfx.walk_player.playing, "leaving the workbench must stop NPC footsteps")
	assert(not sfx.voice_player.playing, "leaving the workbench must stop NPC voice")

	print("FORMOCRACY_NPC_PERFORMANCE_TEST_OK")
	quit(0)
