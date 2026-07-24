extends SceneTree

const FRAME_PATHS := [
	"/tmp/formocracy-opening-approach.png",
	"/tmp/formocracy-opening-ingestion.png",
	"/tmp/formocracy-opening-machine-fade.png",
	"/tmp/formocracy-opening-welcome.png",
]


func _init() -> void:
	call_deferred("run")


func run() -> void:
	var state = root.get_node("WorkdayState")
	state.save_path = "user://formocracy-opening-animation-render.json"
	state.start_new_game()
	var error := change_scene_to_file("res://scenes/opening.tscn")
	assert(error == OK, "opening scene must load for animation rendering")
	await process_frame
	await process_frame
	await create_timer(1.9).timeout
	if DisplayServer.get_name() == "headless":
		state.start_new_game()
		state.save_path = state.DEFAULT_SAVE_PATH
		print("FORMOCRACY_OPENING_ANIMATION_RENDER_OK (skipped on headless display)")
		quit(0)
		return
	var opening = current_scene
	var today := Time.get_date_dict_from_system()
	opening.name_input.text = "张子奕"
	opening.year_input.text = str(today.year)
	opening.month_input.text = "%02d" % today.month
	opening.day_input.text = "%02d" % today.day
	var signature := PackedVector2Array()
	for i in 26:
		signature.append(Vector2(12 + i * 9, 42 + sin(i * 0.8) * 22))
	opening.signature_pad.strokes.append(signature)
	opening.confirmation.button_pressed = true
	opening.refresh_form_validity()
	opening.submit_form()

	await wait_for_phase(opening, "approach")
	await create_timer(1.0).timeout
	save_frame(FRAME_PATHS[0])
	await wait_for_phase(opening, "ingestion")
	await create_timer(1.0).timeout
	save_frame(FRAME_PATHS[1])
	await wait_for_phase(opening, "machine_fade")
	await create_timer(1.4).timeout
	save_frame(FRAME_PATHS[2])
	await wait_for_phase(opening, "welcome")
	await create_timer(0.9).timeout
	save_frame(FRAME_PATHS[3])

	state.start_new_game()
	state.save_path = state.DEFAULT_SAVE_PATH
	print("FORMOCRACY_OPENING_ANIMATION_RENDER_OK %s" % " ".join(FRAME_PATHS))
	quit(0)


func wait_for_phase(opening, phase: String) -> void:
	var deadline := Time.get_ticks_msec() + 15000
	while opening.submission_phase != phase:
		if Time.get_ticks_msec() >= deadline:
			push_error("timed out waiting for opening phase: %s (current: %s)" % [phase, opening.submission_phase])
			quit(1)
			return
		await process_frame


func save_frame(path: String) -> void:
	var image := root.get_viewport().get_texture().get_image()
	assert(not image.is_empty(), "animation viewport must produce an image")
	assert(image.save_png(path) == OK, "animation frame must save: %s" % path)
