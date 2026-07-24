extends SceneTree

const SNAPSHOT_PATH := "/tmp/formocracy-batch-validation.png"


func _init() -> void:
	call_deferred("run")


func run() -> void:
	var state = root.get_node("WorkdayState")
	var config = root.get_node("ConfigDatabase")
	state.reset_for_tests()
	var error := change_scene_to_file("res://main.tscn")
	assert(error == OK, "main scene must open")
	await process_frame
	await process_frame
	current_scene.manager.briefing.skip()
	for case_id in ["CASE-001", "CASE-002", "CASE-003"]:
		var case_data: Dictionary = config.get_gameplay_case(case_id)
		state.manager.record_case_result(case_data, "批准", [], 5.0, case_data.document_ids)
	current_scene.manager.batch_validation.open()
	if DisplayServer.get_name() == "headless":
		print("FORMOCRACY_BATCH_RENDER_OK (skipped on headless display)")
		quit(0)
		return
	await process_frame
	var image := root.get_viewport().get_texture().get_image()
	assert(image.save_png(SNAPSHOT_PATH) == OK, "batch validation screenshot must be saved")
	print("FORMOCRACY_BATCH_RENDER_OK %s" % SNAPSHOT_PATH)
	quit(0)
