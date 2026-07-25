extends SceneTree

const DRAWER_SNAPSHOT := "/tmp/formocracy-handbook-in-drawer.png"
const DESK_SNAPSHOT := "/tmp/formocracy-handbook-on-desk.png"
const READER_SNAPSHOT := "/tmp/formocracy-handbook-reader.png"
const PAGE_TWO_SNAPSHOT := "/tmp/formocracy-handbook-page-two.png"
const RETURNED_SNAPSHOT := "/tmp/formocracy-handbook-returned.png"


func _init() -> void:
	call_deferred("run")


# 渲染手册从抽屉、桌面、阅读到归还的完整视觉链路。
func run() -> void:
	@warning_ignore_start("unsafe_method_access")
	var state_node := root.get_node("WorkdayState")
	state_node.call("reset_for_tests")
	if DisplayServer.get_name() == "headless":
		print("FORMOCRACY_REFERENCE_HANDBOOK_SNAPSHOT_OK (skipped on headless display)")
		quit()
		return
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.disable_3d = true
	root.add_child(viewport)
	var scene := Node2D.new()
	viewport.add_child(scene)
	var builder: Variant = load("res://scripts/gameplay/desk_builder.gd").new()
	var desk: Variant = builder.build(scene)
	var desk_items := DeskItemController.new(scene)
	var cabinet: Variant = load(
		"res://scripts/managers/workbench_manager/workbench_filing_cabinet_module.gd"
	).new(scene, desk, desk_items)
	await process_frame

	cabinet.open_upper()
	await create_timer(0.35).timeout
	await _capture(viewport, DRAWER_SNAPSHOT)

	await cabinet.take_handbook_to_desk()
	await _capture(viewport, DESK_SNAPSHOT)

	cabinet.open_handbook()
	await create_timer(0.22).timeout
	await _capture(viewport, READER_SNAPSHOT)

	await cabinet.turn_handbook_page(1)
	await _capture(viewport, PAGE_TWO_SNAPSHOT)

	await cabinet.close_handbook()
	await cabinet.return_handbook_to_drawer()
	await _capture(viewport, RETURNED_SNAPSHOT)

	cabinet.shutdown()
	scene.queue_free()
	viewport.queue_free()
	await process_frame
	@warning_ignore_restore("unsafe_method_access")
	print(
		"FORMOCRACY_REFERENCE_HANDBOOK_SNAPSHOT_OK %s %s %s %s %s"
		% [
			DRAWER_SNAPSHOT,
			DESK_SNAPSHOT,
			READER_SNAPSHOT,
			PAGE_TWO_SNAPSHOT,
			RETURNED_SNAPSHOT,
		]
	)
	quit()


# 保存当前 SubViewport 画面，供人工视觉验收。
func _capture(viewport: SubViewport, path: String) -> void:
	await process_frame
	await process_frame
	var image := viewport.get_texture().get_image()
	assert(not image.is_empty(), "reference handbook snapshot must render a non-empty frame")
	assert(image.save_png(path) == OK, "reference handbook snapshot must save")
