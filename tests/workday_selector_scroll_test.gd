extends SceneTree


func _init() -> void:
	call_deferred("run")


func run() -> void:
	var state = root.get_node("WorkdayState")
	state.save_path = "user://formocracy-workday-selector-scroll-test.json"
	state.start_new_game()
	state.player_name = "长周期测试员"
	assert(state.create_initial_checkpoint(), "scroll fixture must create a root")
	state.persistence_enabled = true
	for _day in range(8):
		state.begin_next_day()

	var packed: PackedScene = load("res://scenes/workday_selector.tscn")
	var selector = packed.instantiate()
	root.add_child(selector)
	await process_frame
	await process_frame
	assert(selector.timeline.custom_minimum_size.x > selector.timeline_scroll.size.x, "long save trees must grow beyond the viewport")
	var bar: HScrollBar = selector.timeline_scroll.get_h_scroll_bar()
	assert(bar.max_value > bar.page, "long save trees must expose a usable horizontal scroll range")
	selector.timeline_scroll.scroll_horizontal = int(bar.max_value - bar.page)
	await process_frame
	assert(selector.timeline_scroll.scroll_horizontal > 0, "timeline must accept horizontal scrolling")

	state.start_new_game()
	state.save_path = state.DEFAULT_SAVE_PATH
	state.persistence_enabled = false
	print("FORMOCRACY_WORKDAY_SELECTOR_SCROLL_TEST_OK")
	quit(0)

