extends SceneTree

# 核心玩法测试。
# 验证主工作台场景构建、文件袋拆封、材料装袋、盖章与提交记录。


func _init() -> void:
	call_deferred("run")


# 运行核心玩法完整测试流程。
func run() -> void:
	var state = root.get_node("WorkdayState")
	state.reset_for_tests()
	var packed: PackedScene = load("res://main.tscn")
	var desk = packed.instantiate()
	root.add_child(desk)
	await process_frame
	desk.start_first_case_for_tests()
	await process_frame
	assert(desk.get_node("ClerkDeskConcept").texture.resource_path == "res://assets/office/background/service_hall_light.png", "gameplay must use the configured service-hall background plate")
	assert(desk.get_node("ClerkDeskConcept").stretch_mode == TextureRect.STRETCH_SCALE, "background must fill the canvas without cropping its right or bottom edge")
	assert(desk.get_node("ClerkDeskConcept").size == Vector2(1280, 720), "background control must retain the full design-canvas size after entering the tree")
	assert(desk.has_node("FilingCabinet") and desk.has_node("NumberMachine") and desk.has_node("WallCalendar"), "office props must remain independent scene nodes")
	assert(desk.has_node("ServiceRailingForeground") and desk.has_node("WorktableForeground"), "railing and worktable must be independent foreground layers")
	assert(desk.get_node("ServiceRailingForeground").z_index > desk.npc_performance.actor_layer.z_index, "NPC must render behind the service railing")
	assert(desk.desk.npc_panel.z_index >= 0 and desk.presenter.envelope.z_index > desk.get_node("ClerkDeskConcept").z_index, "interactive queue and envelope must render over the background")
	assert(not desk.presenter.envelope_opened, "delivered envelope must start sealed")
	desk.presenter.set_envelope_on_desk(true)
	desk.presenter.open_envelope()
	assert(desk.presenter.thumbnail_tray.visible, "opening must reveal the documents as envelope thumbnails")
	assert(
		desk.presenter.all_document_views.all(func(document): return not document.visible),
		"opening the envelope must not spread every document automatically"
	)
	desk.presenter.open_document(desk.presenter.primary_document_id)
	var supporting_document = desk.presenter.document_panels[0]
	desk.presenter.open_document(String(supporting_document.get_meta("document_id")))
	assert(
		desk.presenter.form.visible and supporting_document.visible,
		"thumbnail selection must allow multiple documents to stay expanded"
	)
	desk.presenter.bring_document_to_front(desk.presenter.primary_document_id)
	assert(
		desk.presenter.form.z_index > supporting_document.z_index,
		"selecting a document must bring it above overlapping documents"
	)
	assert(desk.presenter.envelope.visible, "opened envelope must remain visible as the repacking target")
	assert(desk.presenter.envelope_flap.text.contains("逐份展开"), "opened envelope must explain the thumbnail workflow")
	desk.presenter.apply_stamp("批准", Vector2(350, 360))
	assert(
		desk.presenter.form.stamp_records.size() == 1,
		"the primary document must retain its own stamp records"
	)
	desk.presenter.pack_all_documents()
	assert(desk.presenter.packed_document_ids.size() == desk.current_case.documents.size(), "all materials must return to the original envelope")
	desk.input_mgr._set_machine_preview(desk.presenter, true)
	await create_timer(0.16).timeout
	assert(desk.presenter.envelope.scale.y < 0.7, "machine hover must tilt the envelope with pseudo-3D compression")
	assert(desk.desk.slot_light.color == Color("d7aa45"), "machine hover must show an amber lock indicator")
	desk.submission_mgr.submit(desk.presenter, desk.current_case)
	assert(state.records.is_empty(), "case result must wait until the machine has swallowed the envelope")
	assert(desk.submission_mgr.submission_in_progress, "machine ingestion must lock duplicate submissions")
	await create_timer(0.9).timeout
	assert(state.records.size() == 1, "validation submission must create an immutable processing record")
	assert(state.records[0].procedure_errors.is_empty(), "complete operation must not record a procedural error")

	var incomplete_case: Dictionary = root.get_node("ConfigDatabase").get_gameplay_case("CASE-002")
	state.record_case_result(incomplete_case, "", ["漏盖章", "遗漏材料"], 12.0, [])
	assert(state.records[1].procedure_errors.size() == 2, "incomplete operation must still submit and record errors")
	assert(not state.records[1].correct, "procedural errors must make the handling result incorrect")
	var settlement: Dictionary = state.get_settlement()
	assert(settlement.has("performance") and settlement.has("fines") and settlement.has("living_expenses"), "daily settlement must include performance, fines, and living expenses")
	var delayed_case: Dictionary = root.get_node("ConfigDatabase").get_gameplay_case("CASE-003")
	state.record_case_result(delayed_case, "批准", [], 8.0, delayed_case.document_ids)
	assert(state.delayed_consequences.size() == 1, "configured sensitive mistakes must reserve delayed accountability")
	var bridge := root.get_node("RealityBridge")
	bridge.last_emitted_event.clear()
	state.begin_next_day()
	assert(bridge.last_emitted_event.type == "consequence", "a penalized workday must send its consequence to the glasses")
	assert(bridge.last_emitted_event.body.contains("行政罚款"), "glasses consequence must include the administrative fine")
	var before_tick: float = state.seconds_remaining
	state.tick(1.5)
	assert(state.seconds_remaining < before_tick, "workday countdown must advance with elapsed work time")
	print("FORMOCRACY_CORE_GAMEPLAY_TEST_OK")
	quit(0)
