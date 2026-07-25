extends SceneTree


func _init() -> void:
	call_deferred("run")


func run() -> void:
	var state = root.get_node("WorkdayState")
	var bridge = root.get_node("RealityBridge")
	bridge.last_emitted_event.clear()
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
	assert(opening.theme.resource_path == "res://themes/pixel_theme.tres", "opening must apply the pixel theme to the entire scene")
	assert(opening.opening_pixel_font.base_font.antialiasing == TextServer.FONT_ANTIALIASING_NONE, "opening Chinese pixel font must disable antialiasing")
	assert(opening.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, "opening must preserve hard pixel glyph edges while scaling")
	assert(opening.name_input.get_theme_font("font").resource_path.ends_with("unifont_ui.tres"), "opening form must use Unifont explicitly")
	assert(opening.confirm_button.get_theme_font("font").resource_path.ends_with("unifont_ui.tres"), "opening submit action must inherit Unifont")
	assert(opening.paper_replace_handle.get_script().resource_path == "res://scripts/ui/paper_replace_handle.gd", "opening must replace the resign button with a diegetic paper-corner handle")
	assert(not (opening.paper_replace_handle is Button), "the paper replacement affordance must not use a conventional button")
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
	await opening.replace_entire_form()
	assert(opening.name_input.text.is_empty(), "replacing the paper must clear the applicant name")
	assert(opening.entered_date().is_empty(), "replacing the paper must clear the entire date")
	assert(not opening.signature_pad.has_signature(), "replacing the paper must clear all signature strokes")
	assert(not opening.confirmation.button_pressed, "replacing the paper must clear the handwritten declaration")
	assert(not opening.confirm_button.visible, "a fresh blank paper must not be submittable")
	assert(opening.form_stage.position == Vector2.ZERO and opening.form_stage.rotation_degrees == 0.0, "the fresh paper must settle squarely into the form position")
	opening.name_input.text = "测试职员"
	opening.year_input.text = str(today.year)
	opening.month_input.text = str(today.month)
	opening.day_input.text = str(today.day)
	opening.confirmation.button_pressed = true
	var replacement_signature := PackedVector2Array()
	for i in 20:
		replacement_signature.append(Vector2(i * 4, 24))
	opening.signature_pad.strokes.clear()
	opening.signature_pad.strokes.append(replacement_signature)
	opening.refresh_form_validity()
	assert(opening.confirm_button.visible, "the replacement paper must remain fully interactive")
	opening.set_form_interaction(false)
	assert(opening.name_input.editable, "locking submission must not switch inputs to the recolored read-only style")
	assert(opening.name_input.mouse_filter == Control.MOUSE_FILTER_IGNORE, "locked inputs must stop pointer interaction without changing appearance")
	opening.set_form_interaction(true)
	await opening.submit_form()
	assert(opening.submission_snap_count == opening.APPROACH_FRAME_COUNT + opening.INGEST_FRAME_COUNT, "form ingestion must advance at exactly four held frames per second")
	assert(opening.form_stage.rotation_degrees == 0.0, "perspective must not use left or right rotation")
	assert(opening.projected_form.uv[2] == Vector2(opening.FORM_CAPTURE_RECT.size), "submission projection must capture only the paper bounds instead of the black full-screen stage")
	var top_width: float = opening.projected_form.polygon[0].distance_to(opening.projected_form.polygon[1])
	var bottom_width: float = opening.projected_form.polygon[3].distance_to(opening.projected_form.polygon[2])
	assert(top_width < bottom_width, "forward tilt must be rendered as a perspective trapezoid")
	var mouth_bottom: float = opening.machine_foreground.position.y + opening.machine_foreground.size.y
	assert(opening.FORM_APPROACH_TOP_Y >= opening.machine_foreground.position.y, "the paper far edge must not remain visible above the machine-mouth occluder")
	assert(opening.FORM_APPROACH_BOTTOM_Y > mouth_bottom, "the paper near edge must remain visible on the conveyor before ingestion")
	assert(opening.projected_form.polygon[2].y <= mouth_bottom, "the final paper quad must finish completely behind the machine mouth")
	await process_frame
	await process_frame
	assert(state.player_name == "测试职员", "submitting the form must establish the global player identity")
	assert(not state.player_signature.is_empty(), "submitting the form must persist handwritten signature strokes")
	var checkpoints: Array[Dictionary] = state.save_system.get_checkpoint_nodes()
	assert(checkpoints.size() == 1 and int(checkpoints[0].completed_day) == 0, "opening completion must create the immutable beginning checkpoint")
	assert(
		current_scene != null and current_scene.scene_file_path == "res://scenes/pre_work_sequence.tscn",
		"machine ingestion must enter the daily home-newspaper sequence"
	)
	var pre_work = current_scene
	assert(pre_work.phase == "newspaper_selection", "the first workday must require a manual newspaper choice")
	assert(pre_work.newspaper_selector.visible, "the only delivered newspaper must still be presented as a choice")
	assert(not pre_work.newspaper.visible, "the first newspaper must not open automatically")
	assert(pre_work.dialogue_box is DialogueBox, "the daily pre-work sequence must reuse the shared DialogueBox")
	pre_work._choose_newspaper(pre_work.available_newspapers[0])
	assert(pre_work.headline_label.text.contains("恢复受理"), "day one must load its configured newspaper headline")
	assert(not bridge.last_emitted_event.has("speakerId") or bridge.last_emitted_event.get("speakerId") != "MOMO", "the removed cat assistant must emit no event")
	state.start_new_game()
	state.save_path = state.DEFAULT_SAVE_PATH
	print("FORMOCRACY_OPENING_TEST_OK")
	quit(0)
