extends SceneTree

const DEFAULT_OUTPUT_PATH := "user://evening-map-redesign-default.png"
const SELECTED_OUTPUT_PATH := "user://evening-map-redesign-selected.png"


func _init() -> void:
	call_deferred("run")


func run() -> void:
	var state := root.get_node_or_null("WorkdayState")
	state.reset_for_tests()
	state.day_number = 3
	state.balance = 42
	state.player_name = "测试职员"
	state.manager.begin_evening()
	var error := change_scene_to_file("res://scenes/evening_map.tscn")
	assert(error == OK, "evening map must open")
	await process_frame
	await process_frame
	await process_frame
	if DisplayServer.get_name() == "headless":
		print("FORMOCRACY_EVENING_MAP_REDESIGN_SNAPSHOT_OK (skipped on headless display)")
		quit(0)
		return
	var default_image := root.get_viewport().get_texture().get_image()
	assert(default_image.save_png(DEFAULT_OUTPUT_PATH) == OK, "default snapshot must save")
	current_scene._preview_location(current_scene.LOCATION_FORMS)
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var selected_image := root.get_viewport().get_texture().get_image()
	assert(selected_image.save_png(SELECTED_OUTPUT_PATH) == OK, "selected snapshot must save")
	print("FORMOCRACY_EVENING_MAP_REDESIGN_DEFAULT=" + ProjectSettings.globalize_path(DEFAULT_OUTPUT_PATH))
	print("FORMOCRACY_EVENING_MAP_REDESIGN_SELECTED=" + ProjectSettings.globalize_path(SELECTED_OUTPUT_PATH))
	quit(0)
