class_name WorkbenchCalendarModule
extends RefCounted

# 工作台右上纸质日历：小视图显示进度，点击后展开完整值勤历。

const Schedule := preload("res://scripts/gameplay/work_calendar_schedule.gd")
const MarkerView := preload("res://scripts/ui/work_calendar_markers.gd")
const CALENDAR_TEXTURE := preload("res://assets/office/items/calendar.png")
const UI := preload("res://scripts/ui/bureau_ui.gd")
const CALENDAR_OVERLAY_LAYER := 1100

var root: Node2D
var desk: DeskNodes
var small_markers: WorkCalendarMarkers
var open_button: Button
var overlay: Control
var panel: Panel
var large_markers: WorkCalendarMarkers
var today_label: Label
var schedule_label: Label


# 绑定墙上日历并创建展开阅读层。
func _init(owner_root: Node2D, desk_nodes: DeskNodes) -> void:
	root = owner_root
	desk = desk_nodes
	_build_small_calendar_interaction()
	_build_overlay()
	refresh()


# 为场景内日历增加日期与整面点击热区。
func _build_small_calendar_interaction() -> void:
	small_markers = MarkerView.new()
	small_markers.name = "WallCalendarMarkers"
	small_markers.position = Vector2.ZERO
	small_markers.size = desk.wall_calendar.size
	small_markers.mouse_filter = Control.MOUSE_FILTER_IGNORE
	desk.wall_calendar.add_child(small_markers)

	open_button = Button.new()
	open_button.name = "OpenWorkCalendar"
	open_button.position = Vector2.ZERO
	open_button.size = desk.wall_calendar.size
	open_button.flat = true
	open_button.focus_mode = Control.FOCUS_NONE
	open_button.tooltip_text = "查看值勤历与今天的礼拜"
	open_button.pressed.connect(open)
	open_button.mouse_entered.connect(_play_hover)
	desk.wall_calendar.add_child(open_button)
	CursorManager.watch(open_button, CursorManager.Cursor.POINT)


# 构建置于玩法最前方的大型纸质日历。
func _build_overlay() -> void:
	overlay = Control.new()
	overlay.name = "WorkCalendarOverlay"
	overlay.position = Vector2.ZERO
	overlay.size = DeskGeometry.design_size()
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	# 展开日历必须压过桌面抓取层（999）及所有普通演出层。
	overlay.z_index = CALENDAR_OVERLAY_LAYER
	overlay.visible = false
	root.add_child(overlay)

	var shade := ColorRect.new()
	shade.color = Color(0.008, 0.007, 0.005, 0.76)
	shade.position = Vector2.ZERO
	shade.size = DeskGeometry.design_size()
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(shade)

	var outside_button := Button.new()
	outside_button.name = "CloseCalendarOutside"
	outside_button.position = Vector2.ZERO
	outside_button.size = DeskGeometry.design_size()
	outside_button.flat = true
	outside_button.focus_mode = Control.FOCUS_NONE
	outside_button.pressed.connect(close)
	overlay.add_child(outside_button)

	panel = Panel.new()
	panel.name = "WorkCalendarPanel"
	panel.position = Vector2(190, 28)
	panel.size = Vector2(900, 664)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.pivot_offset = panel.size / 2.0
	panel.add_theme_stylebox_override(
		"panel",
		WorkbenchUI.style_box(Color("11140f"), 4, Color("987643"), 3),
	)
	overlay.add_child(panel)

	var title := WorkbenchUI.add_text(
		panel,
		"中央现实管理局 · 经办员值勤历",
		24,
		Color("ded1ad"),
		Vector2(42, 22),
		Vector2(610, 38),
	)
	title.add_theme_constant_override("outline_size", 4)
	title.add_theme_color_override("font_outline_color", Color("11130f"))

	today_label = WorkbenchUI.add_text(
		panel,
		"",
		19,
		Color("d8bd75"),
		Vector2(44, 65),
		Vector2(650, 30),
	)
	schedule_label = WorkbenchUI.add_text(
		panel,
		"",
		15,
		Color("aebb8c"),
		Vector2(44, 98),
		Vector2(720, 26),
	)

	var paper := TextureRect.new()
	paper.name = "ExpandedCalendarPaper"
	paper.texture = CALENDAR_TEXTURE
	paper.position = Vector2(54, 132)
	paper.size = Vector2(792, 506)
	paper.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	paper.stretch_mode = TextureRect.STRETCH_SCALE
	paper.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	paper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(paper)
	paper.position = Vector2(54, 132)
	paper.size = Vector2(792, 506)

	large_markers = MarkerView.new()
	large_markers.name = "ExpandedCalendarMarkers"
	large_markers.position = Vector2.ZERO
	large_markers.size = paper.size
	large_markers.mouse_filter = Control.MOUSE_FILTER_IGNORE
	paper.add_child(large_markers)

	var close_button := Button.new()
	close_button.name = "CloseWorkCalendar"
	close_button.text = "收起日历  ×"
	close_button.position = Vector2(704, 20)
	close_button.size = Vector2(164, 42)
	UI.style_button(close_button, 15)
	close_button.pressed.connect(close)
	close_button.mouse_entered.connect(_play_hover)
	panel.add_child(close_button)
	CursorManager.watch(close_button, CursorManager.Cursor.POINT)


# 从当前工作日刷新小日历和展开视图。
func refresh() -> void:
	var day := maxi(WorkdayState.day_number, 1)
	small_markers.configure(day, true)
	large_markers.configure(day, false)
	var status := "法定休息日" if Schedule.is_rest_day(day) else "值勤日 · 本周期第 %d 班" % Schedule.duty_day_in_cycle(day)
	today_label.text = "第 %02d 日 · 今天是%s · %s" % [day, Schedule.weekday_name(day), status]
	schedule_label.text = "第 %02d 个值勤周期　/　做六休一：礼拜一至礼拜六值勤，礼拜日休息" % Schedule.cycle_number(day)


# 展开纸质日历，完全由用户关闭。
func open() -> void:
	if overlay.visible:
		return
	refresh()
	overlay.modulate.a = 0.0
	panel.scale = Vector2(0.97, 0.97)
	overlay.visible = true
	var reveal := root.create_tween().set_parallel(true)
	reveal.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	reveal.tween_property(overlay, "modulate:a", 1.0, 0.14)
	reveal.tween_property(panel, "scale", Vector2.ONE, 0.16)
	Sfx.play("ui_switch", -5.0, 0.94)


# 收起展开日历。
func close() -> void:
	if not overlay.visible:
		return
	overlay.visible = false
	overlay.modulate.a = 1.0
	panel.scale = Vector2.ONE
	Sfx.play("ui_switch", -7.0, 0.82)


# ESC 优先收起日历，不传递给暂停菜单。
func handle_unhandled_input(event: InputEvent) -> bool:
	if not overlay.visible or not event is InputEventKey:
		return false
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo or key_event.keycode != KEY_ESCAPE:
		return false
	close()
	root.get_viewport().set_input_as_handled()
	return true


# 释放日历节点与鼠标来源。
func shutdown() -> void:
	CursorManager.release_cursor(open_button)
	if is_instance_valid(overlay):
		overlay.queue_free()
	overlay = null
	open_button = null
	small_markers = null
	large_markers = null
	root = null
	desk = null


# 播放日历悬停反馈。
func _play_hover() -> void:
	Sfx.play("ui_hover")
