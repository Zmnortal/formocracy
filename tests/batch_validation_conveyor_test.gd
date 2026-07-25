extends SceneTree

# 日终送验俯视交互测试。
# 验证拆分资产、盖章过滤、文件袋等比运输、仅有上限、主动离开和现实落效。


func _init() -> void:
	call_deferred("run")


func run() -> void:
	var state := root.get_node("WorkdayState")
	var config := root.get_node("ConfigDatabase")
	state.reset_for_tests()
	for case_id: String in ["CASE-001", "CASE-002", "CASE-003"]:
		var case_data: Dictionary = config.get_gameplay_case(case_id)
		state.manager.record_case_result(case_data, "批准", [], 5.0, case_data.document_ids)
	var unstamped_case: Dictionary = config.get_gameplay_case("CASE-G-D1-01")
	state.manager.record_case_result(unstamped_case, "", ["漏盖章"], 5.0, unstamped_case.document_ids)
	state.machine_capacity = 1

	var error := change_scene_to_file("res://scenes/batch_validation.tscn")
	assert(error == OK, "standalone batch validation scene must open")
	await process_frame
	await process_frame
	var module = current_scene.module
	assert(current_scene.name == "BatchValidation", "validation must replace the workbench scene")
	assert(module.overlay.get_parent() == current_scene, "validation view must belong only to its standalone scene")
	assert(current_scene.get_node_or_null("Desk") == null, "standalone validation scene must not retain workbench desk nodes")
	assert(module.overlay.visible, "batch validation view must open")
	assert(module.overlay.has_node("ValidationFloor"), "validation view must build its floor independently")
	assert(module.overlay.has_node("ValidationMachineBody"), "validation machine must be an independent asset")
	assert(module.overlay.has_node("ValidationMachineLights"), "machine lights must be an independent overlay")
	assert(module.overlay.has_node("ValidationMachineIntakeForeground"), "machine intake foreground must be independent")
	assert(module.overlay.has_node("ValidationRailMachineCap"), "rail machine cap must be independent")
	assert(module.overlay.has_node("ValidationRailMiddle"), "rail middle must be independent")
	assert(module.overlay.has_node("ValidationRailBottomCap"), "rail bottom cap must be independent")
	assert(module.overlay.has_node("ValidationDocumentClip"), "machine intake must clip swallowed document bags")
	assert(module.machine_body.texture.resource_path == "res://assets/concepts/endday_validation/validation_machine_topdown_concept.png", "machine body must use the approved top-down asset")
	assert(
		module.machine_intake_foreground.texture.resource_path == "res://assets/concepts/endday_validation/validation_machine_intake_foreground.png",
		"machine intake must use the approved foreground asset"
	)
	assert(module.rail_machine_cap.texture.resource_path == "res://assets/concepts/endday_validation/validation_rail_machine_cap.png", "rail must use the approved split asset")
	assert(module.archive_row.get_child_count() == 3, "only stamped pending archives may appear in the validation scene")
	assert(not module.buttons.has("ARCHIVE-00004"), "an unstamped archive must remain outside the validation machine")
	assert(module.leave_button.visible and not module.leave_button.disabled, "the player must be able to leave without loading a bag")
	assert(module.selected_ids.is_empty(), "no archive should be loaded before player input")

	var first_button := module.buttons.get("ARCHIVE-00001") as Button
	var second_button := module.buttons.get("ARCHIVE-00002") as Button
	assert(first_button != null and second_button != null, "stamped document bag buttons must be addressable")
	first_button.pressed.emit()
	await process_frame
	assert(module.ingesting, "clicking a document bag must start the rail transport")
	assert(module.in_flight_archive_id == "ARCHIVE-00001", "the clicked bag must become the in-flight archive")
	assert(module.active_document_bag != null, "rail transport must use an independent document bag")
	assert(module.active_document_bag.scale == Vector2.ONE, "the bag must not shrink while it moves")
	var transport_size: Vector2 = module.active_document_bag.size
	await create_timer(0.50).timeout
	assert(module.active_document_bag != null, "the bag must remain visible while travelling on the rail")
	assert(module.active_document_bag.scale == Vector2.ONE, "the bag must keep its scale during ingestion")
	assert(module.active_document_bag.size.is_equal_approx(transport_size), "the bag must keep its physical size during ingestion (%s -> %s)" % [transport_size, module.active_document_bag.size])
	await create_timer(0.90).timeout
	assert(module.selected_ids == ["ARCHIVE-00001"], "one click must ingest exactly one document bag")
	assert(current_scene.name == "BatchValidation", "reaching the upper limit must not force the player to leave")
	assert(not module.leave_button.disabled, "the leave action must be available at the daily limit")
	second_button.pressed.emit()
	await process_frame
	assert(not module.ingesting, "the machine must reject bags beyond the daily upper limit")
	assert(module.selected_ids == ["ARCHIVE-00001"], "the upper limit must prevent an extra bag from being selected")

	module.leave_button.pressed.emit()
	await create_timer(2.0).timeout
	assert(current_scene.name == "DailyReport", "the explicit leave action must open the daily report")
	assert(state.manager.get_pending_archives().size() == 3, "unselected and unstamped archives must remain in the backlog")
	assert(WorkdayContext.read_string(state.archived_cases[0], "status") == "EFFECTIVE", "ingested archive must gain reality effect")
	assert(WorkdayContext.read_string(state.archived_cases[2], "status") == "ARCHIVED", "unselected archive must remain archived")
	assert(WorkdayContext.read_string(state.archived_cases[3], "status") == "ARCHIVED", "unstamped archive must remain archived")
	print("FORMOCRACY_BATCH_VALIDATION_CONVEYOR_TEST_OK")
	quit(0)
