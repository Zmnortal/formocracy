extends SceneTree

const SNAPSHOT_PATH := "res://output/after-work-corridor/formocracy-after-work-corridor.png"


func _init() -> void:
	call_deferred("run")


func run() -> void:
	var state := root.get_node_or_null("WorkdayState")
	assert(state != null, "WorkdayState autoload must exist")
	state.reset_for_tests()
	state.day_number = 5
	state.player_name = "档案员 07"
	state.balance = 46
	(
		state
		. records
		. append(
			{
				"code": "LIN-05",
				"character_id": "PERSON-LIN",
				"applicant": "林默",
				"decision": "批准",
				"effective": true,
				"procedure_errors": [],
			}
		)
	)
	(
		state
		. records
		. append(
			{
				"code": "OUT-05",
				"character_id": "PERSON-OUTSIDE",
				"applicant": "区外申请人",
				"decision": "驳回",
				"effective": false,
				"procedure_errors": ["居住证明过期"],
			}
		)
	)
	var error := change_scene_to_file("res://scenes/after_work_corridor.tscn")
	assert(error == OK, "after-work corridor must open for rendering")
	await process_frame
	await process_frame
	current_scene.show_slide_for_tests(2)
	current_scene.dialogue_box.reveal_current_line()
	await create_timer(0.35).timeout
	if DisplayServer.get_name() == "headless":
		print("FORMOCRACY_AFTER_WORK_CORRIDOR_SNAPSHOT_OK (skipped on headless display)")
		quit(0)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SNAPSHOT_PATH).get_base_dir())
	var image := root.get_viewport().get_texture().get_image()
	assert(not image.is_empty(), "corridor must produce a rendered frame")
	var save_error := image.save_png(SNAPSHOT_PATH)
	assert(save_error == OK, "corridor snapshot must be saved")
	print("FORMOCRACY_AFTER_WORK_CORRIDOR_SNAPSHOT=" + ProjectSettings.globalize_path(SNAPSHOT_PATH))
	quit(0)
