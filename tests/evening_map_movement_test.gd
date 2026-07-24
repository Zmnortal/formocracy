extends SceneTree


func _init() -> void:
	call_deferred("run")


func run() -> void:
	var state = root.get_node("WorkdayState")
	var bridge = root.get_node("RealityBridge")
	bridge.last_emitted_event.clear()
	state.reset_for_tests()
	state.day_number = 2
	state.manager.begin_evening()
	var error := change_scene_to_file("res://scenes/evening_map.tscn")
	assert(error == OK, "evening map must open")
	await process_frame
	await process_frame
	var map = current_scene
	map.end_sequence_fade_duration = 0.01
	map.end_sequence_step_duration = 0.01
	map.auto_transition_after_end_sequence = false
	map.auto_open_location_scenes = false
	var start_position: Vector2 = map.player_token.position
	map.select_location(map.LOCATION_RATION)
	await create_timer(1.0).timeout
	assert(not map.moving, "token movement must finish")
	assert(map.player_token.position != start_position, "token must move along the route")
	assert(state.evening_location_id == map.LOCATION_RATION, "arrival must update current location")
	assert(state.evening_actions_remaining == 1, "arrival must consume one action")
	assert(map.arrival_card.visible, "arrival must open the institution card")
	assert(map.action_label.text.contains("1 / 2"), "action display must update after arrival")
	map.select_location(map.LOCATION_FORMS)
	await create_timer(1.4).timeout
	assert(map.ending_night, "using the final action must start the end-of-night sequence")
	assert(map.end_overlay.visible, "the end-of-night sequence must black out the map")
	assert(map.forms_button.disabled and map.ration_button.disabled and map.home_button.disabled, "all map input must lock during blackout")
	assert(state.day_number == 3, "the dialogue sequence must advance to the next day")
	assert(bridge.last_emitted_event.type == "secretary_line", "the final central broadcast must be sent to the glasses")
	assert(bridge.last_emitted_event.text.contains("第 03 工作日"), "glasses broadcast must include the new workday")
	assert(state.evening_actions_remaining == 2, "advancing the day must immediately restore evening actions")
	assert(state.evening_location_id == map.LOCATION_OFFICE, "advancing the day must reset the evening location")
	state.configure_workday({"id": "WORKDAY-001", "day_number": 1, "case_ids": []})
	assert(state.day_number == 3, "reloading a base workday config must not roll back the progressed day")
	state.manager.begin_evening()
	assert(state.evening_actions_remaining == 2, "a new workday must restore two evening actions")
	assert(state.evening_location_id == map.LOCATION_OFFICE, "a new evening must start at the office")
	state.day_number = 4
	state.evening_day_number = 4
	state.evening_actions_remaining = 0
	state.evening_location_id = map.LOCATION_RATION
	state.settled_day_number = 4
	state.target_case_count = 1
	state.records.assign([{"case_id": "LEGACY-COMPLETE"}])
	assert(state.save_system.repair_legacy_exhausted_evening(5), "legacy exhausted saves must be repaired")
	assert(state.day_number == 5, "legacy repair must advance to the next day")
	assert(state.evening_actions_remaining == 2, "legacy repair must restore two actions")
	assert(state.evening_location_id == map.LOCATION_OFFICE, "legacy repair must return to the office")
	print("FORMOCRACY_EVENING_MAP_MOVEMENT_TEST_OK")
	quit(0)
