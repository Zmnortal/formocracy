extends SceneTree

# 验证选择页的三种真实入口：
# 最新自动保存继续当前进度、历史节点创建分支、根节点进入首次游玩 Opening。


func _init() -> void:
	call_deferred("run")


func run() -> void:
	@warning_ignore_start("unsafe_method_access")
	@warning_ignore_start("unsafe_property_access")
	@warning_ignore_start("unsafe_cast")
	var selector_scene := load("res://scenes/workday_selector.tscn") as PackedScene
	assert(selector_scene != null, "workday selector scene must load")
	var state := root.get_node("WorkdayState") as WorkdayContext
	state.save_path = "user://formocracy-save-resume-flow-test.json"
	state.call("start_new_game")
	state.persistence_enabled = false
	state.player_name = "流程测试员"
	state.target_case_count = 3
	var save_system := state.get("save_system") as FormocracySaveSystem
	var manager := state.get("manager") as WorkdayManager
	assert(save_system.create_initial_checkpoint(), "test must create the opening root")
	state.persistence_enabled = true
	manager.begin_next_day()
	state.records.append({"case_id": "CASE-TEST", "decision": "批准"})
	state.seconds_remaining = 73.0
	assert(state.call("save_progress"), "test must create a working autosave")
	assert(state.call("get_resume_phase") == "workbench", "unfinished cases must resume at the workbench")
	state.records.resize(state.target_case_count)
	assert(state.call("get_resume_phase") == "daily_report", "finished unsettled cases must resume at the report")
	state.settled_day_number = state.day_number
	assert(state.call("get_resume_phase") == "evening", "settled cases must resume at the evening map")
	state.records.resize(1)
	state.settled_day_number = 1

	var selector := selector_scene.instantiate()
	root.add_child(selector)
	await process_frame
	await process_frame

	var root_id := ""
	var history_id := ""
	for node: Dictionary in save_system.get_checkpoint_nodes():
		if WorkdayContext.read_int(node, "completed_day") == 0:
			root_id = WorkdayContext.read_string(node, "node_id")
		else:
			history_id = WorkdayContext.read_string(node, "node_id")
	assert(not root_id.is_empty(), "timeline must retain the opening root")
	assert(not history_id.is_empty(), "timeline must retain completed-day history")

	selector.call("select_checkpoint", root_id)
	assert(selector.get("pending_action") == "new_game", "the opening root must start a new game")
	selector.call("close_confirmation")
	selector.call("select_checkpoint", history_id)
	assert(selector.get("pending_action") == "branch", "a completed day must create a history branch")
	selector.call("close_confirmation")

	state.day_number = 99
	state.records.clear()
	state.seconds_remaining = 1.0
	selector.call("resume_game")
	assert(state.day_number == 2, "resume must load working_state instead of a checkpoint snapshot")
	assert(state.records.size() == 1, "resume must restore mid-day records")
	assert(is_equal_approx(state.seconds_remaining, 73.0), "resume must restore remaining work time")
	await process_frame
	await process_frame
	assert(current_scene != null and current_scene.scene_file_path == "res://main.tscn", "an unfinished workday must resume at the workbench")
	assert(is_equal_approx(state.seconds_remaining, 73.0), "workbench configuration must not reset restored time")
	selector.queue_free()

	state.call("start_new_game")
	state.persistence_enabled = false
	assert(save_system.create_initial_checkpoint(), "test must recreate the opening root")
	var opening_selector := selector_scene.instantiate()
	root.add_child(opening_selector)
	await process_frame
	await process_frame
	var root_node: Dictionary = save_system.get_checkpoint_nodes()[0]
	root_id = WorkdayContext.read_string(root_node, "node_id")
	opening_selector.call("select_checkpoint", root_id)
	assert(opening_selector.get("pending_action") == "new_game", "opening root must request first-play flow")
	opening_selector.call("confirm_pending_action")
	await process_frame
	await process_frame
	assert(current_scene != null and current_scene.scene_file_path == "res://scenes/opening.tscn", "confirming the opening root must enter the Opening scene")
	assert(not save_system.has_save(), "first-play flow must clear the old timeline before Opening")

	state.call("start_new_game")
	state.save_path = FormocracySaveSchema.DEFAULT_PATH
	state.persistence_enabled = false
	@warning_ignore_restore("unsafe_cast")
	@warning_ignore_restore("unsafe_property_access")
	@warning_ignore_restore("unsafe_method_access")
	print("FORMOCRACY_SAVE_RESUME_FLOW_TEST_OK")
	quit(0)
