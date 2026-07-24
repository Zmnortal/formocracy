extends SceneTree


func _init() -> void:
	call_deferred("run")


func run() -> void:
	var state = root.get_node("WorkdayState")
	state.reset_for_tests()
	state.day_number = 2
	state.begin_evening()
	var error := change_scene_to_file("res://scenes/evening_map.tscn")
	assert(error == OK, "evening map must open")
	await process_frame
	await process_frame
	var map = current_scene
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
	assert(state.evening_actions_remaining == 0, "second arrival must consume the final action")
	assert(map.forms_button.disabled and map.ration_button.disabled, "non-home locations must lock at zero actions")
	assert(not map.home_button.disabled, "home must remain available at zero actions")
	map.select_location(map.LOCATION_HOME)
	await create_timer(1.4).timeout
	assert(state.evening_location_id == map.LOCATION_HOME, "player must still be able to return home")
	assert(state.evening_actions_remaining == 0, "returning home cannot make actions negative")
	state.begin_evening()
	assert(state.evening_actions_remaining == 0, "re-entering the same evening must preserve actions")
	state.day_number = 3
	state.begin_evening()
	assert(state.evening_actions_remaining == 2, "a new workday must restore two evening actions")
	assert(state.evening_location_id == map.LOCATION_OFFICE, "a new evening must start at the office")
	print("FORMOCRACY_EVENING_MAP_MOVEMENT_TEST_OK")
	quit(0)
