class_name WorkbenchInputModule
extends RefCounted

# 处理工作台中表单、文件袋与证明材料的拖拽、悬停与放手区域判定。

signal envelope_submitted

var root: Node2D
var desk: DeskNodes
var desk_items: DeskItemController

var form_dragging := false
var envelope_dragging := false
var envelope_in_machine_zone := false
var envelope_preview_tween: Tween
var drag_response_multiplier := 1.0


# 保存节点引用并读取缺水状态下的拖拽响应系数。
func _init(owner_root: Node2D, owner_desk: DeskNodes, item_controller: DeskItemController = null) -> void:
	root = owner_root
	desk = owner_desk
	desk_items = item_controller
	drag_response_multiplier = WorkdayState.manager.get_drag_response_multiplier()


# 为当前案件的表单、文件袋和材料连接输入事件。
func bind_case(presenter: WorkbenchCasePresenter) -> void:
	envelope_dragging = false
	envelope_in_machine_zone = false
	for document in presenter.all_document_views:
		if not is_instance_valid(document):
			continue
		CursorManager.watch(document, CursorManager.Cursor.GRAB)
		document.add_to_group("debug_interaction_zone")
		document.set_meta("debug_zone_label", "主表单" if document.document_id == presenter.primary_document_id else "证明材料")
		if desk_items != null:
			desk_items.register_item(
				document, "case_document_%s" % document.document_id, presenter.bring_document_to_front.bind(document.document_id), Callable(), _on_document_settled.bind(presenter)
			)
		else:
			if document.document_id == presenter.primary_document_id:
				document.gui_input.connect(_on_form_input.bind(presenter))
				document.mouse_entered.connect(_on_form_hover.bind(presenter, true))
				document.mouse_exited.connect(_on_form_hover.bind(presenter, false))
			else:
				document.gui_input.connect(_on_document_input.bind(document, presenter))
	if is_instance_valid(presenter.envelope):
		CursorManager.watch(presenter.envelope, CursorManager.Cursor.GRAB)
		presenter.envelope.add_to_group("debug_interaction_zone")
		presenter.envelope.set_meta("debug_zone_label", "文件袋")
		if desk_items != null:
			desk_items.register_item(presenter.envelope, "case_envelope", Callable(), _on_envelope_drag_motion.bind(presenter), _on_envelope_settled.bind(presenter))
		else:
			presenter.envelope.gui_input.connect(_on_envelope_input.bind(presenter))


# 表单落定后若覆盖在打开的文件袋上则装袋。
func _on_form_settled(item: Control, presenter: WorkbenchCasePresenter) -> void:
	if _is_over_open_envelope(item, presenter):
		presenter.pack_document(presenter.primary_document_id)


# 材料落定后若覆盖在打开的文件袋上则装袋。
func _on_document_settled(item: Control, presenter: WorkbenchCasePresenter) -> void:
	if _is_over_open_envelope(item, presenter):
		presenter.pack_document(WorkdayContext.stringify_value(item.get_meta("document_id")))


# 拖动文件袋时检测是否进入归档区并切换预览状态。
func _on_envelope_drag_motion(item: Control, presenter: WorkbenchCasePresenter) -> void:
	var entered := (
		presenter.envelope_on_desk and presenter.all_documents_packed() and is_instance_valid(desk.archive_drop_zone) and item.get_global_rect().intersects(desk.archive_drop_zone.get_global_rect())
	)
	if entered != envelope_in_machine_zone:
		_set_machine_preview(presenter, entered)


# 文件袋落定处理：材料未收齐则提示，进入归档区则触发提交。
func _on_envelope_settled(item: Control, presenter: WorkbenchCasePresenter) -> void:
	if presenter.envelope_opened and not presenter.all_documents_packed():
		_set_machine_preview(presenter, false)
		if is_instance_valid(desk.status_label):
			desk.status_label.text = "文件袋尚未收齐全部文件，不能送验。"
		return
	var entered := presenter.envelope_on_desk and is_instance_valid(desk.archive_drop_zone) and item.get_global_rect().intersects(desk.archive_drop_zone.get_global_rect())
	if entered:
		if is_instance_valid(envelope_preview_tween):
			envelope_preview_tween.kill()
		envelope_submitted.emit()
		return
	_set_machine_preview(presenter, false)
	if not presenter.envelope_on_desk:
		presenter.set_envelope_on_desk(true)
		if is_instance_valid(desk.status_label):
			desk.status_label.text = "文件袋已置于工作台，点击封口拆开。"


# 表单悬停时的缩放反馈。
func _on_form_hover(presenter: WorkbenchCasePresenter, entered: bool) -> void:
	if form_dragging or not is_instance_valid(presenter.form):
		return
	var base_scale := _read_meta_vector(presenter.form, "desk_base_scale", presenter.form.scale)
	var target_scale := base_scale * (1.012 if entered else 1.0)
	var tween := root.create_tween()
	tween.tween_property(presenter.form, "scale", target_scale, 0.08)


# 表单的拖拽与装袋处理。
func _on_form_input(event: InputEvent, presenter: WorkbenchCasePresenter) -> void:
	if not is_instance_valid(presenter.form):
		return
	if event is InputEventMouseButton:
		var mouse_button: InputEventMouseButton = event
		if mouse_button.button_index != MOUSE_BUTTON_LEFT:
			return
		if mouse_button.pressed:
			form_dragging = true
			CursorManager.begin_drag(presenter.form)
			presenter.form.z_index = 10
			var base_scale := _read_meta_vector(presenter.form, "desk_base_scale", presenter.form.scale)
			var tween := root.create_tween().set_parallel(true)
			tween.tween_property(presenter.form, "scale", base_scale * 1.035, 0.1)
			tween.tween_property(presenter.form, "rotation", -0.012, 0.1)
		else:
			form_dragging = false
			CursorManager.end_drag()
			presenter.form.z_index = 5
			var base_scale := _read_meta_vector(presenter.form, "desk_base_scale", presenter.form.scale)
			var tween := root.create_tween().set_parallel(true)
			tween.tween_property(presenter.form, "scale", base_scale, 0.12)
			tween.tween_property(presenter.form, "rotation", 0.0, 0.12)
			if _is_over_open_envelope(presenter.form, presenter):
				presenter.pack_document(presenter.primary_document_id)
	elif event is InputEventMouseMotion and form_dragging:
		var mouse_motion: InputEventMouseMotion = event
		presenter.form.position += mouse_motion.relative * drag_response_multiplier
		CursorManager.set_drag_cursor(CursorManager.Cursor.DROP_VALID if _is_over_open_envelope(presenter.form, presenter) else CursorManager.Cursor.GRABBING)


# 文件袋的拖拽、放置到工作台与送交验收槽处理。
func _on_envelope_input(event: InputEvent, presenter: WorkbenchCasePresenter) -> void:
	if not is_instance_valid(presenter.envelope):
		return
	if presenter.envelope_opened and not presenter.all_documents_packed():
		return
	if event is InputEventMouseButton:
		var mouse_button: InputEventMouseButton = event
		if mouse_button.button_index != MOUSE_BUTTON_LEFT:
			return
		if mouse_button.pressed:
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
		var mouse_motion: InputEventMouseMotion = event
		presenter.envelope.position += mouse_motion.relative * drag_response_multiplier
		var entered := presenter.envelope_on_desk and is_instance_valid(desk.archive_drop_zone) and presenter.envelope.get_global_rect().intersects(desk.archive_drop_zone.get_global_rect())
		if entered != envelope_in_machine_zone:
			_set_machine_preview(presenter, entered)
		CursorManager.set_drag_cursor(CursorManager.Cursor.DROP_VALID if entered else CursorManager.Cursor.GRABBING)


# 切换文件袋进入归档区的预览动画、指示灯与提示。
func _set_machine_preview(presenter: WorkbenchCasePresenter, active: bool) -> void:
	envelope_in_machine_zone = active
	if not is_instance_valid(presenter.envelope):
		return
	if is_instance_valid(envelope_preview_tween):
		envelope_preview_tween.kill()
	presenter.envelope.pivot_offset = presenter.envelope.size / 2.0
	envelope_preview_tween = root.create_tween().set_parallel(true)
	envelope_preview_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	envelope_preview_tween.tween_property(presenter.envelope, "scale", Vector2(0.92, 0.62) if active else Vector2.ONE, 0.14)
	envelope_preview_tween.tween_property(presenter.envelope, "rotation", -0.055 if active else 0.0, 0.14)
	if is_instance_valid(desk.slot_light):
		desk.slot_light.color = Color("d7aa45") if active else WorkbenchUI.COLORS.red
	if is_instance_valid(desk.slot):
		var tray_tween := root.create_tween()
		tray_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tray_tween.tween_property(desk.slot, "scale", Vector2(1.035, 1.035) if active else Vector2.ONE, 0.12)
	if active and is_instance_valid(desk.status_label):
		desk.status_label.text = "归档区已锁定文件袋：松手完成本案归档。"


# 单个材料的拖拽与装袋处理。
func _on_document_input(event: InputEvent, document: Panel, presenter: WorkbenchCasePresenter) -> void:
	if not is_instance_valid(document):
		return
	if event is InputEventMouseButton:
		var mouse_button: InputEventMouseButton = event
		if mouse_button.button_index != MOUSE_BUTTON_LEFT:
			return
		document.set_meta("dragging", mouse_button.pressed)
		if mouse_button.pressed:
			document.z_index = 25
			CursorManager.begin_drag(document)
		else:
			document.z_index = 8
			CursorManager.end_drag()
			if _is_over_open_envelope(document, presenter):
				presenter.pack_document(WorkdayContext.stringify_value(document.get_meta("document_id")))
	elif event is InputEventMouseMotion and WorkdayContext.to_bool(document.get_meta("dragging")):
		var mouse_motion: InputEventMouseMotion = event
		document.position += mouse_motion.relative * drag_response_multiplier
		CursorManager.set_drag_cursor(CursorManager.Cursor.DROP_VALID if _is_over_open_envelope(document, presenter) else CursorManager.Cursor.GRABBING)


# 判断物件是否覆盖在已打开且可见的文件袋上。
func _is_over_open_envelope(item: Control, presenter: WorkbenchCasePresenter) -> bool:
	return presenter.envelope_opened and is_instance_valid(presenter.envelope) and presenter.envelope.visible and item.get_global_rect().intersects(presenter.envelope.get_global_rect())


# 从物品元数据安全读取 Vector2。
func _read_meta_vector(item: Control, key: String, fallback: Vector2) -> Vector2:
	var value: Variant = item.get_meta(key, fallback)
	return value if value is Vector2 else fallback
