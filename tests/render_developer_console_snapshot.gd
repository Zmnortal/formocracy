extends SceneTree

const SNAPSHOT_PATH := "/tmp/formocracy-developer-console.png"


func _init() -> void:
	call_deferred("run")


func run() -> void:
	var state = root.get_node("WorkdayState")
	state.reset_for_tests()
	state.balance = 25
	var error := change_scene_to_file("res://scenes/main_menu.tscn")
	assert(error == OK, "main menu must load behind the developer console")
	await process_frame
	await process_frame
	var console = root.get_node("DeveloperConsole")
	if not console.is_open:
		console.toggle_console()
	await process_frame
	await create_timer(0.2).timeout
	assert(console.ration_selector.value == 25, "developer console snapshot must show the real ration balance")
	assert(console.command_input.position.y + console.command_input.size.y <= console.console_panel.size.y, "developer console controls must remain inside the panel")
	if DisplayServer.get_name() == "headless":
		print("FORMOCRACY_DEVELOPER_CONSOLE_RENDER_OK (skipped on headless display)")
		quit(0)
		return
	var image := root.get_viewport().get_texture().get_image()
	assert(not image.is_empty(), "developer console viewport must produce an image")
	assert(image.save_png(SNAPSHOT_PATH) == OK, "developer console screenshot must be saved")
	print("FORMOCRACY_DEVELOPER_CONSOLE_RENDER_OK %s" % SNAPSHOT_PATH)
	quit(0)
