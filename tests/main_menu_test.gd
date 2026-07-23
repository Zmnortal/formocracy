extends SceneTree


func _init() -> void:
	call_deferred("run")


func run() -> void:
	var state = root.get_node("WorkdayState")
	var test_path := "user://formocracy-main-menu-test.json"
	state.save_path = test_path
	state.start_new_game()
	state.persistence_enabled = false
	var packed: PackedScene = load("res://scenes/main_menu.tscn")
	assert(packed != null, "main menu scene must load")
	var menu = packed.instantiate()
	root.add_child(menu)
	await process_frame
	assert(menu.start_button.text == "游戏开始", "main menu must expose game start")
	assert(menu.exit_button.text == "退出游戏", "main menu must expose exit")
	assert(not menu.save_panel.visible, "save choice must begin hidden")
	assert(not state.has_save(), "test must begin without a save")
	state.day_number = 4
	state.records.clear()
	state.records.append({"decision": "批准"})
	assert(state.save_progress(), "save progress must succeed")
	assert(state.has_save(), "save file must exist")
	state.day_number = 1
	state.records.clear()
	assert(state.load_progress(), "saved progress must load")
	assert(state.day_number == 4, "saved workday must restore")
	assert(state.records.size() == 1, "saved records must restore")
	state.start_new_game()
	assert(not state.has_save(), "new game must remove old save")
	state.save_path = state.DEFAULT_SAVE_PATH
	state.persistence_enabled = false
	print("FORMOCRACY_MAIN_MENU_TEST_OK")
	quit(0)
