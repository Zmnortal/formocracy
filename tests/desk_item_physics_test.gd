extends SceneTree

# 验证统一桌面物件的点击阈值、全屏抓取、落桌和布局恢复。


func _init() -> void:
	call_deferred("run")


func run() -> void:
	var state := root.get_node("WorkdayState")
	state.reset_for_tests()
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
	assert(is_equal_approx(item.position.y, 634.0), "released item must fall to the desk baseline")
	assert(item.position.x <= 1202.0, "released item must return inside horizontal desk bounds")
	assert(state.get_desk_item_layout("physics_test_item").has("position"), "resting layout must persist")

	var restored := Control.new()
	restored.size = item.size
	scene_root.add_child(restored)
	controller.unregister_item("physics_test_item")
	controller.register_item(restored, "physics_test_item")
	assert(restored.position.is_equal_approx(item.position), "registered item must restore its saved layout")

	print("FORMOCRACY_DESK_ITEM_PHYSICS_TEST_OK")
	quit(0)
