extends SceneTree

# NPC 演出测试：验证纵深队列、进场计时、跳过演出和递交解锁。


func _init() -> void:
	call_deferred("run")


func run() -> void:
	var state = root.get_node("WorkdayState")
	state.reset_for_tests()
	var packed: PackedScene = load("res://main.tscn")
	var main = packed.instantiate()
	root.add_child(main)
	await process_frame

	assert(main.npc_performance.state == "WALKING_IN", "first NPC must begin with an entrance performance")
	assert(is_instance_valid(main.npc_performance.current_actor), "current NPC actor must be visible")
	assert(main.npc_performance.queue_actors.size() == 2, "remaining day-one NPCs must appear in the depth queue")
	assert(not main.presenter.envelope.visible, "envelope must remain locked until the delivery performance")

	var before_time: float = state.seconds_remaining
	await create_timer(0.2).timeout
	assert(state.seconds_remaining < before_time, "NPC performance must continue consuming workday time")

	main.npc_performance.skip_current_performance()
	await create_timer(0.4).timeout
	assert(main.npc_performance.state == "WAITING", "skip control must advance entrance to waiting")
	assert(main.presenter.envelope.visible, "delivery completion must reveal the interactive envelope")
	assert(main.presenter.envelope.mouse_filter == Control.MOUSE_FILTER_STOP, "delivered envelope must accept input")

	main.npc_performance.react_and_leave("批准")
	await create_timer(4.5).timeout
	assert(main.case_index == 1, "NPC departure must advance the queue to the next case")
	assert(
		main.npc_performance.state in ["WALKING_IN", "GREETING", "DELIVERING"],
		"next NPC must begin its entrance and delivery performance"
	)

	print("FORMOCRACY_NPC_PERFORMANCE_TEST_OK")
	quit(0)
