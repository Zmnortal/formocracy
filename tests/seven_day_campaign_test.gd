extends SceneTree


func _init() -> void:
	call_deferred("run")


func run() -> void:
	var state := root.get_node("WorkdayState") as WorkdayContext
	var config = root.get_node("ConfigDatabase")
	state.reset_for_tests()
	assert(config.get_last_workday_day() == 7, "content pack must declare a seven-day campaign")
	assert(not config.is_final_workday(6), "day six must still advance")
	assert(config.is_final_workday(7), "day seven must be the hard campaign end")

	state.day_number = 6
	state.archived_cases.append(
		{
			"case_id": "CASE-S-M52-D5",
			"decision": "驳回",
			"status": "EFFECTIVE",
		}
	)
	state.manager.begin_next_day()
	assert(state.day_number == 7, "finishing day six must enter day seven")
	assert(WorkdayContext.read_bool(state.narrative_flags, "du_chunmei_deceased"), "rejecting M-52 must trigger Du Chunmei's death")
	assert(state.get_resume_phase() == "du_chunmei_death_notice", "day seven must open with the death notice")

	state.reset_for_tests()
	state.day_number = 6
	state.archived_cases.append(
		{
			"case_id": "CASE-S-M52-D5",
			"decision": "批准",
			"status": "EFFECTIVE",
		}
	)
	state.manager.begin_next_day()
	assert(WorkdayContext.read_bool(state.narrative_flags, "du_chunmei_protected"), "approved and effective M-52 must protect Du Chunmei")
	assert(not WorkdayContext.read_bool(state.narrative_flags, "du_chunmei_deceased"), "effective resources must avoid the death branch")
	assert(state.get_resume_phase() == "pre_work", "protected branch must enter the normal day-seven morning")

	state.reset_for_tests()
	state.day_number = 6
	state.archived_cases.append(
		{
			"case_id": "CASE-S-M52-D5",
			"decision": "批准",
			"status": "ARCHIVED",
		}
	)
	state.manager.begin_next_day()
	assert(WorkdayContext.read_bool(state.narrative_flags, "du_chunmei_deceased"), "approval without machine validation must still trigger the death branch")

	state.reset_for_tests()
	state.day_number = 7
	state.manager.begin_next_day()
	assert(state.day_number == 7, "the campaign must never advance beyond day seven")
	assert(WorkdayContext.read_bool(state.narrative_flags, "trial_completed"), "finishing day seven must mark the trial complete")
	assert(state.get_resume_phase() == "trial_complete", "completed saves must return to the thanks flow")

	var notice_scene := load("res://scenes/du_chunmei_death_notice.tscn") as PackedScene
	var complete_scene := load("res://scenes/trial_complete.tscn") as PackedScene
	assert(notice_scene != null, "death notice scene must load")
	assert(complete_scene != null, "trial-complete scene must load")
	assert(ResourceLoader.exists("res://assets/narrative/events/du_chunmei_death/clinic_window.png"), "death notice clinic frame must exist")
	assert(ResourceLoader.exists("res://assets/narrative/events/du_chunmei_death/belongings.png"), "death notice belongings frame must exist")

	state.reset_for_tests()
	print("FORMOCRACY_SEVEN_DAY_CAMPAIGN_TEST_OK")
	quit(0)
