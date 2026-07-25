class_name DeskItemController
extends RefCounted

# 统一管理桌面实体的点击、全屏抓取、伪重力下落、置顶和永久布局。

const DRAG_THRESHOLD := 6.0
# 兼容现有调用；交互边界使用独立的 BOUNDS_* 参数。
const DESK_LEFT := DeskGeometry.BOUNDS_LEFT
const DESK_RIGHT := DeskGeometry.BOUNDS_RIGHT
const DESK_FLOOR_Y := DeskGeometry.BOUNDS_FLOOR
const RESTING_LAYER_BASE := 8
const HELD_LAYER := 999
const RESTING_LAYER_LIMIT := HELD_LAYER - 1
const LANDING_DEPTH_RANDOMNESS := 0.68
const IN_PLACE_SETTLE_DURATION := 0.12

var root: Node2D
var items: Dictionary = {}
var next_resting_layer := RESTING_LAYER_BASE
var drop_sequence := 0
var active_item: Control
var focused_item: Control


# 初始化桌面物品控制器。
func _init(owner_root: Node2D) -> void:
	root = owner_root


# 注册一个可点击、拖拽的桌面实体，恢复其保存的位置与层级。
func register_item(
	item: Control,
	item_id: String,
	on_click: Callable = Callable(),
	on_drag_motion: Callable = Callable(),
	on_settled: Callable = Callable(),
	on_drop_prepare: Callable = Callable(),
	can_begin_interaction: Callable = Callable(),
	uses_gravity: bool = true
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
	item.set_meta("desk_on_drop_prepare", on_drop_prepare)
	item.set_meta("desk_can_begin_interaction", can_begin_interaction)
	item.set_meta("desk_uses_gravity", uses_gravity)
	items[item_id] = item

	var saved: Dictionary = _manager().get_desk_item_layout(item_id)
	if not saved.is_empty():
		item.position = _vector_from_value(saved.get("position", item.position), item.position)
		item.z_index = mini(WorkdayContext.read_int(saved, "layer", next_resting_layer), HELD_LAYER)
	else:
		item.z_index = mini(maxi(item.z_index, next_resting_layer), RESTING_LAYER_LIMIT)
	next_resting_layer = mini(maxi(next_resting_layer + 1, item.z_index + 1), RESTING_LAYER_LIMIT)
	item.set_meta("desk_resting_layer", item.z_index)
	item.gui_input.connect(_on_item_input.bind(item))


# 注销指定桌面实体。
func unregister_item(item_id: String) -> void:
	var removed: Variant = items.get(item_id)
	if not is_instance_valid(active_item) or (is_instance_valid(removed) and removed == active_item):
		active_item = null
	if not is_instance_valid(focused_item) or (is_instance_valid(removed) and removed == focused_item):
		focused_item = null
	items.erase(item_id)


# 所有 GUI 事件都转发给鼠标位置上实际绘制在最前面的桌面物件。
func _on_item_input(event: InputEvent, item: Control) -> void:
	if event is InputEventMouseButton:
		var mouse_button: InputEventMouseButton = event
		if mouse_button.button_index != MOUSE_BUTTON_LEFT:
			return
		if mouse_button.pressed:
			var target := _frontmost_item_at_global(mouse_button.global_position)
			if not is_instance_valid(target):
				return
			var local_position := target.get_global_transform().affine_inverse() * mouse_button.global_position
			_begin_press(target, local_position)
			if _read_meta_bool(target, "desk_pressed"):
				active_item = target
				if target != item:
					target.grab_click_focus()
		else:
			var target := active_item if is_instance_valid(active_item) else item
			_end_press(target)
			active_item = null
	elif event is InputEventMouseMotion and is_instance_valid(active_item) and _read_meta_bool(active_item, "desk_pressed"):
		var mouse_motion: InputEventMouseMotion = event
		_move_pressed_item(active_item, mouse_motion)


# 记录按下位置，停止当前补间动画，准备开始拖拽。
func _begin_press(item: Control, local_position: Vector2) -> void:
	var interaction_guard: Callable = item.get_meta("desk_can_begin_interaction", Callable())
	if interaction_guard.is_valid() and not WorkdayContext.to_bool(interaction_guard.call(item, local_position)):
		return
	var active_tween: Tween
	var tween_value: Variant = item.get_meta("desk_motion_tween") if item.has_meta("desk_motion_tween") else null
	if is_instance_valid(tween_value) and tween_value is Tween:
		active_tween = tween_value
	if is_instance_valid(active_tween):
		active_tween.kill()
	item.remove_meta("desk_motion_tween")
	_focus_item(item)
	item.set_meta("desk_pressed", true)
	item.set_meta("desk_dragging", false)
	item.set_meta("desk_press_position", local_position)
	item.set_meta("desk_press_global_position", item.get_global_transform() * local_position)
	item.set_meta("desk_last_motion", Vector2.ZERO)
	item.set_meta("desk_grab_local_position", local_position)


# 移动被拖拽物品，使用绝对指针坐标保持抓取点贴手，并应用缩放倾斜与拖动回调。
func _move_pressed_item(item: Control, event: InputEventMouseMotion) -> void:
	if _read_meta_bool(item, "desk_drag_locked"):
		return
	var dragging := _read_meta_bool(item, "desk_dragging")
	var press_global_position := _read_meta_vector(item, "desk_press_global_position", event.global_position)
	if not dragging and event.global_position.distance_to(press_global_position) < DRAG_THRESHOLD:
		return
	if not dragging:
		item.set_meta("desk_dragging", true)
		_cursor().call("begin_drag", item)

	var previous_position := item.position
	var base_scale := _read_meta_vector(item, "desk_base_scale", Vector2.ONE)
	item.scale = base_scale * 1.025
	item.rotation = clampf(event.relative.x * 0.0025, -0.07, 0.07)
	var grab_local_position := _read_meta_vector(item, "desk_grab_local_position", Vector2.ZERO)
	_anchor_grab_point(item, grab_local_position, event.global_position)
	var callback: Callable = item.get_meta("desk_on_drag_motion", Callable())
	if callback.is_valid():
		callback.call(item)
		# 回调可能把立起文件切为桌面比例；再次校正，确保缩放切换时抓取点不跳离鼠标。
		_anchor_grab_point(item, grab_local_position, event.global_position)
	item.set_meta("desk_last_motion", item.position - previous_position)


# 从所有已注册且可见的桌面物件中返回指针命中的最前绘制项。
func _frontmost_item_at_global(global_point: Vector2) -> Control:
	var frontmost: Control
	var stale_item_ids: Array[String] = []
	for item_id: String in items:
		var value: Variant = items[item_id]
		if not is_instance_valid(value):
			stale_item_ids.append(item_id)
			continue
		if not value is Control:
			stale_item_ids.append(item_id)
			continue
		var candidate := value as Control
		if not _is_pointer_inside_item(candidate, global_point):
			continue
		if not is_instance_valid(frontmost) or _is_drawn_in_front_of(candidate, frontmost):
			frontmost = candidate
	for item_id: String in stale_item_ids:
		items.erase(item_id)
	return frontmost


# 使用物件真实变换后的矩形做命中，缩放和旋转不会扩大成错误的轴对齐区域。
func _is_pointer_inside_item(item: Control, global_point: Vector2) -> bool:
	if not is_instance_valid(item) or not item.is_visible_in_tree() or item.mouse_filter == Control.MOUSE_FILTER_IGNORE:
		return false
	var local_point := item.get_global_transform().affine_inverse() * global_point
	return Rect2(Vector2.ZERO, item.size).has_point(local_point)


# 绘制层级优先；层级相同时，场景树中更靠后的同级节点显示在前面。
func _is_drawn_in_front_of(candidate: Control, current: Control) -> bool:
	var candidate_layer := _effective_z_index(candidate)
	var current_layer := _effective_z_index(current)
	if candidate_layer != current_layer:
		return candidate_layer > current_layer
	return candidate.is_greater_than(current)


# 汇总相对父节点的 CanvasItem 层级，得到用于同一画布比较的有效 Z 值。
func _effective_z_index(item: CanvasItem) -> int:
	var result := item.z_index
	var current := item
	while current.z_as_relative:
		var parent := current.get_parent() as CanvasItem
		if not is_instance_valid(parent):
			break
		result += parent.z_index
		current = parent
	return result


# 在物件缩放、旋转或语义状态变化后，让最初抓住的局部点仍精确贴住当前指针。
func _anchor_grab_point(item: Control, grab_local_position: Vector2, pointer_global: Vector2) -> void:
	var parent_canvas := item.get_parent() as CanvasItem
	if not is_instance_valid(parent_canvas):
		return
	var parent_inverse := parent_canvas.get_global_transform().affine_inverse()
	var anchored_global := item.get_global_transform() * grab_local_position
	item.position += parent_inverse * pointer_global - parent_inverse * anchored_global


# 将当前按下物件提升到 999；其余物件保持原相对顺序并依次排列为 998、997……
func _focus_item(item: Control) -> void:
	var ordered_items := _stack_items_except(item)
	focused_item = item
	item.z_index = HELD_LAYER
	item.set_meta("desk_resting_layer", HELD_LAYER)
	_persist_item_layer(item, HELD_LAYER)
	var layer := RESTING_LAYER_LIMIT
	for candidate: Control in ordered_items:
		var stack_layer := maxi(layer, RESTING_LAYER_BASE)
		candidate.z_index = stack_layer
		candidate.set_meta("desk_resting_layer", stack_layer)
		_persist_item_layer(candidate, stack_layer)
		layer -= 1


# 供文件展开等程序化交互使用，与鼠标按下共享同一套桌面排名算法。
func focus_item(item: Control) -> void:
	if not is_instance_valid(item):
		return
	_focus_item(item)


# 返回除当前选中项外的桌面堆栈，并保持它们原有的前后顺序。
func _stack_items_except(selected_item: Control) -> Array[Control]:
	var ordered_items: Array[Control] = []
	for value: Variant in items.values():
		if is_instance_valid(value) and value is Control and value != selected_item:
			ordered_items.append(value)
	ordered_items.sort_custom(
		func(left: Control, right: Control) -> bool:
			var left_layer := _effective_z_index(left)
			var right_layer := _effective_z_index(right)
			if left_layer != right_layer:
				return left_layer > right_layer
			return left.is_greater_than(right)
	)
	return ordered_items


# 保存单个道具当前的稳定堆栈层级。
func _persist_item_layer(item: Control, layer: int) -> void:
	var item_id := WorkdayContext.stringify_value(item.get_meta("desk_item_id", ""))
	if item_id.is_empty():
		return
	_manager().set_desk_item_layout(item_id, item.position, layer)


# 释放时判断是点击还是拖拽结束，触发相应回调。
func _end_press(item: Control) -> void:
	if not _read_meta_bool(item, "desk_pressed"):
		return
	item.set_meta("desk_pressed", false)
	if _read_meta_bool(item, "desk_dragging"):
		item.set_meta("desk_dragging", false)
		_cursor().call("end_drag")
		var prepare_callback: Callable = item.get_meta("desk_on_drop_prepare", Callable())
		if prepare_callback.is_valid():
			prepare_callback.call(item)
		if _read_meta_bool(item, "desk_skip_drop_once"):
			item.set_meta("desk_skip_drop_once", false)
			return
		_drop_to_desk(item)
		return
	var callback: Callable = item.get_meta("desk_on_click", Callable())
	if callback.is_valid():
		callback.call()


# 释放拖拽后按物体是否完整位于桌面内，选择原地放下或伪重力坠落。
func _drop_to_desk(item: Control) -> void:
	var base_scale := _read_meta_vector(item, "desk_base_scale", Vector2.ONE)
	if not _read_meta_bool(item, "desk_uses_gravity", true):
		await _settle_in_place(item, base_scale)
		_finalize_settle(item)
		return
	var visual_size := item.size * base_scale.abs()
	if _is_fully_inside_desk(item.position, visual_size):
		await _settle_in_place(item, base_scale)
		_finalize_settle(item)
		return

	var last_motion := _read_meta_vector(item, "desk_last_motion", Vector2.ZERO)
	var target_y := _choose_landing_y(item, visual_size)
	var horizontal_limits := _horizontal_limits(target_y, visual_size)
	var target_x := clampf(item.position.x + last_motion.x * 2.4, horizontal_limits.x, horizontal_limits.y)
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

	_finalize_settle(item)


# 让特殊交互完成后的桌面实体重新进入统一落桌物理。
func drop_item(item: Control) -> void:
	if not is_instance_valid(item):
		return
	_drop_to_desk(item)


# 判断物件完整视觉矩形是否已经处于桌面可放置区域内。
func _is_fully_inside_desk(position: Vector2, visual_size: Vector2) -> bool:
	var top_y := position.y
	var bottom_y := position.y + visual_size.y
	if top_y < DeskGeometry.BOUNDS_TOP or bottom_y > DeskGeometry.BOUNDS_FLOOR:
		return false
	var horizontal_limits := _horizontal_limits(top_y, visual_size)
	return position.x >= horizontal_limits.x and position.x <= horizontal_limits.y


# 桌面内释放只回正旋转与缩放，不改变玩家选择的位置。
func _settle_in_place(item: Control, base_scale: Vector2) -> void:
	var settle := root.create_tween()
	item.set_meta("desk_motion_tween", settle)
	settle.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	settle.tween_property(item, "rotation", 0.0, IN_PLACE_SETTLE_DURATION)
	settle.parallel().tween_property(item, "scale", base_scale, IN_PLACE_SETTLE_DURATION)
	await settle.finished


# 为高处或越界释放的物件选择桌面纵深落点。
# 随机值由物件、释放位置和本局坠落序号共同决定，既有变化又可稳定复现。
func _choose_landing_y(item: Control, visual_size: Vector2) -> float:
	var minimum_y := DeskGeometry.BOUNDS_TOP
	var maximum_y := maxf(minimum_y, DeskGeometry.BOUNDS_FLOOR - visual_size.y)
	if is_equal_approx(minimum_y, maximum_y):
		return minimum_y

	drop_sequence += 1
	var item_id := WorkdayContext.stringify_value(item.get_meta("desk_item_id", "desk_item"))
	var seed_source := "%s:%d:%d:%d" % [item_id, roundi(item.position.x), roundi(item.position.y), drop_sequence]
	var random := RandomNumberGenerator.new()
	random.seed = hash(seed_source)
	var random_y := random.randf_range(minimum_y, maximum_y)
	var projected_y := clampf(item.position.y, minimum_y, maximum_y)
	return lerpf(projected_y, random_y, LANDING_DEPTH_RANDOMNESS)


# 计算物件在指定桌面纵深处完整落入梯形边界时，左上角 X 的合法区间。
func _horizontal_limits(target_y: float, visual_size: Vector2) -> Vector2:
	var top_normalized := inverse_lerp(DeskGeometry.BOUNDS_TOP, DeskGeometry.BOUNDS_FLOOR, target_y)
	var bottom_normalized := inverse_lerp(DeskGeometry.BOUNDS_TOP, DeskGeometry.BOUNDS_FLOOR, target_y + visual_size.y)
	var minimum_x := maxf(DeskGeometry.bounds_left_at(top_normalized), DeskGeometry.bounds_left_at(bottom_normalized))
	var maximum_x := minf(DeskGeometry.bounds_right_at(top_normalized), DeskGeometry.bounds_right_at(bottom_normalized)) - visual_size.x
	if maximum_x < minimum_x:
		var center_x := (minimum_x + maximum_x) * 0.5
		return Vector2(center_x, center_x)
	return Vector2(minimum_x, maximum_x)


# 完成一次落桌：只保存位置，不改变点击时已经确定的相对堆栈层级。
func _finalize_settle(item: Control) -> void:
	item.remove_meta("desk_motion_tween")
	var stack_layer := item.z_index
	item.set_meta("desk_resting_layer", stack_layer)
	_persist_item_layer(item, stack_layer)
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
func _read_meta_bool(item: Control, key: String, fallback: bool = false) -> bool:
	return WorkdayContext.to_bool(item.get_meta(key, fallback))


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
