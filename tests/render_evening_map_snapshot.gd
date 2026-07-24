extends SceneTree

const OUTPUT_PATH := "user://evening-map-snapshot.png"


func _init() -> void:
	call_deferred("run")


func run() -> void:
	var state := root.get_node_or_null("WorkdayState")
	state.reset_for_tests()
	state.day_number = 1
	state.balance = 42
	var error := change_scene_to_file("res://scenes/evening_map.tscn")
	assert(error == OK, "evening map must open")
	await process_frame
	await process_frame
	await process_frame
	var image := root.get_viewport().get_texture().get_image()
	var save_error := image.save_png(OUTPUT_PATH)
	assert(save_error == OK, "snapshot must save")
	print("FORMOCRACY_EVENING_MAP_SNAPSHOT=" + ProjectSettings.globalize_path(OUTPUT_PATH))
	quit(0)
