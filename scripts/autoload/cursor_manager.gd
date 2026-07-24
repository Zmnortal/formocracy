extends Node

# 统一管理情境化像素光标。交互模块只报告动作语义，不直接操作贴图。

enum Cursor {
	DEFAULT,
	POINT,
	POINT_PRESSED,
	GRAB,
	GRABBING,
	DROP_VALID,
	DROP_INVALID,
	OPEN_ENVELOPE,
	STAMP,
}

const TEXTURES := {
	Cursor.DEFAULT: preload("res://assets/ui/cursors/default_arrow.png"),
	Cursor.POINT: preload("res://assets/ui/cursors/point.png"),
	Cursor.POINT_PRESSED: preload("res://assets/ui/cursors/point_pressed.png"),
	Cursor.GRAB: preload("res://assets/ui/cursors/grab.png"),
	Cursor.GRABBING: preload("res://assets/ui/cursors/grabbing.png"),
	Cursor.DROP_VALID: preload("res://assets/ui/cursors/drop_valid.png"),
	Cursor.DROP_INVALID: preload("res://assets/ui/cursors/drop_invalid.png"),
	Cursor.OPEN_ENVELOPE: preload("res://assets/ui/cursors/open_envelope.png"),
	Cursor.STAMP: preload("res://assets/ui/cursors/stamp.png"),
}

const HOTSPOTS := {
	Cursor.DEFAULT: Vector2(3, 3),
	Cursor.POINT: Vector2(8, 6),
	Cursor.POINT_PRESSED: Vector2(8, 8),
	Cursor.GRAB: Vector2(24, 23),
	Cursor.GRABBING: Vector2(24, 21),
	Cursor.DROP_VALID: Vector2(24, 41),
	Cursor.DROP_INVALID: Vector2(23, 23),
	Cursor.OPEN_ENVELOPE: Vector2(11, 12),
	Cursor.STAMP: Vector2(30, 54),
}

var current_cursor: Cursor = Cursor.DEFAULT
var _requests: Dictionary = {}
var _request_sequence := 0
var _drag_source: WeakRef
var _drag_cursor: Cursor = Cursor.GRABBING


# 初始化光标管理器，监听场景节点变化并绑定按钮悬停效果。
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().node_added.connect(_on_node_added)
	get_tree().tree_changed.connect(_on_tree_changed)
	get_viewport().gui_focus_changed.connect(_on_gui_focus_changed)
	call_deferred("_watch_existing_buttons")
	_apply_cursor(Cursor.DEFAULT)


# 注册一个光标请求，按来源对象与顺序决定当前显示光标。
func request_cursor(cursor: Cursor, source: Object) -> void:
	if not is_instance_valid(source):
		return
	_request_sequence += 1
	_requests[source.get_instance_id()] = {
		"source": weakref(source),
		"cursor": cursor,
		"sequence": _request_sequence,
	}
	_refresh_cursor()


# 移除指定来源的光标请求，并刷新当前光标。
func release_cursor(source: Object) -> void:
	if not is_instance_valid(source):
		return
	_requests.erase(source.get_instance_id())
	_refresh_cursor()


# 开始拖拽，记录拖拽来源并应用拖拽光标。
func begin_drag(source: Object, cursor: Cursor = Cursor.GRABBING) -> void:
	_drag_source = weakref(source) if is_instance_valid(source) else null
	_drag_cursor = cursor
	_apply_cursor(cursor)


# 拖拽过程中切换光标样式。
func set_drag_cursor(cursor: Cursor) -> void:
	if _drag_source == null or _drag_source.get_ref() == null:
		return
	_drag_cursor = cursor
	_apply_cursor(cursor)


# 结束拖拽，清除拖拽来源并恢复普通光标。
func end_drag() -> void:
	_drag_source = null
	_drag_cursor = Cursor.GRABBING
	_refresh_cursor()


# 重置所有光标请求与拖拽状态，恢复默认光标。
func reset() -> void:
	_requests.clear()
	_drag_source = null
	_drag_cursor = Cursor.GRABBING
	_apply_cursor(Cursor.DEFAULT)


# 监听指定控件的鼠标事件，根据上下文自动切换光标。
func watch(control: Control, cursor: Cursor) -> void:
	if not is_instance_valid(control):
		return
	control.mouse_default_cursor_shape = Control.CURSOR_ARROW
	control.set_meta("context_cursor", cursor)
	if not control.mouse_entered.is_connected(_on_control_entered.bind(control)):
		control.mouse_entered.connect(_on_control_entered.bind(control))
	if not control.mouse_exited.is_connected(_on_control_exited.bind(control)):
		control.mouse_exited.connect(_on_control_exited.bind(control))
	if not control.gui_input.is_connected(_on_control_input.bind(control)):
		control.gui_input.connect(_on_control_input.bind(control))
	if not control.tree_exiting.is_connected(_on_control_exiting.bind(control)):
		control.tree_exiting.connect(_on_control_exiting.bind(control))


# 新节点加入场景时，若为按钮则自动应用指点光标。
func _on_node_added(node: Node) -> void:
	if node is BaseButton:
		call_deferred("_watch_button", node)


# 遍历当前场景中的所有按钮并统一绑定光标监听。
func _watch_existing_buttons() -> void:
	var root := get_tree().current_scene
	if not is_instance_valid(root):
		return
	for node: Node in root.find_children("*", "BaseButton", true, false):
		if node is BaseButton:
			var button: BaseButton = node
			_watch_button(button)


# 为单个按钮绑定指点光标，避免重复绑定。
func _watch_button(button: BaseButton) -> void:
	if not is_instance_valid(button) or button.has_meta("context_cursor"):
		return
	watch(button, Cursor.POINT)


# 鼠标进入控件时，按控件绑定的上下文光标发起请求。
func _on_control_entered(control: Control) -> void:
	if not _is_control_interactable(control):
		return
	var requested: Cursor = WorkdayContext.to_int(control.get_meta("context_cursor"), Cursor.POINT)
	request_cursor(requested, control)


# 鼠标离开控件时释放对应光标请求。
func _on_control_exited(control: Control) -> void:
	release_cursor(control)


# 处理控件输入事件，在左键按下时切换为按下状态光标。
func _on_control_input(event: InputEvent, control: Control) -> void:
	if not _is_control_interactable(control):
		release_cursor(control)
		return
	var requested: Cursor = WorkdayContext.to_int(control.get_meta("context_cursor"), Cursor.POINT)
	if requested != Cursor.POINT:
		return
	if event is InputEventMouseButton:
		var mouse_button: InputEventMouseButton = event
		if mouse_button.button_index == MOUSE_BUTTON_LEFT:
			request_cursor(Cursor.POINT_PRESSED if mouse_button.pressed else Cursor.POINT, control)


# 控件即将销毁时释放其光标请求。
func _on_control_exiting(control: Control) -> void:
	release_cursor(control)


# 判断控件是否可交互（禁用按钮视为不可交互）。
func _is_control_interactable(control: Control) -> bool:
	if control is BaseButton:
		var button: BaseButton = control
		return not button.disabled
	return true


# 根据当前拖拽状态与请求队列刷新实际光标。
func _refresh_cursor() -> void:
	if _drag_source != null and _drag_source.get_ref() != null:
		_apply_cursor(_drag_cursor)
		return
	_discard_invalid_requests()
	var latest_sequence := -1
	var selected := Cursor.DEFAULT
	for request: Dictionary in _requests.values():
		var sequence := WorkdayContext.read_int(request, "sequence")
		if sequence > latest_sequence:
			latest_sequence = sequence
			selected = WorkdayContext.read_int(request, "cursor", Cursor.DEFAULT)
	_apply_cursor(selected)


# 清理已失效来源（被释放对象）的光标请求。
func _discard_invalid_requests() -> void:
	var invalid_ids: Array[int] = []
	for instance_id: int in _requests:
		var source_ref: WeakRef = _requests[instance_id].source
		if source_ref.get_ref() == null:
			invalid_ids.append(instance_id)
	for instance_id in invalid_ids:
		_requests.erase(instance_id)
	if _drag_source != null and _drag_source.get_ref() == null:
		_drag_source = null


# 场景树变化时清理失效请求并刷新光标。
func _on_tree_changed() -> void:
	_discard_invalid_requests()
	_refresh_cursor()


# 焦点变化时若当前无焦点控件则刷新光标。
func _on_gui_focus_changed(_control: Control) -> void:
	if not get_viewport().gui_get_focus_owner():
		_refresh_cursor()


# 应用失去焦点时重置光标，避免光标状态残留。
func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		reset()


# 应用指定的自定义光标纹理与热点。
func _apply_cursor(cursor: Cursor) -> void:
	current_cursor = cursor
	var texture: Texture2D = TEXTURES.get(cursor)
	if texture == null:
		Input.set_custom_mouse_cursor(null, Input.CURSOR_ARROW)
		return
	var hotspot_value: Variant = HOTSPOTS.get(cursor, Vector2.ZERO)
	var hotspot: Vector2 = hotspot_value if hotspot_value is Vector2 else Vector2.ZERO
	Input.set_custom_mouse_cursor(texture, Input.CURSOR_ARROW, hotspot)
