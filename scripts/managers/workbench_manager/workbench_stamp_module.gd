class_name WorkbenchStampModule
extends RefCounted

# 批准/驳回印章工具的创建、悬停反馈、拖拽与盖章判定。

signal stamp_applied(kind: String, document_id: String, local_position: Vector2)

const APPROVE_STAMP_TEXTURE := preload("res://assets/office/items/approve_stamp.png")
const RETURN_STAMP_TEXTURE := preload("res://assets/office/items/return_stamp.png")
const APPROVE_STAMP_FRAMES := [
	preload("res://assets/office/stamp_animation/approve/00_tilted_entry.png"),
	preload("res://assets/office/stamp_animation/approve/01_diagonal_swing.png"),
	preload("res://assets/office/stamp_animation/approve/02_aligning.png"),
	preload("res://assets/office/stamp_animation/approve/03_pressed_top.png"),
]
const RETURN_STAMP_FRAMES := [
	preload("res://assets/office/stamp_animation/reject/00_tilted_entry.png"),
	preload("res://assets/office/stamp_animation/reject/01_diagonal_swing.png"),
	preload("res://assets/office/stamp_animation/reject/02_aligning.png"),
	preload("res://assets/office/stamp_animation/reject/03_pressed_top.png"),
]
const STAMP_SIZE := Vector2(32, 40)
const STAMP_ANIMATION_SIZE := Vector2(192, 192)
const STAMP_CONTACT_ANCHOR := Vector2(0.5, 0.57)
const STAMP_FRAME_DURATION := 0.075
const STAMP_ANIMATION_LAYER := 1200

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
		desk_items.register_item(tool, "stamp_approve" if kind == "批准" else "stamp_return", Callable(), _on_stamp_drag_motion, Callable(), _prepare_stamp_drop, _can_begin_stamp_interaction)
	else:
		tool.gui_input.connect(_on_stamp_input.bind(tool))
	tool.mouse_entered.connect(_on_stamp_hover.bind(tool, true))
	tool.mouse_exited.connect(_on_stamp_hover.bind(tool, false))


# 鼠标悬停时轻微放大；拖拽时不响应。
func _on_stamp_hover(tool: Panel, entered: bool) -> void:
	if WorkdayContext.to_bool(tool.get_meta("dragging")) or WorkdayContext.to_bool(tool.get_meta("desk_dragging")):
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
			_prepare_stamp_drop(tool)
	elif event is InputEventMouseMotion and WorkdayContext.to_bool(tool.get_meta("dragging")):
		var mouse_motion: InputEventMouseMotion = event
		tool.position += mouse_motion.relative
		_on_stamp_drag_motion(tool)


# 拖动印章时只把最上层打开文件视为有效盖章目标。
func _on_stamp_drag_motion(tool: Control) -> void:
	var document := _stamp_target_at_tool(tool)
	CursorManager.set_drag_cursor(CursorManager.Cursor.DROP_VALID if is_instance_valid(document) else CursorManager.Cursor.STAMP)


# 动画期间锁住实体印章，避免重复开始第二次盖章。
func _can_begin_stamp_interaction(tool: Control, _local_position: Vector2) -> bool:
	return not WorkdayContext.to_bool(tool.get_meta("stamp_animation_playing"))


# 释放印章时只在有效文件上暂停落桌物理；无效落点直接交回统一重力。
func _prepare_stamp_drop(tool: Control) -> void:
	var document := _stamp_target_at_tool(tool)
	if not is_instance_valid(document):
		if is_instance_valid(desk.status_label):
			desk.status_label.text = "印章必须落在当前最上层、已经打开的文件纸面内。"
		if desk_items == null:
			_return_stamp(tool)
		return
	tool.set_meta("desk_skip_drop_once", true)
	var center := tool.get_global_transform() * (tool.size * 0.5)
	var local_position := document.get_global_transform().affine_inverse() * center
	_play_stamp_contact_animation(tool, document, local_position)


# 返回印章中心命中的最上层查验文件；桌面平躺文件不能直接盖章。
func _stamp_target_at_tool(tool: Control) -> DocumentView:
	var center := tool.get_global_transform() * (tool.size * 0.5)
	var document := presenter.find_document_at_global(center)
	if not is_instance_valid(document):
		return null
	if WorkdayContext.stringify_value(document.get_meta("document_state", "BAG")) != "INSPECTION":
		return null
	return document


# 在自由落点上播放四帧下压动作，结束后才写入印章记录并显示印记。
func _play_stamp_contact_animation(tool: Control, document: DocumentView, local_position: Vector2) -> void:
	tool.set_meta("stamp_animation_playing", true)
	tool.set_meta("desk_drag_locked", true)
	tool.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tool.visible = false
	var animation := TextureRect.new()
	animation.name = "StampContactAnimation"
	animation.size = STAMP_ANIMATION_SIZE
	animation.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	animation.stretch_mode = TextureRect.STRETCH_SCALE
	animation.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	animation.mouse_filter = Control.MOUSE_FILTER_IGNORE
	animation.z_index = STAMP_ANIMATION_LAYER
	var contact_global := document.get_global_transform() * local_position
	var contact_in_root := root.to_local(contact_global)
	animation.position = contact_in_root - STAMP_ANIMATION_SIZE * STAMP_CONTACT_ANCHOR
	root.add_child(animation)

	var kind := WorkdayContext.stringify_value(tool.get_meta("kind"))
	var frames: Array = APPROVE_STAMP_FRAMES if kind == "批准" else RETURN_STAMP_FRAMES
	for frame_texture: Texture2D in frames:
		if not is_instance_valid(animation) or not is_instance_valid(document):
			break
		animation.texture = frame_texture
		await root.get_tree().create_timer(STAMP_FRAME_DURATION).timeout

	if is_instance_valid(animation):
		animation.queue_free()
	if is_instance_valid(document):
		Sfx.play("stamp")
		stamp_applied.emit(kind, document.document_id, local_position)
	tool.visible = true
	_release_stamp_after_contact(tool)


# 盖章完成后恢复实体印章，并从盖章位置进入与铃铛相同的落桌物理。
func _release_stamp_after_contact(tool: Control) -> void:
	tool.visible = true
	tool.mouse_filter = Control.MOUSE_FILTER_STOP
	tool.set_meta("stamp_animation_playing", false)
	tool.set_meta("desk_drag_locked", false)
	tool.set_meta("desk_skip_drop_once", false)
	if desk_items != null:
		desk_items.drop_item(tool)
	else:
		_return_stamp(tool)


# 通过 Tween 将印章平滑归位。
func _return_stamp(tool: Control) -> void:
	var tween := root.create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var home: Variant = tool.get_meta("home", tool.position)
	tween.tween_property(tool, "position", home, 0.3)
	tween.tween_property(tool, "scale", Vector2.ONE, 0.18)
	tween.finished.connect(_restore_stamp_layer.bind(tool))


# 印章归位动画结束后恢复静置层级。
func _restore_stamp_layer(tool: Control) -> void:
	tool.z_index = 8
	tool.visible = true
	tool.mouse_filter = Control.MOUSE_FILTER_STOP
	tool.set_meta("stamp_animation_playing", false)
	tool.set_meta("desk_drag_locked", false)
	tool.set_meta("desk_skip_drop_once", false)
