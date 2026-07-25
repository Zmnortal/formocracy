extends SceneTree

const SELECTION_OUTPUT := "user://newspaper-morning-selection.png"
const READING_OUTPUT := "user://newspaper-full-reading.png"
const KIOSK_OUTPUT := "user://newspaper-kiosk.png"
const SHOP_OUTPUT := "user://newspaper-form-shop.png"
const MAP_OUTPUT := "user://newspaper-evening-map.png"


func _init() -> void:
	call_deferred("run")


func run() -> void:
	var state = root.get_node("WorkdayState")
	state.reset_for_tests()
	state.player_name = "张子奕"
	state.balance = 12
	state.day_number = 4
	for publisher_id in [
		"NEWSPAPER-DISTRICT-12-MORNING",
		"NEWSPAPER-ADMIN-GAZETTE",
		"NEWSPAPER-OLD-CITY-EVENING",
	]:
		state.newspaper_subscriptions[publisher_id] = {
			"publisher_id": publisher_id,
			"start_day": 2,
			"end_day": 8,
		}

	var error := change_scene_to_file("res://scenes/pre_work_sequence.tscn")
	assert(error == OK)
	await process_frame
	await process_frame
	await create_timer(0.55).timeout
	if DisplayServer.get_name() == "headless":
		print("FORMOCRACY_NEWSPAPER_SYSTEM_SNAPSHOT_OK (skipped on headless display)")
		quit(0)
		return
	await RenderingServer.frame_post_draw
	_save_frame(SELECTION_OUTPUT)

	var sequence = current_scene
	sequence._choose_newspaper(sequence.available_newspapers[2])
	sequence.dialogue_box.reveal_current_line()
	await process_frame
	await RenderingServer.frame_post_draw
	_save_frame(READING_OUTPUT)

	assert(state.manager.purchase_personal_form("PERSONAL-FORM-NEWSPAPER-S01"))
	error = change_scene_to_file("res://scenes/newspaper_kiosk.tscn")
	assert(error == OK)
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	_save_frame(KIOSK_OUTPUT)

	error = change_scene_to_file("res://scenes/form_shop.tscn")
	assert(error == OK)
	await process_frame
	await process_frame
	current_scene.dialogue_box.close()
	await RenderingServer.frame_post_draw
	_save_frame(SHOP_OUTPUT)

	error = change_scene_to_file("res://scenes/evening_map.tscn")
	assert(error == OK)
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	_save_frame(MAP_OUTPUT)

	print("FORMOCRACY_NEWSPAPER_SELECTION_SNAPSHOT=%s" % ProjectSettings.globalize_path(SELECTION_OUTPUT))
	print("FORMOCRACY_NEWSPAPER_READING_SNAPSHOT=%s" % ProjectSettings.globalize_path(READING_OUTPUT))
	print("FORMOCRACY_NEWSPAPER_KIOSK_SNAPSHOT=%s" % ProjectSettings.globalize_path(KIOSK_OUTPUT))
	print("FORMOCRACY_NEWSPAPER_SHOP_SNAPSHOT=%s" % ProjectSettings.globalize_path(SHOP_OUTPUT))
	print("FORMOCRACY_NEWSPAPER_MAP_SNAPSHOT=%s" % ProjectSettings.globalize_path(MAP_OUTPUT))
	quit(0)


func _save_frame(path: String) -> void:
	var image := root.get_viewport().get_texture().get_image()
	assert(not image.is_empty())
	assert(image.save_png(path) == OK)
