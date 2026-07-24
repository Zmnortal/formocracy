extends SceneTree

# 日常流程测试。
# 验证连续处理 3 件案件后自动切换到日报场景。


func _init() -> void:
	call_deferred("run")


# 运行日常流程完整测试。
func run() -> void:
	var state := root.get_node_or_null("WorkdayState")
	if state == null:
		state = load("res://scripts/autoload/workday_state.gd").new()
		state.name = "WorkdayState"
		root.add_child(state)
	state.reset_for_tests()
	var bridge := root.get_node("RealityBridge")
	bridge.last_emitted_event.clear()
	var error: Error = change_scene_to_file("res://main.tscn")
	assert(error == OK, "main scene must open")
	await process_frame
	await process_frame
	assert(current_scene != null, "main scene must become current")
	assert(bridge.last_emitted_event.type == "morning_briefing", "workday start must send the morning briefing to the glasses")
	assert(bridge.last_emitted_event.lines.size() > 0, "glasses morning briefing must include its instruction lines")
	current_scene.manager.start_first_case_for_tests()
	await process_frame
	for i in state.target_case_count:
		var desk := current_scene
		desk.manager.presenter.apply_stamp("批准" if i != 1 else "驳回", Vector2(350, 360))
		desk.manager.npc_performance.skip_requested = true
		desk.manager.submission.submit(desk.manager.presenter, desk.manager.current_case)
		await create_timer(3.8).timeout
		if i < state.target_case_count - 1:
			assert(desk.manager.call_bell.available, "completed case must wait for the call bell")
			desk.manager.call_bell.trigger(true)
			await process_frame
	assert(current_scene.name == "Main", "third processed case must remain at the workbench for batch validation")
	assert(current_scene.manager.batch_validation.overlay.visible, "day end must open the finite-capacity validation tray")
	assert(state.manager.get_pending_archives().size() == state.target_case_count, "all processed cases must enter the unlimited archive backlog")
	assert(state.machine_capacity == 4, "day-one machine capacity must come from level configuration")
	current_scene.manager.batch_validation.select_first_up_to_capacity()
	current_scene.manager.batch_validation.confirm(true)
	await process_frame
	assert(bridge.last_emitted_event.type == "reality_receipt", "batch validation must send reality receipts to the glasses")
	assert(bridge.last_emitted_event.body.contains("档案已取得现实效力"), "glasses receipt must describe the validation outcome")
	await process_frame
	assert(current_scene.name == "DailyReport", "batch validation must open the daily report")
	assert(state.manager.get_pending_archives().size() == 1, "archives beyond machine capacity must remain backlogged")
	assert(state.records.size() == state.target_case_count, "daily report must retain every configured case")
	assert(current_scene.stats_label.text.contains("批准 %02d" % (state.target_case_count - 1)), "daily report must show decisions")
	print("FORMOCRACY_DAILY_FLOW_TEST_OK")
	quit(0)
