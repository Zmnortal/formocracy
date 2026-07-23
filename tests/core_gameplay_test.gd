extends SceneTree


func _init() -> void:
	call_deferred("run")


func run() -> void:
	var state = root.get_node("WorkdayState")
	state.reset_for_tests()
	var packed: PackedScene = load("res://main.tscn")
	var desk = packed.instantiate()
	root.add_child(desk)
	await process_frame
	assert(desk.get_node("ClerkDeskConcept").texture.resource_path == "res://assets/opening/opening-03-day-one-reveal-8bit-v1.png", "gameplay background must be the configured final opening slide")
	assert(desk.get_node("ClerkDeskConcept").stretch_mode == TextureRect.STRETCH_KEEP_ASPECT_COVERED, "background must use aspect-preserving cover")
	assert(desk.npc_panel.z_index >= 0 and desk.envelope.z_index > desk.get_node("ClerkDeskConcept").z_index, "interactive queue and envelope must render over the background")
	assert(not desk.envelope_opened, "delivered envelope must start sealed")
	desk.envelope_on_desk = true
	desk.open_envelope()
	assert(desk.gameplay_state == "REVIEWING", "interaction state must advance when the envelope is opened")
	assert(desk.form.visible and desk.document_panels.size() >= 1, "opening must reveal one primary form and supporting documents")
	desk.apply_stamp("批准", Vector2(350, 360))
	desk.pack_all_documents()
	assert(desk.packed_document_ids.size() == desk.current_case.documents.size(), "all materials must return to the original envelope")
	assert(desk.gameplay_state == "READY_FOR_VALIDATION", "repacking must make the envelope ready for validation")
	desk.submit_form()
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
	var before_tick: float = state.seconds_remaining
	state.tick(1.5)
	assert(state.seconds_remaining < before_tick, "workday countdown must advance with elapsed work time")
	print("FORMOCRACY_CORE_GAMEPLAY_TEST_OK")
	quit(0)
