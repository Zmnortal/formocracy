extends SceneTree


func _init() -> void:
	call_deferred("run")


func run() -> void:
	@warning_ignore_start("unsafe_method_access")
	var state_node := root.get_node("WorkdayState")
	state_node.call("reset_for_tests")
	state_node.set("day_number", 4)
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var scene := Node2D.new()
	viewport.add_child(scene)
	var builder: Variant = load("res://scripts/gameplay/desk_builder.gd").new()
	var desk: Variant = builder.build(scene)
	var calendar: Variant = load(
		"res://scripts/managers/workbench_manager/workbench_calendar_module.gd"
	).new(scene, desk)
	await process_frame

	assert(desk.wall_calendar.size == Vector2(220, 146), "the in-world calendar must be enlarged")
	assert(calendar.small_markers.passed_day_count == 3, "days before today must be circled")
	assert(calendar.overlay.z_index > 1000, "the expanded calendar must render above every desk interaction layer")
	assert(not calendar.overlay.visible)

	_click(viewport, desk.wall_calendar.position + desk.wall_calendar.size * 0.5)
	await create_timer(0.2).timeout
	assert(calendar.overlay.visible)
	assert(calendar.today_label.text.contains("礼拜四"))
	assert(calendar.today_label.text.contains("值勤日"))
	assert(calendar.schedule_label.text.contains("做六休一"))

	state_node.set("day_number", 7)
	calendar.refresh()
	assert(calendar.today_label.text.contains("礼拜日"))
	assert(calendar.today_label.text.contains("法定休息日"))
	assert(calendar.small_markers.passed_day_count == 6)

	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	assert(calendar.handle_unhandled_input(escape))
	assert(not calendar.overlay.visible)

	calendar.shutdown()
	scene.queue_free()
	viewport.queue_free()
	await process_frame
	@warning_ignore_restore("unsafe_method_access")
	print("FORMOCRACY_WORK_CALENDAR_TEST_OK")
	quit()


# 向日历实际热区发送一次完整鼠标点击。
func _click(viewport: SubViewport, position: Vector2) -> void:
	for pressed in [true, false]:
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = pressed
		click.position = position
		click.global_position = position
		viewport.push_input(click, true)
