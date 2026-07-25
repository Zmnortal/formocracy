class_name WorkCalendarMarkers
extends Control

# 覆盖在纸质日历素材上的日期、已过日期圆圈与今日标记。

const Schedule := preload("res://scripts/gameplay/work_calendar_schedule.gd")

var current_day := 1
var page_start := 1
var compact := false
var passed_day_count := 0


# 使用当前工作日刷新整页日期。
func configure(day_number: int, compact_view: bool) -> void:
	current_day = maxi(day_number, 1)
	page_start = Schedule.calendar_page_start(current_day)
	compact = compact_view
	passed_day_count = maxi(0, current_day - page_start)
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_build_weekday_labels()
	_build_day_labels()
	queue_redraw()


# 构建礼拜标题；星期日使用制度红提示休息日。
func _build_weekday_labels() -> void:
	var header := _header_rect()
	var cell_width := header.size.x / 7.0
	var names: Array[String] = ["一", "二", "三", "四", "五", "六", "休"]
	for column in 7:
		var label := Label.new()
		label.text = names[column]
		label.position = Vector2(header.position.x + column * cell_width, header.position.y)
		label.size = Vector2(cell_width, header.size.y)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.add_theme_font_size_override("font_size", 7 if compact else 18)
		label.add_theme_color_override("font_color", Color("97483d") if column == 6 else Color("4f4738"))
		add_child(label)


# 构建当前 35 日纸面页的日期数字。
func _build_day_labels() -> void:
	for cell_index in Schedule.CALENDAR_PAGE_DAYS:
		var day_number := page_start + cell_index
		var cell := _day_cell_rect(cell_index)
		var label := Label.new()
		label.text = str(day_number)
		label.position = cell.position
		label.size = cell.size
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.add_theme_font_size_override("font_size", 7 if compact else 17)
		var day_color := Color("9a4f43") if Schedule.is_rest_day(day_number) else Color("51493b")
		if day_number < current_day:
			day_color = day_color.darkened(0.18)
		label.add_theme_color_override("font_color", day_color)
		add_child(label)


# 绘制已过日期的手圈与今天的黄铜框。
func _draw() -> void:
	for cell_index in Schedule.CALENDAR_PAGE_DAYS:
		var day_number := page_start + cell_index
		var cell := _day_cell_rect(cell_index)
		var center := cell.get_center()
		if day_number < current_day:
			var radius := minf(cell.size.x, cell.size.y) * (0.38 if compact else 0.34)
			draw_arc(
				center,
				radius,
				0.0,
				TAU,
				24,
				Color(0.57, 0.18, 0.14, 0.88),
				1.2 if compact else 3.0,
				true,
			)
		elif day_number == current_day:
			var inset := 1.0 if compact else 5.0
			var highlight := cell.grow(-inset)
			draw_rect(highlight, Color(0.78, 0.57, 0.22, 0.14), true)
			draw_rect(highlight, Color(0.66, 0.48, 0.18, 0.96), false, 1.2 if compact else 3.0)


# 返回纸面礼拜标题区域。
func _header_rect() -> Rect2:
	return Rect2(
		Vector2(size.x * 0.047, size.y * 0.258),
		Vector2(size.x * 0.907, size.y * 0.092),
	)


# 返回纸面日期表格区域。
func _body_rect() -> Rect2:
	return Rect2(
		Vector2(size.x * 0.047, size.y * 0.350),
		Vector2(size.x * 0.907, size.y * 0.566),
	)


# 返回指定零基日期格的矩形。
func _day_cell_rect(cell_index: int) -> Rect2:
	var body := _body_rect()
	var cell_size := Vector2(body.size.x / 7.0, body.size.y / 5.0)
	return Rect2(
		body.position + Vector2((cell_index % 7) * cell_size.x, (cell_index / 7) * cell_size.y),
		cell_size,
	)
