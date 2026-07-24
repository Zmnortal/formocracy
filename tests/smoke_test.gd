extends SceneTree

# 冒烟测试。
# 验证主场景能加载、生成表单、盖章、提交并推进到下一个案件。


func _init() -> void:
	call_deferred("run")


# 运行冒烟测试流程。
func run() -> void:
	var state := root.get_node_or_null("WorkdayState")
	if state == null:
		state = load("res://scripts/autoload/workday_state.gd").new()
		state.name = "WorkdayState"
		root.add_child(state)
	state.reset_for_tests()
	var packed: PackedScene = load("res://main.tscn")
	assert(packed != null, "main scene must load")
	var main := packed.instantiate()
	root.add_child(main)
	await process_frame
	main.start_first_case_for_tests()
	await process_frame
	assert(main.presenter.form != null, "a form must be created")
	assert(not main.desk.applicant_card_label.text.is_empty(), "applicant card must be populated")
	assert(main.get_node("ClerkDeskConcept").texture != null, "workbench concept must be loaded")
	assert(main.get_node("ClerkDeskConcept").stretch_mode == TextureRect.STRETCH_SCALE, "background must fill the design canvas")
	assert(main.get_node("ClerkDeskConcept").size == Vector2(1280, 720), "background control must retain design-canvas size")
	assert(main.case_index == 0, "first case must be active")
	assert(main.presenter.is_stamped() == false, "new form must be unstamped")
	assert(main.presenter.form.mouse_default_cursor_shape == Control.CURSOR_MOVE, "form must advertise drag interaction")
	assert(main.stamp_mgr.stamp_tools.all(func(tool): return tool.size == Vector2(140, 132)), "stamp hit areas must match their visible textures")

	main.presenter.apply_stamp("批准", Vector2(360, 365))
	assert(main.presenter.is_stamped() == true, "stamp state must be recorded")
	assert(main.presenter.stamp_type() == "批准", "stamp type must be recorded")
	assert(main.presenter.stamp_mark.text.contains("批准"), "stamp must be visible on form")

	main.npc_performance.skip_requested = true
	main.submission_mgr.submit(main.presenter, main.current_case)
	await create_timer(0.9).timeout
	assert(main.desk.validation_overlay.visible, "validation concept transition must appear")
	await create_timer(3.1).timeout
	assert(main.call_bell.available, "next case must wait for the player to ring the call bell")
	main.call_bell.trigger(true)
	await process_frame
	assert(main.case_index == 1, "accepted form must advance to next case")
	assert(main.presenter.is_stamped() == false, "next case must reset stamp state")
	assert(main.presenter.form != null, "next form must be created")

	print("FORMOCRACY_SMOKE_TEST_OK")
	quit(0)
