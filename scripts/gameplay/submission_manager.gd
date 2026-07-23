class_name SubmissionManager
extends RefCounted

# 处理申请表提交到验收槽的完整流程：
# 程序错误检查、结果记录、验收槽动画、现实验收转场，最后通知主脚本流程结束。

signal submission_finished

var root: Node2D
var desk: DeskNodes


func _init(owner_root: Node2D, owner_desk: DeskNodes) -> void:
	root = owner_root
	desk = owner_desk


# 提交当前案件。
# 检查程序错误，记录结果，播放验收动画与转场。
func submit(presenter: CasePresenter, case_data: Dictionary) -> void:
	var procedure_errors: Array[String] = []
	if not presenter.is_stamped():
		procedure_errors.append("漏盖章")
	if not presenter.all_documents_packed():
		procedure_errors.append("遗漏材料")
	if not presenter.envelope_opened:
		procedure_errors.append("未拆封归档")

	if is_instance_valid(desk.status_label):
		desk.status_label.text = "材料已接收。批准不构成现实效力承诺。"

	WorkdayState.record_case_result(
		case_data,
		presenter.stamp_type(),
		procedure_errors,
		Time.get_ticks_msec() / 1000.0 - presenter.case_started_at,
		presenter.packed_document_ids.duplicate()
	)

	_flash_slot(WorkbenchUI.COLORS.green_glow)

	if is_instance_valid(presenter.form):
		presenter.form.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if is_instance_valid(presenter.envelope):
		presenter.envelope.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var submitted_object: Control = presenter.envelope if is_instance_valid(presenter.envelope) and presenter.envelope.visible else presenter.form
	if not is_instance_valid(submitted_object):
		_show_validation_transition()
		return

	submitted_object.visible = true
	var target := desk.slot.global_position + Vector2(80, 76)
	var tween := root.create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(submitted_object, "global_position", target, 0.55)
	tween.tween_property(submitted_object, "scale", Vector2(0.28, 0.06), 0.55)
	tween.tween_property(submitted_object, "modulate:a", 0.0, 0.5).set_delay(0.18)
	tween.finished.connect(_show_validation_transition)


func _show_validation_transition() -> void:
	if not is_instance_valid(desk.validation_overlay):
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
