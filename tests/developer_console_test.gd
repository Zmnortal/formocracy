extends SceneTree


func _init() -> void:
	call_deferred("run")


func run() -> void:
	var state := root.get_node_or_null("WorkdayState")
	if state == null:
		state = load("res://scripts/workday_state.gd").new()
		state.name = "WorkdayState"
		root.add_child(state)
	state.reset_for_tests()
	var console = load("res://scripts/developer_console.gd").new()
	root.add_child(console)
	await process_frame
	assert(console.dev_button != null, "DEV button must be created")
	assert(console.scene_selector.item_count == 4, "scene selector must expose opening plus three development scenes")
	assert(console.scene_selector.get_item_metadata(0) == "res://scenes/opening.tscn", "opening scene must be selectable")
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
	console.toggle_console()
	assert(not console.is_open and not console.blocker.visible, "console must close")
	print("FORMOCRACY_DEVELOPER_CONSOLE_TEST_OK")
	quit(0)
