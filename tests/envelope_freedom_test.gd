extends SceneTree

# 验证文件袋是自由容器：任意取放、任意内容归档，限制只在最终快照中表达。


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

	var manager = main.manager
	var presenter = manager.presenter
	presenter.set_envelope_on_desk(true)
	assert(presenter.packed_document_ids.size() == presenter.all_document_views.size(), "a delivered envelope must initially contain every configured document")

	presenter.expand_envelope_billboard()
	await create_timer(0.3).timeout
	presenter.open_envelope()
	await create_timer(0.3).timeout
	var primary_id: String = presenter.primary_document_id
	presenter.open_document(primary_id)
	assert(not presenter.packed_document_ids.has(primary_id), "extracting a document must remove it from the live envelope contents")
	assert(presenter.pack_document(primary_id), "a document must be insertable without completing a checklist")
	assert(presenter.packed_document_ids.has(primary_id), "reinserting a document must update the live envelope contents")
	presenter.open_document(primary_id)
	assert(not presenter.packed_document_ids.has(primary_id), "a reinserted document must remain immediately extractable")

	for document: DocumentView in presenter.all_document_views:
		if WorkdayContext.stringify_value(document.get_meta("document_state", "BAG")) == "BAG":
			presenter.open_document(document.document_id)
	assert(presenter.packed_document_ids.is_empty(), "the player must be allowed to empty the envelope completely")

	presenter.collapse_envelope_billboard()
	await create_timer(0.3).timeout
	var archive_rect: Rect2 = manager.desk.archive_drop_zone.get_global_rect()
	presenter.envelope.global_position = archive_rect.position
	manager.input._on_envelope_drag_motion(presenter.envelope, presenter)
	assert(manager.input.envelope_in_machine_zone, "an empty envelope must still activate the archive target")
	manager.input._on_envelope_settled(presenter.envelope, presenter)
	await create_timer(0.9).timeout

	assert(state.records.size() == 1, "dropping an empty envelope must archive the case instead of rejecting interaction")
	var record: Dictionary = state.records[0]
	var snapshot := WorkdayContext.read_dictionary(record, "envelope_snapshot")
	assert(WorkdayContext.read_array(snapshot, "document_ids").is_empty(), "the final snapshot must preserve the actual empty contents")
	assert(WorkdayContext.read_array(snapshot, "missing_document_ids").size() == presenter.all_document_views.size(), "the final snapshot must calculate missing files only after the archive drop")
	assert(WorkdayContext.read_array(record, "procedure_errors").has("遗漏材料"), "missing contents must become a recorded result, not an interaction lock")
	assert(state.archived_cases.size() == 1, "the freely submitted envelope must enter the persistent archive")
	assert(WorkdayContext.read_dictionary(state.archived_cases[0], "envelope_snapshot") == snapshot, "the archive must retain the immutable envelope snapshot")

	print("FORMOCRACY_ENVELOPE_FREEDOM_TEST_OK")
	quit(0)
