class_name StampManager
extends RefCounted

# 批准/驳回印章工具的创建、悬停反馈、拖拽与盖章判定。

signal stamp_applied(kind: String, local_position: Vector2)

const APPROVE_STAMP_TEXTURE := preload("res://assets/day1_8bit/interactive/approve_stamp.png")
const RETURN_STAMP_TEXTURE := preload("res://assets/day1_8bit/interactive/return_stamp.png")

var root: Node2D
var desk: DeskNodes
var presenter: CasePresenter
var stamp_tools: Array[Panel] = []


func _init(owner_root: Node2D, owner_desk: DeskNodes, owner_presenter: CasePresenter) -> void:
	root = owner_root
	desk = owner_desk
	presenter = owner_presenter
	_create_stamp_tool("批准", WorkbenchUI.COLORS.green, Vector2(850, 565))
	_create_stamp_tool("驳回", WorkbenchUI.COLORS.red, Vector2(945, 565))


func _create_stamp_tool(kind: String, color: Color, at: Vector2) -> void:
	var tool := Panel.new()
	tool.name = kind + "Stamp"
	var visual_position := at - Vector2(18, 20)
	tool.position = visual_position
	tool.size = Vector2(140, 132)
	tool.set_meta("home", visual_position)
	tool.set_meta("kind", kind)
	tool.set_meta("dragging", false)
	tool.mouse_default_cursor_shape = Control.CURSOR_ARROW
	tool.add_theme_stylebox_override("panel", WorkbenchUI.style_box(Color(0, 0, 0, 0), 0))
	root.add_child(tool)
	stamp_tools.append(tool)
	CursorManager.watch(tool, CursorManager.Cursor.STAMP)

	var stamp_image := TextureRect.new()
	stamp_image.texture = APPROVE_STAMP_TEXTURE if kind == "批准" else RETURN_STAMP_TEXTURE
	stamp_image.position = Vector2.ZERO
	stamp_image.size = Vector2(140, 132)
	stamp_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stamp_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	stamp_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tool.add_child(stamp_image)

	tool.gui_input.connect(_on_stamp_input.bind(tool))
	tool.mouse_entered.connect(_on_stamp_hover.bind(tool, true))
	tool.mouse_exited.connect(_on_stamp_hover.bind(tool, false))


# 鼠标悬停时轻微放大；拖拽时不响应。
func _on_stamp_hover(tool: Panel, entered: bool) -> void:
	if bool(tool.get_meta("dragging")):
		return
	if entered:
		Sfx.play("ui_hover")
	var tween := root.create_tween()
	tween.tween_property(tool, "scale", Vector2(1.04, 1.04) if entered else Vector2.ONE, 0.08)


# 印章拖拽与释放处理。
func _on_stamp_input(event: InputEvent, tool: Panel) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			tool.set_meta("dragging", true)
			CursorManager.begin_drag(tool, CursorManager.Cursor.STAMP)
			tool.set_meta("offset", event.position)
			tool.z_index = 20
			var tween := root.create_tween()
			tween.tween_property(tool, "scale", Vector2(1.08, 1.08), 0.08)
		else:
			tool.set_meta("dragging", false)
			CursorManager.end_drag()
			_try_apply_stamp(tool)
			_return_stamp(tool)
	elif event is InputEventMouseMotion and tool.get_meta("dragging"):
		tool.position += event.relative


# 释放印章时判断是否盖到申请表上。
func _try_apply_stamp(tool: Panel) -> void:
	if not is_instance_valid(presenter.form):
		return
	var center := tool.get_global_rect().get_center()
	if presenter.form.get_global_rect().has_point(center):
		Sfx.play("stamp")
		stamp_applied.emit(String(tool.get_meta("kind")), center - presenter.form.global_position)


# 通过 Tween 将印章平滑归位。
func _return_stamp(tool: Panel) -> void:
	var tween := root.create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(tool, "position", tool.get_meta("home"), 0.3)
	tween.tween_property(tool, "scale", Vector2.ONE, 0.18)
	tween.finished.connect(func(): tool.z_index = 0)
