extends SceneTree


func _init() -> void:
	call_deferred("run")


func run() -> void:
	var state := root.get_node("WorkdayState") as WorkdayContext
	state.save_path = "user://formocracy-day-start-checkpoint-test.json"
	state.start_new_game()
	state.player_name = "晨间存档测试员"
	state.persistence_enabled = false
	assert(state.save_system.create_initial_checkpoint(), "opening root must be created")
	state.persistence_enabled = true
	state.manager.begin_next_day()

	var day_one_id := ""
	for node: Dictionary in state.save_system.get_checkpoint_nodes():
		if WorkdayContext.read_int(node, "completed_day") == 1:
			day_one_id = WorkdayContext.read_string(node, "node_id")
			break
	assert(not day_one_id.is_empty(), "finishing day one must create a historical checkpoint")
	assert(state.save_system.load_checkpoint(day_one_id), "historical day one checkpoint must load")
	assert(state.day_number == 2, "day one checkpoint must restore the beginning of day two")
	assert(state.manager.get_read_newspaper().is_empty(), "day-start checkpoint must precede newspaper reading")
	assert(state.get_resume_phase() == "pre_work", "an unread day-start save must route to the morning sequence")
	assert(state.manager.mark_newspaper_read("NEWSPAPER-HENGCHUAN-DAILY"), "test must be able to finish the morning paper")
	assert(state.get_resume_phase() == "workbench", "a day whose paper is already read may resume at the workbench")
	assert(state.save_system.load_checkpoint(day_one_id), "historical checkpoint must restore its unread morning state")

	var selector_scene := load("res://scenes/workday_selector.tscn") as PackedScene
	assert(selector_scene != null, "workday selector must load")
	var selector = selector_scene.instantiate()
	root.add_child(selector)
	await process_frame
	await process_frame
	selector.selected_checkpoint_id = day_one_id
	selector._continue_game()
	await process_frame
	await process_frame

	assert(
		current_scene != null
		and current_scene.scene_file_path == "res://scenes/pre_work_sequence.tscn",
		"loading a completed-day checkpoint must enter the morning newspaper scene"
	)
	assert(current_scene.phase == "newspaper_selection", "restored day must wait for the player's newspaper choice")

	state.start_new_game()
	state.save_path = state.DEFAULT_SAVE_PATH
	state.persistence_enabled = false
	print("FORMOCRACY_DAY_START_CHECKPOINT_TEST_OK")
	quit(0)
