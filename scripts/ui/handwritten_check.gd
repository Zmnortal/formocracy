class_name HandwrittenCheck
extends Control

signal toggled(pressed: bool)

const INK_COLOR := Color("29281d")

var points := PackedVector2Array()
var drawing := false
var disabled := false

var button_pressed: bool:
	get:
		return _checked
	set(value):
		_checked = value
		if value and points.is_empty():
			points = PackedVector2Array(
				[
					Vector2(22, 26),
					Vector2(29, 37),
					Vector2(54, 8),
				]
			)
		elif not value:
			points.clear()
			queue_redraw()

var _checked := false


# 节点就绪时设置十字光标并拦截鼠标事件。
func _ready() -> void:
	mouse_default_cursor_shape = Control.CURSOR_CROSS
	mouse_filter = Control.MOUSE_FILTER_STOP
	queue_redraw()


# 处理手写勾选输入：按下开始描画，松开时判定是否构成勾形手势并发出 toggled 信号。
func _gui_input(event: InputEvent) -> void:
	if disabled:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			drawing = true
			_checked = false
			points = PackedVector2Array([event.position])
			queue_redraw()
		else:
			drawing = false
			_checked = _is_check_gesture()
			if not _checked:
				points.clear()
			queue_redraw()
			toggled.emit(_checked)
		accept_event()
	elif event is InputEventMouseMotion and drawing:
		var point: Vector2 = event.position
		if points.is_empty() or points[-1].distance_to(point) >= 1.5:
			points.append(point)
			queue_redraw()
		accept_event()


# 绘制手写笔迹：单点画圆，多点画折线。
func _draw() -> void:
	if points.size() == 1:
		draw_circle(points[0], 1.7, INK_COLOR)
	elif points.size() > 1:
		draw_polyline(points, INK_COLOR, 3.2, true)


# 判定笔迹是否构成勾形手势：存在最低谷点，且起笔、谷点、收笔自左向右、先下后上。
func _is_check_gesture() -> bool:
	if points.size() < 5:
		return false
	var valley_index := 0
	for i in points.size():
		if points[i].y > points[valley_index].y:
			valley_index = i
	if valley_index <= 0 or valley_index >= points.size() - 1:
		return false
	var start := points[0]
	var valley := points[valley_index]
	var finish := points[-1]
	return valley.x > start.x + 3.0 and finish.x > valley.x + 6.0 and valley.y > start.y + 3.0 and valley.y > finish.y + 6.0
