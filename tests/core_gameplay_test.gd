extends SceneTree

# 核心玩法测试。
# 验证主工作台场景构建、文件袋拆封、材料装袋、盖章与提交记录。


func _init() -> void:
	call_deferred("run")


# 运行核心玩法完整测试流程。
func run() -> void:
	# 场景脚本属性在独立 `--script` 启动时属于动态边界；
	# 仅在本测试流程内豁免动态访问，业务数据仍通过 WorkdayContext 收口。
	@warning_ignore_start("unsafe_method_access")
	@warning_ignore_start("unsafe_property_access")
	@warning_ignore_start("unsafe_cast")
	var state := root.get_node("WorkdayState") as WorkdayContext
	state.call("reset_for_tests")
	var packed := load("res://main.tscn") as PackedScene
	var desk := packed.instantiate() as Node2D
	root.add_child(desk)
	await process_frame
	var manager: Variant = desk.get("manager")
	manager.start_first_case_for_tests()
	await process_frame
	var background := desk.get_node("ClerkDeskConcept") as TextureRect
	assert(background.texture.resource_path == "res://assets/office/background/service_hall_light.png", "gameplay must use the configured service-hall background plate")
	assert(background.stretch_mode == TextureRect.STRETCH_SCALE, "background must fill the canvas without cropping its right or bottom edge")
	assert(background.size == DeskGeometry.design_size(), "background control must retain the full design-canvas size after entering the tree")
	assert(
		(
			DeskGeometry.DESIGN_WIDTH == WorkdayContext.to_float(ProjectSettings.get_setting("display/window/size/viewport_width"))
			and DeskGeometry.DESIGN_HEIGHT == WorkdayContext.to_float(ProjectSettings.get_setting("display/window/size/viewport_height"))
		),
		"DeskGeometry design size must match the project viewport configuration"
	)
	assert(DeskGeometry.BOUNDS_FLOOR == DeskGeometry.DESIGN_HEIGHT, "DeskBounds floor must stay attached to the game canvas bottom edge")
	assert(desk.has_node("FilingCabinet") and desk.has_node("NumberMachine") and desk.has_node("WallCalendar"), "office props must remain independent scene nodes")
	assert(desk.has_node("ServiceRailingForeground") and desk.has_node("WorktableForeground"), "railing and worktable must be independent foreground layers")
	var worktable := desk.get_node("WorktableForeground") as TextureRect
	var desk_bounds := desk.get_node("DeskBounds") as Control
	assert(worktable.position == Vector2(DeskGeometry.visual_left(), DeskGeometry.TOP), "negative desk inset must expand the visual draw bounds")
	assert(worktable.size == DeskGeometry.visual_size(), "worktable draw width must include negative-inset expansion")
	assert(desk_bounds.position == Vector2(DeskGeometry.BOUNDS_LEFT, DeskGeometry.BOUNDS_TOP), "DeskBounds must use independent interaction coordinates")
	assert(desk_bounds.size == DeskGeometry.bounds_size(), "DeskBounds size must not follow the visual texture expansion")
	assert(desk_bounds.position != worktable.position and desk_bounds.size != worktable.size, "DeskBounds and the table image must remain independent")
	assert(DeskGeometry.left_at(0.0) == DeskGeometry.LEFT + DeskGeometry.TOP_INSET, "negative top inset must move the top-left edge outward")
	assert(DeskGeometry.right_at(0.0) == DeskGeometry.RIGHT - DeskGeometry.TOP_INSET, "negative top inset must move the top-right edge outward")
	var worktable_material := worktable.material as ShaderMaterial
	assert(is_zero_approx(WorkdayContext.to_float(worktable_material.get_shader_parameter("top_inset"))), "the widest desk edge must touch the expanded draw bounds")
	assert(WorkdayContext.to_float(worktable_material.get_shader_parameter("bottom_inset")) > 0.0, "the narrower edge must retain an inset inside the expanded bounds")
	var service_railing := desk.get_node("ServiceRailingForeground") as CanvasItem
	assert(service_railing.z_index > manager.npc_performance.actor_layer.z_index, "NPC must render behind the service railing")
	assert(manager.desk.npc_panel.z_index >= 0 and manager.presenter.envelope.z_index > background.z_index, "interactive queue and envelope must render over the background")
	var presenter: Variant = manager.presenter
	assert(not presenter.envelope_opened, "delivered envelope must start sealed")
	presenter.set_envelope_on_desk(true)
	presenter.open_envelope()
	assert(presenter.thumbnail_tray.visible, "opening must reveal the documents as envelope thumbnails")
	for document: DocumentView in presenter.all_document_views:
		assert(not document.visible, "opening the envelope must not spread every document automatically")
	presenter.open_document(presenter.primary_document_id)
	var supporting_document := presenter.document_panels[0] as DocumentView
	presenter.open_document(WorkdayContext.stringify_value(supporting_document.get_meta("document_id")))
	assert(presenter.form.visible and supporting_document.visible, "thumbnail selection must allow multiple documents to stay expanded")
	presenter.bring_document_to_front(presenter.primary_document_id)
	assert(presenter.form.z_index > supporting_document.z_index, "selecting a document must bring it above overlapping documents")
	assert(presenter.envelope.visible, "opened envelope must remain visible as the repacking target")
	assert(presenter.envelope_flap.text.contains("逐份展开"), "opened envelope must explain the thumbnail workflow")
	presenter.apply_stamp("批准", Vector2(350, 360))
	assert(presenter.form.stamp_records.size() == 1, "the primary document must retain its own stamp records")
	presenter.pack_all_documents()
	var current_case := manager.current_case as Dictionary
	assert(presenter.packed_document_ids.size() == WorkdayContext.read_array(current_case, "documents").size(), "all materials must return to the original envelope")
	manager.input._set_machine_preview(presenter, true)
	await create_timer(0.16).timeout
	assert(presenter.envelope.scale.y < 0.7, "machine hover must tilt the envelope with pseudo-3D compression")
	assert(manager.desk.slot_light.color == Color("d7aa45"), "machine hover must show an amber lock indicator")
	manager.submission.submit(presenter, manager.current_case)
	assert(state.records.is_empty(), "case result must wait until the machine has swallowed the envelope")
	assert(manager.submission.submission_in_progress, "machine ingestion must lock duplicate submissions")
	await create_timer(0.9).timeout
	assert(state.records.size() == 1, "validation submission must create an immutable processing record")
	assert(WorkdayContext.read_array(state.records[0], "procedure_errors").is_empty(), "complete operation must not record a procedural error")

	var database := root.get_node("ConfigDatabase")
	var incomplete_case: Dictionary = database.call("get_gameplay_case", "CASE-002")
	var workday_manager: Variant = state.get("manager")
	workday_manager.record_case_result(incomplete_case, "", ["漏盖章", "遗漏材料"], 12.0, [])
	assert(WorkdayContext.read_array(state.records[1], "procedure_errors").size() == 2, "incomplete operation must still submit and record errors")
	assert(not WorkdayContext.read_bool(state.records[1], "correct"), "procedural errors must make the handling result incorrect")
	var settlement: Dictionary = workday_manager.get_settlement()
	assert(settlement.has("performance") and settlement.has("fines") and settlement.has("living_expenses"), "daily settlement must include performance, fines, and living expenses")
	var delayed_case: Dictionary = database.call("get_gameplay_case", "CASE-003")
	workday_manager.record_case_result(delayed_case, "批准", [], 8.0, WorkdayContext.read_array(delayed_case, "document_ids"))
	assert(state.delayed_consequences.size() == 1, "configured sensitive mistakes must reserve delayed accountability")
	var bridge := root.get_node("RealityBridge")
	@warning_ignore("unsafe_cast")
	var last_emitted_event := bridge.get("last_emitted_event") as Dictionary
	last_emitted_event.clear()
	workday_manager.begin_next_day()
	@warning_ignore("unsafe_cast")
	last_emitted_event = bridge.get("last_emitted_event") as Dictionary
	assert(WorkdayContext.read_string(last_emitted_event, "type") == "consequence", "a penalized workday must send its consequence to the glasses")
	assert(WorkdayContext.read_string(last_emitted_event, "body").contains("行政罚款"), "glasses consequence must include the administrative fine")
	var before_tick: float = state.seconds_remaining
	workday_manager.tick(1.5)
	assert(state.seconds_remaining < before_tick, "workday countdown must advance with elapsed work time")
	@warning_ignore_restore("unsafe_cast")
	@warning_ignore_restore("unsafe_property_access")
	@warning_ignore_restore("unsafe_method_access")
	print("FORMOCRACY_CORE_GAMEPLAY_TEST_OK")
	quit(0)
