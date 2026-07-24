class_name InteractionDebugOverlay
extends Control

const PIXEL_FONT := preload("res://assets/fonts/ark_pixel/ark-pixel-16px-proportional-zh_cn.ttf")
const OUTLINE := Color(0.55, 1.0, 0.35, 0.92)
const FILL := Color(0.3, 0.9, 0.2, 0.08)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(true)


func _process(_delta: float) -> void:
	if visible:
		queue_redraw()


func _draw() -> void:
	for node in get_tree().get_nodes_in_group("debug_interaction_zone"):
		if not node is Control or not is_instance_valid(node) or not node.is_visible_in_tree():
			continue
		var control := node as Control
		var global_rect := control.get_global_rect()
		var inverse := get_global_transform_with_canvas().affine_inverse()
		var top_left: Vector2 = inverse * global_rect.position
		var bottom_right: Vector2 = inverse * global_rect.end
		var local_rect := Rect2(top_left, bottom_right - top_left)
		if local_rect.size.x <= 0.0 or local_rect.size.y <= 0.0:
			continue
		draw_rect(local_rect, FILL, true)
		draw_rect(local_rect, OUTLINE, false, 2.0)
		var label := String(control.get_meta("debug_zone_label", control.name))
		draw_string(
			PIXEL_FONT,
			local_rect.position + Vector2(5, 17),
			label,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			14,
			OUTLINE
		)
