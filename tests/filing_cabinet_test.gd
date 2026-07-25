extends SceneTree

const CLOSED_TEXTURE := preload("res://assets/office/filing_cabinet/states/00_closed.png")
const UPPER_OPEN_TEXTURE := preload("res://assets/office/filing_cabinet/states/02_upper_open_handbook.png")
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
	var cabinet_script: Variant = load("res://scripts/managers/workbench_manager/workbench_filing_cabinet_module.gd")
	var cabinet: Variant = cabinet_script.new(scene, desk)
	await process_frame

	assert(desk.filing_cabinet.texture == CLOSED_TEXTURE)
	assert(desk.filing_cabinet.scale == Vector2(1.8, 1.8))
	assert(desk.filing_cabinet.z_index > 4)
	assert(not cabinet.overlay.visible)
	assert(not desk.filing_cabinet_upper_hit.disabled)

	_click(viewport, Vector2(114, 395))
	await create_timer(0.35).timeout
	assert(cabinet.state == cabinet.STATE_UPPER_OPEN)
	assert(desk.filing_cabinet.texture == UPPER_OPEN_TEXTURE)
	assert(cabinet.overlay.visible)
	assert(cabinet.section_label.text.contains("办理流程"))
	assert(cabinet.content_asset.texture == cabinet.HANDBOOK_TEXTURE)
	var close_button := cabinet.overlay.get_node("CabinetPanel/CloseCabinetButton") as Button
	assert(close_button.shortcut != null)

	cabinet.select_handbook_page(2)
	assert(cabinet.section_label.text.contains("局务常识"))
	assert(cabinet.body_label.text.contains("现实效力"))

	await cabinet.close()
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
