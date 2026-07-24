extends SceneTree


func _init() -> void:
	call_deferred("run")


func run() -> void:
	var state = root.get_node("WorkdayState")
	state.reset_for_tests()
	var director := WorkbenchBriefingDirector.new(state)
	var lines := director.build_lines()
	assert(lines.size() >= 4, "day briefing must include the fixed daily flow")
	assert(lines[-1].contains("召唤铃"), "briefing must end with the first-call instruction")

	var packed: PackedScene = load("res://main.tscn")
	var main = packed.instantiate()
	root.add_child(main)
	await process_frame
	assert(main.manager.flow_state == "BRIEFING", "workday must begin with the secretary briefing")
	assert(main.manager.briefing.playing, "secretary briefing must play automatically")
	assert(not main.manager.call_bell.available, "call bell must remain locked during the briefing")
	assert(main.manager.case_index == -1, "no applicant may enter before the first bell")

	main.manager.briefing.skip()
	assert(main.manager.call_bell.available, "briefing completion must unlock the call bell")
	main.manager.call_bell.trigger(true)
	await process_frame
	assert(main.manager.case_index == 0, "first bell must summon exactly one applicant")
	assert(main.manager.call_bell.call_count == 1, "first bell must be recorded once")
	main.manager.call_bell.trigger(true)
	assert(main.manager.call_bell.call_count == 1, "locked bell must ignore repeated activation")

	print("FORMOCRACY_DAILY_BRIEFING_CALL_BELL_TEST_OK")
	quit(0)
