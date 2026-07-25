extends SceneTree


func _init() -> void:
	call_deferred("run")


func run() -> void:
	var state = root.get_node("WorkdayState")
	var sfx = root.get_node("Sfx")
	state.save_path = "user://formocracy-pre-work-sequence-test.json"
	state.start_new_game()
	state.player_name = "测试职员"
	var error := change_scene_to_file("res://scenes/pre_work_sequence.tscn")
	assert(error == OK, "daily pre-work sequence must load")
	await process_frame
	await process_frame
	var sequence = current_scene
	assert(sequence.phase == "newspaper_selection", "every workday must begin with a manual newspaper choice")
	assert(sequence.newspaper_selector.visible, "the newspaper choice must remain visible even when only one paper arrives")
	assert(not sequence.newspaper.visible, "the game must not open the only delivered paper automatically")
	assert(not sequence.dialogue_box.visible, "newspaper selection must wait for the player's explicit click")
	assert(sequence.available_newspapers.size() == 1, "day one must still deliver the official newspaper")
	sequence._choose_newspaper(sequence.available_newspapers[0])
	assert(sequence.phase == "newspaper", "clicking the delivered paper must open it for reading")
	assert(sequence.newspaper.visible, "the chosen newspaper must become visible")
	assert(sequence.headline_label.text.contains("恢复受理"), "day one must load its configured headline")
	assert(sequence.dialogue_box is DialogueBox, "the sequence must reuse the shared DialogueBox")
	var initial_line_id: int = sequence.dialogue_box.line_id
	await create_timer(0.25).timeout
	assert(sequence.phase == "newspaper", "the newspaper must never advance on a timer")
	assert(sequence.dialogue_box.line_id == initial_line_id, "waiting must not replace the current newspaper line")

	sequence.dialogue_box.reveal_current_line()
	assert(sequence.phase == "newspaper", "the first input must only reveal the current line")
	sequence.dialogue_box._handle_manual_advance()
	assert(sequence.phase == "departure_prompt", "finishing the newspaper must show the going-to-work prompt")
	assert(sequence.dialogue_box.dialogue_label.text.contains("该去上班了"), "the prompt must state that it is time to work")
	sequence.dialogue_box.reveal_current_line()
	sequence.dialogue_box._handle_manual_advance()
	assert(sequence.phase == "walking" and sequence.walk_index == 0, "confirming the prompt must enter the first walking beat")
	assert(sequence.frame_texture.texture.resource_path.ends_with("corridor_legs_01_step.png"), "walking must reuse the approved neutral leg artwork")
	assert(sfx.walk_player.playing, "walking beats must play footsteps")

	sequence.show_phase_for_tests("walking", 2)
	assert(not sfx.walk_player.playing, "the stopped walking beat must stop footsteps")
	sequence.show_phase_for_tests("arrival")
	assert(sequence.phase == "arrival", "the last walking beat must lead to the service hall entrance")
	assert(sfx.ambience_player.playing, "the service hall entrance must establish noisy crowd ambience")
	assert(
		is_equal_approx(sfx.ambience_player.volume_db, sfx.ARRIVAL_AMBIENCE_VOLUME_DB),
		"arrival ambience must begin louder than normal work ambience"
	)

	sequence.finish_for_tests()
	await process_frame
	await process_frame
	var main = current_scene
	assert(main != null and main.scene_file_path == "res://main.tscn", "confirming the door must enter the workbench")
	assert(main.manager.briefing.playing, "the existing internal broadcast must guide the player after arrival")
	if DisplayServer.get_name() == "headless":
		await process_frame
	else:
		await create_timer(1.3).timeout
	assert(
		is_equal_approx(sfx.ambience_player.volume_db, sfx.BROADCAST_AMBIENCE_VOLUME_DB),
		"crowd ambience must fade beneath the primary broadcast (actual: %.2f)"
		% sfx.ambience_player.volume_db
	)
	assert(main.manager.dialogue_box.visible, "the broadcast must still use the shared manual dialogue component")

	var home_source := FileAccess.get_file_as_string("res://scripts/scenes/home_12c_scene.gd")
	var evening_source := FileAccess.get_file_as_string("res://scripts/scenes/evening_map.gd")
	assert(home_source.contains("pre_work_sequence.tscn"), "resting at home must route through the next morning sequence")
	assert(evening_source.contains("pre_work_sequence.tscn"), "nightly completion must route through the next morning sequence")
	var opening_source := FileAccess.get_file_as_string("res://scripts/scenes/opening.gd")
	assert(not opening_source.contains("momo") and not opening_source.contains("墨墨"), "opening code must contain no cat assistant")

	main.manager.shutdown()
	state.start_new_game()
	state.save_path = state.DEFAULT_SAVE_PATH
	print("FORMOCRACY_PRE_WORK_SEQUENCE_TEST_OK")
	quit(0)
