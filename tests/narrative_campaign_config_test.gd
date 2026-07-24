extends SceneTree

# 七日叙事内容包测试。
# 验证每日五槽、七三比例、确定性普通池、跨日选择和归档条件读取。


func _init() -> void:
	call_deferred("run")


func run() -> void:
	await process_frame
	var database = root.get_node("ConfigDatabase")
	var director = root.get_node("LevelDirector")
	var state = root.get_node("WorkdayState")
	state.reset_for_tests()
	assert(database.loaded and database.errors.is_empty(), "narrative content pack must load without errors")

	var general_slots := 0
	var story_slots := 0
	for case_id in database.ontology.cases_v2:
		var case_data: Dictionary = database.get_gameplay_case(case_id)
		assert(not case_data.is_empty(), "every configured case must resolve at runtime: %s" % case_id)
		assert(case_data.documents.size() <= 6, "each case must fit the six-document envelope tray: %s" % case_id)
		assert(database.evaluate_gameplay_case(case_data).decision in ["批准", "驳回"], "every configured case must produce a rule decision: %s" % case_id)
	for day in range(1, 8):
		var workday: Dictionary = database.get_workday_for_day(day)
		assert(int(workday.day_number) == day, "each demo day must resolve by its configured day number")
		assert(workday.slots.size() == 5 and int(workday.case_count) == 5, "each demo day must contain five cases")
		for slot in workday.slots:
			if String(slot.get("kind", "")) == "story":
				story_slots += 1
			else:
				general_slots += 1
	assert(general_slots == 24 and story_slots == 11, "seven-day slot mix must be 24 general and 11 story cases")

	state.day_number = 1
	assert(director.start_gameplay_workday(), "day one queue must build from configured slots")
	var first_queue: Array[String] = director.gameplay_case_ids.duplicate()
	assert(first_queue.size() == 5, "day one must generate five runtime cases")
	assert(first_queue[0] == "CASE-001", "day one must retain the Lin Mo story hook")
	assert(director.start_gameplay_workday(), "restarting a configured day must succeed")
	assert(director.gameplay_case_ids == first_queue, "the same workday seed must reproduce general-case order")

	state.day_number = 6
	assert(director.start_gameplay_workday(), "day six queue must build from the current saved day")
	assert(director.active_gameplay_workday.id == "WORKDAY-006", "director must select workday by state day number")
	assert(director.gameplay_case_ids.has("CASE-S-R12-D6"), "day six must include the cohabitation return")
	assert(director.gameplay_case_ids.has("CASE-S-A73-D6"), "day six must include the archive-unsealing request")

	state.archived_cases.append({"case_id": "CASE-001", "decision": "批准"})
	assert(director._gameplay_conditions_match([{"kind": "decision_is", "case_id": "CASE-001", "decision": "批准"}]), "story conditions must read decisions from persistent cross-day archives")
	assert(not director._gameplay_conditions_match([{"kind": "decision_is", "case_id": "CASE-001", "decision": "驳回"}]), "mismatched historical decisions must fail a configured story condition")

	print("FORMOCRACY_NARRATIVE_CAMPAIGN_CONFIG_TEST_OK")
	quit(0)
