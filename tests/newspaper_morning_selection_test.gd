extends SceneTree


func _init() -> void:
	call_deferred("run")


func run() -> void:
	var state = root.get_node("WorkdayState")
	state.reset_for_tests()
	state.player_name = "测试职员"
	state.day_number = 2
	state.newspaper_subscriptions["NEWSPAPER-DISTRICT-12-MORNING"] = {
		"publisher_id": "NEWSPAPER-DISTRICT-12-MORNING",
		"start_day": 2,
		"end_day": 4,
	}
	state.newspaper_subscriptions["NEWSPAPER-ADMIN-GAZETTE"] = {
		"publisher_id": "NEWSPAPER-ADMIN-GAZETTE",
		"start_day": 2,
		"end_day": 8,
	}

	var error := change_scene_to_file("res://scenes/pre_work_sequence.tscn")
	assert(error == OK, "morning newspaper selection must load")
	await process_frame
	await process_frame
	var sequence = current_scene
	assert(sequence.phase == "newspaper_selection", "multiple deliveries must begin at the headline shelf")
	assert(sequence.available_newspapers.size() == 3, "official plus two active subscriptions must be visible")
	assert(sequence.newspaper_selector.visible, "headline selection layer must be visible")
	assert(not sequence.dialogue_box.visible, "selection must wait for a paper click rather than dialogue autoplay")

	var chosen: Dictionary = sequence.available_newspapers[1]
	var chosen_id := String(chosen.get("id", ""))
	sequence._choose_newspaper(chosen)
	assert(sequence.phase == "newspaper", "choosing a headline must open the full paper")
	assert(sequence.newspaper.visible and not sequence.newspaper_selector.visible, "full paper must replace the headline shelf")
	assert(sequence.edition_label.text.contains(String(chosen.get("name", ""))), "full paper must use the selected masthead")
	assert(state.manager.get_read_newspaper().is_empty(), "choice is recorded only after the player finishes the article")

	sequence.dialogue_box.reveal_current_line()
	sequence.dialogue_box._handle_manual_advance()
	assert(sequence.phase == "departure_prompt", "finishing the article must show the going-to-work prompt")
	assert(sequence.dialogue_box.dialogue_label.text.contains("该去上班了"), "departure prompt must use the confirmed line")
	assert(state.manager.get_read_newspaper() == chosen_id, "finishing must lock the selected paper for the day")
	assert(not state.manager.mark_newspaper_read("NEWSPAPER-HENGCHUAN-DAILY"), "the player must not read a second full paper")

	sequence.dialogue_box.reveal_current_line()
	sequence.dialogue_box._handle_manual_advance()
	assert(sequence.phase == "walking" and sequence.walk_index == 0, "manual confirmation must enter the existing walking cutscene")

	print("FORMOCRACY_NEWSPAPER_MORNING_SELECTION_TEST_OK")
	quit(0)
