class_name WorkbenchBatchValidationModule
extends RefCounted

signal finished

var root: Node2D
var overlay: Control
var list_box: VBoxContainer
var capacity_label: Label
var confirm_button: Button
var selected_ids: Array[String] = []
var buttons: Dictionary = {}


# 初始化批量验证界面：遮罩、托盘、容量标签与确认按钮。
func _init(owner_root: Node2D) -> void:
	root = owner_root
	overlay = Control.new()
	overlay.name = "BatchValidationOverlay"
	overlay.position = Vector2.ZERO
	overlay.size = Vector2(1280, 720)
	overlay.z_index = 120
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.visible = false
	root.add_child(overlay)
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.72)
	shade.size = overlay.size
	overlay.add_child(shade)
	var panel := Panel.new()
	panel.name = "ValidationTray"
	panel.position = Vector2(335, 82)
	panel.size = Vector2(610, 555)
	panel.add_theme_stylebox_override("panel", WorkbenchUI.style_box(Color("11150f"), 6, Color("a78a52"), 3))
	overlay.add_child(panel)
	WorkbenchUI.add_text(panel, "日终统一送验 / 档案装载托盘", 24, Color("e0d1aa"), Vector2(28, 22), Vector2(550, 38))
	capacity_label = WorkbenchUI.add_text(panel, "", 16, Color("aabd78"), Vector2(28, 66), Vector2(550, 28))
	list_box = VBoxContainer.new()
	list_box.position = Vector2(28, 108)
	list_box.size = Vector2(554, 340)
	list_box.add_theme_constant_override("separation", 8)
	panel.add_child(list_box)
	confirm_button = Button.new()
	confirm_button.text = "确认整批送入现实验收设施"
	confirm_button.position = Vector2(145, 475)
	confirm_button.size = Vector2(320, 52)
	confirm_button.pressed.connect(confirm)
	panel.add_child(confirm_button)


# 打开批量验证界面，列出所有待验归档案件。
func open() -> void:
	selected_ids.clear()
	buttons.clear()
	for child: Node in list_box.get_children():
		child.queue_free()
	for archive: Dictionary in WorkdayState.manager.get_pending_archives():
		var archive_id := WorkdayContext.read_string(archive, "archive_id")
		var button := Button.new()
		button.toggle_mode = true
		button.text = (
			"%s  %s  [%s]  等待 %d 日"
			% [
				archive_id,
				WorkdayContext.read_string(archive, "applicant", "身份受限"),
				WorkdayContext.read_string(archive, "decision", "未决"),
				WorkdayContext.read_int(archive, "waiting_days"),
			]
		)
		button.custom_minimum_size = Vector2(540, 48)
		button.toggled.connect(_on_archive_toggled.bind(archive_id, button))
		list_box.add_child(button)
		buttons[archive_id] = button
	overlay.visible = true
	_refresh()


# 归档案件按钮被切换时更新已选列表，并防止超过机器容量。
func _on_archive_toggled(pressed: bool, archive_id: String, button: Button) -> void:
	if pressed:
		if selected_ids.size() >= WorkdayState.machine_capacity:
			button.set_pressed_no_signal(false)
			return
		selected_ids.append(archive_id)
	else:
		selected_ids.erase(archive_id)
	_refresh()


# 自动选择前 N 个待验案件，直到达到机器容量上限。
func select_first_up_to_capacity() -> void:
	for archive_id: String in buttons:
		if selected_ids.size() >= WorkdayState.machine_capacity:
			break
		selected_ids.append(archive_id)
		var button: Button = buttons[archive_id]
		button.set_pressed_no_signal(true)
	_refresh()


# 确认批量送验，播放吞入动画，验证后发送回执并关闭界面。
func confirm(skip_animation: bool = false) -> void:
	if selected_ids.is_empty():
		return
	var submitted_archives := _get_selected_archives()
	confirm_button.disabled = true
	if not skip_animation:
		Sfx.start_conveyor()
		var tray: Control = overlay.get_node("ValidationTray")
		tray.pivot_offset = tray.size / 2.0
		var ingest := root.create_tween().set_parallel(true)
		ingest.tween_property(tray, "position", Vector2(510, 205), 0.55)
		ingest.tween_property(tray, "scale", Vector2(0.38, 0.08), 0.55)
		ingest.tween_property(tray, "modulate:a", 0.0, 0.18).set_delay(0.37)
		await ingest.finished
		Sfx.stop_conveyor()
	if not WorkdayState.manager.validate_archive_batch(selected_ids):
		confirm_button.disabled = false
		return
	_send_validation_receipts(submitted_archives)
	overlay.visible = false
	finished.emit()


# 返回当前已选归档案件的完整数据副本。
func _get_selected_archives() -> Array[Dictionary]:
	var selected: Array[Dictionary] = []
	for archive: Dictionary in WorkdayState.manager.get_pending_archives():
		if WorkdayContext.read_string(archive, "archive_id") in selected_ids:
			selected.append(archive.duplicate(true))
	return selected


# 向 RealityBridge 发送每份已验档案的现实验收回执。
func _send_validation_receipts(archives: Array[Dictionary]) -> void:
	var bridge := root.get_tree().root.get_node_or_null("RealityBridge")
	if bridge == null:
		return
	for archive in archives:
		var errors := WorkdayContext.read_array(archive, "procedure_errors")
		var applicant := WorkdayContext.read_string(archive, "applicant", "身份受限")
		var decision := WorkdayContext.read_string(archive, "decision", "未决")
		var procedure_text := "完整" if errors.is_empty() else "、".join(errors)
		bridge.call(
			"reality_receipt",
			"%s · 现实验收回执" % applicant,
			"处理决定：%s\n程序记录：%s\n档案已取得现实效力" % [decision, procedure_text],
			"normal" if errors.is_empty() else "warning",
			WorkdayState.day_number,
			WorkdayContext.read_string(archive, "case_id"),
			"approved" if decision == "批准" else "rejected"
		)


# 刷新容量标签与确认按钮可用状态。
func _refresh() -> void:
	capacity_label.text = (
		"今日机器容量：已装载 %d / %d　积压总量：%d"
		% [
			selected_ids.size(),
			WorkdayState.machine_capacity,
			WorkdayState.manager.get_pending_archives().size(),
		]
	)
	confirm_button.disabled = selected_ids.is_empty()
