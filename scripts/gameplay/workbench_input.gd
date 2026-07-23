class_name WorkbenchInput
extends RefCounted

# 处理工作台中表单、文件袋与证明材料的拖拽、悬停与放手区域判定。

signal envelope_submitted

const DOCUMENT_PACK_POINT := Vector2(250, 540)

var root: Node2D
var desk: DeskNodes

var form_dragging := false
var envelope_dragging := false


func _init(owner_root: Node2D, owner_desk: DeskNodes) -> void:
	root = owner_root
	desk = owner_desk


# 为当前案件的表单、文件袋和材料连接输入事件。
func bind_case(presenter: CasePresenter) -> void:
	if is_instance_valid(presenter.form):
		presenter.form.gui_input.connect(_on_form_input.bind(presenter))
		presenter.form.mouse_entered.connect(_on_form_hover.bind(presenter, true))
		presenter.form.mouse_exited.connect(_on_form_hover.bind(presenter, false))
	if is_instance_valid(presenter.envelope):
		presenter.envelope.gui_input.connect(_on_envelope_input.bind(presenter))
	for document in presenter.document_panels:
		if is_instance_valid(document):
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
			presenter.form.z_index = 10
			var tween := root.create_tween().set_parallel(true)
			tween.tween_property(presenter.form, "scale", desk.form_base_scale * 1.035, 0.1)
			tween.tween_property(presenter.form, "rotation", -0.012, 0.1)
		else:
			form_dragging = false
			presenter.form.z_index = 5
			var tween := root.create_tween().set_parallel(true)
			tween.tween_property(presenter.form, "scale", desk.form_base_scale, 0.12)
			tween.tween_property(presenter.form, "rotation", 0.0, 0.12)
			if presenter.form.position.x < 300 and presenter.form.position.y > 430:
				presenter.pack_document(presenter.primary_document_id)
	elif event is InputEventMouseMotion and form_dragging:
		presenter.form.position += event.relative


# 文件袋的拖拽、放置到工作台与送交验收槽处理。
func _on_envelope_input(event: InputEvent, presenter: CasePresenter) -> void:
	if not is_instance_valid(presenter.envelope):
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			envelope_dragging = true
			presenter.envelope.z_index = 30
		else:
			envelope_dragging = false
			presenter.envelope.z_index = 12
			if not presenter.envelope_on_desk:
				presenter.set_envelope_on_desk(presenter.envelope.position.x > 300)
				if presenter.envelope_on_desk and is_instance_valid(desk.status_label):
					desk.status_label.text = "文件袋已置于工作台，点击封口拆开。"
			elif presenter.envelope_on_desk and presenter.envelope.get_global_rect().intersects(desk.slot.get_global_rect()):
				envelope_submitted.emit()
	elif event is InputEventMouseMotion and envelope_dragging:
		presenter.envelope.position += event.relative


# 单个材料的拖拽与装袋处理。
func _on_document_input(event: InputEvent, document: Panel, presenter: CasePresenter) -> void:
	if not is_instance_valid(document):
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		document.set_meta("dragging", event.pressed)
		if event.pressed:
			document.z_index = 25
		else:
			document.z_index = 8
			if document.get_global_rect().has_point(DOCUMENT_PACK_POINT):
				presenter.pack_document(String(document.get_meta("document_id")))
	elif event is InputEventMouseMotion and bool(document.get_meta("dragging")):
		document.position += event.relative
