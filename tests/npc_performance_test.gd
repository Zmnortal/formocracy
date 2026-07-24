extends SceneTree

# NPC 演出测试：验证纵深队列、进场计时、跳过演出和递交解锁。


func _init() -> void:
	call_deferred("run")


func run() -> void:
	var state = root.get_node("WorkdayState")
	var sfx = root.get_node("Sfx")
	state.reset_for_tests()
	var packed: PackedScene = load("res://main.tscn")
	var main = packed.instantiate()
	root.add_child(main)
	await process_frame
	main.start_first_case_for_tests()
	await process_frame

	assert(main.npc_performance.state == "WALKING_IN", "first NPC must begin with an entrance performance")
	assert(is_instance_valid(main.npc_performance.current_actor), "current NPC actor must be visible")
	assert(main.npc_performance.queue_actors.size() == 2, "remaining day-one NPCs must appear in the depth queue")
	assert(not main.presenter.envelope.visible, "envelope must remain locked until the delivery performance")
	assert(sfx.walk_player.playing, "NPC entrance must start footsteps")

	var before_time: float = state.seconds_remaining
	await create_timer(0.2).timeout
	assert(state.seconds_remaining < before_time, "NPC performance must continue consuming workday time")
	await create_timer(0.55).timeout
	assert(sfx.last_voice_person_id == "PERSON-LIN", "greeting must play the configured NPC voice")
	assert(sfx.voice_player.stream != null, "configured NPC voice stream must load")

	main.npc_performance.skip_current_performance()
	await create_timer(0.4).timeout
	assert(main.npc_performance.state == "WAITING", "skip control must advance entrance to waiting")
	assert(not sfx.walk_player.playing, "skip control must stop NPC footsteps")
	assert(not sfx.voice_player.playing, "skip control must stop NPC voice")
	assert(main.presenter.envelope.visible, "delivery completion must reveal the interactive envelope")
	assert(main.presenter.envelope.mouse_filter == Control.MOUSE_FILTER_STOP, "delivered envelope must accept input")

	main.npc_performance.react_and_leave("批准")
	await create_timer(4.5).timeout
	assert(main.call_bell.available, "NPC departure must unlock the call bell")
	main.call_bell.trigger(true)
	await process_frame
	assert(main.case_index == 1, "NPC departure must advance the queue to the next case")
	assert(
		main.npc_performance.state in ["WALKING_IN", "GREETING", "DELIVERING"],
		"next NPC must begin its entrance and delivery performance"
	)
	main.queue_free()
	await process_frame
	assert(not sfx.walk_player.playing, "leaving the workbench must stop NPC footsteps")
	assert(not sfx.voice_player.playing, "leaving the workbench must stop NPC voice")

	print("FORMOCRACY_NPC_PERFORMANCE_TEST_OK")
	quit(0)
