extends SceneTree


func _init() -> void:
	call_deferred("run")


func run() -> void:
	var state = root.get_node("WorkdayState")
	state.save_path = "user://formocracy-opening-playtest.json"
	state.start_new_game()
	var open_error := change_scene_to_file("res://scenes/opening.tscn")
	assert(open_error == OK, "opening scene must load for the full playtest")
	await process_frame
	await process_frame
	var opening = current_scene
	await process_frame
	assert(opening.form_stage != null, "opening must begin with an interactive reinstatement form")
	assert(opening.machine.modulate.a == 0.0, "validation machine must remain hidden before submission")
	assert(opening.name_input.get_theme_font("font").resource_path.contains("ark-pixel"), "opening form must use Ark Pixel explicitly")
	assert(not opening.confirm_button.visible, "submission must remain hidden until the form is complete")
	var today := Time.get_date_dict_from_system()
	opening.name_input.text = "测试职员"
	opening.year_input.text = str(today.year)
	opening.month_input.text = str(today.month)
	opening.day_input.text = str(today.day)
	var check_down := InputEventMouseButton.new()
	check_down.button_index = MOUSE_BUTTON_LEFT
	check_down.pressed = true
	check_down.position = Vector2(22, 26)
	opening.confirmation._gui_input(check_down)
	for check_point in [Vector2(25, 31), Vector2(29, 37), Vector2(34, 32), Vector2(42, 21), Vector2(54, 8), Vector2(78, -3)]:
		var check_move := InputEventMouseMotion.new()
		check_move.position = check_point
		opening.confirmation._gui_input(check_move)
	var check_up := InputEventMouseButton.new()
	check_up.button_index = MOUSE_BUTTON_LEFT
	check_up.pressed = false
	check_up.position = Vector2(78, -3)
	opening.confirmation._gui_input(check_up)
	assert(opening.confirmation.points[-1].x > opening.confirmation.size.x, "handwritten check must preserve strokes beyond the printed box")
	var pen_down := InputEventMouseButton.new()
	pen_down.button_index = MOUSE_BUTTON_LEFT
	pen_down.pressed = true
	pen_down.position = Vector2(8, 52)
	opening.signature_pad._gui_input(pen_down)
	for i in 24:
		var pen_move := InputEventMouseMotion.new()
		pen_move.position = Vector2(12 + i * 12, 42 + sin(i * 0.9) * 24)
		opening.signature_pad._gui_input(pen_move)
	var pen_up := InputEventMouseButton.new()
	pen_up.button_index = MOUSE_BUTTON_LEFT
	pen_up.pressed = false
	pen_up.position = Vector2(300, 52)
	opening.signature_pad._gui_input(pen_up)
	opening.refresh_form_validity()
	assert(opening.confirm_button.visible, "valid name, current date, signature and declaration must reveal submission")
	assert(opening.entered_date() == opening.current_date(), "opening must require the current system date")
	opening.set_form_interaction(false)
	assert(opening.name_input.editable, "locking submission must not switch inputs to the recolored read-only style")
	assert(opening.name_input.mouse_filter == Control.MOUSE_FILTER_IGNORE, "locked inputs must stop pointer interaction without changing appearance")
	opening.set_form_interaction(true)
	await opening.submit_form()
	assert(opening.submission_snap_count == opening.APPROACH_FRAME_COUNT + opening.INGEST_FRAME_COUNT, "form ingestion must advance at exactly four held frames per second")
	assert(opening.form_stage.rotation_degrees == 0.0, "perspective must not use left or right rotation")
	var top_width: float = opening.projected_form.polygon[0].distance_to(opening.projected_form.polygon[1])
	var bottom_width: float = opening.projected_form.polygon[3].distance_to(opening.projected_form.polygon[2])
	assert(top_width < bottom_width, "forward tilt must be rendered as a perspective trapezoid")
	assert(opening.welcome_panel.visible, "submission must end on the welcome screen")
	assert(current_scene == opening, "the game must not start before the player confirms they passed")
	opening.complete_reinstatement()
	await create_timer(0.5).timeout
	await process_frame
	assert(state.player_name == "测试职员", "submitting the form must establish the global player identity")
	assert(not state.player_signature.is_empty(), "submitting the form must persist handwritten signature strokes")
	assert(current_scene != null and current_scene.scene_file_path == "res://main.tscn", "machine ingestion must finish by entering the first workday")
	state.start_new_game()
	state.save_path = state.DEFAULT_SAVE_PATH
	print("FORMOCRACY_OPENING_TEST_OK")
	quit(0)
