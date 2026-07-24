class_name DeskItemController
extends RefCounted

# 统一管理桌面实体的点击、全屏抓取、伪重力下落、置顶和永久布局。

const DRAG_THRESHOLD := 6.0
# 兼容现有调用；交互边界使用独立的 BOUNDS_* 参数。
const DESK_LEFT := DeskGeometry.BOUNDS_LEFT
const DESK_RIGHT := DeskGeometry.BOUNDS_RIGHT
const DESK_FLOOR_Y := DeskGeometry.BOUNDS_FLOOR
const RESTING_LAYER_BASE := 8
const HELD_LAYER := 80

var root: Node2D
var items: Dictionary = {}
var next_resting_layer := RESTING_LAYER_BASE


# 初始化桌面物品控制器。
func _init(owner_root: Node2D) -> void:
	root = owner_root


# 注册一个可点击、拖拽的桌面实体，恢复其保存的位置与层级。
func register_item(item: Control, item_id: String, on_click: Callable = Callable(), on_drag_motion: Callable = Callable(), on_settled: Callable = Callable()) -> void:
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

	var saved: Dictionary = _manager().get_desk_item_layout(item_id)
	if not saved.is_empty():
		item.position = _vector_from_value(saved.get("position", item.position), item.position)
		item.z_index = WorkdayContext.read_int(saved, "layer", next_resting_layer)
	else:
		item.z_index = maxi(item.z_index, next_resting_layer)
	next_resting_layer = maxi(next_resting_layer + 1, item.z_index + 1)
	item.gui_input.connect(_on_item_input.bind(item))


# 注销指定桌面实体。
func unregister_item(item_id: String) -> void:
	items.erase(item_id)


# 分发桌面物品的 GUI 输入事件：按下、移动、释放。
func _on_item_input(event: InputEvent, item: Control) -> void:
	if event is InputEventMouseButton:
		var mouse_button: InputEventMouseButton = event
		if mouse_button.button_index != MOUSE_BUTTON_LEFT:
			return
		if mouse_button.pressed:
			_begin_press(item, mouse_button.position)
		else:
			_end_press(item)
	elif event is InputEventMouseMotion and _read_meta_bool(item, "desk_pressed"):
		var mouse_motion: InputEventMouseMotion = event
		_move_pressed_item(item, mouse_motion)


# 记录按下位置，停止当前补间动画，准备开始拖拽。
func _begin_press(item: Control, local_position: Vector2) -> void:
	var active_tween: Tween
	var tween_value: Variant = item.get_meta("desk_motion_tween") if item.has_meta("desk_motion_tween") else null
	if tween_value is Tween:
		active_tween = tween_value
	if is_instance_valid(active_tween):
		active_tween.kill()
	item.set_meta("desk_pressed", true)
	item.set_meta("desk_dragging", false)
	item.set_meta("desk_press_position", local_position)
	item.set_meta("desk_last_motion", Vector2.ZERO)


# 移动被拖拽物品，应用响应倍率、缩放倾斜与拖动回调。
func _move_pressed_item(item: Control, event: InputEventMouseMotion) -> void:
	var dragging := _read_meta_bool(item, "desk_dragging")
	var press_position := _read_meta_vector(item, "desk_press_position", Vector2.ZERO)
	if not dragging and event.position.distance_to(press_position) < DRAG_THRESHOLD:
		return
	if not dragging:
		item.set_meta("desk_dragging", true)
		item.z_index = HELD_LAYER
		_cursor().call("begin_drag", item)

	var motion: Vector2 = event.relative * _manager().get_drag_response_multiplier()
	item.position += motion
	item.set_meta("desk_last_motion", motion)
	var base_scale := _read_meta_vector(item, "desk_base_scale", Vector2.ONE)
	item.scale = base_scale * 1.025
	item.rotation = clampf(motion.x * 0.0025, -0.07, 0.07)
	var callback: Callable = item.get_meta("desk_on_drag_motion", Callable())
	if callback.is_valid():
		callback.call(item)


# 释放时判断是点击还是拖拽结束，触发相应回调。
func _end_press(item: Control) -> void:
	if not _read_meta_bool(item, "desk_pressed"):
		return
	item.set_meta("desk_pressed", false)
	if _read_meta_bool(item, "desk_dragging"):
		item.set_meta("desk_dragging", false)
		_cursor().call("end_drag")
		_drop_to_desk(item)
		return
	var callback: Callable = item.get_meta("desk_on_click", Callable())
	if callback.is_valid():
		callback.call()


# 释放拖拽后让物品落到桌面边界内，并保存布局。
func _drop_to_desk(item: Control) -> void:
	var base_scale := _read_meta_vector(item, "desk_base_scale", Vector2.ONE)
	var visual_size := item.size * base_scale.abs()
	var last_motion := _read_meta_vector(item, "desk_last_motion", Vector2.ZERO)
	var target_x := clampf(item.position.x + last_motion.x * 2.4, DeskGeometry.bounds_left_at(1.0), DeskGeometry.bounds_right_at(1.0) - visual_size.x)
	var target_y := DeskGeometry.BOUNDS_FLOOR - visual_size.y
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
	var item_id := WorkdayContext.stringify_value(item.get_meta("desk_item_id", ""))
	_manager().set_desk_item_layout(item_id, item.position, item.z_index)
	_sfx().call("play", "ui_click")
	var callback: Callable = item.get_meta("desk_on_settled", Callable())
	if callback.is_valid():
		callback.call(item)


# 将数组或字典值转换为 Vector2。
func _vector_from_value(value: Variant, fallback: Vector2) -> Vector2:
	if value is Vector2:
		return value
	if value is Array:
		var array_value: Array = value
		if array_value.size() >= 2:
			return Vector2(WorkdayContext.to_float(array_value[0], fallback.x), WorkdayContext.to_float(array_value[1], fallback.y))
	if value is Dictionary:
		var dictionary_value: Dictionary = value
		return Vector2(WorkdayContext.read_float(dictionary_value, "x", fallback.x), WorkdayContext.read_float(dictionary_value, "y", fallback.y))
	return fallback


# 安全读取布尔类型的桌面物品元数据。
func _read_meta_bool(item: Control, key: String) -> bool:
	return WorkdayContext.to_bool(item.get_meta(key, false))


# 安全读取 Vector2 类型的桌面物品元数据。
func _read_meta_vector(item: Control, key: String, fallback: Vector2) -> Vector2:
	return _vector_from_value(item.get_meta(key, fallback), fallback)


# 获取 WorkdayState 单例引用。
func _state() -> Node:
	return root.get_tree().root.get_node("WorkdayState")


# 获取工作日功能域的统一 Manager 入口。
func _manager() -> WorkdayManager:
	var value: Variant = _state().get("manager")
	assert(value is WorkdayManager, "WorkdayState.manager 必须是 WorkdayManager")
	@warning_ignore("unsafe_cast")
	var workday_manager: WorkdayManager = value
	return workday_manager


# 获取 CursorManager 单例引用。
func _cursor() -> Node:
	return root.get_tree().root.get_node("CursorManager")


# 获取 Sfx 单例引用。
func _sfx() -> Node:
	return root.get_tree().root.get_node("Sfx")
