extends SceneTree

# 主菜单功能测试。
# 验证标题界面和独立工作日选择场景入口。


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
	assert(menu.start_button.get_theme_font_size("font_size") == 45, "main menu typography must use the enlarged presentation scale")
	assert(menu.start_button.custom_minimum_size == Vector2(570, 114), "main menu buttons must follow the 1.5x presentation scale")
	var artwork := menu.get_node("TitleArtwork") as TextureRect
	assert(artwork.anchor_right == 1.0 and artwork.anchor_bottom == 1.0, "title artwork must follow the full viewport")
	assert(artwork.stretch_mode == TextureRect.STRETCH_KEEP_ASPECT_COVERED, "title artwork must stay centered with aspect-cover cropping")
	assert(not state.has_save(), "test must begin without a save")
	state.day_number = 1
	state.player_name = "测试审批员"
	state.reinstatement_date = "2026-07-23"
	state.player_signature = [[[1.0, 2.0], [3.0, 4.0]]]
	assert(state.create_initial_checkpoint(), "opening completion must create the beginning node")
	state.persistence_enabled = true
	state.begin_next_day()
	state.begin_next_day()
	state.begin_next_day()
	state.records.append({"decision": "批准"})
	assert(state.save_progress(), "save progress must succeed")
	assert(state.has_save(), "save file must exist")
	var selector_scene: PackedScene = load(menu.WORKDAY_SELECTOR_SCENE)
	assert(selector_scene != null, "game start must point to the full-screen workday selector")
	var selector = selector_scene.instantiate()
	root.add_child(selector)
	await process_frame
	assert(selector.title_label.text == "选择一天来继续或者从头开始游戏", "selector must present the workday timeline heading")
	assert(selector.timeline_scroll.horizontal_scroll_mode == ScrollContainer.SCROLL_MODE_AUTO, "deep save trees must expose horizontal scrolling")
	assert(selector.timeline_scroll.follow_focus, "keyboard navigation must scroll focused checkpoints into view")
	assert(not selector.new_game_button.visible, "an existing save must render as one pure tree without a detached new-game card")
	assert(selector.save_button.visible, "existing save must appear as a timeline node")
	for checkpoint_button in selector.checkpoint_buttons.values():
		assert(checkpoint_button.size == Vector2(150, 92), "all checkpoint cards must share one actual size")
	assert(selector.save_button.text.contains("第 3 天"), "latest checkpoint must represent the last completed day")
	assert(selector.delete_button.visible, "saved workday must expose the delete action")
	assert(not selector.confirmation_layer.visible, "selector confirmation state must begin hidden")
	selector.request_delete_save()
	assert(selector.confirmation_layer.visible, "delete must use the selector's full-screen confirmation state")
	assert(selector.pending_action == "delete", "delete confirmation must retain its requested action")
	selector.close_confirmation()
	selector.request_continue_game()
	assert(selector.confirmation_layer.visible, "saved workday must require confirmation before loading")
	assert(selector.pending_action == "continue", "continue confirmation must retain its requested action")
	selector.close_confirmation()
	selector.request_new_game()
	assert(selector.confirmation_layer.visible, "new game must require overwrite confirmation when a save exists")
	assert(selector.pending_action == "new_game", "overwrite confirmation must retain its requested action")
	selector.close_confirmation()
	selector.queue_free()
	state.day_number = 1
	state.player_name = ""
	state.player_signature.clear()
	state.records.clear()
	assert(state.load_progress(), "saved progress must load")
	assert(state.day_number == 4, "saved workday must restore")
	assert(state.player_name == "测试审批员", "player identity from the opening form must persist globally")
	assert(state.player_signature.size() == 1, "handwritten signature strokes must persist")
	assert(state.records.size() == 1, "saved records must restore")
	state.start_new_game()
	assert(not state.has_save(), "new game must remove old save")
	state.save_path = state.DEFAULT_SAVE_PATH
	state.persistence_enabled = false
	print("FORMOCRACY_MAIN_MENU_TEST_OK")
	quit(0)
