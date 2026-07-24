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
	in_bounds_item.position = Vector2(360, 535)
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

	print("FORMOCRACY_DESK_ITEM_PHYSICS_TEST_OK")
	quit(0)
