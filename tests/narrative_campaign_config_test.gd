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

	var character_dialogues: Dictionary = database.ontology.get("character_dialogues", {})
	var people: Dictionary = database.ontology.get("people", {})
	assert(character_dialogues.size() == 18, "all eighteen existing people must have a character dialogue profile")
	assert(character_dialogues.size() == people.size(), "character dialogue profiles must cover the complete people ontology")
	var dialogue_stage_counts := {
		"greeting": 3,
		"delivery": 3,
		"waiting_public": 4,
		"waiting_personal": 4,
		"waiting_identity": 3,
		"waiting_story": 3,
		"approved": 3,
		"rejected": 3,
	}
	for person_id_value: Variant in people:
		var person_id := String(person_id_value)
		var profile: Dictionary = character_dialogues.get(person_id, {})
		assert(not profile.is_empty(), "existing person must have a dialogue profile: %s" % person_id)
		var total_lines := 0
		for stage_value: Variant in dialogue_stage_counts:
			var stage := String(stage_value)
			var lines: Variant = profile.get(stage, [])
			assert(lines is Array, "character dialogue stage must be an array: %s/%s" % [person_id, stage])
			assert(lines.size() == int(dialogue_stage_counts[stage]), "character dialogue stage count must match its schema: %s/%s" % [person_id, stage])
			total_lines += lines.size()
			for line: Variant in lines:
				assert(not String(line).strip_edges().is_empty(), "character dialogue must not contain empty lines: %s/%s" % [person_id, stage])
				assert(String(line).length() <= 36, "character dialogue must fit the compact NPC bubble: %s/%s" % [person_id, stage])
		assert(total_lines == 26, "every existing person must have exactly twenty-six character lines: %s" % person_id)

	var general_slots := 0
	var story_slots := 0
	var multi_line_story_cases := 0
	for case_id in database.ontology.cases_v2:
		var case_data: Dictionary = database.get_gameplay_case(case_id)
		assert(not case_data.is_empty(), "every configured case must resolve at runtime: %s" % case_id)
		assert(case_data.documents.size() <= 6, "each case must fit the six-document envelope tray: %s" % case_id)
		assert(database.evaluate_gameplay_case(case_data).decision in ["批准", "驳回"], "every configured case must produce a rule decision: %s" % case_id)
		if String(case_data.get("content_kind", "")) == "story":
			var dialogue: Dictionary = case_data.get("dialogue", {})
			for dialogue_key in ["greeting", "delivery", "waiting", "approved", "rejected"]:
				var lines: Variant = dialogue.get(dialogue_key, [])
				assert(lines is Array and lines.size() >= 2, "story dialogue stage must contain at least two lines: %s/%s" % [case_id, dialogue_key])
				for line: Variant in lines:
					assert(not String(line).strip_edges().is_empty(), "story dialogue must not contain empty lines: %s/%s" % [case_id, dialogue_key])
					assert(String(line).length() <= 36, "story dialogue must fit the compact NPC bubble: %s/%s" % [case_id, dialogue_key])
			multi_line_story_cases += 1
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
	assert(multi_line_story_cases == 11, "all eleven story cases must use multi-line key NPC dialogue")

	var daily_dialogue: Variant = JSON.parse_string(
		FileAccess.get_file_as_string("res://data/narrative/daily_dialogue.json")
	)
	assert(daily_dialogue is Dictionary, "daily dialogue registry must load")
	for day_value: Variant in daily_dialogue.get("days", []):
		assert(day_value is Dictionary, "daily dialogue day must be a dictionary")
		for period in ["daytime", "evening"]:
			for line_value: Variant in day_value.get(period, []):
				assert(line_value is Dictionary, "daily dialogue entry must be a dictionary")
				if String(line_value.get("scene", "")).contains("广播") or String(line_value.get("scene", "")).contains("简报"):
					assert(line_value.get("speaker", "") == "秘书", "all registered broadcasts must be spoken by the secretary")
					assert(String(line_value.get("tone", "")).contains("温度"), "secretary broadcast registry must preserve the warm-but-controlled tone")

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
