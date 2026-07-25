class_name WorkbenchBatchValidationModule
extends RefCounted

signal finished

const MACHINE_TEXTURE := preload("res://assets/concepts/endday_validation/validation_machine_topdown_concept.png")
const MACHINE_INTAKE_FOREGROUND_TEXTURE := preload("res://assets/concepts/endday_validation/validation_machine_intake_foreground.png")
const MACHINE_LIGHTS_TEXTURE := preload("res://assets/concepts/endday_validation/validation_machine_lights.png")
const RAIL_MACHINE_CAP_TEXTURE := preload("res://assets/concepts/endday_validation/validation_rail_machine_cap.png")
const RAIL_MIDDLE_TEXTURE := preload("res://assets/concepts/endday_validation/validation_rail_middle.png")
const RAIL_BOTTOM_CAP_TEXTURE := preload("res://assets/concepts/endday_validation/validation_rail_bottom_cap.png")
const DOCUMENT_BAG_TEXTURE := preload("res://assets/documents/envelopes/bureau_envelope_closed.png")

const DESIGN_SIZE := Vector2(1280, 720)
const MACHINE_POSITION := Vector2(360, -100)
const MACHINE_SIZE := Vector2(560, 560)
const DOCUMENT_CLIP_Y := 278.0
const DOCUMENT_BAG_SIZE := Vector2(94, 144)
const BELT_ENTRY_POSITION := Vector2(593, 242)
const MACHINE_INGEST_POSITION := Vector2(593, -152)

var root: Node2D
var overlay: Control
var archive_strip: ScrollContainer
var archive_row: HBoxContainer
var document_clip: Control
var machine_body: TextureRect
var machine_intake_foreground: TextureRect
var machine_lights: TextureRect
var rail_machine_cap: TextureRect
var active_document_bag: TextureRect
var capacity_label: Label
var instruction_label: Label
var machine_state_label: Label
var confirm_button: Button
var leave_button: Button
var selected_ids: Array[String] = []
var archive_order: Array[String] = []
var buttons: Dictionary = {}
var in_flight_archive_id := ""
var ingesting := false
var finishing := false


# 初始化独立的俯视日终送验视图。
func _init(owner_root: Node2D) -> void:
	root = owner_root
	overlay = Control.new()
	overlay.name = "BatchValidationOverlay"
	overlay.position = Vector2.ZERO
	overlay.size = DESIGN_SIZE
	overlay.z_index = 120
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.visible = false
	root.add_child(overlay)
	_build_validation_view()


# 按地面、轨道、机器、文件袋、入口遮挡的顺序组装视图。
func _build_validation_view() -> void:
	_build_floor()
	_build_rail()
	_build_machine()
	_build_document_clip()
	_build_status_panels()
	_build_archive_queue()

	# 保留旧测试与调试入口；实际玩家流程在装满容量后自动确认。
	confirm_button = Button.new()
	confirm_button.name = "HiddenBatchConfirm"
	confirm_button.visible = false
	confirm_button.pressed.connect(confirm)
	overlay.add_child(confirm_button)


# 使用克制的模块化地板衬托独立资产，不再烘焙验收室背景。
func _build_floor() -> void:
	var floor := ColorRect.new()
	floor.name = "ValidationFloor"
	floor.color = Color("171917")
	floor.size = DESIGN_SIZE
	floor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(floor)

	var vignette := ColorRect.new()
	vignette.name = "ValidationFloorTint"
	vignette.color = Color(0.02, 0.025, 0.022, 0.28)
	vignette.size = DESIGN_SIZE
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vignette.z_index = 1
	overlay.add_child(vignette)

	for x: int in range(0, 1281, 160):
		var vertical := ColorRect.new()
		vertical.color = Color("3a3b354d")
		vertical.position = Vector2(x, 0)
		vertical.size = Vector2(1, 720)
		vertical.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vertical.z_index = 1
		overlay.add_child(vertical)
	for y: int in range(0, 721, 144):
		var horizontal := ColorRect.new()
		horizontal.color = Color("3a3b354d")
		horizontal.position = Vector2(0, y)
		horizontal.size = Vector2(1280, 1)
		horizontal.mouse_filter = Control.MOUSE_FILTER_IGNORE
		horizontal.z_index = 1
		overlay.add_child(horizontal)


# 轨道三件套保持独立，当前视口内按 2 px 重叠消除接缝。
func _build_rail() -> void:
	rail_machine_cap = _add_texture("ValidationRailMachineCap", RAIL_MACHINE_CAP_TEXTURE, Vector2(550, 292), Vector2(180, 260), 3)
	_add_texture("ValidationRailMiddle", RAIL_MIDDLE_TEXTURE, Vector2(550, 516), Vector2(180, 305), 3)
	_add_texture("ValidationRailBottomCap", RAIL_BOTTOM_CAP_TEXTURE, Vector2(550, 626), Vector2(180, 380), 3)


# 机器主体、状态灯与入口前景使用相同画布和原点。
func _build_machine() -> void:
	machine_body = _add_texture("ValidationMachineBody", MACHINE_TEXTURE, MACHINE_POSITION, MACHINE_SIZE, 10)
	machine_lights = _add_texture("ValidationMachineLights", MACHINE_LIGHTS_TEXTURE, MACHINE_POSITION, MACHINE_SIZE, 24)
	machine_lights.visible = false
	machine_intake_foreground = _add_texture("ValidationMachineIntakeForeground", MACHINE_INTAKE_FOREGROUND_TEXTURE, MACHINE_POSITION, MACHINE_SIZE, 30)


# 文件袋只在机器口以下可见，越过裁切线后自然消失。
func _build_document_clip() -> void:
	document_clip = Control.new()
	document_clip.name = "ValidationDocumentClip"
	document_clip.position = Vector2(0, DOCUMENT_CLIP_Y)
	document_clip.size = Vector2(1280, 720 - DOCUMENT_CLIP_Y)
	document_clip.clip_contents = true
	document_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	document_clip.z_index = 20
	overlay.add_child(document_clip)


# 顶部保留每日上限与运行状态，右侧提供随时结束送验的离开入口。
func _build_status_panels() -> void:
	var title_panel := Panel.new()
	title_panel.name = "ValidationTitlePanel"
	title_panel.position = Vector2(22, 18)
	title_panel.size = Vector2(310, 68)
	title_panel.z_index = 50
	title_panel.add_theme_stylebox_override("panel", WorkbenchUI.style_box(Color("0a0f0ced"), 3, Color("6e693f"), 2))
	overlay.add_child(title_panel)
	WorkbenchUI.add_text(title_panel, "日终送验", 22, Color("dfd09c"), Vector2(18, 9), Vector2(250, 30))
	WorkbenchUI.add_text(title_panel, "仅接收已盖章档案 · 送验无最低数量", 11, Color("8f9470"), Vector2(18, 38), Vector2(280, 20))

	var capacity_panel := Panel.new()
	capacity_panel.name = "ValidationCapacityPanel"
	capacity_panel.position = Vector2(930, 18)
	capacity_panel.size = Vector2(328, 68)
	capacity_panel.z_index = 50
	capacity_panel.add_theme_stylebox_override("panel", WorkbenchUI.style_box(Color("0a0f0ced"), 3, Color("6e693f"), 2))
	overlay.add_child(capacity_panel)
	capacity_label = WorkbenchUI.add_text(capacity_panel, "", 16, Color("d0ad58"), Vector2(12, 19), Vector2(304, 30))
	capacity_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	machine_state_label = WorkbenchUI.add_text(overlay, "现实验收机待机", 14, Color("d1b65f"), Vector2(470, 376), Vector2(340, 28))
	machine_state_label.z_index = 48
	machine_state_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	instruction_label = WorkbenchUI.add_text(overlay, "选择一个文件袋，装入中央轨道", 16, Color("e2d7b4"), Vector2(350, 516), Vector2(580, 30))
	instruction_label.z_index = 48
	instruction_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	leave_button = Button.new()
	leave_button.name = "LeaveValidationButton"
	leave_button.text = "离开送验间"
	leave_button.position = Vector2(1032, 464)
	leave_button.size = Vector2(216, 58)
	leave_button.z_index = 52
	leave_button.focus_mode = Control.FOCUS_ALL
	leave_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	leave_button.add_theme_font_size_override("font_size", 18)
	leave_button.add_theme_color_override("font_color", Color("e7d9ac"))
	leave_button.add_theme_color_override("font_hover_color", Color("fff0b7"))
	leave_button.add_theme_stylebox_override("normal", WorkbenchUI.style_box(Color("101711ed"), 4, Color("817848"), 2))
	leave_button.add_theme_stylebox_override("hover", WorkbenchUI.style_box(Color("283226f5"), 4, Color("d1b65f"), 2))
	leave_button.add_theme_stylebox_override("pressed", WorkbenchUI.style_box(Color("353c2cf5"), 4, Color("f0d67d"), 2))
	leave_button.pressed.connect(_on_leave_pressed)
	overlay.add_child(leave_button)


# 底部队列只负责选择，运输时会生成同尺寸的独立文件袋实体。
func _build_archive_queue() -> void:
	var archive_panel := Panel.new()
	archive_panel.name = "ArchiveLoadingDesk"
	archive_panel.position = Vector2(32, 550)
	archive_panel.size = Vector2(1216, 166)
	archive_panel.z_index = 40
	archive_panel.add_theme_stylebox_override("panel", WorkbenchUI.style_box(Color("080d0aef"), 4, Color("6e693f"), 2))
	overlay.add_child(archive_panel)

	archive_strip = ScrollContainer.new()
	archive_strip.name = "ArchiveStrip"
	archive_strip.position = Vector2(14, 7)
	archive_strip.size = Vector2(1188, 152)
	archive_strip.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	archive_strip.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	archive_panel.add_child(archive_strip)

	archive_row = HBoxContainer.new()
	archive_row.name = "ArchiveRow"
	archive_row.custom_minimum_size = Vector2(1180, 146)
	archive_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	archive_row.alignment = BoxContainer.ALIGNMENT_CENTER
	archive_row.add_theme_constant_override("separation", 10)
	archive_strip.add_child(archive_row)


func _add_texture(node_name: String, texture: Texture2D, texture_position: Vector2, texture_size: Vector2, texture_z_index: int) -> TextureRect:
	var texture_rect := TextureRect.new()
	texture_rect.name = node_name
	texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	texture_rect.texture = texture
	texture_rect.position = texture_position
	texture_rect.size = texture_size
	texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	texture_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	texture_rect.z_index = texture_z_index
	overlay.add_child(texture_rect)
	return texture_rect


# 打开视图，把全部待验档案映射为文件袋队列，不按章或内容预筛选。
func open() -> void:
	selected_ids.clear()
	archive_order.clear()
	buttons.clear()
	in_flight_archive_id = ""
	ingesting = false
	finishing = false
	if is_instance_valid(active_document_bag):
		active_document_bag.queue_free()
	active_document_bag = null
	for child: Node in archive_row.get_children():
		child.queue_free()
	var pending_archives := _get_pending_archives()
	for archive: Dictionary in pending_archives:
		_add_archive_bag(archive)
	overlay.visible = true
	overlay.modulate = Color.WHITE
	machine_lights.visible = false
	machine_lights.modulate = Color.WHITE
	machine_state_label.text = "现实验收机待机"
	leave_button.disabled = false
	_refresh()


# 为待验档案生成竖向文件袋按钮。
func _add_archive_bag(archive: Dictionary) -> void:
	var archive_id := WorkdayContext.read_string(archive, "archive_id")
	var applicant := WorkdayContext.read_string(archive, "applicant", "身份受限")
	var decision := WorkdayContext.read_string(archive, "decision", "未决")
	var waiting_days := WorkdayContext.read_int(archive, "waiting_days")
	var button := Button.new()
	button.name = archive_id
	button.custom_minimum_size = Vector2(116, 146)
	button.pivot_offset = Vector2(58, 73)
	button.flat = true
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_stylebox_override("normal", WorkbenchUI.style_box(Color("11150f00"), 0, Color("766c4300"), 0))
	button.add_theme_stylebox_override("hover", WorkbenchUI.style_box(Color("293127c0"), 3, Color("b8a15c"), 2))
	button.add_theme_stylebox_override("pressed", WorkbenchUI.style_box(Color("34382bc0"), 3, Color("dcc46e"), 2))
	button.pressed.connect(_on_archive_pressed.bind(archive_id, button))
	button.mouse_entered.connect(_animate_archive_hover.bind(button, true))
	button.mouse_exited.connect(_animate_archive_hover.bind(button, false))
	archive_row.add_child(button)

	var bag := TextureRect.new()
	bag.name = "DocumentBag"
	bag.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bag.texture = DOCUMENT_BAG_TEXTURE
	bag.position = Vector2(18, 0)
	bag.size = Vector2(80, 122)
	bag.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	bag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bag.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	button.add_child(bag)

	var id_label := WorkbenchUI.add_text(button, archive_id, 9, Color("d3c59a"), Vector2(3, 108), Vector2(110, 17))
	id_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var decision_color := Color("91b28b") if decision == "批准" else Color("c98277")
	var detail_label := WorkbenchUI.add_text(button, "%s · %s · %d日" % [applicant, decision, waiting_days], 8, decision_color, Vector2(2, 126), Vector2(112, 16))
	detail_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	archive_order.append(archive_id)
	buttons[archive_id] = button


# 点击后生成运输实体；只有文件袋完全吞入时才计入本批送验。
func _on_archive_pressed(archive_id: String, button: Button) -> void:
	if ingesting or finishing or archive_id in selected_ids:
		return
	if selected_ids.size() >= _current_batch_limit():
		return
	ingesting = true
	in_flight_archive_id = archive_id
	button.disabled = true
	var global_start := button.global_position + (button.size - DOCUMENT_BAG_SIZE) * 0.5
	button.visible = false
	active_document_bag = TextureRect.new()
	active_document_bag.name = "ActiveDocumentBag"
	active_document_bag.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	active_document_bag.texture = DOCUMENT_BAG_TEXTURE
	active_document_bag.position = global_start - document_clip.global_position
	active_document_bag.size = DOCUMENT_BAG_SIZE
	active_document_bag.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	active_document_bag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	active_document_bag.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	active_document_bag.pivot_offset = DOCUMENT_BAG_SIZE * 0.5
	active_document_bag.scale = Vector2.ONE
	document_clip.add_child(active_document_bag)

	_refresh()
	machine_state_label.text = "轨道装载中 · %s" % archive_id
	instruction_label.text = "文件袋正在送往验收机"
	machine_lights.visible = true
	machine_lights.modulate = Color(1.0, 0.72, 0.42, 0.72)
	Sfx.start_conveyor()

	var load_tween := root.create_tween()
	load_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	load_tween.tween_property(active_document_bag, "position", BELT_ENTRY_POSITION, 0.28)
	await load_tween.finished

	machine_state_label.text = "文件袋吞入中 · %s" % archive_id
	var light_tween := root.create_tween()
	light_tween.set_loops(4)
	light_tween.tween_property(machine_lights, "modulate:a", 1.0, 0.10)
	light_tween.tween_property(machine_lights, "modulate:a", 0.52, 0.10)
	var ingest_tween := root.create_tween()
	ingest_tween.set_trans(Tween.TRANS_LINEAR)
	ingest_tween.tween_property(active_document_bag, "position", MACHINE_INGEST_POSITION, 0.82)
	await ingest_tween.finished
	light_tween.kill()
	Sfx.stop_conveyor()

	if is_instance_valid(active_document_bag):
		active_document_bag.queue_free()
	active_document_bag = null
	selected_ids.append(archive_id)
	in_flight_archive_id = ""
	buttons.erase(archive_id)
	button.queue_free()
	ingesting = false
	_send_secretary_pick_comment(archive_id)
	machine_lights.modulate = Color(1.0, 0.82, 0.52, 0.72)
	machine_state_label.text = "文件袋已吞入 · %s" % archive_id
	instruction_label.text = "该档案已进入机器，不得撤回"
	_refresh()
	await root.get_tree().create_timer(0.24).timeout
	if not finishing:
		machine_lights.visible = false
		_refresh()


# 离开按钮负责主动结束送验；零件直接离开，有已送入档案时先完成验收。
func _on_leave_pressed() -> void:
	if ingesting or finishing:
		return
	if selected_ids.is_empty():
		finishing = true
		leave_button.disabled = true
		instruction_label.text = "本日未送验档案，正在离开"
		machine_state_label.text = "送验结束"
		overlay.visible = false
		finished.emit()
		return
	await confirm(false)


# 队列悬停只抬起待选文件袋，不影响运输实体。
func _animate_archive_hover(button: Button, hovered: bool) -> void:
	if ingesting or finishing or button.disabled:
		return
	var tween := root.create_tween()
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(button, "scale", Vector2(1.035, 1.035) if hovered else Vector2.ONE, 0.10)
	tween.parallel().tween_property(button, "modulate", Color(1.08, 1.05, 0.92, 1.0) if hovered else Color.WHITE, 0.10)


# 自动选择前 N 个待验案件，供测试和调试跳过逐袋动画。
func select_first_up_to_capacity() -> void:
	for archive_id: String in archive_order:
		if selected_ids.size() >= _current_batch_limit():
			break
		selected_ids.append(archive_id)
		var button := buttons.get(archive_id) as Button
		if button == null:
			continue
		button.disabled = true
		button.visible = false
	_refresh()


# 验收已吞入的文件袋，并沿用现有现实回执与日报跳转。
func confirm(skip_animation: bool = false) -> void:
	if finishing or selected_ids.is_empty() or ingesting:
		return
	finishing = true
	leave_button.disabled = true
	instruction_label.text = "验收机正在写入现实效力"
	machine_state_label.text = "整批验收中"
	machine_lights.visible = true
	machine_lights.modulate = Color(0.68, 1.0, 0.62, 0.82)
	if not skip_animation:
		Sfx.start_conveyor()
		var pulse := root.create_tween()
		pulse.set_loops(2)
		pulse.tween_property(machine_lights, "modulate:a", 1.0, 0.12)
		pulse.tween_property(machine_lights, "modulate:a", 0.58, 0.12)
		await pulse.finished
		Sfx.stop_conveyor()
	var submitted_archives := _get_selected_archives()
	if not WorkdayState.manager.validate_archive_batch(selected_ids):
		finishing = false
		open()
		machine_state_label.text = "验收失败 · 已恢复待验文件袋"
		return
	_send_validation_receipts(submitted_archives)
	instruction_label.text = "本批文件袋已取得现实效力"
	machine_state_label.text = "验收完成"
	if not skip_animation:
		await root.get_tree().create_timer(0.38).timeout
	overlay.visible = false
	finished.emit()


# 当前批次只有每日上限，没有最低送验数量。
func _current_batch_limit() -> int:
	return maxi(0, WorkdayState.machine_capacity)


# 返回全部待验档案；错误内容由归档快照和程序记录表达，不在这里阻止送验。
func _get_pending_archives() -> Array[Dictionary]:
	return WorkdayState.manager.get_pending_archives()


func _get_selected_archives() -> Array[Dictionary]:
	var selected: Array[Dictionary] = []
	for archive: Dictionary in _get_pending_archives():
		if WorkdayContext.read_string(archive, "archive_id") in selected_ids:
			selected.append(archive.duplicate(true))
	return selected


# 文件袋完成吞入后，把这次不可撤回的选择交给眼镜秘书评论。
func _send_secretary_pick_comment(archive_id: String) -> void:
	var bridge := root.get_tree().root.get_node_or_null("RealityBridge")
	if bridge == null:
		return
	for archive: Dictionary in _get_pending_archives():
		if WorkdayContext.read_string(archive, "archive_id") != archive_id:
			continue
		var errors := WorkdayContext.read_array(archive, "procedure_errors")
		var waiting_days := WorkdayContext.read_int(archive, "waiting_days")
		var fact_parts: Array[String] = []
		if not errors.is_empty():
			fact_parts.append("程序记录存在 %d 项异常" % errors.size())
		if waiting_days > 0:
			fact_parts.append("该档案已等待 %d 日" % waiting_days)
		bridge.call(
			"secretary_pick_comment",
			WorkdayContext.read_string(archive, "case_id", archive_id),
			WorkdayContext.read_string(archive, "request", WorkdayContext.read_string(archive, "applicant", "未登记档案")),
			"add",
			maxi(0, _current_batch_limit() - selected_ids.size()),
			"；".join(fact_parts)
		)
		return


func _send_validation_receipts(archives: Array[Dictionary]) -> void:
	var bridge := root.get_tree().root.get_node_or_null("RealityBridge")
	if bridge == null:
		return
	for archive: Dictionary in archives:
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


func _refresh() -> void:
	var pending_archives := _get_pending_archives()
	var pending_count := pending_archives.size()
	var batch_limit := _current_batch_limit()
	var loaded_count := selected_ids.size() + (1 if ingesting else 0)
	var selectable_count := maxi(0, pending_count - loaded_count)
	capacity_label.text = (
		"已送入　%02d / 上限 %02d　　可选　%02d"
		% [
			loaded_count,
			batch_limit,
			selectable_count,
		]
	)
	leave_button.disabled = ingesting or finishing
	if ingesting or finishing:
		return
	if batch_limit <= 0:
		machine_state_label.text = "今日送验额度为零"
		instruction_label.text = "今日不可送验档案；点击右侧“离开送验间”"
	elif selected_ids.size() >= batch_limit:
		machine_state_label.text = "今日送验已达上限"
		instruction_label.text = "无法继续送入；点击右侧“离开送验间”结算"
	elif pending_count <= selected_ids.size():
		machine_state_label.text = "没有更多待验档案"
		instruction_label.text = "可点击右侧“离开送验间”结束本日"
	elif selected_ids.is_empty():
		machine_state_label.text = "现实验收机待机"
		instruction_label.text = "可送验 0–%d 个；选择任意文件袋，或直接离开" % mini(batch_limit, pending_count)
	else:
		machine_state_label.text = "已送入 %d 个文件袋" % selected_ids.size()
		instruction_label.text = "还可送入 %d 个；也可以直接离开" % (batch_limit - selected_ids.size())
