extends SceneTree

const OPENING_SNAPSHOT := "/tmp/formocracy-du-cinematic-opening.png"
const CLOSEUP_SNAPSHOT := "/tmp/formocracy-du-cinematic-closeup.png"
const AMBULANCE_SNAPSHOT := "/tmp/formocracy-du-cinematic-ambulance.png"


func _init() -> void:
	call_deferred("run")


func run() -> void:
	var state := root.get_node("WorkdayState") as WorkdayContext
	state.reset_for_tests()
	var error := change_scene_to_file("res://scenes/du_chunmei_death_notice.tscn")
	assert(error == OK, "death cinematic scene must open")
	await process_frame
	await process_frame
	if DisplayServer.get_name() == "headless":
		print("FORMOCRACY_DU_CINEMATIC_SNAPSHOT_OK (skipped on headless display)")
		quit(0)
		return

	await create_timer(0.35).timeout
	_save_snapshot(OPENING_SNAPSHOT)

	current_scene._show_shot(3, true)
	await create_timer(0.35).timeout
	_save_snapshot(CLOSEUP_SNAPSHOT)

	current_scene._show_shot(4, true)
	await create_timer(0.35).timeout
	_save_snapshot(AMBULANCE_SNAPSHOT)

	print(
		"FORMOCRACY_DU_CINEMATIC_SNAPSHOT_OK %s %s %s"
		% [OPENING_SNAPSHOT, CLOSEUP_SNAPSHOT, AMBULANCE_SNAPSHOT]
	)
	quit(0)


func _save_snapshot(path: String) -> void:
	var image := root.get_viewport().get_texture().get_image()
	assert(not image.is_empty(), "cinematic viewport must render an image")
	assert(image.save_png(path) == OK, "cinematic snapshot must be saved: %s" % path)
