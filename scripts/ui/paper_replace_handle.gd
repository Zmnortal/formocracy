class_name PaperReplaceHandle
extends Control

signal replacement_requested

const PAPER_COLOR := Color("d8c99d")
const PAPER_HOVER_COLOR := Color("f0dfa8")
const FOLD_SHADOW_COLOR := Color("6e6244")
const INK_COLOR := Color("4a432f")

var disabled := false:
	set(value):
		disabled = value
		mouse_default_cursor_shape = Control.CURSOR_ARROW if disabled else Control.CURSOR_POINTING_HAND
		queue_redraw()

var _hovered := false


# 用纸张折角代替常规按钮，让“重填”表现为作废旧表并抽取一张新表。
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	tooltip_text = "作废当前表单，换取一张空白新表"
	mouse_entered.connect(_set_hovered.bind(true))
	mouse_exited.connect(_set_hovered.bind(false))
	queue_redraw()


# 点击折角时请求 Opening 场景更换整张表单。
func _gui_input(event: InputEvent) -> void:
	if disabled:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if not event.pressed:
			replacement_requested.emit()
		accept_event()


# 绘制右下角卷起的纸角与双向换纸记号；它不是 Button，也不会出现按钮悬浮切片。
func _draw() -> void:
	var color := PAPER_HOVER_COLOR if _hovered and not disabled else PAPER_COLOR
	if disabled:
		color = color.darkened(0.22)
	var corner := PackedVector2Array(
		[
			Vector2(4, size.y - 4),
			Vector2(size.x - 4, 4),
			Vector2(size.x - 4, size.y - 4),
		]
	)
	draw_colored_polygon(corner, FOLD_SHADOW_COLOR.darkened(0.12))
	var folded_corner := PackedVector2Array(
		[
			Vector2(8, size.y - 7),
			Vector2(size.x - 7, 8),
			Vector2(size.x - 7, size.y - 7),
		]
	)
	draw_colored_polygon(folded_corner, color)
	draw_polyline(
		PackedVector2Array(
			[
				Vector2(8, size.y - 7),
				Vector2(size.x - 7, 8),
				Vector2(size.x - 7, size.y - 7),
				Vector2(8, size.y - 7),
			]
		),
		INK_COLOR,
		1.5,
		true
	)
	var center := Vector2(size.x - 17, size.y - 17)
	draw_line(center + Vector2(-8, -3), center + Vector2(6, -3), INK_COLOR, 2.0, true)
	draw_line(center + Vector2(6, -3), center + Vector2(2, -7), INK_COLOR, 2.0, true)
	draw_line(center + Vector2(-6, 4), center + Vector2(8, 4), INK_COLOR, 2.0, true)
	draw_line(center + Vector2(-6, 4), center + Vector2(-2, 8), INK_COLOR, 2.0, true)


# 折角悬浮时只提亮纸面，不使用常规按钮的九宫格 Hover 样式。
func _set_hovered(value: bool) -> void:
	_hovered = value
	queue_redraw()
