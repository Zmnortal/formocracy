class_name DeskItemController
extends RefCounted

# 统一管理桌面实体的点击、全屏抓取、伪重力下落、置顶和永久布局。

const DRAG_THRESHOLD := 6.0
# 兼容现有调用；实际参数统一在 desk_geometry.gd 修改。
const DESK_LEFT := DeskGeometry.LEFT
const DESK_RIGHT := DeskGeometry.RIGHT
const DESK_FLOOR_Y := DeskGeometry.FLOOR
const RESTING_LAYER_BASE := 8
const HELD_LAYER := 80

var root: Node2D
var items: Dictionary = {}
var next_resting_layer := RESTING_LAYER_BASE


func _init(owner_root: Node2D) -> void:
	root = owner_root


func register_item(
		item: Control,
		item_id: String,
		on_click := Callable(),
		on_drag_motion := Callable(),
		on_settled := Callable()
) -> void:
	if not is_instance_valid(item) or item_id.is_empty():
		return
	item.mouse_filter = Control.MOUSE_FILTER_STOP
	item.set_meta("desk_item_id", item_id)
	item.add_to_group("debug_interaction_zone")
	if not item.has_meta("debug_zone_label"):
		item.set_meta("debug_zone_label", "可移动物件：%s" % item_id)
	item.set_meta("desk_pressed", false)
	item.set_meta("desk_dragging", false)
	item.set_meta("desk_press_position", Vector2.ZERO)
	item.set_meta("desk_last_motion", Vector2.ZERO)
	item.set_meta("desk_base_scale", item.scale)
	item.set_meta("desk_on_click", on_click)
	item.set_meta("desk_on_drag_motion", on_drag_motion)
	item.set_meta("desk_on_settled", on_settled)
	items[item_id] = item

	var saved: Dictionary = _state().get_desk_item_layout(item_id)
	if not saved.is_empty():
		item.position = _vector_from_value(saved.get("position", item.position), item.position)
		item.z_index = int(saved.get("layer", next_resting_layer))
	else:
		item.z_index = maxi(item.z_index, next_resting_layer)
	next_resting_layer = maxi(next_resting_layer + 1, item.z_index + 1)
	item.gui_input.connect(_on_item_input.bind(item))


func unregister_item(item_id: String) -> void:
	items.erase(item_id)


func _on_item_input(event: InputEvent, item: Control) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_begin_press(item, event.position)
		else:
			_end_press(item)
	elif event is InputEventMouseMotion and bool(item.get_meta("desk_pressed", false)):
		_move_pressed_item(item, event)


func _begin_press(item: Control, local_position: Vector2) -> void:
	var active_tween: Tween = (
		item.get_meta("desk_motion_tween") if item.has_meta("desk_motion_tween") else null
	)
	if is_instance_valid(active_tween):
		active_tween.kill()
	item.set_meta("desk_pressed", true)
	item.set_meta("desk_dragging", false)
	item.set_meta("desk_press_position", local_position)
	item.set_meta("desk_last_motion", Vector2.ZERO)


func _move_pressed_item(item: Control, event: InputEventMouseMotion) -> void:
	var dragging := bool(item.get_meta("desk_dragging", false))
	var press_position: Vector2 = item.get_meta("desk_press_position", Vector2.ZERO)
	if not dragging and event.position.distance_to(press_position) < DRAG_THRESHOLD:
		return
	if not dragging:
		item.set_meta("desk_dragging", true)
		item.z_index = HELD_LAYER
		_cursor().begin_drag(item)

	var motion: Vector2 = event.relative * float(_state().get_drag_response_multiplier())
	item.position += motion
	item.set_meta("desk_last_motion", motion)
	var base_scale: Vector2 = item.get_meta("desk_base_scale", Vector2.ONE)
	item.scale = base_scale * 1.025
	item.rotation = clampf(motion.x * 0.0025, -0.07, 0.07)
	var callback: Callable = item.get_meta("desk_on_drag_motion", Callable())
	if callback.is_valid():
		callback.call(item)


func _end_press(item: Control) -> void:
	if not bool(item.get_meta("desk_pressed", false)):
		return
	item.set_meta("desk_pressed", false)
	if bool(item.get_meta("desk_dragging", false)):
		item.set_meta("desk_dragging", false)
		_cursor().end_drag()
		_drop_to_desk(item)
		return
	var callback: Callable = item.get_meta("desk_on_click", Callable())
	if callback.is_valid():
		callback.call()


func _drop_to_desk(item: Control) -> void:
	var base_scale: Vector2 = item.get_meta("desk_base_scale", Vector2.ONE)
	var visual_size := item.size * base_scale.abs()
	var last_motion: Vector2 = item.get_meta("desk_last_motion", Vector2.ZERO)
	var target_x := clampf(
		item.position.x + last_motion.x * 2.4,
		DeskGeometry.left_at(1.0),
		DeskGeometry.right_at(1.0) - visual_size.x
	)
	var target_y := DeskGeometry.FLOOR - visual_size.y
	var fall_distance := maxf(0.0, target_y - item.position.y)
	var duration := clampf(0.18 + sqrt(fall_distance) * 0.012, 0.22, 0.62)
	var target := Vector2(target_x, target_y)

	var fall := root.create_tween()
	item.set_meta("desk_motion_tween", fall)
	fall.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	fall.tween_property(item, "position", target, duration)
	fall.parallel().tween_property(item, "rotation", 0.0, duration)
	fall.parallel().tween_property(item, "scale", base_scale, duration)
	await fall.finished

	var impact_strength := clampf(fall_distance / 360.0, 0.08, 0.32)
	var bounce := root.create_tween()
	item.set_meta("desk_motion_tween", bounce)
	bounce.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	bounce.tween_property(item, "scale", base_scale * Vector2(1.0 + impact_strength * 0.12, 1.0 - impact_strength), 0.07)
	bounce.tween_property(item, "scale", base_scale, 0.12)
	await bounce.finished

	item.z_index = next_resting_layer
	next_resting_layer += 1
	_state().set_desk_item_layout(
		String(item.get_meta("desk_item_id", "")),
		item.position,
		item.z_index
	)
	_sfx().play("ui_click")
	var callback: Callable = item.get_meta("desk_on_settled", Callable())
	if callback.is_valid():
		callback.call(item)


func _vector_from_value(value: Variant, fallback: Vector2) -> Vector2:
	if value is Vector2:
		return value
	if value is Array and value.size() >= 2:
		return Vector2(float(value[0]), float(value[1]))
	if value is Dictionary:
		return Vector2(float(value.get("x", fallback.x)), float(value.get("y", fallback.y)))
	return fallback


func _state() -> Node:
	return root.get_tree().root.get_node("WorkdayState")


func _cursor() -> Node:
	return root.get_tree().root.get_node("CursorManager")


func _sfx() -> Node:
	return root.get_tree().root.get_node("Sfx")
