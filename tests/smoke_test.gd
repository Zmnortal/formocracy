extends SceneTree


func _init() -> void:
	call_deferred("run")


func run() -> void:
	var packed: PackedScene = load("res://main.tscn")
	assert(packed != null, "main scene must load")
	var main := packed.instantiate()
	root.add_child(main)
	await process_frame
	assert(main.form != null, "a form must be created")
	assert(main.case_index == 0, "first case must be active")
	assert(main.form_stamped == false, "new form must be unstamped")

	main.apply_stamp("批准", Vector2(360, 365))
	assert(main.form_stamped == true, "stamp state must be recorded")
	assert(main.form_stamp_type == "批准", "stamp type must be recorded")
	assert(main.stamp_mark.text.contains("批准"), "stamp must be visible on form")

	main.submit_form()
	await create_timer(1.2).timeout
	assert(main.case_index == 1, "accepted form must advance to next case")
	assert(main.form_stamped == false, "next case must reset stamp state")
	assert(main.form != null, "next form must be created")

	print("FORMOCRACY_SMOKE_TEST_OK")
	quit(0)
