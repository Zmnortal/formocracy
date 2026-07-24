extends SceneTree


func _init() -> void:
	call_deferred("run")


func run() -> void:
	var state = root.get_node("WorkdayState")
	state.reset_for_tests()
	state.player_name = "测试职员"
	state.balance = 10
	assert(state.purchase_personal_form("PERSONAL-FORM-WATER-R01"), "test must acquire one blank water form")
	state.begin_evening()
	state.evening_location_id = "LOCATION-RATION"
	state.evening_actions_remaining = 1
	var error := change_scene_to_file("res://scenes/evening_map.tscn")
	assert(error == OK, "evening map must open")
	await process_frame
	await process_frame
	var map = current_scene
	map.select_location(map.LOCATION_HOME)
	await create_timer(1.4).timeout
	assert(map.home_window.visible, "arriving home must open personal form desk")
	assert(map.applicant_input.text == "测试职员", "form must use registered clerk identity")
	map.reason_input.text = "本周期日常饮用"
	map.truth_declaration.button_pressed = true
	map.refresh_home_form_validity()
	assert(not map.submit_form_button.disabled, "complete fields and declaration must unlock submission")
	map.submit_water_form()
	assert(state.get_personal_form_count(map.WATER_FORM_ID, "blank") == 0, "submission must consume one blank form")
	assert(state.get_personal_form_count(map.WATER_FORM_ID, "pending") == 1, "submission must create one pending form")
	var submitted: Dictionary = state.personal_form_inventory[0]
	assert(submitted.fields.request_reason == "本周期日常饮用", "submitted form must preserve filled fields")
	assert(int(submitted.effective_day) == 2, "water form must be scheduled for next-day processing")
	assert(map.submit_form_button.text.contains("等待次日处理"), "form desk must show submission receipt")
	map.end_night()
	assert(state.day_number == 2, "ending the night must advance the workday")
	assert(map.next_day_receipt.visible, "ending the night must show the personal review receipt")
	assert(map.review_result_label.text.contains("批准"), "valid submitted form must be approved")
	assert(map.next_day_effect_label.text.contains("饮水正常"), "approved form must show normal next-day status")
	print("FORMOCRACY_PERSONAL_FORM_SUBMISSION_TEST_OK")
	quit(0)
