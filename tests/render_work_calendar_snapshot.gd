extends SceneTree

const SMALL_SNAPSHOT := "/tmp/formocracy-work-calendar-small.png"
const OPEN_SNAPSHOT := "/tmp/formocracy-work-calendar-open.png"
const REST_SNAPSHOT := "/tmp/formocracy-work-calendar-rest-day.png"


func _init() -> void:
	call_deferred("run")


# 渲染小日历、展开值勤日和展开休息日三种状态。
func run() -> void:
	@warning_ignore_start("unsafe_method_access")
	var state_node := root.get_node("WorkdayState")
	state_node.call("reset_for_tests")
	state_node.set("day_number", 4)
	if DisplayServer.get_name() == "headless":
		print("FORMOCRACY_WORK_CALENDAR_RENDER_OK (skipped on headless display)")
		quit()
		return

	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.disable_3d = true
	root.add_child(viewport)
	var scene := Node2D.new()
	viewport.add_child(scene)
	var desk: Variant = load("res://scripts/gameplay/desk_builder.gd").new().build(scene)
	var calendar: Variant = load(
		"res://scripts/managers/workbench_manager/workbench_calendar_module.gd"
	).new(scene, desk)
	await process_frame

	await _capture(viewport, SMALL_SNAPSHOT)
	calendar.open()
	await create_timer(0.22).timeout
	await _capture(viewport, OPEN_SNAPSHOT)

	state_node.set("day_number", 7)
	calendar.refresh()
	await _capture(viewport, REST_SNAPSHOT)

	calendar.shutdown()
	scene.queue_free()
	viewport.queue_free()
	await process_frame
	@warning_ignore_restore("unsafe_method_access")
	print(
		"FORMOCRACY_WORK_CALENDAR_RENDER_OK %s %s %s"
		% [SMALL_SNAPSHOT, OPEN_SNAPSHOT, REST_SNAPSHOT]
	)
	quit()


# 保存当前 GPU 渲染帧。
func _capture(viewport: SubViewport, path: String) -> void:
	await process_frame
	await process_frame
	var image := viewport.get_texture().get_image()
	assert(not image.is_empty())
	assert(image.save_png(path) == OK)
