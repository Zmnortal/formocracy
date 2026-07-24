extends SceneTree

const SaveSchema := preload("res://scripts/save/save_schema.gd")


func _init() -> void:
	call_deferred("run")


func run() -> void:
	var state := root.get_node("WorkdayState") as WorkdayContext
	var save_system_value: Variant = state.get("save_system")
	assert(save_system_value is Object, "WorkdayState must expose the save system")
	@warning_ignore("unsafe_cast")
	var save_system: Object = save_system_value
	var manager_value: Variant = state.get("manager")
	assert(manager_value is Object, "WorkdayState must expose the workday manager")
	@warning_ignore("unsafe_cast")
	var workday_manager: Object = manager_value
	state.save_path = "user://formocracy-workday-selector-scroll-test.json"
	state.call("start_new_game")
	state.player_name = "长周期测试员"
	assert(save_system.call("create_initial_checkpoint") == true, "scroll fixture must create a root")
	state.persistence_enabled = true
	for _day in range(8):
		workday_manager.call("begin_next_day")

	var packed: PackedScene = load("res://scenes/workday_selector.tscn")
	var selector := packed.instantiate()
	root.add_child(selector)
	await process_frame
	await process_frame
	var timeline_scroll := selector.get_node("Canvas/TimelineScroll") as ScrollContainer
	var timeline := timeline_scroll.get_node("Timeline") as Control
	assert(timeline.custom_minimum_size.x > timeline_scroll.size.x, "long save trees must grow beyond the viewport")
	var bar := timeline_scroll.get_h_scroll_bar()
	assert(bar.max_value > bar.page, "long save trees must expose a usable horizontal scroll range")
	timeline_scroll.scroll_horizontal = int(bar.max_value - bar.page)
	await process_frame
	assert(timeline_scroll.scroll_horizontal > 0, "timeline must accept horizontal scrolling")

	state.call("start_new_game")
	state.save_path = SaveSchema.DEFAULT_PATH
	state.persistence_enabled = false
	print("FORMOCRACY_WORKDAY_SELECTOR_SCROLL_TEST_OK")
	quit(0)
