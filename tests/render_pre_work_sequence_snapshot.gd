extends SceneTree

const NEWSPAPER_PATH := "/tmp/formocracy-pre-work-newspaper.png"
const WALK_PATH := "/tmp/formocracy-pre-work-walking.png"
const ARRIVAL_PATH := "/tmp/formocracy-pre-work-arrival.png"


func _init() -> void:
	call_deferred("run")


func run() -> void:
	var state = root.get_node("WorkdayState")
	state.save_path = "user://formocracy-pre-work-render.json"
	state.start_new_game()
	state.player_name = "张子奕"
	var error := change_scene_to_file("res://scenes/pre_work_sequence.tscn")
	assert(error == OK, "pre-work sequence must load for visual QA")
	await process_frame
	await process_frame
	if DisplayServer.get_name() == "headless":
		state.start_new_game()
		state.save_path = state.DEFAULT_SAVE_PATH
		print("FORMOCRACY_PRE_WORK_RENDER_OK (skipped on headless display)")
		quit(0)
		return
	var sequence = current_scene
	await create_timer(0.55).timeout
	sequence.dialogue_box.reveal_current_line()
	await RenderingServer.frame_post_draw
	_save_frame(NEWSPAPER_PATH)

	sequence.show_phase_for_tests("walking", 1)
	sequence.dialogue_box.reveal_current_line()
	await process_frame
	await RenderingServer.frame_post_draw
	_save_frame(WALK_PATH)

	sequence.show_phase_for_tests("arrival")
	sequence.dialogue_box.reveal_current_line()
	await process_frame
	await RenderingServer.frame_post_draw
	_save_frame(ARRIVAL_PATH)

	state.start_new_game()
	state.save_path = state.DEFAULT_SAVE_PATH
	print("FORMOCRACY_PRE_WORK_RENDER_OK %s %s %s" % [NEWSPAPER_PATH, WALK_PATH, ARRIVAL_PATH])
	quit(0)


func _save_frame(path: String) -> void:
	var image := root.get_viewport().get_texture().get_image()
	assert(not image.is_empty(), "viewport must render a visual QA frame")
	assert(image.save_png(path) == OK, "visual QA frame must save: %s" % path)
