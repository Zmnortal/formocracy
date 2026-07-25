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
	assert(state.get_resume_phase() == "du_chunmei_death_notice", "day seven must open with the commute cinematic")

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
	assert(notice_scene != null, "death cinematic scene must load")
	assert(complete_scene != null, "trial-complete scene must load")
	assert(FileAccess.file_exists("res://data/narrative/cinematics/du_chunmei_death.json"), "death cinematic configuration must exist")
	for image_name in [
		"01_commute_street.png",
		"02_du_collapsed.png",
		"03_ambulance_arrives.png",
		"04_stretcher.png",
		"05_ambulance_leaves.png",
	]:
		var image_path := "res://assets/narrative/events/du_chunmei_death/cinematic/%s" % image_name
		assert(ResourceLoader.exists(image_path), "death cinematic frame must exist: %s" % image_path)

	var cinematic := notice_scene.instantiate()
	root.add_child(cinematic)
	await process_frame
	assert(cinematic.shots.size() == 9, "death cinematic must contain nine shots")
	assert(cinematic.shot_index == 0, "death cinematic must start on its first shot")
	var initial_scale: Vector2 = cinematic.frame_image.scale
	await create_timer(0.2).timeout
	assert(cinematic.shot_index == 0, "death cinematic must never auto-advance")
	assert(cinematic.frame_image.scale != initial_scale, "each still must receive a subtle camera move")
	cinematic.advance_cinematic()
	await create_timer(0.6).timeout
	assert(cinematic.shot_index == 1, "click advance must move to the next shot")
	cinematic.queue_free()
	await process_frame

	state.reset_for_tests()
	print("FORMOCRACY_SEVEN_DAY_CAMPAIGN_TEST_OK")
	quit(0)
