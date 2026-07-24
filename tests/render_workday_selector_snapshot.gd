extends SceneTree

const SNAPSHOT_PATH := "/tmp/formocracy-workday-selector.png"
const CONFIRMATION_SNAPSHOT_PATH := "/tmp/formocracy-workday-selector-confirmation.png"


func _init() -> void:
	call_deferred("run")


func run() -> void:
	var state = root.get_node("WorkdayState")
	state.save_path = "user://formocracy-workday-selector-render.json"
	state.start_new_game()
	state.player_name = "张子奕"
	assert(state.create_initial_checkpoint(), "selector render root must be created")
	state.persistence_enabled = true
	state.begin_next_day()
	var nodes: Array[Dictionary] = state.get_checkpoint_nodes()
	var day_one_id := ""
	for node in nodes:
		if int(node.completed_day) == 1:
			day_one_id = String(node.node_id)
	state.begin_next_day()
	assert(state.load_checkpoint(day_one_id), "render must return to day one")
	state.balance = 77
	state.begin_next_day()
	var error := change_scene_to_file("res://scenes/workday_selector.tscn")
	assert(error == OK, "workday selector scene must load")
	await process_frame
	await process_frame
	await create_timer(0.2).timeout
	if DisplayServer.get_name() == "headless":
		print("FORMOCRACY_WORKDAY_SELECTOR_RENDER_OK (skipped on headless display)")
		state.start_new_game()
		state.save_path = state.DEFAULT_SAVE_PATH
		quit(0)
		return
	var image := root.get_viewport().get_texture().get_image()
	assert(not image.is_empty(), "selector viewport must produce an image")
	assert(image.save_png(SNAPSHOT_PATH) == OK, "selector snapshot must save")
	current_scene.request_continue_game()
	await process_frame
	var confirmation_image := root.get_viewport().get_texture().get_image()
	assert(
		confirmation_image.save_png(CONFIRMATION_SNAPSHOT_PATH) == OK,
		"selector confirmation snapshot must save"
	)
	state.start_new_game()
	state.save_path = state.DEFAULT_SAVE_PATH
	print("FORMOCRACY_WORKDAY_SELECTOR_RENDER_OK %s %s" % [SNAPSHOT_PATH, CONFIRMATION_SNAPSHOT_PATH])
	quit(0)
