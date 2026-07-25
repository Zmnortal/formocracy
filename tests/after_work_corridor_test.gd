extends SceneTree


func _init() -> void:
	call_deferred("run")


func run() -> void:
	var state := root.get_node_or_null("WorkdayState")
	var bridge := root.get_node_or_null("RealityBridge")
	var pause_menu := root.get_node_or_null("PauseMenu")
	assert(state != null, "WorkdayState autoload must exist")
	assert(bridge != null, "RealityBridge autoload must exist")
	assert(pause_menu != null, "PauseMenu autoload must exist")
	assert(pause_menu.is_scene_allowed_path("res://scenes/after_work_corridor.tscn"), "after-work corridor must allow pause menu")
	state.reset_for_tests()
	state.day_number = 4
	state.player_name = "测试职员"
	state.balance = 23
	(
		state
		. records
		. append(
			{
				"code": "LIN-04",
				"character_id": "PERSON-LIN",
				"applicant": "林默",
				"decision": "批准",
				"effective": true,
				"procedure_errors": ["遗漏材料"],
			}
		)
	)
	(
		state
		. records
		. append(
			{
				"code": "GEN-04",
				"character_id": "PERSON-GENERAL",
				"applicant": "普通申请人",
				"decision": "驳回",
				"effective": false,
				"procedure_errors": [],
			}
		)
	)
	var error := change_scene_to_file("res://scenes/after_work_corridor.tscn")
	assert(error == OK, "after-work corridor must open")
	await process_frame
	await process_frame
	var corridor = current_scene
	assert(corridor != null and corridor.name == "AfterWorkCorridor", "corridor must be the current scene")
	assert(corridor.day_label.text.contains("04"), "corridor must show the current workday")
	assert(corridor.balance_label.text.contains("023"), "corridor must show the current balance")
	assert(corridor.echo_label.text.contains("现实生效 01"), "corridor must echo effective submissions")
	assert(corridor.echo_label.text.contains("等待处理 01"), "corridor must echo pending submissions")

	corridor.walk_by(0.26)
	assert(corridor.speaker_label.text == "走廊广播", "first milestone must be a corridor broadcast")
	assert(corridor.message_label.text.contains("形式审查 02 件"), "first milestone must report the reviewed count")
	corridor.walk_by(0.27)
	assert(corridor.message_label.text.contains("程序错误 01 项"), "second milestone must report procedural errors")
	corridor.walk_by(0.23)
	assert(corridor.lin_mo.visible, "Lin Mo must appear when her case was handled today")
	assert(corridor.speaker_label.text == "林默", "story milestone must identify Lin Mo")
	assert(corridor.message_label.text.contains("至少今天，它算数"), "approved Lin Mo case must use the approved story echo")
	corridor.walk_by(-0.5)
	assert(corridor.speaker_label.text == "林默", "walking backward must not replay completed milestones")
	corridor.walk_by(0.74)
	assert(corridor.walk_progress == 1.0, "corridor progress must clamp at the exit")
	assert(corridor.exit_button.visible, "reaching the exit must reveal the leave action")
	assert(corridor.distance_label.text == "出口识别完成", "exit distance must resolve into access confirmation")
	print("FORMOCRACY_AFTER_WORK_CORRIDOR_TEST_OK")
	quit(0)
