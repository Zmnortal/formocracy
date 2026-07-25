extends SceneTree

const SNAPSHOT_PATH := "/tmp/formocracy-opening-approved.png"


func _init() -> void:
	call_deferred("run")


func run() -> void:
	var error := change_scene_to_file("res://scenes/opening.tscn")
	assert(error == OK, "opening scene must load for approval-stamp visual verification")
	await process_frame
	await process_frame
	await create_timer(1.9).timeout
	var opening = current_scene
	var today := Time.get_date_dict_from_system()
	opening.name_input.text = "测试职员"
	opening.year_input.text = str(today.year)
	opening.month_input.text = "%02d" % today.month
	opening.day_input.text = "%02d" % today.day
	opening.confirmation.button_pressed = true
	opening.confirm_button.visible = false
	opening.paper_replace_handle.visible = false
	await opening._play_approval_stamp()
	await process_frame
	if DisplayServer.get_name() == "headless":
		print("FORMOCRACY_OPENING_APPROVAL_RENDER_OK (skipped on headless display)")
		quit(0)
		return
	var image := root.get_viewport().get_texture().get_image()
	assert(not image.is_empty(), "approved opening viewport must produce an image")
	assert(image.save_png(SNAPSHOT_PATH) == OK, "approved opening screenshot must be saved")
	print("FORMOCRACY_OPENING_APPROVAL_RENDER_OK %s" % SNAPSHOT_PATH)
	quit(0)
