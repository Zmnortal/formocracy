extends SceneTree


func _init() -> void:
	call_deferred("run")


func run() -> void:
	var state := root.get_node_or_null("WorkdayState")
	var pause_menu := root.get_node_or_null("PauseMenu")
	assert(state != null, "WorkdayState autoload must exist")
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
				"code": "ERR-04",
				"character_id": "PERSON-GENERAL",
				"applicant": "普通申请人",
				"decision": "驳回",
				"effective": false,
				"procedure_errors": ["遗漏材料"],
			}
		)
	)
	var error := change_scene_to_file("res://scenes/after_work_corridor.tscn")
	assert(error == OK, "after-work corridor must open")
	await process_frame
	await process_frame
	var corridor = current_scene
	assert(corridor != null and corridor.name == "AfterWorkCorridor", "corridor must be the current scene")
	assert(corridor.slide_index == 0, "slideshow must start on the first walking frame")
	assert(corridor.dialogue_box is DialogueBox, "corridor must reuse the shared bottom dialogue box")
	assert(corridor.dialogue_box.dialogue_label.text == "……", "first frame must begin with an ellipsis")
	assert(corridor.dialogue_box.state == DialogueBox.DialogueState.TYPING, "first frame must begin with typewriter text")
	assert(corridor.frame_texture.texture.resource_path.ends_with("corridor_legs_01_step.png"), "first frame must use the approved leg close-up asset")
	assert(corridor.footsteps_active, "walking frame must play footsteps")
	var first_slide_index: int = corridor.slide_index
	await create_timer(0.25).timeout
	assert(corridor.slide_index == first_slide_index, "corridor slides must never advance on a timer")
	corridor.dialogue_box.reveal_current_line()
	assert(corridor.dialogue_box.state == DialogueBox.DialogueState.WAITING_FOR_INPUT, "first input must only complete the current thought")
	assert(corridor.slide_index == first_slide_index, "revealing a thought must not change the image")
	corridor.dialogue_box._handle_manual_advance()
	assert(corridor.slide_index == 1, "second input must manually advance to the memory frame")

	assert(corridor.dialogue_box.dialogue_label.text == "最后一份档案……我是不是漏看了日期。", "procedural errors must become the residual memory line")
	assert(corridor.frame_texture.texture.resource_path.ends_with("corridor_legs_02_step.png"), "memory frame must use the second walking asset")

	corridor.show_slide_for_tests(2)
	assert(corridor.dialogue_box.dialogue_label.text == "再确认一下。", "third frame must stop on the re-check thought")
	assert(not corridor.footsteps_active, "stopped frame must silence footsteps")
	assert(corridor.frame_texture.texture.resource_path.ends_with("corridor_legs_03_stop.png"), "re-check frame must use the stopped-leg asset")

	corridor.show_slide_for_tests(3)
	assert(corridor.dialogue_box.dialogue_label.text == "……", "final walking frame must return to an ellipsis")
	assert(corridor.footsteps_active, "final walking frame must resume footsteps")
	assert(corridor.frame_texture.texture.resource_path.ends_with("corridor_legs_04_resume.png"), "final frame must use the pushed-in resumed-walk asset")
	print("FORMOCRACY_AFTER_WORK_CORRIDOR_TEST_OK")
	quit(0)
