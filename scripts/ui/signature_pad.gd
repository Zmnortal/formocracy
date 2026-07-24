class_name SignaturePad
extends Control

signal signature_changed(has_signature: bool)

const INK_COLOR := Color("29281d")
const MIN_POINT_COUNT := 18

var strokes: Array[PackedVector2Array] = []
var active_stroke := PackedVector2Array()
var drawing := false


# 节点就绪时设置十字光标、拦截鼠标事件并请求重绘。
func _ready() -> void:
	mouse_default_cursor_shape = Control.CURSOR_CROSS
	mouse_filter = Control.MOUSE_FILTER_STOP
	queue_redraw()


# 处理签名输入：按下开始新笔画，拖动追加采样点，松开结束笔画并广播签名状态。
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		drawing = event.pressed
		if drawing:
			active_stroke = PackedVector2Array([_clamp_point(event.position)])
			strokes.append(active_stroke)
		else:
			_finish_stroke()
		accept_event()
	elif event is InputEventMouseMotion and drawing:
		var point := _clamp_point(event.position)
		if active_stroke.is_empty() or active_stroke[-1].distance_to(point) >= 2.0:
			active_stroke.append(point)
			strokes[-1] = active_stroke
			queue_redraw()
			signature_changed.emit(has_signature())
		accept_event()


# 绘制全部签名笔画：单点画圆，多点画折线。
func _draw() -> void:
	for stroke in strokes:
		if stroke.size() == 1:
			draw_circle(stroke[0], 2.0, INK_COLOR)
		elif stroke.size() > 1:
			draw_polyline(stroke, INK_COLOR, 3.0, true)


# 清空全部笔画并广播签名已清除。
func clear_signature() -> void:
	strokes.clear()
	active_stroke = PackedVector2Array()
	drawing = false
	queue_redraw()
	signature_changed.emit(false)


# 统计所有笔画的采样点总数，达到阈值即视为已签名。
func has_signature() -> bool:
	var count := 0
	for stroke in strokes:
		count += stroke.size()
	return count >= MIN_POINT_COUNT


# 将全部笔画序列化为坐标数组，坐标精确到 0.1。
func serialize_strokes() -> Array:
	var serialized: Array = []
	for stroke in strokes:
		var serialized_stroke: Array = []
		for point in stroke:
			serialized_stroke.append([snappedf(point.x, 0.1), snappedf(point.y, 0.1)])
		serialized.append(serialized_stroke)
	return serialized


# 结束当前笔画：写回笔画数组、重绘并广播签名状态。
func _finish_stroke() -> void:
	if not active_stroke.is_empty():
		strokes[-1] = active_stroke
	active_stroke = PackedVector2Array()
	queue_redraw()
	signature_changed.emit(has_signature())


# 将采样点限制在控件内缩 2 像素的范围内。
func _clamp_point(point: Vector2) -> Vector2:
	return Vector2(clampf(point.x, 2.0, maxf(2.0, size.x - 2.0)), clampf(point.y, 2.0, maxf(2.0, size.y - 2.0)))
