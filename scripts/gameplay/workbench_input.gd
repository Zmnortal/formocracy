class_name WorkbenchInput
extends RefCounted

# 处理工作台中表单、文件袋与证明材料的拖拽、悬停与放手区域判定。

signal envelope_submitted

var root: Node2D
var desk: DeskNodes

var form_dragging := false
var envelope_dragging := false
var envelope_in_machine_zone := false
var envelope_preview_tween: Tween
var drag_response_multiplier := 1.0


func _init(owner_root: Node2D, owner_desk: DeskNodes) -> void:
	root = owner_root
	desk = owner_desk
	drag_response_multiplier = WorkdayState.get_drag_response_multiplier()


# 为当前案件的表单、文件袋和材料连接输入事件。
func bind_case(presenter: CasePresenter) -> void:
	envelope_dragging = false
	envelope_in_machine_zone = false
	if is_instance_valid(presenter.form):
		CursorManager.watch(presenter.form, CursorManager.Cursor.GRAB)
		presenter.form.gui_input.connect(_on_form_input.bind(presenter))
		presenter.form.mouse_entered.connect(_on_form_hover.bind(presenter, true))
		presenter.form.mouse_exited.connect(_on_form_hover.bind(presenter, false))
	if is_instance_valid(presenter.envelope):
		CursorManager.watch(presenter.envelope, CursorManager.Cursor.GRAB)
		presenter.envelope.gui_input.connect(_on_envelope_input.bind(presenter))
	for document in presenter.document_panels:
		if is_instance_valid(document):
			CursorManager.watch(document, CursorManager.Cursor.GRAB)
			document.gui_input.connect(_on_document_input.bind(document, presenter))


# 表单悬停时的缩放反馈。
func _on_form_hover(presenter: CasePresenter, entered: bool) -> void:
	if form_dragging or not is_instance_valid(presenter.form):
		return
	var target_scale := desk.form_base_scale * (1.012 if entered else 1.0)
	var tween := root.create_tween()
	tween.tween_property(presenter.form, "scale", target_scale, 0.08)


# 表单的拖拽与装袋处理。
func _on_form_input(event: InputEvent, presenter: CasePresenter) -> void:
	if not is_instance_valid(presenter.form):
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			form_dragging = true
			CursorManager.begin_drag(presenter.form)
			presenter.form.z_index = 10
			var tween := root.create_tween().set_parallel(true)
			tween.tween_property(presenter.form, "scale", desk.form_base_scale * 1.035, 0.1)
			tween.tween_property(presenter.form, "rotation", -0.012, 0.1)
		else:
			form_dragging = false
			CursorManager.end_drag()
			presenter.form.z_index = 5
			var tween := root.create_tween().set_parallel(true)
			tween.tween_property(presenter.form, "scale", desk.form_base_scale, 0.12)
			tween.tween_property(presenter.form, "rotation", 0.0, 0.12)
			if _is_over_open_envelope(presenter.form, presenter):
				presenter.pack_document(presenter.primary_document_id)
	elif event is InputEventMouseMotion and form_dragging:
		presenter.form.position += event.relative * drag_response_multiplier
		CursorManager.set_drag_cursor(
			CursorManager.Cursor.DROP_VALID
			if _is_over_open_envelope(presenter.form, presenter)
			else CursorManager.Cursor.GRABBING
		)


# 文件袋的拖拽、放置到工作台与送交验收槽处理。
func _on_envelope_input(event: InputEvent, presenter: CasePresenter) -> void:
	if not is_instance_valid(presenter.envelope):
		return
	if presenter.envelope_opened and not presenter.all_documents_packed():
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			envelope_dragging = true
			CursorManager.begin_drag(presenter.envelope)
			presenter.envelope.z_index = 30
		else:
			envelope_dragging = false
			CursorManager.end_drag()
			if envelope_in_machine_zone and presenter.envelope_on_desk:
				if is_instance_valid(envelope_preview_tween):
					envelope_preview_tween.kill()
				presenter.envelope.z_index = 46
				envelope_submitted.emit()
			else:
				presenter.envelope.z_index = 12
				_set_machine_preview(presenter, false)
			if not presenter.envelope_on_desk:
				presenter.set_envelope_on_desk(presenter.envelope.position.x > 300)
				if presenter.envelope_on_desk and is_instance_valid(desk.status_label):
					desk.status_label.text = "文件袋已置于工作台，点击封口拆开。"
	elif event is InputEventMouseMotion and envelope_dragging:
		presenter.envelope.position += event.relative * drag_response_multiplier
		var entered := (
			presenter.envelope_on_desk
			and is_instance_valid(desk.machine_drop_zone)
			and presenter.envelope.get_global_rect().intersects(desk.machine_drop_zone.get_global_rect())
		)
		if entered != envelope_in_machine_zone:
			_set_machine_preview(presenter, entered)
		CursorManager.set_drag_cursor(
			CursorManager.Cursor.DROP_VALID if entered else CursorManager.Cursor.GRABBING
		)


func _set_machine_preview(presenter: CasePresenter, active: bool) -> void:
	envelope_in_machine_zone = active
	if not is_instance_valid(presenter.envelope):
		return
	if is_instance_valid(envelope_preview_tween):
		envelope_preview_tween.kill()
	presenter.envelope.pivot_offset = presenter.envelope.size / 2.0
	envelope_preview_tween = root.create_tween().set_parallel(true)
	envelope_preview_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	envelope_preview_tween.tween_property(
		presenter.envelope,
		"scale",
		Vector2(0.92, 0.62) if active else Vector2.ONE,
		0.14
	)
	envelope_preview_tween.tween_property(
		presenter.envelope,
		"rotation",
		-0.055 if active else 0.0,
		0.14
	)
	if is_instance_valid(desk.slot_light):
		desk.slot_light.color = Color("d7aa45") if active else WorkbenchUI.COLORS.red
	if active and is_instance_valid(desk.status_label):
		desk.status_label.text = "验收机器已锁定文件袋：松手送入。"


# 单个材料的拖拽与装袋处理。
func _on_document_input(event: InputEvent, document: Panel, presenter: CasePresenter) -> void:
	if not is_instance_valid(document):
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		document.set_meta("dragging", event.pressed)
		if event.pressed:
			document.z_index = 25
			CursorManager.begin_drag(document)
		else:
			document.z_index = 8
			CursorManager.end_drag()
			if _is_over_open_envelope(document, presenter):
				presenter.pack_document(String(document.get_meta("document_id")))
	elif event is InputEventMouseMotion and bool(document.get_meta("dragging")):
		document.position += event.relative * drag_response_multiplier
		CursorManager.set_drag_cursor(
			CursorManager.Cursor.DROP_VALID
			if _is_over_open_envelope(document, presenter)
			else CursorManager.Cursor.GRABBING
		)


func _is_over_open_envelope(item: Control, presenter: CasePresenter) -> bool:
	return (
		presenter.envelope_opened
		and is_instance_valid(presenter.envelope)
		and presenter.envelope.visible
		and item.get_global_rect().intersects(presenter.envelope.get_global_rect())
	)
