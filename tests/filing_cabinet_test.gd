extends SceneTree

const CLOSED_TEXTURE := preload("res://assets/office/filing_cabinet/states/00_closed.png")
const UPPER_OPEN_EMPTY_TEXTURE := preload("res://assets/office/filing_cabinet/states/02_upper_open_empty.png")
const LOWER_OPEN_TEXTURE := preload("res://assets/office/filing_cabinet/states/04_lower_open_evidence.png")


func _init() -> void:
	call_deferred("run")


func run() -> void:
	@warning_ignore_start("unsafe_method_access")
	var state_node := root.get_node("WorkdayState")
	state_node.call("reset_for_tests")
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var scene := Node2D.new()
	viewport.add_child(scene)
	var builder_script: Variant = load("res://scripts/gameplay/desk_builder.gd")
	var builder: Variant = builder_script.new()
	var desk: Variant = builder.build(scene)
	var item_controller := DeskItemController.new(scene)
	var cabinet_script: Variant = load("res://scripts/managers/workbench_manager/workbench_filing_cabinet_module.gd")
	var cabinet: Variant = cabinet_script.new(scene, desk, item_controller)
	await process_frame

	assert(desk.filing_cabinet.texture == CLOSED_TEXTURE)
	assert(desk.filing_cabinet.scale == Vector2(1.8, 1.8))
	assert(desk.filing_cabinet.z_index > 4)
	assert(not cabinet.overlay.visible)
	assert(not desk.filing_cabinet_upper_hit.disabled)

	_click(viewport, Vector2(114, 395))
	await create_timer(0.35).timeout
	assert(cabinet.state == cabinet.STATE_UPPER_OPEN)
	assert(desk.filing_cabinet.texture == UPPER_OPEN_EMPTY_TEXTURE)
	assert(not cabinet.overlay.visible)
	assert(cabinet.handbook_item.visible)
	assert(cabinet.book_state == cabinet.BOOK_IN_DRAWER)

	_click(viewport, cabinet.BOOK_DRAWER_POSITION + Vector2(56, 72))
	await create_timer(0.35).timeout
	assert(cabinet.book_state == cabinet.BOOK_ON_DESK)
	assert(cabinet.handbook_item.position.is_equal_approx(cabinet.BOOK_DESK_POSITION))
	assert(desk.filing_cabinet.texture == UPPER_OPEN_EMPTY_TEXTURE)

	_click(viewport, cabinet.BOOK_DESK_POSITION + Vector2(56, 72))
	await create_timer(0.22).timeout
	assert(cabinet.reader_overlay.visible)
	assert(not cabinet.handbook_item.visible)
	assert(cabinet.reader_left_title.text.contains("办理流程"))
	assert(cabinet.reader_previous_button.disabled)
	assert(not cabinet.reader_next_button.disabled)

	await cabinet.turn_handbook_page(1)
	assert(cabinet.reader_left_title.text.contains("操作方法"))
	assert(cabinet.reader_page_label.text.contains("2 / 3"))

	await cabinet.close_handbook()
	assert(not cabinet.reader_overlay.visible)
	assert(cabinet.handbook_item.visible)
	assert(cabinet.book_state == cabinet.BOOK_ON_DESK)

	_drag(
		viewport,
		cabinet.BOOK_DESK_POSITION + Vector2(56, 72),
		cabinet.handbook_return_zone.position + cabinet.handbook_return_zone.size * 0.5,
	)
	await create_timer(0.4).timeout
	assert(cabinet.book_state == cabinet.BOOK_IN_DRAWER)
	assert(cabinet.handbook_item.position.is_equal_approx(cabinet.BOOK_DRAWER_POSITION))
	assert(desk.filing_cabinet.texture == UPPER_OPEN_EMPTY_TEXTURE)

	await cabinet.close_upper()
	assert(cabinet.state == cabinet.STATE_CLOSED)
	assert(desk.filing_cabinet.texture == CLOSED_TEXTURE)
	assert(not cabinet.overlay.visible)

	_click(viewport, Vector2(114, 548))
	await create_timer(0.35).timeout
	assert(cabinet.state == cabinet.STATE_LOWER_OPEN)
	assert(desk.filing_cabinet.texture == LOWER_OPEN_TEXTURE)
	assert(cabinet.overlay.visible)
	assert(cabinet.section_label.text.contains("私人证物"))
	assert(cabinet.clue_asset.visible)
	assert(cabinet.body_label.text.contains("黄铜钥匙"))

	await cabinet.close()
	assert(cabinet.state == cabinet.STATE_CLOSED)
	assert(not desk.filing_cabinet_lower_hit.disabled)

	cabinet.shutdown()
	scene.queue_free()
	viewport.queue_free()
	@warning_ignore_restore("unsafe_method_access")
	print("FORMOCRACY_FILING_CABINET_TEST_OK")
	quit()


func _click(viewport: SubViewport, position: Vector2) -> void:
	for pressed in [true, false]:
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = pressed
		click.position = position
		click.global_position = position
		viewport.push_input(click, true)


# 从一个设计坐标拖到另一个设计坐标。
func _drag(viewport: SubViewport, from: Vector2, to: Vector2) -> void:
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = from
	press.global_position = from
	viewport.push_input(press, true)

	var motion := InputEventMouseMotion.new()
	motion.position = to
	motion.global_position = to
	motion.relative = to - from
	motion.button_mask = MOUSE_BUTTON_MASK_LEFT
	viewport.push_input(motion, true)

	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = to
	release.global_position = to
	viewport.push_input(release, true)
