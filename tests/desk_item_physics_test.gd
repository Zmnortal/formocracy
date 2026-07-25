extends SceneTree

# 验证统一桌面物件的点击阈值、全屏抓取、落桌和布局恢复。


func _init() -> void:
	call_deferred("run")


func run() -> void:
	var state := root.get_node("WorkdayState") as WorkdayContext
	state.call("reset_for_tests")
	@warning_ignore("unsafe_cast")
	var manager := state.get("manager") as WorkdayManager
	var scene_root := Node2D.new()
	root.add_child(scene_root)
	var controller := DeskItemController.new(scene_root)
	var item := Control.new()
	item.position = Vector2(400, 120)
	item.size = Vector2(60, 50)
	scene_root.add_child(item)

	var click_count := [0]
	controller.register_item(item, "physics_test_item", func(): click_count[0] += 1)
	controller._begin_press(item, Vector2(10, 10))
	controller._end_press(item)
	assert(click_count[0] == 1, "a stationary press must remain a click")

	controller._begin_press(item, Vector2(10, 10))
	var direct_drag := InputEventMouseMotion.new()
	direct_drag.position = Vector2(90, 90)
	direct_drag.relative = Vector2(1, 1)
	direct_drag.global_position = scene_root.to_global(Vector2(530, 510))
	controller._move_pressed_item(item, direct_drag)
	var anchored_pointer := item.get_global_transform() * Vector2(10, 10)
	assert(anchored_pointer.is_equal_approx(direct_drag.global_position), "the original grab point must track the absolute pointer one-to-one through drag transforms")
	controller._end_press(item)
	await create_timer(0.25).timeout

	controller._begin_press(item, Vector2(10, 10))
	item.set_meta("desk_dragging", true)
	item.position = Vector2(1500, 80)
	item.set_meta("desk_last_motion", Vector2(20, -4))
	controller._end_press(item)
	await create_timer(0.9).timeout
	var minimum_landing_y := DeskGeometry.BOUNDS_TOP
	var maximum_landing_y := DeskGeometry.BOUNDS_FLOOR - item.size.y
	var landing_normalized := inverse_lerp(DeskGeometry.BOUNDS_TOP, DeskGeometry.BOUNDS_FLOOR, item.position.y)
	var expected_left_edge := DeskGeometry.bounds_left_at(landing_normalized)
	var expected_right_edge := DeskGeometry.bounds_right_at(landing_normalized) - item.size.x
	assert(item.position.y >= minimum_landing_y and item.position.y <= maximum_landing_y, "gravity landing must choose a valid point within the desk depth")
	assert(item.position.x >= expected_left_edge, "released item must return inside the left desk bound")
	assert(item.position.x <= expected_right_edge, "released item must return inside horizontal desk bounds")
	assert(manager.get_desk_item_layout("physics_test_item").has("position"), "resting layout must persist")

	var in_bounds_item := Control.new()
	in_bounds_item.position = Vector2(360, DeskGeometry.BOUNDS_TOP + 20)
	in_bounds_item.size = Vector2(70, 44)
	scene_root.add_child(in_bounds_item)
	controller.register_item(in_bounds_item, "in_bounds_item")
	controller._begin_press(in_bounds_item, Vector2(10, 10))
	in_bounds_item.set_meta("desk_dragging", true)
	in_bounds_item.set_meta("desk_last_motion", Vector2(8, 3))
	var released_position := in_bounds_item.position
	controller._end_press(in_bounds_item)
	await create_timer(0.25).timeout
	assert(in_bounds_item.position.is_equal_approx(released_position), "an item released fully inside DeskBounds must settle exactly where the player left it")
	assert(manager.get_desk_item_layout("in_bounds_item").has("position"), "in-bounds placement must persist without a gravity fall")

	var restored := Control.new()
	restored.size = item.size
	scene_root.add_child(restored)
	controller.unregister_item("physics_test_item")
	controller.register_item(restored, "physics_test_item")
	assert(restored.position.is_equal_approx(item.position), "registered item must restore its saved layout")

	var guarded_item := Control.new()
	guarded_item.position = Vector2(520, 520)
	guarded_item.size = Vector2(80, 60)
	scene_root.add_child(guarded_item)
	controller.register_item(guarded_item, "guarded_item", Callable(), Callable(), Callable(), Callable(), func(_item: Control, _local_position: Vector2): return false)
	controller._begin_press(guarded_item, Vector2(12, 12))
	assert(not WorkdayContext.to_bool(guarded_item.get_meta("desk_pressed")), "an interaction guard must prevent a covered item from starting a drag")

	var back_item := Control.new()
	back_item.position = Vector2(620, 180)
	back_item.size = Vector2(120, 100)
	scene_root.add_child(back_item)
	controller.register_item(back_item, "overlap_back")
	var front_item := Control.new()
	front_item.position = back_item.position
	front_item.size = back_item.size
	scene_root.add_child(front_item)
	controller.register_item(front_item, "overlap_front")
	back_item.z_index = 30
	front_item.z_index = 40
	var overlap_press := InputEventMouseButton.new()
	overlap_press.button_index = MOUSE_BUTTON_LEFT
	overlap_press.pressed = true
	overlap_press.global_position = scene_root.to_global(back_item.position + Vector2(24, 24))
	overlap_press.position = Vector2(24, 24)
	controller._on_item_input(overlap_press, back_item)
	assert(not WorkdayContext.to_bool(back_item.get_meta("desk_pressed")), "a visually covered item must never capture the press")
	assert(WorkdayContext.to_bool(front_item.get_meta("desk_pressed")), "the frontmost visible item must receive a press even when the event reached a lower control")
	var overlap_release := InputEventMouseButton.new()
	overlap_release.button_index = MOUSE_BUTTON_LEFT
	overlap_release.pressed = false
	overlap_release.global_position = overlap_press.global_position
	controller._on_item_input(overlap_release, back_item)
	assert(not WorkdayContext.to_bool(front_item.get_meta("desk_pressed")), "release must finish the item selected by the centralized frontmost resolver")

	print("FORMOCRACY_DESK_ITEM_PHYSICS_TEST_OK")
	quit(0)
