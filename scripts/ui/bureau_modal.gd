class_name BureauModal
extends Control

# 局务通用模态弹窗。
# 支持标题、正文、一个或多个动作按钮，以及 ESC 取消/关闭行为。

signal dismissed
signal action_pressed(action_id: String)

const UI := preload("res://scripts/ui/bureau_ui.gd")
const REFERENCE_VIEWPORT := Vector2(1280, 720)

var panel: Panel
var title_label: Label
var message_label: Label
var action_row: BoxContainer
var cancel_action := ""
var default_button: Button
var action_button_size := Vector2(220, 54)
var base_panel_size := Vector2.ZERO


# 初始化弹窗：全屏停靠、拦截鼠标事件、始终运行。
func _init() -> void:
	name = "BureauModal"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false


# 配置弹窗内容：标题、正文、面板尺寸、动作按钮纵向/横向排列。
func configure(
		title: String,
		message: String,
		panel_size := Vector2(620, 330),
		vertical_actions := false
) -> void:
	for child in get_children():
		child.queue_free()

	var shade := ColorRect.new()
	shade.name = "ModalShade"
	shade.color = UI.COLOR_BACKDROP
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(shade)

	panel = Panel.new()
	panel.name = "ModalPanel"
	base_panel_size = panel_size
	panel.position = Vector2.ZERO
	panel.size = panel_size
	UI.style_panel(panel)
	add_child(panel)

	title_label = Label.new()
	title_label.name = "ModalTitle"
	title_label.text = title
	title_label.position = Vector2(36, 28)
	title_label.size = Vector2(panel_size.x - 72, 46)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UI.style_label(title_label, 26)
	panel.add_child(title_label)

	var rule := HSeparator.new()
	rule.position = Vector2(36, 83)
	rule.size = Vector2(panel_size.x - 72, 8)
	panel.add_child(rule)

	message_label = Label.new()
	message_label.name = "ModalMessage"
	message_label.text = message
	message_label.position = Vector2(48, 101)
	message_label.size = Vector2(panel_size.x - 96, panel_size.y - (298 if vertical_actions else 210))
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UI.style_label(message_label, 19, true)
	panel.add_child(message_label)

	action_row = VBoxContainer.new() if vertical_actions else HBoxContainer.new()
	action_row.name = "ModalActions"
	action_row.position = Vector2(70, panel_size.y - 210) if vertical_actions else Vector2(42, panel_size.y - 82)
	action_row.size = Vector2(panel_size.x - 140, 180) if vertical_actions else Vector2(panel_size.x - 84, 54)
	action_row.alignment = BoxContainer.ALIGNMENT_CENTER
	action_row.add_theme_constant_override("separation", 10 if vertical_actions else 18)
	panel.add_child(action_row)
	action_button_size = Vector2(panel_size.x - 140, 52) if vertical_actions else Vector2(220, 54)
	call_deferred("_fit_to_viewport")


# 添加一个动作按钮并返回引用；primary 按钮会被记录为默认焦点按钮。
func add_action(action_id: String, text: String, primary := false, danger := false) -> Button:
	var button := Button.new()
	button.name = "%sButton" % action_id.to_pascal_case()
	button.text = text
	button.custom_minimum_size = action_button_size
	UI.style_button(button, 18, danger)
	button.pressed.connect(_on_action.bind(action_id))
	action_row.add_child(button)
	if primary or default_button == null:
		default_button = button
	return button


# 设置 ESC 取消时触发的动作 ID；若为空则仅关闭弹窗。
func set_cancel_action(action_id: String) -> void:
	cancel_action = action_id


# 显示弹窗并将焦点设置到默认按钮。
func open() -> void:
	_fit_to_viewport()
	visible = true
	if default_button != null:
		default_button.grab_focus()


# 隐藏弹窗。
func close() -> void:
	visible = false


# 弹窗可见时按 ESC 触发取消或关闭。
func _gui_input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		if cancel_action.is_empty():
			close()
			dismissed.emit()
		else:
			_on_action(cancel_action)
		accept_event()


# 内部：按钮按下时发射 action_pressed 信号。
func _on_action(action_id: String) -> void:
	action_pressed.emit(action_id)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and panel != null:
		_fit_to_viewport()


func _fit_to_viewport() -> void:
	if panel == null or base_panel_size == Vector2.ZERO:
		return
	var viewport_size := size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		viewport_size = get_viewport_rect().size
	var ui_scale: float = minf(
		viewport_size.x / REFERENCE_VIEWPORT.x,
		viewport_size.y / REFERENCE_VIEWPORT.y
	)
	ui_scale = clampf(ui_scale, 1.0, 2.0)
	panel.scale = Vector2.ONE * ui_scale
	panel.position = (viewport_size - base_panel_size * ui_scale) / 2.0
