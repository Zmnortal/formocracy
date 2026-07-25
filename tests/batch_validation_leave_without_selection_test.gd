extends SceneTree

# 日终送验零件离开测试。
# 验证每日额度只有上限，没有最低数量；玩家可不送入任何档案直接离开。


func _init() -> void:
	call_deferred("run")


func run() -> void:
	var state := root.get_node("WorkdayState")
	var config := root.get_node("ConfigDatabase")
	state.reset_for_tests()
	var stamped_case: Dictionary = config.get_gameplay_case("CASE-001")
	var unstamped_case: Dictionary = config.get_gameplay_case("CASE-G-D1-01")
	state.manager.record_case_result(stamped_case, "批准", [], 5.0, stamped_case.document_ids)
	state.manager.record_case_result(unstamped_case, "", ["漏盖章"], 5.0, unstamped_case.document_ids)
	state.machine_capacity = 4

	var error := change_scene_to_file("res://scenes/batch_validation.tscn")
	assert(error == OK, "standalone batch validation scene must open")
	await process_frame
	await process_frame
	var module = current_scene.module
	assert(current_scene.name == "BatchValidation", "validation must replace the workbench scene")
	assert(module.archive_row.get_child_count() == 1, "only the stamped archive may appear")
	assert(module.selected_ids.is_empty(), "nothing should be preselected")
	assert(not module.leave_button.disabled, "leave must be enabled with zero selected archives")

	var stamped_button := module.buttons.get("ARCHIVE-00001") as Button
	assert(stamped_button != null, "stamped archive must be selectable")
	stamped_button.pressed.emit()
	await process_frame
	assert(module.selected_ids == ["ARCHIVE-00001"], "player may stage a selection before deciding to leave")
	module.leave_button.pressed.emit()
	await process_frame
	await process_frame
	assert(current_scene.name == "DailyReport", "leaving without confirmation must open the daily report")
	assert(state.manager.get_pending_archives().size() == 2, "leaving without confirmation must preserve every pending archive")
	assert(WorkdayContext.read_string(state.archived_cases[0], "status") == "ARCHIVED", "the unselected stamped archive must remain pending")
	assert(WorkdayContext.read_string(state.archived_cases[1], "status") == "ARCHIVED", "the unstamped archive must remain pending")
	print("FORMOCRACY_BATCH_VALIDATION_ZERO_EXIT_TEST_OK")
	quit(0)
