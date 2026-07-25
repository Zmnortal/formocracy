class_name WorkbenchSubmissionModule
extends RefCounted

# 处理申请表提交到验收槽的完整流程：
# 程序错误检查、结果记录、验收槽动画、现实验收转场，最后通知主脚本流程结束。

signal submission_finished

var root: Node2D
var desk: DeskNodes
var submission_in_progress := false


# 保存场景根节点与桌面节点引用。
func _init(owner_root: Node2D, owner_desk: DeskNodes) -> void:
	root = owner_root
	desk = owner_desk


# 提交当前案件。
# 检查程序错误，记录结果，并把封好的文件袋收入当日归档区。
func submit(presenter: WorkbenchCasePresenter, case_data: Dictionary) -> void:
	if submission_in_progress:
		return
	submission_in_progress = true
	var envelope_snapshot := presenter._capture_envelope_snapshot()
	var procedure_errors: Array[String] = []
	if not presenter.is_stamped():
		procedure_errors.append("漏盖章")
	if presenter.has_stamp_conflict():
		procedure_errors.append("裁决冲突")
	if not WorkdayContext.read_array(envelope_snapshot, "missing_document_ids").is_empty():
		procedure_errors.append("遗漏材料")

	if is_instance_valid(presenter.form):
		presenter.form.mouse_filter = Control.MOUSE_FILTER_IGNORE
		presenter.form.visible = false
	if is_instance_valid(presenter.envelope):
		presenter.envelope.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for document in presenter.document_panels:
		if is_instance_valid(document):
			document.visible = false

	var submitted_object: Control = presenter.envelope if is_instance_valid(presenter.envelope) else null
	if not is_instance_valid(submitted_object):
		_record_submission(presenter, case_data, procedure_errors, envelope_snapshot)
		submission_in_progress = false
		submission_finished.emit()
		return

	submitted_object.visible = true
	submitted_object.pivot_offset = submitted_object.size / 2.0
	submitted_object.z_index = 46
	var zone_rect := desk.archive_drop_zone.get_global_rect()
	var target := zone_rect.position + Vector2((zone_rect.size.x - submitted_object.size.x) / 2.0, (zone_rect.size.y - submitted_object.size.y) / 2.0)

	var archive := root.create_tween().set_parallel(true)
	archive.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	archive.tween_property(submitted_object, "global_position", target, 0.48)
	archive.tween_property(submitted_object, "scale", Vector2(0.42, 0.24), 0.48)
	archive.tween_property(submitted_object, "rotation", -0.04, 0.3)
	archive.tween_property(submitted_object, "modulate:a", 0.0, 0.16).set_delay(0.32)
	await archive.finished

	submitted_object.visible = false
	_record_submission(presenter, case_data, procedure_errors, envelope_snapshot)
	submission_in_progress = false
	submission_finished.emit()


# 将案件结果写入工作日状态，刷新归档堆并闪烁提示灯。
func _record_submission(presenter: WorkbenchCasePresenter, case_data: Dictionary, procedure_errors: Array[String], envelope_snapshot: Dictionary) -> void:
	WorkdayState.manager.record_case_result(
		case_data,
		presenter.stamp_type(),
		procedure_errors,
		Time.get_ticks_msec() / 1000.0 - presenter.case_started_at,
		WorkdayContext.read_array(envelope_snapshot, "document_ids"),
		presenter.get_stamp_records(),
		envelope_snapshot
	)
	desk.refresh_archive_stack(true)
	if is_instance_valid(desk.status_label):
		desk.status_label.text = "文件袋已归档，等待日终统一送验。"
	Sfx.play("bling")
	_flash_slot(WorkbenchUI.COLORS.green_glow)


# 播放现实验收转场动画，结束后通知提交流程完成。
func _show_validation_transition() -> void:
	if not is_instance_valid(desk.validation_overlay):
		submission_in_progress = false
		submission_finished.emit()
		return

	desk.validation_overlay.visible = true
	desk.validation_overlay.modulate.a = 0.0
	desk.validation_image.scale = Vector2(1.035, 1.035)
	desk.validation_image.pivot_offset = desk.validation_image.size / 2.0

	var fade_in := root.create_tween().set_parallel(true)
	fade_in.tween_property(desk.validation_overlay, "modulate:a", 1.0, 0.28)
	fade_in.tween_property(desk.validation_image, "scale", Vector2.ONE, 1.4)
	await root.get_tree().create_timer(1.35).timeout

	var fade_out := root.create_tween()
	fade_out.tween_property(desk.validation_overlay, "modulate:a", 0.0, 0.32)
	await fade_out.finished

	desk.validation_overlay.visible = false
	submission_in_progress = false
	submission_finished.emit()


# 用指定颜色闪烁验收槽指示灯三次后恢复红色。
func _flash_slot(color: Color) -> void:
	if not is_instance_valid(desk.slot_light):
		return
	desk.slot_light.color = color
	var tween := root.create_tween()
	for i in 3:
		tween.tween_property(desk.slot_light, "modulate:a", 0.15, 0.1)
		tween.tween_property(desk.slot_light, "modulate:a", 1.0, 0.1)
	tween.tween_callback(_restore_slot_light)


# 闪烁结束后恢复归档槽默认红灯。
func _restore_slot_light() -> void:
	desk.slot_light.color = WorkbenchUI.COLORS.red
