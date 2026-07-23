extends SceneTree

const SNAPSHOT_PATH := "/tmp/formocracy-core-gameplay.png"


func _init() -> void:
	call_deferred("run")


func run() -> void:
	var state = root.get_node("WorkdayState")
	state.reset_for_tests()
	var error := change_scene_to_file("res://main.tscn")
	assert(error == OK, "main scene must open for render verification")
	await process_frame
	await process_frame
	current_scene.envelope_on_desk = true
	current_scene.open_envelope()
	await process_frame
	var image := root.get_viewport().get_texture().get_image()
	assert(not image.is_empty(), "rendered viewport must produce an image")
	assert(image.save_png(SNAPSHOT_PATH) == OK, "render verification screenshot must be saved")
	print("FORMOCRACY_RENDER_SNAPSHOT_OK " + SNAPSHOT_PATH)
	quit(0)
