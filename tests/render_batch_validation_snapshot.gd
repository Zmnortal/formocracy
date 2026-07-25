extends SceneTree

const SNAPSHOT_PATH := "/tmp/formocracy-batch-validation.png"


func _init() -> void:
	call_deferred("run")


func run() -> void:
	var state = root.get_node("WorkdayState")
	var config = root.get_node("ConfigDatabase")
	state.reset_for_tests()
	for case_id in [
		"CASE-001",
		"CASE-002",
		"CASE-003",
		"CASE-G-D1-01",
		"CASE-G-D1-02",
	]:
		var case_data: Dictionary = config.get_gameplay_case(case_id)
		state.manager.record_case_result(case_data, "批准", [], 5.0, case_data.document_ids)
	state.machine_capacity = 4
	var error := change_scene_to_file("res://scenes/batch_validation.tscn")
	assert(error == OK, "standalone batch validation scene must open")
	await process_frame
	await process_frame
	var module = current_scene.module
	assert(current_scene.name == "BatchValidation", "snapshot must use the standalone validation scene")
	assert(module.overlay.has_node("ValidationMachineBody"), "snapshot must render the split top-down machine")
	assert(module.overlay.has_node("ValidationDocumentClip"), "snapshot must render the machine intake clip")
	assert(module.overlay.find_child("LeaveValidationButton", true, false) != null, "snapshot must render the explicit leave action")
	if DisplayServer.get_name() == "headless":
		print("FORMOCRACY_BATCH_RENDER_OK (skipped on headless display)")
		quit(0)
		return
	var first_button := module.buttons.get("ARCHIVE-00001") as Button
	var second_button := module.buttons.get("ARCHIVE-00002") as Button
	assert(first_button != null and second_button != null, "snapshot document bags must exist")
	module._commit_archive_drop("ARCHIVE-00001", true)
	module._commit_archive_drop("ARCHIVE-00002", true)
	await process_frame
	assert(module.selected_ids.size() == 2, "snapshot must show a visible multi-selection")
	assert(not module.confirm_button.disabled, "snapshot must show the explicit confirm action")
	assert(module.active_document_bag == null, "selection snapshot must precede machine animation")
	await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_viewport().get_texture().get_image()
	assert(image.save_png(SNAPSHOT_PATH) == OK, "batch validation screenshot must be saved")
	print("FORMOCRACY_BATCH_RENDER_OK %s" % SNAPSHOT_PATH)
	quit(0)
