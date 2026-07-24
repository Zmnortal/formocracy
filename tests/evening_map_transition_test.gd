extends SceneTree


func _init() -> void:
	call_deferred("run")


func run() -> void:
	var state := root.get_node_or_null("WorkdayState")
	assert(state != null, "WorkdayState autoload must exist")
	state.reset_for_tests()
	state.day_number = 3
	state.player_name = "测试职员"
	(
		state
		. records
		. append(
			{
				"code": "TEST-01",
				"applicant": "测试申请人",
				"decision": "批准",
				"effective": false,
				"procedure_errors": [],
			}
		)
	)
	var error := change_scene_to_file("res://scenes/daily_report.tscn")
	assert(error == OK, "daily report must open")
	await process_frame
	await process_frame
	var report = current_scene
	assert(report != null and report.name == "DailyReport", "report must be current scene")
	report.declaration.button_pressed = true
	report.confirm_button.pressed.emit()
	await process_frame
	await process_frame
	assert(current_scene != null and current_scene.name == "EveningMap", "confirming report must enter evening map")
	assert(state.day_number == 3, "entering map must not advance the day")
	assert(state.records.size() == 1, "entering map must preserve current-day records")
	assert(current_scene.day_label.text.contains("03"), "map must show the current workday")
	assert(current_scene.action_label.text.contains("2 / 2"), "map must expose the evening action budget")
	print("FORMOCRACY_EVENING_MAP_TRANSITION_TEST_OK")
	quit(0)
