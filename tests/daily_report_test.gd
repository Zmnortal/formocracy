extends SceneTree


func _init() -> void:
	call_deferred("run")


func run() -> void:
	var state := root.get_node_or_null("WorkdayState")
	if state == null:
		state = load("res://scripts/autoload/workday_state.gd").new()
		state.name = "WorkdayState"
		root.add_child(state)
	state.reset_for_tests()
	state.player_name = "测试审批员"
	for i in 3:
		state.manager.record_case_result({"department": "测试部门", "code": "T-%02d/测试事项" % i, "applicant": "测试申请人 %02d" % i, "request": "测试请求"}, "批准" if i < 2 else "驳回")
	assert(state.manager.should_show_report(), "three records must finish a workday")
	var packed: PackedScene = load("res://scenes/daily_report.tscn")
	assert(packed != null, "daily report scene must load")
	var report := packed.instantiate()
	root.add_child(report)
	await process_frame
	var bridge := root.get_node("RealityBridge")
	assert(bridge.last_emitted_event.type == "day_report", "opening the daily report must send its summary to the glasses")
	assert(bridge.last_emitted_event.lines.size() == 5, "glasses daily report must contain the compact settlement summary")
	assert(report.metadata_label.text.contains("测试审批员"), "daily report must use the name entered during reinstatement")
	assert(report.stats_label.text.contains("批准 02"), "report must aggregate approvals")
	assert(report.stats_label.text.contains("驳回 01"), "report must aggregate rejections")
	assert(report.cases_label.text.contains("T-00/测试事项"), "report must list daily cases")
	report.declaration.button_pressed = true
	assert(not report.confirm_button.disabled, "confirmation must unlock after declaration")
	state.manager.begin_next_day()
	assert(state.day_number == 2, "next day must increment")
	assert(state.records.is_empty(), "next day must clear records")
	print("FORMOCRACY_DAILY_REPORT_TEST_OK")
	quit(0)
