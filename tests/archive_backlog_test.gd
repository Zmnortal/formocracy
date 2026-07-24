extends SceneTree


func _init() -> void:
	call_deferred("run")


func run() -> void:
	@warning_ignore_start("unsafe_method_access")
	@warning_ignore_start("unsafe_property_access")
	@warning_ignore_start("unsafe_cast")
	var state := root.get_node("WorkdayState") as WorkdayContext
	var config := root.get_node("ConfigDatabase")
	state.call("reset_for_tests")
	state.machine_capacity = 2
	var manager: Variant = state.get("manager")
	for case_id: String in ["CASE-001", "CASE-002", "CASE-003"]:
		var case_data: Dictionary = config.call("get_gameplay_case", case_id)
		manager.record_case_result(case_data, "批准", [], 5.0, WorkdayContext.read_array(case_data, "document_ids"))
	assert(state.archived_cases.size() == 3, "every processed case must create a persistent archive")
	assert(manager.get_pending_archives().size() == 3, "daytime archive capacity must be unlimited")
	assert(not manager.validate_archive_batch(["ARCHIVE-00001", "ARCHIVE-00002", "ARCHIVE-00003"]), "machine must reject batches beyond configured capacity")
	assert(manager.validate_archive_batch(["ARCHIVE-00001", "ARCHIVE-00002"]), "machine must accept a batch within configured capacity")
	assert(manager.get_pending_archives().size() == 1, "unselected archives must remain backlogged")
	manager.begin_next_day()
	var pending_archives: Array = manager.get_pending_archives()
	var pending_archive := pending_archives[0] as Dictionary
	assert(WorkdayContext.read_int(pending_archive, "waiting_days") == 1, "backlogged archives must age across workdays")
	assert(WorkdayContext.read_int(state.archived_cases[0], "effective_day") == 1, "validated archive must preserve its effective day")
	@warning_ignore_restore("unsafe_cast")
	@warning_ignore_restore("unsafe_property_access")
	@warning_ignore_restore("unsafe_method_access")
	print("FORMOCRACY_ARCHIVE_BACKLOG_TEST_OK")
	quit(0)
