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
	assert(
		desk.has_node("ServiceWindowForeground") and desk.has_node("ServiceWindowGlass") and desk.has_node("WorktableForeground"),
		"service window, glass, and worktable must be independent foreground layers"
	)
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
	var service_window := desk.get_node("ServiceWindowForeground") as CanvasItem
	var service_glass := desk.get_node("ServiceWindowGlass") as CanvasItem
	assert(service_window.z_index > manager.npc_performance.actor_layer.z_index, "NPC must render behind the service-window frame")
	assert(service_glass.z_index > manager.npc_performance.actor_layer.z_index, "NPC must render behind the protective glass tint")
	assert(manager.npc_performance.actor_layer.z_index >= 0 and manager.presenter.envelope.z_index > background.z_index, "interactive NPCs and envelope must render over the background")
	var presenter: Variant = manager.presenter
	assert(not presenter.envelope_opened, "delivered envelope must start sealed")
	presenter.set_envelope_on_desk(true)
	assert(presenter.envelope.size == Vector2(180, 126), "NPC delivery must preserve the compact side-flat envelope asset ratio")
	assert(presenter.envelope_image.texture.resource_path.ends_with("bureau_envelope_desk_side.png"), "NPC delivery must render the portrait envelope lying away from the player")
	manager.desk_items._begin_press(presenter.envelope, Vector2(10, 10))
	manager.desk_items._end_press(presenter.envelope)
	await create_timer(0.3).timeout
	assert(presenter.envelope_billboard_expanded, "clicking the desk envelope must expand the billboard inspection layer")
	assert(presenter.envelope.size == Vector2(500, 620), "billboard envelope must occupy the configured large inspection area")
	assert(presenter.envelope.z_index > manager.npc_performance.actor_layer.z_index, "billboard envelope must cover the NPC layer")
	assert(presenter.envelope.mouse_filter == Control.MOUSE_FILTER_IGNORE, "expanded envelope body must not block documents or desk tools")
	assert(presenter.envelope_flap.visible and presenter.envelope_flap.position.y < 40, "the only opening hit area must cover the upper ring and flap")
	assert(presenter.envelope_flap.text.is_empty(), "the envelope must not use a bottom open button")
	presenter.envelope_flap.emit_signal("button_down")
	assert(presenter.envelope_image.texture.resource_path.ends_with("bureau_envelope_unstrung.png"), "opening must begin with the original unstrung frame")
	await create_timer(0.3).timeout
	assert(presenter.thumbnail_tray.visible, "opening must reveal the real case documents inside the pocket")
	assert(presenter.envelope_image.texture.resource_path.ends_with("bureau_envelope_open_empty.png"), "opening must use the empty source frame instead of baked fake documents")
	var pocket_style := presenter.thumbnail_tray.get_theme_stylebox("panel") as StyleBoxFlat
	assert(pocket_style.bg_color.a == 0.0, "the document pocket must not draw a black thumbnail background")
	for document: DocumentView in presenter.all_document_views:
		assert(not document.visible, "opening the envelope must not spread every document automatically")
	var primary_preview := presenter.thumbnail_by_id[presenter.primary_document_id] as Button
	primary_preview.emit_signal("pressed")
	var supporting_document := presenter.document_panels[0] as DocumentView
	var supporting_preview := presenter.thumbnail_by_id[supporting_document.document_id] as Button
	supporting_preview.emit_signal("pressed")
	await create_timer(0.3).timeout
	assert(presenter.form.visible and supporting_document.visible, "thumbnail selection must allow multiple documents to stay expanded")
	assert(not primary_preview.visible, "extracting a real document must remove its pocket preview")
	var supporting_home: Vector2 = supporting_document.position
	supporting_document.position = presenter.form.position
	supporting_document.scale = presenter.form.scale
	presenter.bring_document_to_front(supporting_document.document_id)
	manager.desk_items._begin_press(presenter.form, Vector2(10, 10))
	assert(not WorkdayContext.to_bool(presenter.form.get_meta("desk_pressed")), "a covered document must not begin interacting through the top sheet")
	manager.desk_items._begin_press(supporting_document, Vector2(10, 10))
	assert(WorkdayContext.to_bool(supporting_document.get_meta("desk_pressed")), "only the topmost overlapping document may begin interacting")
	manager.desk_items._end_press(supporting_document)
	supporting_document.position = supporting_home
	assert(presenter.inspection_dismiss_layer.visible, "expanded envelope must expose a dismiss layer below inspection items")
	assert(presenter.inspection_dismiss_layer.mouse_filter == Control.MOUSE_FILTER_IGNORE, "inspection dismiss handling must not block documents or desk tools")
	for child: Node in presenter.form.get_children():
		if child is Label:
			assert((child as Label).mouse_filter == Control.MOUSE_FILTER_IGNORE, "document display labels must pass drag input to the document panel")
	var document_probe := InputEventMouseMotion.new()
	document_probe.position = presenter.form.get_global_transform() * Vector2(8, 8)
	Input.parse_input_event(document_probe)
	await process_frame
	assert(desk.get_viewport().gui_get_hovered_control() == presenter.form, "real GUI hit testing must reach the expanded document instead of a transparent blocker")
	var approve_stamp := manager.stamp.stamp_tools[0] as Control
	var stamp_probe := InputEventMouseMotion.new()
	stamp_probe.position = approve_stamp.get_global_rect().get_center()
	Input.parse_input_event(stamp_probe)
	await process_frame
	assert(desk.get_viewport().gui_get_hovered_control() == approve_stamp, "expanded inspection layers must not block the stamp tools")
	var outside_click := InputEventMouseButton.new()
	outside_click.button_index = MOUSE_BUTTON_LEFT
	outside_click.pressed = true
	manager.handle_unhandled_input(outside_click)
	await create_timer(0.3).timeout
	assert(not presenter.envelope_billboard_expanded, "clicking outside the envelope must collapse it to the desk")
	assert(presenter.envelope.mouse_filter == Control.MOUSE_FILTER_STOP, "desk-flat envelope must recover its own click and drag input")
	assert(presenter.form.visible and supporting_document.visible, "collapsing the envelope must leave extracted documents available")
	manager.desk_items._begin_press(presenter.envelope, Vector2(10, 10))
	manager.desk_items._end_press(presenter.envelope)
	await create_timer(0.3).timeout
	assert(presenter.envelope_billboard_expanded and presenter.thumbnail_tray.visible, "an opened envelope must be expandable again without losing its contents")
	for document: DocumentView in presenter.all_document_views:
		if WorkdayContext.stringify_value(document.get_meta("document_state", "BAG")) == "BAG":
			var preview := presenter.thumbnail_by_id[document.document_id] as Button
			preview.emit_signal("pressed")
	await create_timer(0.3).timeout
	assert(presenter.thumbnail_tray.visible, "an emptied open envelope must retain its transparent repacking target")
	for thumbnail_value: Variant in presenter.thumbnail_by_id.values():
		var thumbnail := thumbnail_value as Button
		assert(not thumbnail.visible, "an extracted document must no longer leave a fake preview inside the envelope")

	manager.desk_items._begin_press(presenter.form, Vector2(10, 10))
	var downward_drag := InputEventMouseMotion.new()
	downward_drag.position = Vector2(10, 390)
	downward_drag.relative = Vector2(0, 320)
	var desired_document_position := Vector2(presenter.form.position.x, DeskGeometry.BOUNDS_TOP + 20)
	downward_drag.global_position = desk.to_global(desired_document_position + Vector2(10, 10))
	manager.desk_items._move_pressed_item(presenter.form, downward_drag)
	assert(WorkdayContext.stringify_value(presenter.form.get_meta("document_state")) == "DESK", "dragging an inspection document down must convert it into a desk paper")
	assert(_meta_vector(presenter.form, "desk_base_scale") == presenter.DOCUMENT_DESK_SCALE, "desk paper must use the compact foreshortened scale")
	manager.desk_items._end_press(presenter.form)
	await create_timer(0.7).timeout
	assert(presenter.form.position.y >= DeskGeometry.BOUNDS_TOP, "released desk paper must land within the desk vertical bounds")
	assert(presenter.form.position.y + presenter.form.size.y * presenter.form.scale.y <= DeskGeometry.BOUNDS_FLOOR + 0.01, "desk paper must fit entirely above the desk floor")
	assert(not presenter.packed_document_ids.has(presenter.primary_document_id), "placing a document below the bag must not be mistaken for repacking")
	var desk_home: Vector2 = presenter.form.position
	presenter.collapse_envelope_billboard()
	await create_timer(0.3).timeout
	manager.desk_items._begin_press(presenter.form, Vector2(10, 10))
	manager.desk_items._end_press(presenter.form)
	await create_timer(0.25).timeout
	assert(WorkdayContext.stringify_value(presenter.form.get_meta("document_state")) == "INSPECTION", "clicking a desk paper must raise it into the inspection layer")
	assert(presenter.form.scale == presenter.DOCUMENT_INSPECTION_SCALE, "raised desk paper must recover its readable inspection scale")
	manager.handle_unhandled_input(outside_click)
	await create_timer(0.25).timeout
	assert(WorkdayContext.stringify_value(presenter.form.get_meta("document_state")) == "DESK", "clicking outside a raised desk paper must lay it down again")
	assert(presenter.form.position == desk_home, "lowering a raised paper must preserve its previous desk position")
	manager.desk_items._begin_press(presenter.envelope, Vector2(10, 10))
	manager.desk_items._end_press(presenter.envelope)
	await create_timer(0.3).timeout

	assert(presenter.thumbnail_tray.visible, "an empty bag opening must remain available before the first document is returned")
	var tray_center_global: Vector2 = presenter.thumbnail_tray.get_global_transform() * (presenter.thumbnail_tray.size * 0.5)
	var tray_center := desk.to_local(tray_center_global)
	supporting_document.position = tray_center - supporting_document.size * 0.5
	manager.input._prepare_document_drop(supporting_document, presenter)
	assert(presenter.packed_document_ids.has(supporting_document.document_id), "only a document centered inside the bag opening may be repacked")

	presenter.bring_document_to_front(presenter.primary_document_id)
	assert(presenter.form.z_index > supporting_document.z_index, "selecting a document must bring it above overlapping documents")
	assert(presenter.envelope.visible, "opened envelope must remain visible as the repacking target")
	assert(not presenter.envelope_flap.visible, "the upper opening hit area must disappear after the envelope is open")
	presenter.apply_stamp("批准", Vector2(350, 360))
	assert(presenter.form.stamp_records.size() == 1, "the primary document must retain its own stamp records")
	presenter.pack_all_documents()
	await create_timer(0.3).timeout
	var current_case := manager.current_case as Dictionary
	assert(presenter.packed_document_ids.size() == WorkdayContext.read_array(current_case, "documents").size(), "all materials must return to the original envelope")
	assert(not presenter.envelope_billboard_expanded and presenter.envelope.size == Vector2(180, 126), "repacked envelope must collapse back to its compact side-flat state")
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


# 从测试节点元数据读取 Vector2。
func _meta_vector(item: Control, key: String) -> Vector2:
	var value: Variant = item.get_meta(key, Vector2.ZERO)
	return value if value is Vector2 else Vector2.ZERO
