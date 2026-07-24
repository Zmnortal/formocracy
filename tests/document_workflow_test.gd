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
	main.start_first_case_for_tests()
	await process_frame

	var presenter = main.presenter
	presenter.set_envelope_on_desk(true)
	presenter.open_envelope()
	assert(
		presenter.thumbnail_by_id.size() == presenter.current_case.documents.size(),
		"each configured document must have one envelope thumbnail"
	)
	assert(
		presenter.all_document_views.all(func(document): return not document.visible),
		"documents must remain in the envelope until a thumbnail is selected"
	)

	var primary_id: String = presenter.primary_document_id
	var supporting = presenter.document_panels[0]
	presenter.open_document(primary_id)
	presenter.open_document(supporting.document_id)
	assert(presenter.form.visible and supporting.visible, "multiple documents must remain expanded")
	presenter.bring_document_to_front(primary_id)
	assert(presenter.form.z_index > supporting.z_index, "the selected document must be topmost")

	presenter.apply_stamp("批准", supporting.document_id, Vector2(280, 220))
	presenter.apply_stamp("驳回", supporting.document_id, Vector2(330, 245))
	assert(supporting.stamp_records.size() == 2, "one document must retain multiple stamps")
	assert(presenter.has_stamp_conflict(), "approve and return on one document must conflict")
	assert(
		presenter.get_stamp_records().all(
			func(record): return String(record.document_id) == supporting.document_id
		),
		"each stamp record must identify its owning document"
	)

	presenter.pack_document(supporting.document_id)
	assert(not supporting.visible, "dragging a document back must hide only that document")
	assert(presenter.form.visible, "other expanded documents must remain on the desk")
	presenter.pack_all_documents()
	assert(presenter.all_documents_packed(), "every document must be individually recoverable")
	assert(not presenter.thumbnail_tray.visible, "a fully repacked envelope must hide thumbnails")

	main.submission_mgr.submit(presenter, main.current_case)
	await create_timer(0.9).timeout
	assert(state.records.size() == 1, "submission must create a processing record")
	assert(
		state.records[0].procedure_errors.has("裁决冲突"),
		"conflicting stamps must be stored as a procedural error"
	)
	assert(
		state.records[0].document_stamps.size() == 2,
		"archive records must preserve all file-level stamps"
	)

	print("FORMOCRACY_DOCUMENT_WORKFLOW_TEST_OK")
	quit(0)
