extends SceneTree


func _init() -> void:
	call_deferred("run")


func run() -> void:
	await process_frame
	var state = root.get_node("WorkdayState")
	var database = root.get_node("ConfigDatabase")
	var director = root.get_node("LevelDirector")
	state.reset_for_tests()

	assert(database.loaded, "CSV configuration must load without errors")
	assert(database.errors.is_empty(), "valid sample configuration must not report errors")
	assert(database.characters.size() == 4, "four sample characters must be indexed")
	assert(database.cases.size() == 5, "five sample cases must be indexed")
	var housing: Dictionary = database.get_case("case_housing_001")
	assert(housing.applicant.contains("林默"), "case lookup must merge character identity")
	assert(housing.checks.size() == 3, "case lookup must expose three checks")

	assert(director.start_level("day_1", 77), "day_1 must start")
	var first: Dictionary = director.get_next_case()
	assert(first.case_id == "case_housing_001", "story case must occupy slot one")
	state.record_case(first, "批准")
	var second: Dictionary = director.get_next_case()
	assert(second.case_id == "case_water_001", "approved prerequisite must unlock slot-two story case")
	state.record_case(second, "批准")
	var third: Dictionary = director.get_next_case()
	assert(not third.is_empty(), "normal pool must fill the remaining slot")
	assert(third.case_id not in [first.case_id, second.case_id], "daily queue must not repeat cases")
	assert(director.get_next_case().is_empty(), "queue must stop at configured case_count")
	assert(state.target_case_count == 3, "workday target must come from level config")

	state.reset_for_tests()
	assert(director.start_level("day_1", 902), "level restart must succeed")
	first = director.get_next_case()
	state.record_case(first, "驳回")
	var rejected_branch: Dictionary = director.get_next_case()
	assert(rejected_branch.case_id != "case_water_001", "failed prerequisite must use a normal-pool replacement")
	var first_random_id: String = rejected_branch.case_id

	state.reset_for_tests()
	director.start_level("day_1", 902)
	first = director.get_next_case()
	state.record_case(first, "驳回")
	assert(director.get_next_case().case_id == first_random_id, "same seed must reproduce random replacement")

	print("FORMOCRACY_CONFIG_LEVEL_TEST_OK")
	quit(0)
