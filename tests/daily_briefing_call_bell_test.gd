extends SceneTree


func _init() -> void:
	call_deferred("run")


func run() -> void:
	var state = root.get_node("WorkdayState")
	state.reset_for_tests()
	var director = load("res://scripts/managers/workbench_manager/workbench_briefing_director.gd").new(state)
	var lines: Array[String] = director.build_lines()
	assert(lines.size() >= 4, "day briefing must include the fixed daily flow")
	assert(lines[0].contains("早上好") and lines[0].contains("工位"), "secretary briefing must open with restrained warmth")
	assert(not lines[0].contains("内部广播"), "secretary briefing must not hide behind an anonymous broadcast label")
	assert(lines[-1].contains("召唤铃"), "briefing must end with the first-call instruction")
	assert(lines[-1].contains("铃坏了"), "secretary briefing must retain the character's slight playfulness")

	var packed: PackedScene = load("res://main.tscn")
	var main = packed.instantiate()
	root.add_child(main)
	await process_frame
	assert(main.manager.flow_state == "BRIEFING", "workday must begin with the secretary briefing")
	assert(main.manager.briefing.playing, "secretary briefing must play automatically")
	assert(not main.manager.call_bell.available, "call bell must remain locked during the briefing")
	assert(main.manager.case_index == -1, "no applicant may enter before the first bell")
	assert(main.manager.dialogue_box.visible, "briefing must use the shared bottom dialogue box")
	assert(main.manager.dialogue_box.speaker_label.text == "秘书", "every briefing line must be visibly spoken by the secretary")
	assert(main.manager.dialogue_box.z_index >= 4000, "form dialogue must render above every workbench item")
	var briefing_line_id: int = main.manager.dialogue_box.line_id
	await create_timer(0.12).timeout
	assert(main.manager.dialogue_box.line_id == briefing_line_id, "briefing must never advance to another line on a timer")

	while main.manager.briefing.playing:
		main.manager.dialogue_box.reveal_current_line()
		main.manager.dialogue_box._handle_manual_advance()
		await process_frame
	assert(main.manager.call_bell.available, "briefing completion must unlock the call bell")
	main.manager.call_bell.trigger(true)
	await process_frame
	assert(main.manager.case_index == -1, "call broadcast must wait for player confirmation before summoning an applicant")
	assert(main.manager.dialogue_box.speaker_label.text == "秘书", "the call-bell broadcast must also belong to the secretary")
	assert(main.manager.dialogue_box.full_text.contains("走廊"), "the call-bell line must carry the secretary's restrained personal observation")
	main.manager.dialogue_box.reveal_current_line()
	main.manager.dialogue_box._handle_manual_advance()
	await process_frame
	assert(main.manager.case_index == 0, "first bell must summon exactly one applicant")
	assert(main.manager.call_bell.call_count == 1, "first bell must be recorded once")
	main.manager.call_bell.trigger(true)
	assert(main.manager.call_bell.call_count == 1, "locked bell must ignore repeated activation")

	print("FORMOCRACY_DAILY_BRIEFING_CALL_BELL_TEST_OK")
	quit(0)
