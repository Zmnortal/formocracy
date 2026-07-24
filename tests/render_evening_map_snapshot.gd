extends SceneTree

const OUTPUT_PATH := "user://evening-map-snapshot.png"


func _init() -> void:
	call_deferred("run")


func run() -> void:
	var state := root.get_node_or_null("WorkdayState")
	state.reset_for_tests()
	state.day_number = 1
	state.balance = 42
	state.player_name = "林默"
	var error := change_scene_to_file("res://scenes/evening_map.tscn")
	assert(error == OK, "evening map must open")
	await process_frame
	await process_frame
	await process_frame
	current_scene.select_location(current_scene.LOCATION_RATION)
	await create_timer(1.1).timeout
	current_scene.purchase_water_form()
	await create_timer(0.7).timeout
	current_scene.ration_window.visible = false
	current_scene.select_location(current_scene.LOCATION_HOME)
	await create_timer(1.4).timeout
	current_scene.reason_input.text = "本周期日常饮用"
	current_scene.truth_declaration.button_pressed = true
	current_scene.refresh_home_form_validity()
	current_scene.submit_water_form()
	await process_frame
	current_scene.end_night()
	await process_frame
	var image := root.get_viewport().get_texture().get_image()
	var save_error := image.save_png(OUTPUT_PATH)
	assert(save_error == OK, "snapshot must save")
	print("FORMOCRACY_EVENING_MAP_SNAPSHOT=" + ProjectSettings.globalize_path(OUTPUT_PATH))
	quit(0)
