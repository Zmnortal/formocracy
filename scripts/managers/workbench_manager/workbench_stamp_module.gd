class_name WorkbenchStampModule
extends RefCounted

# 批准/驳回印章工具的创建、悬停反馈、拖拽与盖章判定。

signal stamp_applied(kind: String, document_id: String, local_position: Vector2)

const APPROVE_STAMP_TEXTURE := preload("res://assets/office/items/approve_stamp.png")
const RETURN_STAMP_TEXTURE := preload("res://assets/office/items/return_stamp.png")
const STAMP_SIZE := Vector2(46, 56)

var root: Node2D
var desk: DeskNodes
var presenter: WorkbenchCasePresenter
var stamp_tools: Array[Panel] = []
var desk_items: DeskItemController


# 保存节点引用并创建批准与驳回两枚印章工具。
func _init(owner_root: Node2D, owner_desk: DeskNodes, owner_presenter: WorkbenchCasePresenter, item_controller: DeskItemController = null) -> void:
	root = owner_root
	desk = owner_desk
	presenter = owner_presenter
	desk_items = item_controller
	_create_stamp_tool("批准", Vector2(764, 613))
	_create_stamp_tool("驳回", Vector2(828, 613))


# 创建单枚印章工具：面板、贴图、光标与拖拽注册。
func _create_stamp_tool(kind: String, at: Vector2) -> void:
	var tool := Panel.new()
	tool.name = kind + "Stamp"
	var visual_position := at
	tool.position = visual_position
	tool.size = STAMP_SIZE
	tool.set_meta("home", visual_position)
	tool.set_meta("kind", kind)
	tool.set_meta("dragging", false)
	tool.z_index = 8
	tool.mouse_default_cursor_shape = Control.CURSOR_ARROW
	tool.add_theme_stylebox_override("panel", WorkbenchUI.style_box(Color(0, 0, 0, 0), 0))
	root.add_child(tool)
	stamp_tools.append(tool)
	CursorManager.watch(tool, CursorManager.Cursor.STAMP)

	var stamp_image := TextureRect.new()
	stamp_image.texture = APPROVE_STAMP_TEXTURE if kind == "批准" else RETURN_STAMP_TEXTURE
	stamp_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stamp_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	stamp_image.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	stamp_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tool.add_child(stamp_image)
	# TextureRect 会先采用原图 250×300 的最小尺寸；进入场景树后再覆盖，
	# 才能确保视觉贴图与印章交互框共同服从 STAMP_SIZE。
	stamp_image.position = Vector2.ZERO
	stamp_image.size = STAMP_SIZE

	if desk_items != null:
		desk_items.register_item(tool, "stamp_approve" if kind == "批准" else "stamp_return", Callable(), Callable(), _try_apply_stamp)
	else:
		tool.gui_input.connect(_on_stamp_input.bind(tool))
	tool.mouse_entered.connect(_on_stamp_hover.bind(tool, true))
	tool.mouse_exited.connect(_on_stamp_hover.bind(tool, false))


# 鼠标悬停时轻微放大；拖拽时不响应。
func _on_stamp_hover(tool: Panel, entered: bool) -> void:
	if WorkdayContext.to_bool(tool.get_meta("dragging")):
		return
	if entered:
		Sfx.play("ui_hover")
	var tween := root.create_tween()
	tween.tween_property(tool, "scale", Vector2(1.04, 1.04) if entered else Vector2.ONE, 0.08)


# 印章拖拽与释放处理。
func _on_stamp_input(event: InputEvent, tool: Panel) -> void:
	if event is InputEventMouseButton:
		var mouse_button: InputEventMouseButton = event
		if mouse_button.button_index != MOUSE_BUTTON_LEFT:
			return
		if mouse_button.pressed:
			tool.set_meta("dragging", true)
			CursorManager.begin_drag(tool, CursorManager.Cursor.STAMP)
			tool.set_meta("offset", mouse_button.position)
			tool.z_index = 20
			var tween := root.create_tween()
			tween.tween_property(tool, "scale", Vector2(1.08, 1.08), 0.08)
		else:
			tool.set_meta("dragging", false)
			CursorManager.end_drag()
			_try_apply_stamp(tool)
			_return_stamp(tool)
	elif event is InputEventMouseMotion and WorkdayContext.to_bool(tool.get_meta("dragging")):
		var mouse_motion: InputEventMouseMotion = event
		tool.position += mouse_motion.relative


# 释放印章时判断命中的最上层展开文件。
func _try_apply_stamp(tool: Panel) -> void:
	var center := tool.get_global_rect().get_center()
	var document := presenter.find_document_at_global(center)
	if not is_instance_valid(document):
		if is_instance_valid(desk.status_label):
			desk.status_label.text = "印章必须落在已展开文件的纸面范围内。"
		return
	var local_position: Vector2 = document.get_global_transform().affine_inverse() * center
	Sfx.play("stamp")
	stamp_applied.emit(WorkdayContext.stringify_value(tool.get_meta("kind")), document.document_id, local_position)


# 通过 Tween 将印章平滑归位。
func _return_stamp(tool: Panel) -> void:
	var tween := root.create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var home: Variant = tool.get_meta("home", tool.position)
	tween.tween_property(tool, "position", home, 0.3)
	tween.tween_property(tool, "scale", Vector2.ONE, 0.18)
	tween.finished.connect(_restore_stamp_layer.bind(tool))


# 印章归位动画结束后恢复静置层级。
func _restore_stamp_layer(tool: Panel) -> void:
	tool.z_index = 8
