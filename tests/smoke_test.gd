extends SceneTree

# 冒烟测试。
# 验证主场景能加载、生成表单、盖章、提交并推进到下一个案件。


func _init() -> void:
	call_deferred("run")


# 运行冒烟测试流程。
func run() -> void:
	# 场景实例公开属性在独立测试脚本启动时属于动态边界。
	@warning_ignore_start("unsafe_method_access")
	@warning_ignore_start("unsafe_property_access")
	@warning_ignore_start("unsafe_cast")
	var state := root.get_node_or_null("WorkdayState") as WorkdayContext
	if state == null:
		var state_script := load("res://scripts/autoload/workday_state.gd") as GDScript
		@warning_ignore("unsafe_cast")
		state = state_script.new() as WorkdayContext
		state.name = "WorkdayState"
		root.add_child(state)
	state.call("reset_for_tests")
	var packed := load("res://main.tscn") as PackedScene
	assert(packed != null, "main scene must load")
	var main := packed.instantiate() as Node2D
	root.add_child(main)
	await process_frame
	var manager: Variant = main.get("manager")
	manager.start_first_case_for_tests()
	await process_frame
	var presenter: Variant = manager.presenter
	assert(presenter.form != null, "a form must be created")
	assert(not is_instance_valid(manager.desk.applicant_card_label), "applicant data must not be duplicated in an out-of-world information panel")
	assert(main.get_node_or_null("ApplicantCard") == null, "the black applicant information panel must be removed")
	assert(main.get_node_or_null("NpcWindow") == null, "the black visitor information panel must be removed")
	assert(main.get_node_or_null("InstitutionalWallClock") != null, "the visitor panel space must contain an institutional wall clock")
	assert(main.get_node_or_null("ClerkToolCabinet") != null, "the applicant panel space must contain a clerk tool cabinet")
	assert(main.get_node("WallCalendar").size == Vector2(220, 146), "the interactive calendar must use the enlarged in-world size")
	assert(main.get_node_or_null("WorkCalendarOverlay") != null, "the workbench must expose the interactive calendar reader")
	assert(main.get_node_or_null("NumberMachine") == null, "the retired reputation counter must be absent from the desk")
	assert(not main.get_node("WorkbenchHintPanel").visible, "the obsolete bottom hint panel must stay hidden")
	assert(not main.get_node("ClerkStatusLabel").visible, "the obsolete top-left clerk status must stay hidden")
	assert(not main.get_node("NeedStatusLabel").visible, "the obsolete top-left need status must stay hidden")
	assert(not main.get_node("RemainingTimeLabel").visible, "the obsolete top-right remaining-time label must stay hidden")
	assert(manager.desk.slot.visible, "the bottom-right archive tray must remain visible")
	assert(not manager.desk.slot.get_node("ArchiveTitleLabel").visible, "only the obsolete archive title text must stay hidden")
	assert(manager.desk.archive_drop_zone == manager.desk.slot, "sealed envelopes must still be submitted to the archive tray")
	var background := main.get_node("ClerkDeskConcept") as TextureRect
	assert(background.texture != null, "workbench concept must be loaded")
	assert(background.stretch_mode == TextureRect.STRETCH_SCALE, "background must fill the design canvas")
	assert(background.size == Vector2(1280, 720), "background control must retain design-canvas size")
	assert(manager.case_index == 0, "first case must be active")
	assert(presenter.is_stamped() == false, "new form must be unstamped")
	presenter.set_envelope_on_desk(true)
	presenter.expand_envelope_billboard()
	await create_timer(0.3).timeout
	presenter.open_envelope()
	presenter.open_document(presenter.primary_document_id)
	assert(presenter.form.get_meta("context_cursor") == CursorManager.Cursor.GRAB, "form must advertise contextual grab interaction")
	for tool: Panel in manager.stamp.stamp_tools:
		assert(tool.size == Vector2(32, 40), "stamp hit areas must match their configured visible size")

	presenter.apply_stamp("批准", Vector2(360, 365))
	assert(presenter.is_stamped() == true, "stamp state must be recorded")
	assert(presenter.stamp_type() == "批准", "stamp type must be recorded")
	assert(presenter.form.stamp_records.size() == 1, "stamp must remain attached to the form")
	presenter.pack_all_documents()
	await create_timer(0.3).timeout

	manager.npc_performance.skip_requested = true
	manager.submission.submit(presenter, manager.current_case)
	await create_timer(0.9).timeout
	assert(state.archived_cases.size() == 1, "completed case must enter the archive backlog")
	assert(WorkdayContext.read_string(state.archived_cases[0], "status") == "ARCHIVED", "daytime archiving must not grant reality effect")
	assert(manager.desk.archive_stack.get_child_count() == 1, "archived envelope must remain visibly stacked in the tray")
	assert(manager.desk.archive_count_label.text == "×1", "archive tray must display its persistent envelope count")
	await create_timer(3.1).timeout
	assert(manager.call_bell.available, "next case must wait for the player to ring the call bell")
	manager.call_bell.trigger(true)
	await process_frame
	assert(manager.dialogue_box.visible, "ringing the call bell must show the foreground confirmation dialogue")
	manager.dialogue_box.reveal_current_line()
	manager.dialogue_box._handle_manual_advance()
	await process_frame
	assert(manager.case_index == 1, "accepted form must advance to next case")
	assert(presenter.is_stamped() == false, "next case must reset stamp state")
	assert(presenter.form != null, "next form must be created")

	@warning_ignore_restore("unsafe_cast")
	@warning_ignore_restore("unsafe_property_access")
	@warning_ignore_restore("unsafe_method_access")
	print("FORMOCRACY_SMOKE_TEST_OK")
	quit(0)
