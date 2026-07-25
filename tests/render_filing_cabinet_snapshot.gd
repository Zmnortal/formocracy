extends SceneTree

const CLOSED_SNAPSHOT := "/tmp/formocracy-filing-cabinet-closed.png"
const UPPER_SNAPSHOT := "/tmp/formocracy-filing-cabinet-upper.png"
const LOWER_SNAPSHOT := "/tmp/formocracy-filing-cabinet-lower.png"


func _init() -> void:
	call_deferred("run")


func run() -> void:
	@warning_ignore_start("unsafe_method_access")
	var state_node := root.get_node("WorkdayState")
	state_node.call("reset_for_tests")
	if DisplayServer.get_name() == "headless":
		print("FORMOCRACY_FILING_CABINET_SNAPSHOT_OK (skipped on headless display)")
		quit()
		return

	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.disable_3d = true
	root.add_child(viewport)
	var scene := Node2D.new()
	viewport.add_child(scene)
	var builder_script: Variant = load("res://scripts/gameplay/desk_builder.gd")
	var builder: Variant = builder_script.new()
	var desk: Variant = builder.build(scene)
	var cabinet_script: Variant = load("res://scripts/managers/workbench_manager/workbench_filing_cabinet_module.gd")
	var cabinet: Variant = cabinet_script.new(scene, desk)
	await process_frame

	await _capture(viewport, CLOSED_SNAPSHOT)
	cabinet.open_upper()
	await create_timer(0.4).timeout
	assert(cabinet.state == cabinet.STATE_UPPER_OPEN)
	await _capture(viewport, UPPER_SNAPSHOT)
	cabinet.close_upper()
	await create_timer(0.35).timeout
	cabinet.open_lower()
	await create_timer(0.4).timeout
	assert(cabinet.state == cabinet.STATE_LOWER_OPEN)
	await _capture(viewport, LOWER_SNAPSHOT)

	cabinet.shutdown()
	scene.queue_free()
	viewport.queue_free()
	await process_frame
	@warning_ignore_restore("unsafe_method_access")
	print("FORMOCRACY_FILING_CABINET_SNAPSHOT_OK %s %s %s" % [CLOSED_SNAPSHOT, UPPER_SNAPSHOT, LOWER_SNAPSHOT])
	quit()


func _capture(viewport: SubViewport, path: String) -> void:
	await process_frame
	await process_frame
	var image := viewport.get_texture().get_image()
	assert(not image.is_empty(), "filing cabinet snapshot must render a non-empty frame")
	assert(image.save_png(path) == OK, "filing cabinet snapshot must save")
