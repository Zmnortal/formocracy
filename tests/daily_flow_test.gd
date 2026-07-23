extends SceneTree


func _init() -> void:
	call_deferred("run")


func run() -> void:
	var state := root.get_node_or_null("WorkdayState")
	if state == null:
		state = load("res://scripts/workday_state.gd").new()
		state.name = "WorkdayState"
		root.add_child(state)
	state.reset_for_tests()
	var error: Error = change_scene_to_file("res://main.tscn")
	assert(error == OK, "main scene must open")
	await process_frame
	await process_frame
	assert(current_scene != null, "main scene must become current")
	for i in 3:
		var desk := current_scene
		desk.apply_stamp("批准" if i != 1 else "驳回", Vector2(350, 360))
		desk.submit_form()
		await create_timer(2.6).timeout
	assert(current_scene.name == "DailyReport", "third processed case must open daily report")
	assert(state.records.size() == 3, "daily report must retain all three records")
	assert(current_scene.stats_label.text.contains("批准 02"), "daily report must show decisions")
	print("FORMOCRACY_DAILY_FLOW_TEST_OK")
	quit(0)
