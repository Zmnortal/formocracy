extends SceneTree

# 验证缩略图展开、多文件置顶、文件级多章、冲突记录与重新装袋。


func _init() -> void:
	call_deferred("run")


func run() -> void:
	var state := root.get_node("WorkdayState")
	state.reset_for_tests()
	var packed: PackedScene = load("res://main.tscn")
	var main = packed.instantiate()
	root.add_child(main)
	await process_frame
	main.manager.start_first_case_for_tests()
	await process_frame

	var presenter = main.manager.presenter
	presenter.set_envelope_on_desk(true)
	presenter.open_envelope()
	assert(presenter.thumbnail_by_id.size() == presenter.current_case.documents.size(), "each configured document must have one envelope thumbnail")
	assert(presenter.all_document_views.all(func(document): return not document.visible), "documents must remain in the envelope until a thumbnail is selected")

	var primary_id: String = presenter.primary_document_id
	var supporting = presenter.document_panels[0]
	var primary_preview := presenter.thumbnail_by_id[primary_id] as Button
	var supporting_preview := presenter.thumbnail_by_id[supporting.document_id] as Button
	assert(primary_preview.icon.resource_path.ends_with("/application/pocket.png"), "application pocket preview must use its independent cropped asset")
	assert(supporting_preview.icon.resource_path.ends_with("/identity/pocket.png"), "identity pocket preview must use its independent cropped asset")
	assert(presenter.thumbnail_by_id.values().all(func(thumbnail: Button): return thumbnail.visible), "opening the envelope must reveal every configured document in one visible stack")
	assert(primary_preview.position != supporting_preview.position, "stacked pocket documents must retain separately clickable exposed edges")
	presenter.open_document(primary_id)
	assert(
		main.manager.desk_items._effective_z_index(presenter.form) > main.manager.desk_items._effective_z_index(presenter.envelope_front_cover),
		"an extracted document must rise above the envelope cover as one atomic group"
	)
	presenter.open_document(supporting.document_id)
	assert(presenter.form.visible and supporting.visible, "multiple documents must remain expanded")
	presenter.bring_document_to_front(primary_id)
	assert(presenter.form.z_index > supporting.z_index, "the selected document must be topmost")
	presenter.collapse_envelope_billboard()
	await create_timer(0.3).timeout
	assert(not WorkdayContext.to_bool(presenter.envelope.get_meta("desk_drag_locked")), "an envelope with extracted documents must remain draggable")
	var envelope_before_drag: Vector2 = presenter.envelope.position
	main.manager.desk_items._begin_press(presenter.envelope, Vector2(12, 12))
	assert(WorkdayContext.to_bool(presenter.envelope.get_meta("desk_pressed")), "the envelope must accept a press while documents remain outside")
	var envelope_drag := InputEventMouseMotion.new()
	envelope_drag.relative = Vector2(48, 0)
	envelope_drag.global_position = presenter.envelope.get_meta("desk_press_global_position") + Vector2(60, 0)
	main.manager.desk_items._move_pressed_item(presenter.envelope, envelope_drag)
	assert(
		presenter.envelope.position.x > envelope_before_drag.x + 30.0,
		"a partially emptied envelope must follow the pointer instead of remaining glued to the desk (%s -> %s)" % [envelope_before_drag, presenter.envelope.position]
	)
	main.manager.desk_items._end_press(presenter.envelope)
	await create_timer(0.2).timeout
	main.manager.desk_items._begin_press(presenter.envelope, Vector2(12, 12))
	var upward_envelope_drag := InputEventMouseMotion.new()
	upward_envelope_drag.relative = Vector2(0, -180)
	upward_envelope_drag.global_position = presenter.envelope.get_meta("desk_press_global_position") + Vector2(0, -180)
	main.manager.desk_items._move_pressed_item(presenter.envelope, upward_envelope_drag)
	var elevated_envelope_position: Vector2 = presenter.envelope.position
	main.manager.desk_items._end_press(presenter.envelope)
	await create_timer(0.25).timeout
	assert(presenter.envelope.position.is_equal_approx(elevated_envelope_position), "the case envelope must stay where it is released above the desk instead of falling under desk-item gravity")
	presenter.expand_envelope_billboard()
	await create_timer(0.3).timeout

	presenter.apply_stamp("批准", supporting.document_id, Vector2(280, 220))
	presenter.apply_stamp("驳回", supporting.document_id, Vector2(330, 245))
	assert(supporting.stamp_records.size() == 2, "one document must retain multiple stamps")
	assert(presenter.has_stamp_conflict(), "approve and return on one document must conflict")
	assert(presenter.get_stamp_records().all(func(record): return String(record.document_id) == supporting.document_id), "each stamp record must identify its owning document")

	presenter.pack_document(supporting.document_id)
	assert(not supporting.visible, "dragging a document back must hide only that document")
	assert(presenter.form.visible, "other expanded documents must remain on the desk")
	assert(supporting_preview.visible, "a repacked document must immediately return to the visible pocket stack")
	presenter.pack_all_documents()
	assert(presenter.all_documents_packed(), "every document must be individually recoverable")
	assert(presenter.envelope_billboard_expanded, "repacking the last document must leave the open envelope visible for confirmation")
	assert(presenter.thumbnail_tray.visible, "a fully repacked envelope must keep the document stack visible")
	assert(presenter.thumbnail_by_id.values().all(func(thumbnail: Button): return thumbnail.visible), "every repacked document must be visible in the completed pocket stack")
	presenter.collapse_envelope_billboard()
	await create_timer(0.3).timeout

	main.manager.submission.submit(presenter, main.manager.current_case)
	await create_timer(0.9).timeout
	assert(state.records.size() == 1, "submission must create a processing record")
	assert(state.records[0].procedure_errors.has("裁决冲突"), "conflicting stamps must be stored as a procedural error")
	assert(state.records[0].document_stamps.size() == 2, "archive records must preserve all file-level stamps")

	print("FORMOCRACY_DOCUMENT_WORKFLOW_TEST_OK")
	quit(0)
