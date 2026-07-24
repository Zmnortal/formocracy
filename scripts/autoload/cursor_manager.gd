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


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().node_added.connect(_on_node_added)
	get_tree().tree_changed.connect(_on_tree_changed)
	get_viewport().gui_focus_changed.connect(_on_gui_focus_changed)
	call_deferred("_watch_existing_buttons")
	_apply_cursor(Cursor.DEFAULT)


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


func release_cursor(source: Object) -> void:
	if not is_instance_valid(source):
		return
	_requests.erase(source.get_instance_id())
	_refresh_cursor()


func begin_drag(source: Object, cursor: Cursor = Cursor.GRABBING) -> void:
	_drag_source = weakref(source) if is_instance_valid(source) else null
	_drag_cursor = cursor
	_apply_cursor(cursor)


func set_drag_cursor(cursor: Cursor) -> void:
	if _drag_source == null or _drag_source.get_ref() == null:
		return
	_drag_cursor = cursor
	_apply_cursor(cursor)


func end_drag() -> void:
	_drag_source = null
	_drag_cursor = Cursor.GRABBING
	_refresh_cursor()


func reset() -> void:
	_requests.clear()
	_drag_source = null
	_drag_cursor = Cursor.GRABBING
	_apply_cursor(Cursor.DEFAULT)


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


func _on_node_added(node: Node) -> void:
	if node is BaseButton:
		call_deferred("_watch_button", node)


func _watch_existing_buttons() -> void:
	var root := get_tree().current_scene
	if not is_instance_valid(root):
		return
	for node in root.find_children("*", "BaseButton", true, false):
		_watch_button(node)


func _watch_button(button: BaseButton) -> void:
	if not is_instance_valid(button) or button.has_meta("context_cursor"):
		return
	watch(button, Cursor.POINT)


func _on_control_entered(control: Control) -> void:
	if not _is_control_interactable(control):
		return
	request_cursor(control.get_meta("context_cursor", Cursor.POINT), control)


func _on_control_exited(control: Control) -> void:
	release_cursor(control)


func _on_control_input(event: InputEvent, control: Control) -> void:
	if not _is_control_interactable(control):
		release_cursor(control)
		return
	var requested: Cursor = control.get_meta("context_cursor", Cursor.POINT)
	if requested != Cursor.POINT:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		request_cursor(Cursor.POINT_PRESSED if event.pressed else Cursor.POINT, control)


func _on_control_exiting(control: Control) -> void:
	release_cursor(control)


func _is_control_interactable(control: Control) -> bool:
	return not (control is BaseButton and control.disabled)


func _refresh_cursor() -> void:
	if _drag_source != null and _drag_source.get_ref() != null:
		_apply_cursor(_drag_cursor)
		return
	_discard_invalid_requests()
	var latest_sequence := -1
	var selected := Cursor.DEFAULT
	for request: Dictionary in _requests.values():
		if int(request.sequence) > latest_sequence:
			latest_sequence = int(request.sequence)
			selected = request.cursor
	_apply_cursor(selected)


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


func _on_tree_changed() -> void:
	_discard_invalid_requests()
	_refresh_cursor()


func _on_gui_focus_changed(_control: Control) -> void:
	if not get_viewport().gui_get_focus_owner():
		_refresh_cursor()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		reset()


func _apply_cursor(cursor: Cursor) -> void:
	current_cursor = cursor
	var texture: Texture2D = TEXTURES.get(cursor)
	if texture == null:
		Input.set_custom_mouse_cursor(null, Input.CURSOR_ARROW)
		return
	Input.set_custom_mouse_cursor(texture, Input.CURSOR_ARROW, HOTSPOTS.get(cursor, Vector2.ZERO))
