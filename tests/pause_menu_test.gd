extends SceneTree

# 暂停菜单功能测试。
# 验证 ESC 打开/关闭、暂停恢复、确认弹窗、返回主菜单与开发控制台优先级。


func _init() -> void:
	call_deferred("run")


# 运行暂停菜单完整测试流程。
func run() -> void:
	var pause_menu = root.get_node("PauseMenu")
	var developer_console = root.get_node("DeveloperConsole")
	assert(pause_menu.is_scene_allowed_path("res://main.tscn"), "main gameplay must allow pause menu")
	assert(pause_menu.is_scene_allowed_path("res://scenes/daily_report.tscn"), "daily report must allow pause menu")
	assert(pause_menu.is_scene_allowed_path("res://scenes/evening_map.tscn"), "evening map must allow pause menu")
	assert(not pause_menu.is_scene_allowed_path("res://scenes/opening.tscn"), "opening must retain its own escape behavior")
	assert(not pause_menu.is_scene_allowed_path("res://scenes/main_menu.tscn"), "main menu must retain its own escape behavior")

	var error := change_scene_to_file("res://main.tscn")
	assert(error == OK, "main scene must open for pause testing")
	await process_frame
	await process_frame
	pause_menu.open_menu()
	assert(pause_menu.is_open, "pause menu must open in gameplay")
	assert(paused, "opening pause menu must pause the scene tree")
	assert(pause_menu.overlay.visible, "pause overlay must be visible")
	assert(pause_menu.resume_button.has_focus(), "resume action must receive keyboard focus")
	assert(pause_menu.music_slider.value == root.get_node("OpeningMusic").volume_percent, "pause menu must expose global music volume")
	assert(pause_menu.mute_button.text in ["静音", "恢复"], "pause menu must expose mute control")
	pause_menu.confirm_return_to_menu()
	assert(pause_menu.menu_confirmation.visible, "return confirmation must open as an in-game bureau modal")
	assert(pause_menu.menu_confirmation.panel.get_theme_stylebox("panel").border_color == Color("84945c"), "pause confirmations must share the pause visual language")
	var modal_escape := InputEventKey.new()
	modal_escape.keycode = KEY_ESCAPE
	modal_escape.pressed = true
	pause_menu._unhandled_key_input(modal_escape)
	assert(not pause_menu.menu_confirmation.visible and pause_menu.is_open, "escape must close the confirmation before closing the pause menu")
	pause_menu.close_menu()
	assert(not pause_menu.is_open and not paused, "closing pause menu must resume gameplay")

	developer_console.is_open = true
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	pause_menu._unhandled_key_input(escape)
	assert(not pause_menu.is_open, "developer console must take escape priority")
	developer_console.is_open = false

	pause_menu.open_menu()
	pause_menu.return_to_main_menu()
	await process_frame
	await process_frame
	assert(not paused, "returning to menu must clear paused state")
	assert(current_scene.scene_file_path == "res://scenes/main_menu.tscn", "return action must open main menu")
	print("FORMOCRACY_PAUSE_MENU_TEST_OK")
	quit(0)
