extends SceneTree

# 主菜单功能测试。
# 验证标题界面、按钮、存档检测、继续/新游戏/覆盖弹窗交互。


func _init() -> void:
	call_deferred("run")


# 运行主菜单完整测试流程。
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
	assert(menu.start_button.get_theme_font_size("font_size") == 30, "main menu text must remain legible at high resolutions")
	assert(menu.start_button.custom_minimum_size == Vector2(380, 76), "main menu buttons must use the large presentation size")
	assert(menu.continue_button != null, "continue button reference must be retained for save-menu focus")
	assert(menu.overwrite_panel.panel.size == Vector2(680, 360), "overwrite confirmation must use the shared bureau modal")
	assert(menu.overwrite_panel.panel.get_theme_stylebox("panel").border_color == Color("84945c"), "modal must use the pause-menu border color")
	assert(menu.overwrite_confirm_button.get_theme_font_size("font_size") == 18, "overwrite actions must use the shared pixel button style")
	assert(menu.save_panel.panel.scale.x >= 1.0, "bureau modal must scale up instead of shrinking on large viewports")
	var modal_visual_size: Vector2 = menu.save_panel.panel.size * menu.save_panel.panel.scale
	var modal_center: Vector2 = menu.save_panel.panel.position + modal_visual_size / 2.0
	assert(modal_center.distance_to(menu.save_panel.size / 2.0) < 1.0, "bureau modal must remain centered after viewport scaling")
	var artwork := menu.get_node("TitleArtwork") as TextureRect
	assert(artwork.anchor_right == 1.0 and artwork.anchor_bottom == 1.0, "title artwork must follow the full viewport")
	assert(artwork.stretch_mode == TextureRect.STRETCH_KEEP_ASPECT_COVERED, "title artwork must stay centered with aspect-cover cropping")
	assert(not menu.save_panel.visible, "save choice must begin hidden")
	assert(not state.has_save(), "test must begin without a save")
	state.day_number = 4
	state.records.clear()
	state.records.append({"decision": "批准"})
	assert(state.save_progress(), "save progress must succeed")
	assert(state.has_save(), "save file must exist")
	menu.on_start_pressed()
	assert(menu.save_panel.visible, "existing save must open the save-choice panel")
	assert(menu.continue_button.has_focus(), "continue button must receive focus without a node-path lookup")
	menu.confirm_new_game()
	assert(menu.overwrite_panel.visible, "new game must open the custom overwrite panel")
	assert(menu.overwrite_confirm_button.has_focus(), "overwrite confirmation must receive keyboard focus")
	menu.close_overwrite_panel()
	menu.close_save_panel()
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
