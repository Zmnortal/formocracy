extends SceneTree


func _init() -> void:
	call_deferred("run")


func run() -> void:
	@warning_ignore_start("unsafe_method_access")
	@warning_ignore_start("unsafe_property_access")
	@warning_ignore_start("unsafe_cast")
	await process_frame
	var state := root.get_node("WorkdayState") as WorkdayContext
	var database := root.get_node("ConfigDatabase")
	var director := root.get_node("LevelDirector")
	state.call("reset_for_tests")
	var manager: Variant = state.get("manager")

	assert(WorkdayContext.to_bool(database.get("loaded")), "CSV configuration must load without errors")
	var errors := database.get("errors") as Array
	var characters := database.get("characters") as Dictionary
	var cases := database.get("cases") as Dictionary
	assert(errors.is_empty(), "valid sample configuration must not report errors")
	assert(characters.size() == 4, "four sample characters must be indexed")
	assert(cases.size() == 5, "five sample cases must be indexed")
	var housing: Dictionary = database.call("get_case", "case_housing_001")
	assert(WorkdayContext.read_string(housing, "applicant").contains("林默"), "case lookup must merge character identity")
	assert(WorkdayContext.read_array(housing, "checks").size() == 3, "case lookup must expose three checks")

	assert(director.call("start_level", "day_1", 77), "day_1 must start")
	var first: Dictionary = director.call("get_next_case")
	assert(WorkdayContext.read_string(first, "case_id") == "case_housing_001", "story case must occupy slot one")
	manager.record_case_result(first, "批准")
	var second: Dictionary = director.call("get_next_case")
	assert(WorkdayContext.read_string(second, "case_id") == "case_water_001", "approved prerequisite must unlock slot-two story case")
	manager.record_case_result(second, "批准")
	var third: Dictionary = director.call("get_next_case")
	assert(not third.is_empty(), "normal pool must fill the remaining slot")
	assert(WorkdayContext.read_string(third, "case_id") not in [WorkdayContext.read_string(first, "case_id"), WorkdayContext.read_string(second, "case_id")], "daily queue must not repeat cases")
	var exhausted_case: Dictionary = director.call("get_next_case")
	assert(exhausted_case.is_empty(), "queue must stop at configured case_count")
	assert(state.target_case_count == 3, "workday target must come from level config")

	state.call("reset_for_tests")
	assert(director.call("start_level", "day_1", 902), "level restart must succeed")
	first = director.call("get_next_case")
	manager.record_case_result(first, "驳回")
	var rejected_branch: Dictionary = director.call("get_next_case")
	assert(WorkdayContext.read_string(rejected_branch, "case_id") != "case_water_001", "failed prerequisite must use a normal-pool replacement")
	var first_random_id := WorkdayContext.read_string(rejected_branch, "case_id")

	state.call("reset_for_tests")
	director.call("start_level", "day_1", 902)
	first = director.call("get_next_case")
	manager.record_case_result(first, "驳回")
	var repeated_case: Dictionary = director.call("get_next_case")
	assert(WorkdayContext.read_string(repeated_case, "case_id") == first_random_id, "same seed must reproduce random replacement")

	@warning_ignore_restore("unsafe_cast")
	@warning_ignore_restore("unsafe_property_access")
	@warning_ignore_restore("unsafe_method_access")
	print("FORMOCRACY_CONFIG_LEVEL_TEST_OK")
	quit(0)
