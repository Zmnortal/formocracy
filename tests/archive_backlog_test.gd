extends SceneTree


func _init() -> void:
	call_deferred("run")


func run() -> void:
	var state = root.get_node("WorkdayState")
	var config = root.get_node("ConfigDatabase")
	state.reset_for_tests()
	state.machine_capacity = 2
	for case_id in ["CASE-001", "CASE-002", "CASE-003"]:
		var case_data: Dictionary = config.get_gameplay_case(case_id)
		state.record_case_result(case_data, "批准", [], 5.0, case_data.document_ids)
	assert(state.archived_cases.size() == 3, "every processed case must create a persistent archive")
	assert(state.get_pending_archives().size() == 3, "daytime archive capacity must be unlimited")
	assert(not state.validate_archive_batch(["ARCHIVE-00001", "ARCHIVE-00002", "ARCHIVE-00003"]), "machine must reject batches beyond configured capacity")
	assert(state.validate_archive_batch(["ARCHIVE-00001", "ARCHIVE-00002"]), "machine must accept a batch within configured capacity")
	assert(state.get_pending_archives().size() == 1, "unselected archives must remain backlogged")
	state.begin_next_day()
	assert(state.get_pending_archives()[0].waiting_days == 1, "backlogged archives must age across workdays")
	assert(state.archived_cases[0].effective_day == 1, "validated archive must preserve its effective day")
	print("FORMOCRACY_ARCHIVE_BACKLOG_TEST_OK")
	quit(0)
