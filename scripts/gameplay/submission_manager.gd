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
# 检查程序错误，记录结果，播放验收动画与转场。
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
		_show_validation_transition()
		return

	submitted_object.visible = true
	submitted_object.pivot_offset = submitted_object.size / 2.0
	submitted_object.z_index = 46
	Sfx.start_conveyor()
	if is_instance_valid(desk.machine_mouth_mask):
		desk.machine_mouth_mask.visible = true
	var zone_rect := desk.machine_drop_zone.get_global_rect()
	var target := zone_rect.position + Vector2(
		(zone_rect.size.x - submitted_object.size.x) / 2.0,
		zone_rect.size.y * 0.56
	)

	var snap := root.create_tween().set_parallel(true)
	snap.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	snap.tween_property(submitted_object, "global_position", target, 0.2)
	snap.tween_property(submitted_object, "scale", Vector2(0.78, 0.46), 0.2)
	snap.tween_property(submitted_object, "rotation", -0.065, 0.2)
	await snap.finished

	submitted_object.z_index = 40
	var ingest := root.create_tween().set_parallel(true)
	ingest.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	ingest.tween_property(submitted_object, "global_position", target + Vector2(0, -92), 0.58)
	ingest.tween_property(submitted_object, "scale", Vector2(0.54, 0.035), 0.58)
	ingest.tween_property(submitted_object, "rotation", 0.0, 0.4)
	ingest.tween_property(submitted_object, "modulate:a", 0.0, 0.18).set_delay(0.42)
	await ingest.finished

	submitted_object.visible = false
	if is_instance_valid(desk.machine_mouth_mask):
		desk.machine_mouth_mask.visible = false
	Sfx.stop_conveyor()
	_record_submission(presenter, case_data, procedure_errors)
	_show_validation_transition()


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
	if is_instance_valid(desk.status_label):
		desk.status_label.text = "材料已吞入。批准不构成现实效力承诺。"
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
