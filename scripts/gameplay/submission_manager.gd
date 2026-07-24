class_name SubmissionManager
extends RefCounted

# 处理申请表提交到验收槽的完整流程：
# 程序错误检查、结果记录、验收槽动画、现实验收转场，最后通知主脚本流程结束。

signal submission_finished

var root: Node2D
var desk: DeskNodes
var submission_in_progress := false


func _init(owner_root: Node2D, owner_desk: DeskNodes) -> void:
	root = owner_root
	desk = owner_desk


# 提交当前案件。
# 检查程序错误，记录结果，并把封好的文件袋收入当日归档区。
func submit(presenter: CasePresenter, case_data: Dictionary) -> void:
	if submission_in_progress:
		return
	submission_in_progress = true
	var procedure_errors: Array[String] = []
	if not presenter.is_stamped():
		procedure_errors.append("漏盖章")
	if not presenter.all_documents_packed():
		procedure_errors.append("遗漏材料")
	if not presenter.envelope_opened:
		procedure_errors.append("未拆封归档")

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
		_record_submission(presenter, case_data, procedure_errors)
		submission_in_progress = false
		submission_finished.emit()
		return

	submitted_object.visible = true
	submitted_object.pivot_offset = submitted_object.size / 2.0
	submitted_object.z_index = 46
	var zone_rect := desk.archive_drop_zone.get_global_rect()
	var target := zone_rect.position + Vector2(
		(zone_rect.size.x - submitted_object.size.x) / 2.0,
		(zone_rect.size.y - submitted_object.size.y) / 2.0
	)

	var archive := root.create_tween().set_parallel(true)
	archive.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	archive.tween_property(submitted_object, "global_position", target, 0.48)
	archive.tween_property(submitted_object, "scale", Vector2(0.42, 0.24), 0.48)
	archive.tween_property(submitted_object, "rotation", -0.04, 0.3)
	archive.tween_property(submitted_object, "modulate:a", 0.0, 0.16).set_delay(0.32)
	await archive.finished

	submitted_object.visible = false
	_record_submission(presenter, case_data, procedure_errors)
	submission_in_progress = false
	submission_finished.emit()


func _record_submission(
		presenter: CasePresenter,
		case_data: Dictionary,
		procedure_errors: Array[String]
) -> void:
	WorkdayState.record_case_result(
		case_data,
		presenter.stamp_type(),
		procedure_errors,
		Time.get_ticks_msec() / 1000.0 - presenter.case_started_at,
		presenter.packed_document_ids.duplicate()
	)
	desk.refresh_archive_stack(true)
	if is_instance_valid(desk.status_label):
		desk.status_label.text = "文件袋已归档，等待日终统一送验。"
	Sfx.play("bling")
	_flash_slot(WorkbenchUI.COLORS.green_glow)


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


func _flash_slot(color: Color) -> void:
	if not is_instance_valid(desk.slot_light):
		return
	desk.slot_light.color = color
	var tween := root.create_tween()
	for i in 3:
		tween.tween_property(desk.slot_light, "modulate:a", 0.15, 0.1)
		tween.tween_property(desk.slot_light, "modulate:a", 1.0, 0.1)
	tween.tween_callback(func(): desk.slot_light.color = WorkbenchUI.COLORS.red)
