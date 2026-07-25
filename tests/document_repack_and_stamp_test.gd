extends SceneTree

# 文件归袋与盖章交互回归测试。
# 验证三角袋口、查验层释放语义，以及四帧盖章动画完成后才生成印记。


func _init() -> void:
	call_deferred("run")


func run() -> void:
	@warning_ignore_start("unsafe_method_access")
	@warning_ignore_start("unsafe_property_access")
	@warning_ignore_start("unsafe_cast")
	var state := root.get_node("WorkdayState") as WorkdayContext
	state.call("reset_for_tests")
	var packed := load("res://main.tscn") as PackedScene
	var workbench := packed.instantiate() as Node2D
	root.add_child(workbench)
	await process_frame
	var manager: Variant = workbench.get("manager")
	manager.start_first_case_for_tests()
	await process_frame
	var presenter: Variant = manager.presenter

	presenter.set_envelope_on_desk(true)
	presenter._show_billboard_immediate()
	presenter.open_envelope()
	await create_timer(0.3).timeout
	var primary_preview := presenter.thumbnail_by_id[presenter.primary_document_id] as Button
	primary_preview.emit_signal("pressed")
	var supporting_document := presenter.document_panels[0] as DocumentView
	var supporting_preview := presenter.thumbnail_by_id[supporting_document.document_id] as Button
	supporting_preview.emit_signal("pressed")
	await create_timer(0.3).timeout

	var upper_release_position := Vector2(420, 110)
	_place_visual_center(presenter.form, workbench.to_global(upper_release_position))
	var inspection_position: Vector2 = presenter.form.position
	manager.input._on_document_drag_motion(presenter.form, presenter)
	manager.input._prepare_document_drop(presenter.form, presenter)
	await create_timer(0.14).timeout
	assert(WorkdayContext.stringify_value(presenter.form.get_meta("document_state")) == "INSPECTION", "an inspection document released above the desk must stay in the inspection layer")
	assert(presenter.form.position == inspection_position, "upper-screen release must not invoke desk gravity")

	var invalid_mouth_global: Vector2 = presenter.envelope.get_global_transform() * Vector2(100, 240)
	_place_visual_center(supporting_document, invalid_mouth_global)
	manager.input._on_document_drag_motion(supporting_document, presenter)
	assert(not WorkdayContext.to_bool(presenter.envelope.get_meta("repack_preview_active")), "the old rectangular pocket area outside the triangular mouth must not show a valid drop preview")
	manager.input._prepare_document_drop(supporting_document, presenter)
	assert(not presenter.packed_document_ids.has(supporting_document.document_id), "a document outside the triangular mouth must never enter the envelope")
	assert(WorkdayContext.stringify_value(supporting_document.get_meta("document_state")) == "INSPECTION", "an invalid envelope drop must preserve inspection state")

	var valid_mouth_global: Vector2 = presenter.envelope.get_global_transform() * Vector2(250, 180)
	_place_visual_center(supporting_document, valid_mouth_global)
	manager.input._on_document_drag_motion(supporting_document, presenter)
	assert(WorkdayContext.to_bool(presenter.envelope.get_meta("repack_preview_active")), "entering the triangular envelope mouth must enable the whole-envelope white outline")
	assert(WorkdayContext.to_bool(presenter.envelope_outline_material.get_shader_parameter("outline_enabled")), "the envelope outline shader must receive the valid-drop state")
	manager.input._prepare_document_drop(supporting_document, presenter)
	assert(presenter.packed_document_ids.has(supporting_document.document_id), "a document centered in the triangular mouth must be repacked")
	assert(not WorkdayContext.to_bool(presenter.envelope.get_meta("repack_preview_active")), "the valid-drop outline must clear immediately after repacking")

	presenter.bring_document_to_front(presenter.primary_document_id)
	var approve_stamp := manager.stamp.stamp_tools[0] as Control
	var stamp_target_global: Vector2 = presenter.form.get_global_transform() * Vector2(330, 420)
	_place_visual_center(approve_stamp, stamp_target_global)
	manager.stamp._prepare_stamp_drop(approve_stamp)
	assert(workbench.has_node("StampContactAnimation"), "a valid free stamp drop must start the contact animation")
	assert(presenter.form.stamp_records.is_empty(), "the stamp mark must not appear before the contact animation finishes")
	await create_timer(0.38).timeout
	assert(not workbench.has_node("StampContactAnimation"), "the temporary stamp animation must clean itself up")
	assert(presenter.form.stamp_records.size() == 1, "the stamp mark must be written after the fourth animation frame")
	assert(WorkdayContext.stringify_value(presenter.form.stamp_records[0].get("kind")) == "批准", "the resulting mark must preserve the dragged stamp kind")

	print("FORMOCRACY_DOCUMENT_REPACK_AND_STAMP_OK")
	quit()


func _place_visual_center(item: Control, global_center: Vector2) -> void:
	var parent := item.get_parent() as CanvasItem
	var parent_inverse := parent.get_global_transform().affine_inverse()
	var current_center := item.get_global_transform() * (item.size * 0.5)
	item.position += parent_inverse * global_center - parent_inverse * current_center
