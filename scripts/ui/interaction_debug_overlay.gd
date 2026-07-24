class_name InteractionDebugOverlay
extends Control

const PIXEL_FONT := preload("res://assets/fonts/ark_pixel/ark-pixel-16px-proportional-zh_cn.ttf")
const OUTLINE := Color(0.55, 1.0, 0.35, 0.92)
const FILL := Color(0.3, 0.9, 0.2, 0.08)


# 节点就绪时忽略鼠标事件并开启逐帧处理。
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(true)


# 覆盖层可见时每帧请求重绘以跟随交互区域变化。
func _process(_delta: float) -> void:
	if visible:
		queue_redraw()


# 绘制 debug_interaction_zone 分组中所有可见控件的高亮矩形、边框与标签名称。
func _draw() -> void:
	for node: Node in get_tree().get_nodes_in_group("debug_interaction_zone"):
		if not node is Control or not is_instance_valid(node):
			continue
		var control: Control = node
		if not control.is_visible_in_tree():
			continue
		var global_rect := control.get_global_rect()
		var inverse := get_global_transform_with_canvas().affine_inverse()
		var top_left: Vector2 = inverse * global_rect.position
		var bottom_right: Vector2 = inverse * global_rect.end
		var local_rect := Rect2(top_left, bottom_right - top_left)
		if local_rect.size.x <= 0.0 or local_rect.size.y <= 0.0:
			continue
		draw_rect(local_rect, FILL, true)
		draw_rect(local_rect, OUTLINE, false, 2.0)
		var label := WorkdayContext.stringify_value(control.get_meta("debug_zone_label"), control.name)
		draw_string(PIXEL_FONT, local_rect.position + Vector2(5, 17), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, OUTLINE)
