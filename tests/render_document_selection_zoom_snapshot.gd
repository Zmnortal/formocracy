extends SceneTree

# 渲染一份被选中并放大的材料，用于检查边框、中心锚点和正文可读性。

const OUTPUT_PATH := "/tmp/formocracy-document-selection-zoom.png"


func _init() -> void:
	call_deferred("run")


func run() -> void:
	@warning_ignore_start("unsafe_method_access")
	@warning_ignore_start("unsafe_property_access")
	@warning_ignore_start("unsafe_cast")
	var state := root.get_node("WorkdayState") as WorkdayContext
	state.call("reset_for_tests")
	assert(change_scene_to_file("res://main.tscn") == OK)
	await process_frame
	await process_frame
	if DisplayServer.get_name() == "headless":
		print("FORMOCRACY_DOCUMENT_SELECTION_ZOOM_SNAPSHOT_OK (skipped on headless display)")
		quit(0)
		return

	current_scene.manager.start_first_case_for_tests()
	await process_frame
	var presenter: Variant = current_scene.manager.presenter
	current_scene.manager.npc_performance.skip_current_performance()
	await create_timer(0.1).timeout
	presenter.set_envelope_on_desk(true)
	presenter._show_billboard_immediate()
	presenter.open_envelope()
	await create_timer(0.3).timeout
	presenter.open_document(presenter.primary_document_id)
	var selected_document: Variant = presenter.document_panels[0]
	presenter.open_document(selected_document.document_id)
	await create_timer(0.35).timeout
	for step in 4:
		selected_document.adjust_user_zoom(1)
	await process_frame

	var image := root.get_viewport().get_texture().get_image()
	assert(not image.is_empty())
	assert(image.save_png(OUTPUT_PATH) == OK)
	@warning_ignore_restore("unsafe_cast")
	@warning_ignore_restore("unsafe_property_access")
	@warning_ignore_restore("unsafe_method_access")
	print("FORMOCRACY_DOCUMENT_SELECTION_ZOOM_SNAPSHOT_OK %s" % OUTPUT_PATH)
	quit(0)
