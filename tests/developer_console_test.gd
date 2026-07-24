extends SceneTree


func _init() -> void:
	call_deferred("run")


func run() -> void:
	var state := root.get_node_or_null("WorkdayState")
	if state == null:
		state = load("res://scripts/autoload/workday_state.gd").new()
		state.name = "WorkdayState"
		root.add_child(state)
	state.reset_for_tests()
	var console = load("res://scripts/autoload/developer_console.gd").new()
	root.add_child(console)
	await process_frame
	assert(console.dev_button != null, "DEV button must be created")
	assert(console.root_control.mouse_filter == Control.MOUSE_FILTER_IGNORE, "closed developer console must not intercept game input")
	assert(console.scene_selector.item_count == 7, "scene selector must expose menu, workday selector, narrative and five development scenes")
	assert(console.scene_selector.get_item_metadata(0) == "res://scenes/main_menu.tscn", "main menu must be selectable")
	assert(console.scene_selector.get_item_metadata(5) == "res://scenes/evening_map.tscn", "evening map must be selectable")
	assert(console.level_selector.item_count >= 1, "level selector must expose CSV-configured levels")
	assert(console.collision_button != null, "developer console must expose collision visualization")
	assert(console.interaction_overlay != null, "developer console must create the UI interaction overlay")
	assert(not console.get_tree().debug_collisions_hint, "collision visualization must default to off")
	console.toggle_console()
	assert(console.is_open and console.blocker.visible, "console must open")
	console.fill_test_records("mixed")
	assert(state.records.size() == 3, "mixed preset must create three records")
	assert(state.get_summary().approved == 2, "mixed preset must create two approvals")
	assert(state.get_summary().rejected == 1, "mixed preset must create one rejection")
	console.day_selector.value = 12
	console._on_set_day()
	assert(state.day_number == 12, "day selector must update workday")
	console.execute_command("clear")
	console.execute_command("state")
	assert(console.status_label.text.contains("工作日：12"), "state command must report current day")
	console.toggle_collision_debug()
	assert(console.get_tree().debug_collisions_hint, "collision switch must enable runtime collision drawing")
	assert(console.interaction_overlay.visible, "collision switch must reveal Control and Rect2 interaction zones")
	assert(console.collision_button.text.contains("显示"), "collision switch must report its enabled state")
	console.toggle_collision_debug()
	assert(not console.get_tree().debug_collisions_hint, "collision switch must disable runtime collision drawing")
	console.toggle_console()
	assert(not console.is_open and not console.blocker.visible, "console must close")
	print("FORMOCRACY_DEVELOPER_CONSOLE_TEST_OK")
	quit(0)
