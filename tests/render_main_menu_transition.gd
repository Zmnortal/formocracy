extends SceneTree

const SCATTER_PATH := "/tmp/formocracy-main-menu-scatter.png"
const BLACK_HOLD_PATH := "/tmp/formocracy-main-menu-black-hold.png"
const RECORDS_FADE_PATH := "/tmp/formocracy-workday-selector-fade.png"
const BRIGHTEST_BOUNDARY_PATH := "/tmp/formocracy-main-menu-transition-brightest-boundary.png"


# 渲染主菜单散场、黑场停顿与记录页面渐显三个关键状态。
func _init() -> void:
	call_deferred("run")


# 启动实际场景流并在三个关键时刻保存画面。
func run() -> void:
	if DisplayServer.get_name() == "headless":
		print("FORMOCRACY_MAIN_MENU_TRANSITION_RENDER_OK (skipped on headless display)")
		quit(0)
		return
	var error := change_scene_to_file("res://scenes/main_menu.tscn")
	assert(error == OK, "main menu must load for transition rendering")
	await process_frame
	await process_frame
	await create_timer(1.1).timeout
	var menu = current_scene
	menu.on_start_pressed()
	await create_timer(0.45).timeout
	save_frame(SCATTER_PATH)
	await wait_for_menu_phase(menu, "black_hold")
	save_frame(BLACK_HOLD_PATH)
	var brightest_boundary_luma := await audit_scene_boundary_luminance()
	assert(
		brightest_boundary_luma < 0.18,
		"menu-to-record boundary must never contain a bright clear frame: %.3f" % brightest_boundary_luma
	)
	save_frame(RECORDS_FADE_PATH)
	print(
		"FORMOCRACY_MAIN_MENU_TRANSITION_RENDER_OK %s %s %s brightest=%.3f"
		% [SCATTER_PATH, BLACK_HOLD_PATH, RECORDS_FADE_PATH, brightest_boundary_luma]
	)
	quit(0)


# 等待主菜单到达指定转场阶段。
func wait_for_menu_phase(menu, phase: String) -> void:
	var deadline := Time.get_ticks_msec() + 5000
	while is_instance_valid(menu) and menu.transition_phase != phase:
		assert(Time.get_ticks_msec() < deadline, "timed out waiting for menu phase: %s" % phase)
		await process_frame


# 逐帧检查黑场到记录页渐显的完整边界，保存其中平均亮度最高的一帧。
func audit_scene_boundary_luminance() -> float:
	var deadline := Time.get_ticks_msec() + 5000
	var brightest_luma := 0.0
	while Time.get_ticks_msec() < deadline:
		await process_frame
		var image := root.get_viewport().get_texture().get_image()
		var frame_luma := sampled_average_luminance(image)
		if frame_luma > brightest_luma:
			brightest_luma = frame_luma
			assert(image.save_png(BRIGHTEST_BOUNDARY_PATH) == OK, "brightest boundary frame must save")
		if (
			current_scene != null
			and current_scene.scene_file_path == "res://scenes/workday_selector.tscn"
			and current_scene.entrance_complete
		):
			break
	assert(Time.get_ticks_msec() < deadline, "timed out auditing menu-to-record boundary")
	return brightest_luma


# 在规则网格上计算画面平均亮度；全屏白/灰闪会显著抬高该值。
func sampled_average_luminance(image: Image) -> float:
	assert(not image.is_empty(), "boundary audit viewport must produce an image")
	var total := 0.0
	var sample_count := 0
	for y_step in 18:
		for x_step in 32:
			var x := mini(image.get_width() - 1, roundi((float(x_step) + 0.5) * image.get_width() / 32.0))
			var y := mini(image.get_height() - 1, roundi((float(y_step) + 0.5) * image.get_height() / 18.0))
			var color := image.get_pixel(x, y)
			total += color.r * 0.2126 + color.g * 0.7152 + color.b * 0.0722
			sample_count += 1
	return total / float(sample_count)


# 等待目标场景成为当前场景，并在超时时明确失败。
func wait_for_scene(path: String) -> void:
	var deadline := Time.get_ticks_msec() + 5000
	while current_scene == null or current_scene.scene_file_path != path:
		assert(Time.get_ticks_msec() < deadline, "timed out waiting for scene: %s" % path)
		await process_frame


# 保存当前主视口画面。
func save_frame(path: String) -> void:
	var image := root.get_viewport().get_texture().get_image()
	assert(not image.is_empty(), "transition viewport must produce an image")
	assert(image.save_png(path) == OK, "transition frame must save: %s" % path)
