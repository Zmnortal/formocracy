class_name WorkbenchBatchValidationModule
extends RefCounted

signal finished

const MACHINE_TEXTURE := preload("res://assets/concepts/endday_validation/validation_machine_topdown_concept.png")
const MACHINE_INTAKE_FOREGROUND_TEXTURE := preload("res://assets/concepts/endday_validation/validation_machine_intake_foreground.png")
const MACHINE_LIGHTS_TEXTURE := preload("res://assets/concepts/endday_validation/validation_machine_lights.png")
const INSPECTION_DESK_TEXTURE := preload("res://assets/concepts/endday_validation/validation_inspection_desk_background.png")
const RAIL_MACHINE_CAP_TEXTURE := preload("res://assets/concepts/endday_validation/validation_rail_machine_cap.png")
const RAIL_MIDDLE_TEXTURE := preload("res://assets/concepts/endday_validation/validation_rail_middle.png")
const RAIL_BOTTOM_CAP_TEXTURE := preload("res://assets/concepts/endday_validation/validation_rail_bottom_cap.png")
const DOCUMENT_BAG_TEXTURE := preload("res://assets/documents/envelopes/bureau_envelope_closed.png")

const DESIGN_SIZE := Vector2(1280, 720)
const MACHINE_POSITION := Vector2(490, -78)
const MACHINE_SIZE := Vector2(300, 300)
const DOCUMENT_CLIP_Y := 118.0
const DOCUMENT_BAG_SIZE := Vector2(84, 128)
const BELT_STAGING_POSITION := Vector2(605, 182)
const MACHINE_INGEST_POSITION := Vector2(605, -100)
const ARCHIVE_SLOT_POSITIONS: Array[Vector2] = [
	Vector2(238, 438),
	Vector2(425, 438),
	Vector2(622, 438),
	Vector2(813, 438),
	Vector2(1005, 438),
]
const WAITING_ZONE_Y := 272.0
const WAITING_ZONE_CENTER_X := 640.0
const WAITING_ZONE_SPACING := 200.0

var root: Node2D
var overlay: Control
var archive_strip: Control
var archive_row: Control
var document_clip: Control
var desk_background: TextureRect
var machine_body: TextureRect
var machine_intake_foreground: TextureRect
var machine_lights: TextureRect
var rail_machine_cap: TextureRect
var active_document_bag: TextureRect
var capacity_label: Label
var capacity_meter: ProgressBar
var selection_label: Label
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


# 以完整的行政检验桌底图建立空间，让选择位、待送区与机器成为同一件装置。
func _build_floor() -> void:
	var floor := ColorRect.new()
	floor.name = "ValidationFloor"
	floor.color = Color("070907")
	floor.size = DESIGN_SIZE
	floor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(floor)

	desk_background = _add_texture(
		"ValidationInspectionDesk",
		INSPECTION_DESK_TEXTURE,
		Vector2.ZERO,
		DESIGN_SIZE,
		1
	)
	desk_background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED

	var vignette := ColorRect.new()
	vignette.name = "ValidationFloorTint"
	vignette.color = Color(0.005, 0.008, 0.006, 0.12)
	vignette.size = DESIGN_SIZE
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vignette.z_index = 2
	overlay.add_child(vignette)


# 轨道缩短到桌面待送区与机器之间，避免像一条穿过整张页面的装饰线。
func _build_rail() -> void:
	rail_machine_cap = _add_texture(
		"ValidationRailMachineCap",
		RAIL_MACHINE_CAP_TEXTURE,
		Vector2(595, 148),
		Vector2(90, 112),
		6
	)
	_add_texture(
		"ValidationRailMiddle",
		RAIL_MIDDLE_TEXTURE,
		Vector2(595, 230),
		Vector2(90, 52),
		6
	)
	_add_texture(
		"ValidationRailBottomCap",
		RAIL_BOTTOM_CAP_TEXTURE,
		Vector2(595, 258),
		Vector2(90, 42),
		6
	)


# 机器只露出必要的入口体量，视觉重点留给桌面上的玩家选择。
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


# 信息被压缩进墙上的铭牌、机械计数器与右侧纸质清单，不再悬浮遮挡轨道。
func _build_status_panels() -> void:
	var title_panel := Panel.new()
	title_panel.name = "ValidationTitlePanel"
	title_panel.position = Vector2(66, 28)
	title_panel.size = Vector2(224, 52)
	title_panel.z_index = 50
	title_panel.add_theme_stylebox_override("panel", WorkbenchUI.style_box(Color("856a3bdc"), 3, Color("c2a15a"), 2))
	overlay.add_child(title_panel)
	var title := WorkbenchUI.add_text(title_panel, "日终送验", 22, Color("211a0e"), Vector2.ZERO, title_panel.size)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	var capacity_panel := Panel.new()
	capacity_panel.name = "ValidationCapacityPanel"
	capacity_panel.position = Vector2(84, 96)
	capacity_panel.size = Vector2(202, 58)
	capacity_panel.z_index = 50
	capacity_panel.add_theme_stylebox_override("panel", WorkbenchUI.style_box(Color("171913e8"), 2, Color("6e6243"), 1))
	overlay.add_child(capacity_panel)
	WorkbenchUI.add_text(capacity_panel, "今日送验额度", 8, Color("8f8a72"), Vector2(12, 7), Vector2(92, 16))
	capacity_label = WorkbenchUI.add_text(capacity_panel, "", 14, Color("dfbd62"), Vector2(85, 6), Vector2(104, 22))
	capacity_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	capacity_meter = ProgressBar.new()
	capacity_meter.name = "ValidationCapacityMeter"
	capacity_meter.position = Vector2(12, 38)
	capacity_meter.size = Vector2(178, 8)
	capacity_meter.show_percentage = false
	capacity_meter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	capacity_meter.add_theme_stylebox_override("background", WorkbenchUI.style_box(Color("161b16"), 1, Color("4e503f"), 1))
	capacity_meter.add_theme_stylebox_override("fill", WorkbenchUI.style_box(Color("b99843"), 1, Color("d5bb67"), 0))
	capacity_panel.add_child(capacity_meter)

	var checklist_title := WorkbenchUI.add_text(overlay, "送验清单", 12, Color("4a3d27"), Vector2(1000, 34), Vector2(144, 20))
	checklist_title.z_index = 50
	var checklist_items := WorkbenchUI.add_text(
		overlay,
		"1  公民序号\n2  档案编号\n3  封装完好\n4  未超上限",
		8,
		Color("51432b"),
		Vector2(1000, 68),
		Vector2(144, 78)
	)
	checklist_items.z_index = 50
	machine_state_label = WorkbenchUI.add_text(
		overlay,
		"现实验收机待机",
		9,
		Color("3f3421"),
		Vector2(1000, 154),
		Vector2(144, 24)
	)
	machine_state_label.z_index = 50
	machine_state_label.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	instruction_label = WorkbenchUI.add_text(
		overlay,
		"从下方编号位选择档案，确认后依次送入。",
		7,
		Color("493c27"),
		Vector2(1000, 182),
		Vector2(144, 42)
	)
	instruction_label.z_index = 50
	instruction_label.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY


# 文件袋直接落在桌垫编号位上；选中后整袋移动至待送区，形成可见的空间状态。
func _build_archive_queue() -> void:
	archive_strip = Control.new()
	archive_strip.name = "ArchiveStrip"
	archive_strip.position = Vector2.ZERO
	archive_strip.size = DESIGN_SIZE
	archive_strip.mouse_filter = Control.MOUSE_FILTER_PASS
	archive_strip.z_index = 40
	overlay.add_child(archive_strip)

	archive_row = Control.new()
	archive_row.name = "ArchiveRow"
	archive_row.position = Vector2.ZERO
	archive_row.size = DESIGN_SIZE
	archive_row.mouse_filter = Control.MOUSE_FILTER_PASS
	archive_strip.add_child(archive_row)
	for slot_index: int in ARCHIVE_SLOT_POSITIONS.size():
		var fixed_slot_number := WorkbenchUI.add_text(
			archive_strip,
			"%d" % (slot_index + 1),
			13,
			Color("81765d"),
			ARCHIVE_SLOT_POSITIONS[slot_index] + Vector2(5, 171),
			Vector2(140, 20)
		)
		fixed_slot_number.name = "ArchiveSlotNumber%d" % (slot_index + 1)
		fixed_slot_number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		fixed_slot_number.z_index = 42

	WorkbenchUI.add_text(archive_strip, "待送区", 9, Color("8e8058"), Vector2(599, 330), Vector2(82, 18))
	selection_label = WorkbenchUI.add_text(
		archive_strip,
		"00 份",
		14,
		Color("d6ba68"),
		Vector2(594, 348),
		Vector2(92, 28)
	)
	selection_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	WorkbenchUI.add_text(
		archive_strip,
		"点击文件袋加入待送区 · 再次点击撤回",
		9,
		Color("918a70"),
		Vector2(442, 674),
		Vector2(394, 20)
	)

	leave_button = Button.new()
	leave_button.name = "LeaveValidationButton"
	leave_button.text = "直接离开"
	leave_button.position = Vector2(1080, 404)
	leave_button.size = Vector2(166, 40)
	leave_button.z_index = 52
	leave_button.focus_mode = Control.FOCUS_ALL
	leave_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	leave_button.add_theme_font_size_override("font_size", 12)
	leave_button.add_theme_color_override("font_color", Color("a8a58f"))
	leave_button.add_theme_color_override("font_hover_color", Color("fff0b7"))
	leave_button.add_theme_stylebox_override("normal", WorkbenchUI.style_box(Color("171711e8"), 2, Color("4f4b38"), 1))
	leave_button.add_theme_stylebox_override("hover", WorkbenchUI.style_box(Color("2b2a20f2"), 2, Color("a98d4d"), 2))
	leave_button.add_theme_stylebox_override("pressed", WorkbenchUI.style_box(Color("353326"), 2, Color("d3b565"), 2))
	leave_button.pressed.connect(_on_leave_pressed)
	archive_strip.add_child(leave_button)

	confirm_button = Button.new()
	confirm_button.name = "ConfirmValidationButton"
	confirm_button.text = "确认送验"
	confirm_button.position = Vector2(1080, 330)
	confirm_button.size = Vector2(166, 62)
	confirm_button.z_index = 52
	confirm_button.focus_mode = Control.FOCUS_ALL
	confirm_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	confirm_button.add_theme_font_size_override("font_size", 15)
	confirm_button.add_theme_color_override("font_color", Color("20180c"))
	confirm_button.add_theme_color_override("font_hover_color", Color("090a06"))
	confirm_button.add_theme_color_override("font_disabled_color", Color("64675a"))
	confirm_button.add_theme_stylebox_override("normal", WorkbenchUI.style_box(Color("a67732"), 4, Color("d0a253"), 3))
	confirm_button.add_theme_stylebox_override("hover", WorkbenchUI.style_box(Color("c99a49"), 4, Color("f0c66f"), 3))
	confirm_button.add_theme_stylebox_override("pressed", WorkbenchUI.style_box(Color("8e622b"), 4, Color("d9aa58"), 3))
	confirm_button.add_theme_stylebox_override("disabled", WorkbenchUI.style_box(Color("292a23e8"), 4, Color("47483d"), 2))
	confirm_button.pressed.connect(confirm)
	archive_strip.add_child(confirm_button)


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


# 打开视图，只把已经形成审批决定（盖过章）的待验档案映射为文件袋队列。
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
	_update_archive_layout(false)
	overlay.visible = true
	overlay.modulate = Color.WHITE
	machine_lights.visible = false
	machine_lights.modulate = Color.WHITE
	machine_state_label.text = "现实验收机待机"
	leave_button.disabled = false
	_refresh()


# 为待验档案生成桌面上的实体文件袋；按钮本身不再表现为卡片。
func _add_archive_bag(archive: Dictionary) -> void:
	var archive_id := WorkdayContext.read_string(archive, "archive_id")
	var applicant := WorkdayContext.read_string(archive, "applicant", "身份受限")
	var decision := WorkdayContext.read_string(archive, "decision", "未决")
	var waiting_days := WorkdayContext.read_int(archive, "waiting_days")
	var slot_index := archive_order.size()
	var button := Button.new()
	button.name = archive_id
	button.position = _archive_home_position(slot_index)
	button.size = Vector2(150, 196)
	button.pivot_offset = Vector2(75, 88)
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	button.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
	button.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
	button.add_theme_stylebox_override("disabled", StyleBoxEmpty.new())
	button.pressed.connect(_on_archive_pressed.bind(archive_id, button))
	button.mouse_entered.connect(_animate_archive_hover.bind(button, true))
	button.mouse_exited.connect(_animate_archive_hover.bind(button, false))
	archive_row.add_child(button)

	var bag := TextureRect.new()
	bag.name = "DocumentBag"
	bag.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bag.texture = DOCUMENT_BAG_TEXTURE
	bag.position = Vector2(33, 0)
	bag.size = DOCUMENT_BAG_SIZE
	bag.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	bag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bag.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	button.add_child(bag)

	var id_label := WorkbenchUI.add_text(button, archive_id, 9, Color("cfbf91"), Vector2(5, 132), Vector2(140, 18))
	id_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var decision_color := Color("91b28b") if decision == "批准" else Color("c98277")
	var detail_label := WorkbenchUI.add_text(
		button,
		"%s · %s%s" % [applicant, decision, " · 等待%d日" % waiting_days if waiting_days > 0 else ""],
		8,
		decision_color,
		Vector2(4, 152),
		Vector2(142, 26)
	)
	detail_label.name = "ArchiveDetail"
	detail_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_label.clip_text = true
	var selected_badge := Panel.new()
	selected_badge.name = "SelectedBadge"
	selected_badge.position = Vector2(55, 76)
	selected_badge.size = Vector2(50, 20)
	selected_badge.rotation = -0.08
	selected_badge.visible = false
	selected_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	selected_badge.add_theme_stylebox_override("panel", WorkbenchUI.style_box(Color("7f251fcf"), 1, Color("c25b49"), 2))
	button.add_child(selected_badge)
	var selected_text := WorkbenchUI.add_text(selected_badge, "已选", 8, Color("f1b19d"), Vector2.ZERO, selected_badge.size)
	selected_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	selected_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	archive_order.append(archive_id)
	buttons[archive_id] = button


# 点击只切换本批选择；确认之前机器与轨道都不会启动。
func _on_archive_pressed(archive_id: String, button: Button) -> void:
	if ingesting or finishing:
		return
	if archive_id in selected_ids:
		selected_ids.erase(archive_id)
		_set_archive_button_selected(button, false)
		_update_archive_layout()
		_refresh()
		return
	if selected_ids.size() >= _current_batch_limit():
		instruction_label.text = "今日最多选择 %d 份；请先取消一份" % _current_batch_limit()
		return
	selected_ids.append(archive_id)
	_set_archive_button_selected(button, true)
	_update_archive_layout()
	_refresh()


func _set_archive_button_selected(button: Button, selected: bool) -> void:
	button.set_meta("selected_for_validation", selected)
	var badge := button.get_node_or_null("SelectedBadge") as Panel
	if badge != null:
		badge.visible = selected
	var detail_label := button.get_node_or_null("ArchiveDetail") as Label
	if detail_label != null:
		detail_label.visible = not selected
	button.z_index = 47 if selected else 41
	button.modulate = Color(1.12, 1.03, 0.82, 1.0) if selected else Color.WHITE


func _archive_home_position(slot_index: int) -> Vector2:
	if slot_index < ARCHIVE_SLOT_POSITIONS.size():
		return ARCHIVE_SLOT_POSITIONS[slot_index]
	return ARCHIVE_SLOT_POSITIONS[-1] + Vector2((slot_index - ARCHIVE_SLOT_POSITIONS.size() + 1) * 12, 0)


func _waiting_position(selected_index: int, selected_count: int) -> Vector2:
	var total_width := float(maxi(0, selected_count - 1)) * WAITING_ZONE_SPACING
	var center_x := WAITING_ZONE_CENTER_X - total_width * 0.5 + float(selected_index) * WAITING_ZONE_SPACING
	return Vector2(center_x - 61.5, WAITING_ZONE_Y)


# 每次选择变化都重排桌面：选中档案进入待送区，取消后回到原编号位。
func _update_archive_layout(animate: bool = true) -> void:
	for slot_index: int in archive_order.size():
		var archive_id := archive_order[slot_index]
		var button := buttons.get(archive_id) as Button
		if button == null or not is_instance_valid(button):
			continue
		var selected_index := selected_ids.find(archive_id)
		var target_position := (
			_waiting_position(selected_index, selected_ids.size())
			if selected_index >= 0
			else _archive_home_position(slot_index)
		)
		var target_scale := Vector2(0.82, 0.82) if selected_index >= 0 else Vector2.ONE
		if not animate:
			button.position = target_position
			button.scale = target_scale
			continue
		var tween := root.create_tween()
		tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(button, "position", target_position, 0.24)
		tween.parallel().tween_property(button, "scale", target_scale, 0.24)


# 将一份已确认档案从选择卡放到轨道下端，再向上吞入机器。
func _animate_selected_archive(archive_id: String, sequence_index: int, sequence_total: int) -> void:
	var button := buttons.get(archive_id) as Button
	if button == null:
		return
	in_flight_archive_id = archive_id
	machine_state_label.text = "正在送入 %02d / %02d" % [sequence_index + 1, sequence_total]
	instruction_label.text = "%s 正沿轨道进入机器。" % archive_id
	var bag_visual := button.get_node("DocumentBag") as TextureRect
	var bag_center := bag_visual.global_position + bag_visual.size * button.scale * 0.5
	var global_start := bag_center - DOCUMENT_BAG_SIZE * 0.5
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
	button.visible = false
	machine_lights.visible = true
	machine_lights.modulate = Color(1.0, 0.72, 0.42, 0.72)

	var place_tween := root.create_tween()
	place_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	place_tween.tween_property(active_document_bag, "position", BELT_STAGING_POSITION, 0.26)
	await place_tween.finished
	await root.get_tree().create_timer(0.10).timeout

	var light_tween := root.create_tween()
	light_tween.set_loops(3)
	light_tween.tween_property(machine_lights, "modulate:a", 1.0, 0.10)
	light_tween.tween_property(machine_lights, "modulate:a", 0.52, 0.10)
	var ingest_tween := root.create_tween()
	ingest_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	ingest_tween.tween_property(active_document_bag, "position", MACHINE_INGEST_POSITION, 0.62)
	await ingest_tween.finished
	light_tween.kill()

	if is_instance_valid(active_document_bag):
		active_document_bag.queue_free()
	active_document_bag = null
	in_flight_archive_id = ""
	buttons.erase(archive_id)
	button.queue_free()
	_send_secretary_pick_comment(archive_id)


# 离开不会提交尚未确认的选择；只有“确认送验”会启动机器。
func _on_leave_pressed() -> void:
	if ingesting or finishing:
		return
	selected_ids.clear()
	finishing = true
	leave_button.disabled = true
	confirm_button.disabled = true
	instruction_label.text = "本日没有确认送验档案"
	machine_state_label.text = "送验结束"
	overlay.visible = false
	finished.emit()


# 队列悬停只抬起待选文件袋，不影响运输实体。
func _animate_archive_hover(button: Button, hovered: bool) -> void:
	if ingesting or finishing or button.disabled:
		return
	var selected := bool(button.get_meta("selected_for_validation", false))
	var resting_color := Color(1.07, 1.03, 0.86, 1.0) if selected else Color.WHITE
	var resting_scale := Vector2(0.82, 0.82) if selected else Vector2.ONE
	var hover_scale := resting_scale * 1.045
	var tween := root.create_tween()
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(button, "scale", hover_scale if hovered else resting_scale, 0.10)
	tween.parallel().tween_property(button, "modulate", Color(1.12, 1.08, 0.93, 1.0) if hovered else resting_color, 0.10)


# 自动选择前 N 个待验案件，供测试和调试跳过逐袋动画。
func select_first_up_to_capacity() -> void:
	for archive_id: String in archive_order:
		if selected_ids.size() >= _current_batch_limit():
			break
		selected_ids.append(archive_id)
		var button := buttons.get(archive_id) as Button
		if button == null:
			continue
		_set_archive_button_selected(button, true)
	_update_archive_layout()
	_refresh()


# 锁定玩家选择，依次播放上轨吞入动画，最后统一写入现实效力。
func confirm(skip_animation: bool = false) -> void:
	if finishing or selected_ids.is_empty() or ingesting:
		return
	var submitted_archives := _get_selected_archives()
	var confirmed_ids := selected_ids.duplicate()
	finishing = true
	ingesting = true
	leave_button.disabled = true
	confirm_button.disabled = true
	for button_value: Variant in buttons.values():
		var archive_button := button_value as Button
		if archive_button != null:
			archive_button.disabled = true
	instruction_label.text = "选择已锁定，正在把文件袋放上轨道"
	machine_state_label.text = "批次确认 · %02d 份" % confirmed_ids.size()
	machine_lights.visible = true
	machine_lights.modulate = Color(1.0, 0.76, 0.38, 0.82)
	if not skip_animation:
		Sfx.start_conveyor()
		for index: int in confirmed_ids.size():
			await _animate_selected_archive(confirmed_ids[index], index, confirmed_ids.size())
		Sfx.stop_conveyor()
	ingesting = false
	if not WorkdayState.manager.validate_archive_batch(selected_ids):
		finishing = false
		open()
		machine_state_label.text = "验收失败 · 已恢复待验文件袋"
		return
	_send_validation_receipts(submitted_archives)
	instruction_label.text = "本批文件袋已取得现实效力"
	machine_state_label.text = "验收完成"
	machine_lights.modulate = Color(0.68, 1.0, 0.62, 0.86)
	if not skip_animation:
		await root.get_tree().create_timer(0.55).timeout
	overlay.visible = false
	finished.emit()


# 当前批次只有每日上限，没有最低送验数量。
func _current_batch_limit() -> int:
	return maxi(0, WorkdayState.machine_capacity)


# 返回已经盖章但尚未生效的待验档案；未盖章档案继续留在积压中。
func _get_pending_archives() -> Array[Dictionary]:
	var stamped_archives: Array[Dictionary] = []
	for archive: Dictionary in WorkdayState.manager.get_pending_archives():
		if WorkdayContext.read_string(archive, "decision").is_empty():
			continue
		stamped_archives.append(archive)
	return stamped_archives


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
	var selected_count := selected_ids.size()
	capacity_label.text = "%02d / %02d" % [selected_count, batch_limit]
	capacity_meter.max_value = maxi(1, batch_limit)
	capacity_meter.value = mini(selected_count, batch_limit)
	selection_label.text = "%02d 份" % selected_count
	leave_button.disabled = ingesting or finishing
	confirm_button.disabled = ingesting or finishing or selected_count == 0
	confirm_button.text = "确认送验 · %02d" % selected_count
	if ingesting or finishing:
		return
	if batch_limit <= 0:
		machine_state_label.text = "今日送验额度为零"
		instruction_label.text = "今日不可选择档案，可以直接离开。"
	elif selected_count >= batch_limit:
		machine_state_label.text = "已达到今日上限"
		instruction_label.text = "请确认本批，或点击待送区中的文件袋撤回。"
	elif pending_count <= selected_count and selected_count > 0:
		machine_state_label.text = "可选档案已全部加入"
		instruction_label.text = "请核对待送区中的文件袋，然后确认送验。"
	elif selected_ids.is_empty():
		machine_state_label.text = "现实验收机待机"
		instruction_label.text = "请从下方编号位选择 0–%d 份已盖章档案。" % mini(batch_limit, pending_count)
	else:
		machine_state_label.text = "待送 %d 份" % selected_count
		instruction_label.text = "还可选择 %d 份；确认后机器才会启动。" % (batch_limit - selected_count)
