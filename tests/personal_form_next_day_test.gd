extends SceneTree


func _init() -> void:
	call_deferred("run")


func run() -> void:
	var state = root.get_node("WorkdayState")
	state.reset_for_tests()
	state.player_name = "测试职员"
	state.balance = 10
	assert(state.purchase_personal_form("PERSONAL-FORM-WATER-R01"), "approved path needs a blank form")
	assert(state.submit_personal_form("PERSONAL-FORM-WATER-R01", {
		"applicant_name": "测试职员",
		"residence": "第十二区 · 职员宿舍 12-C",
		"request_reason": "本周期日常饮用",
		"truth_declared": true,
	}), "valid water form must submit")
	state.begin_next_day()
	assert(state.day_number == 2, "ending night must enter day two")
	assert(state.get_personal_form_count("PERSONAL-FORM-WATER-R01", "effective") == 1, "valid form must become effective")
	assert(not state.water_deprived, "approved water form must prevent dehydration")
	assert(state.seconds_remaining == state.workday_duration, "approved form must preserve full work time")
	assert(state.get_drag_response_multiplier() == 1.0, "approved form must preserve normal drag response")

	state.reset_for_tests()
	state.player_name = "测试职员"
	state.balance = 10
	assert(state.purchase_personal_form("PERSONAL-FORM-WATER-R01"), "returned path needs a blank form")
	assert(state.submit_personal_form("PERSONAL-FORM-WATER-R01", {
		"applicant_name": "错误姓名",
		"residence": "未登记住所",
		"request_reason": "饮用",
		"truth_declared": false,
	}), "invalid facts can still enter pending review")
	state.begin_next_day()
	assert(state.get_personal_form_count("PERSONAL-FORM-WATER-R01", "returned") == 1, "invalid form must be returned")
	assert(state.water_deprived, "returned form must cause dehydration")
	assert(state.seconds_remaining == state.workday_duration - 20.0, "dehydration must remove twenty work seconds")
	assert(state.get_drag_response_multiplier() == 0.72, "dehydration must lower drag response")

	var error := change_scene_to_file("res://main.tscn")
	assert(error == OK, "next workday must open")
	await process_frame
	await process_frame
	assert(current_scene.input_mgr.drag_response_multiplier == 0.72, "workbench input must consume dehydration drag multiplier")
	assert(current_scene.desk.need_status_label.text.contains("缺水"), "workbench must visibly report dehydration")
	print("FORMOCRACY_PERSONAL_FORM_NEXT_DAY_TEST_OK")
	quit(0)
