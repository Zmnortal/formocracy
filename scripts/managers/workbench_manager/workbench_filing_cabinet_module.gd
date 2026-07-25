class_name WorkbenchFilingCabinetModule
extends RefCounted

# 左侧双层文件柜。
# 上层保存局务参考手册，下层保存跨工作日累积的私人证物。

const CLOSED_TEXTURE := preload("res://assets/office/filing_cabinet/states/00_closed.png")
const UPPER_HALF_TEXTURE := preload("res://assets/office/filing_cabinet/states/01_upper_half_open.png")
const UPPER_OPEN_TEXTURE := preload("res://assets/office/filing_cabinet/states/02_upper_open_handbook.png")
const UPPER_OPEN_EMPTY_TEXTURE := preload("res://assets/office/filing_cabinet/states/02_upper_open_empty.png")
const LOWER_HALF_TEXTURE := preload("res://assets/office/filing_cabinet/states/03_lower_half_open.png")
const LOWER_OPEN_TEXTURE := preload("res://assets/office/filing_cabinet/states/04_lower_open_evidence.png")
const HANDBOOK_ITEM_TEXTURE := preload("res://assets/office/filing_cabinet/contents/reference_handbook_item.png")
const HANDBOOK_PAPER_TEXTURE := preload("res://assets/office/filing_cabinet/contents/reference_handbook_paper_spread.png")
const DOSSIER_TEXTURE := preload("res://assets/office/filing_cabinet/contents/private_evidence_dossier.png")
const CLUE_TEXTURE := preload("res://assets/office/filing_cabinet/contents/loose_clue_set.png")
const UI := preload("res://scripts/ui/bureau_ui.gd")

const STATE_CLOSED := "closed"
const STATE_UPPER_HALF := "upper_half"
const STATE_UPPER_OPEN := "upper_open"
const STATE_LOWER_HALF := "lower_half"
const STATE_LOWER_OPEN := "lower_open"

const BOOK_IN_DRAWER := "in_drawer"
const BOOK_ON_DESK := "on_desk_closed"
const BOOK_READING := "reading"
const BOOK_MOVING := "moving"
const BOOK_ITEM_ID := "reference_handbook"
const BOOK_DRAWER_POSITION := Vector2(51, 250)
const BOOK_DRAWER_SCALE := Vector2(0.96, 0.46)
const BOOK_DESK_POSITION := Vector2(310, 570)
const BOOK_DESK_SCALE := Vector2(1.0, 1.0)

const HANDBOOK_SPREADS := [
	{
		"left_title": "第一编 / 办理流程",
		"left_body": (
			"一、接收申请人投递的封存文件袋。\n\n"
			+ "二、拆封并核对表单与全部附件。\n\n"
			+ "三、依据当日规则作出批准或退回决定。"
		),
		"right_title": "送验与归档",
		"right_body": (
			"四、将全部材料重新装袋并封存。\n\n"
			+ "五、把封存袋放入当日归档托盘。\n\n"
			+ "未完成封存的材料不得送往现实验收设施。"
		),
	},
	{
		"left_title": "第二编 / 操作方法",
		"left_body": (
			"拖动\n按住文件、附件或印章移动。\n\n"
			+ "查验\n点击表单可将其立起阅读。\n\n"
			+ "勾选\n点击方框完成形式核对。"
		),
		"right_title": "桌面操作",
		"right_body": (
			"盖章\n将批准章或退回章压在指定区域。\n\n"
			+ "归袋\n把全部文件送回打开的袋口。\n\n"
			+ "菜单\n按 ESC 打开暂停菜单。"
		),
	},
	{
		"left_title": "第三编 / 局务常识",
		"left_body": (
			"表单不是记录现实的纸张。\n\n"
			+ "在中央现实管理局，完成程序的表单会获得现实效力。"
		),
		"right_title": "经办员须知",
		"right_body": (
			"经办员既是制度的执行者，也是制度的申请人。\n\n"
			+ "所有私人需求，同样必须经过申请、审批与送验。"
		),
	},
]

const EVIDENCE_BODY := (
	"证物 01 / 剪去姓名的旧职员照片\n"
	+ "背面留有与本人档案相同的归档序号，来源不明。\n\n"
	+ "证物 02 / 无编号黄铜钥匙\n"
	+ "齿形不属于宿舍、办公室或已登记公共设施。\n\n"
	+ "证物 03 / 被注销的夜间通行票\n"
	+ "签发日期早于本人记忆开始的那一天。"
)

var root: Node2D
var desk: DeskNodes
var desk_items: DeskItemController
var overlay: Control
var content_asset: TextureRect
var clue_asset: TextureRect
var section_label: Label
var body_label: Label
var footer_label: Label
var handbook_item: TextureRect
var handbook_return_zone: Control
var reader_overlay: Control
var reader_content: Control
var reader_left_title: Label
var reader_left_body: Label
var reader_right_title: Label
var reader_right_body: Label
var reader_page_label: Label
var reader_previous_button: Button
var reader_next_button: Button
var state := STATE_CLOSED
var book_state := BOOK_IN_DRAWER
var _transition_token := 0
var _transitioning := false
var _handbook_page := 0
var _page_transitioning := false


func _init(owner_root: Node2D, desk_nodes: DeskNodes, item_controller: DeskItemController = null) -> void:
	root = owner_root
	desk = desk_nodes
	desk_items = item_controller
	_build_overlay()
	_build_handbook_item()
	_build_reader_overlay()
	desk.filing_cabinet_upper_hit.pressed.connect(open_upper)
	desk.filing_cabinet_lower_hit.pressed.connect(open_lower)
	desk.filing_cabinet_upper_hit.mouse_entered.connect(_play_hover)
	desk.filing_cabinet_lower_hit.mouse_entered.connect(_play_hover)
	CursorManager.watch(desk.filing_cabinet_upper_hit, CursorManager.Cursor.POINT)
	CursorManager.watch(desk.filing_cabinet_lower_hit, CursorManager.Cursor.POINT)


# 打开上层抽屉。手册只作为实体物件出现，不直接进入阅读层。
func open_upper() -> void:
	if _transitioning or overlay.visible or reader_overlay.visible:
		return
	if state == STATE_UPPER_OPEN:
		close_upper()
		return
	if state != STATE_CLOSED:
		return
	_transitioning = true
	_set_drawer_buttons_disabled(true)
	_transition_token += 1
	var token := _transition_token
	state = STATE_UPPER_HALF
	desk.filing_cabinet.texture = UPPER_HALF_TEXTURE
	Sfx.play("door", -5.0, 1.15)
	await root.get_tree().create_timer(0.11).timeout
	if token != _transition_token or not is_instance_valid(desk.filing_cabinet):
		return
	state = STATE_UPPER_OPEN
	# 稳定帧始终使用空抽屉；手册由独立节点绘制，避免底图和实体书重影。
	desk.filing_cabinet.texture = UPPER_OPEN_EMPTY_TEXTURE
	_show_book_in_open_drawer()
	desk.filing_cabinet_upper_hit.disabled = false
	desk.filing_cabinet_lower_hit.disabled = true
	_transitioning = false


# 关闭上层抽屉；已经拿到桌面的手册不会随抽屉消失。
func close_upper() -> void:
	if _transitioning or state != STATE_UPPER_OPEN or reader_overlay.visible:
		return
	_transitioning = true
	_transition_token += 1
	var token := _transition_token
	if book_state == BOOK_IN_DRAWER:
		handbook_item.visible = false
		desk.filing_cabinet.texture = UPPER_HALF_TEXTURE
	Sfx.play("door", -7.0, 0.82)
	await root.get_tree().create_timer(0.1).timeout
	if token != _transition_token or not is_instance_valid(desk.filing_cabinet):
		return
	state = STATE_CLOSED
	desk.filing_cabinet.texture = CLOSED_TEXTURE
	_set_drawer_buttons_disabled(false)
	_transitioning = false


# 打开下层抽屉，并显示跨工作日保存的私人证物。
func open_lower() -> void:
	if _transitioning or overlay.visible or reader_overlay.visible or state != STATE_CLOSED:
		return
	_transitioning = true
	_set_drawer_buttons_disabled(true)
	_transition_token += 1
	var token := _transition_token
	state = STATE_LOWER_HALF
	desk.filing_cabinet.texture = LOWER_HALF_TEXTURE
	Sfx.play("door", -5.0, 0.92)
	await root.get_tree().create_timer(0.11).timeout
	if token != _transition_token or not is_instance_valid(desk.filing_cabinet):
		return
	state = STATE_LOWER_OPEN
	desk.filing_cabinet.texture = LOWER_OPEN_TEXTURE
	_render_evidence()
	await _reveal_overlay()
	_transitioning = false


# 关闭阅读层并把当前抽屉收回柜体。
func close() -> void:
	if _transitioning or not overlay.visible:
		return
	_transitioning = true
	_transition_token += 1
	var token := _transition_token
	var fade := overlay.create_tween()
	fade.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	fade.tween_property(overlay, "modulate:a", 0.0, 0.12)
	await fade.finished
	if token != _transition_token:
		return
	overlay.visible = false
	overlay.modulate.a = 1.0
	if state == STATE_UPPER_OPEN:
		state = STATE_UPPER_HALF
		desk.filing_cabinet.texture = UPPER_HALF_TEXTURE
	elif state == STATE_LOWER_OPEN:
		state = STATE_LOWER_HALF
		desk.filing_cabinet.texture = LOWER_HALF_TEXTURE
	Sfx.play("door", -7.0, 0.8)
	await root.get_tree().create_timer(0.09).timeout
	if token != _transition_token or not is_instance_valid(desk.filing_cabinet):
		return
	state = STATE_CLOSED
	desk.filing_cabinet.texture = CLOSED_TEXTURE
	_set_drawer_buttons_disabled(false)
	_transitioning = false


# ESC 在阅读层可见时只关闭文件柜，不传递给暂停菜单。
func handle_unhandled_input(event: InputEvent) -> bool:
	if not event is InputEventKey:
		return false
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo or key_event.keycode != KEY_ESCAPE:
		return false
	if reader_overlay.visible:
		close_handbook()
	elif overlay.visible:
		close()
	elif state == STATE_UPPER_OPEN:
		close_upper()
	else:
		return false
	root.get_viewport().set_input_as_handled()
	return true


# 测试与调试入口：切换参考手册页签。
func select_handbook_page(page_index: int) -> void:
	_render_reader_page(page_index)


# 场景退出时终止异步过渡并释放阅读层。
func shutdown() -> void:
	_transition_token += 1
	_transitioning = false
	if desk_items != null:
		desk_items.unregister_item(BOOK_ITEM_ID)
	CursorManager.release_cursor(handbook_item)
	if is_instance_valid(overlay):
		overlay.queue_free()
	if is_instance_valid(reader_overlay):
		reader_overlay.queue_free()
	if is_instance_valid(handbook_item):
		handbook_item.queue_free()
	overlay = null
	reader_overlay = null
	handbook_item = null
	root = null
	desk = null
	desk_items = null


# 构建可在抽屉与桌面之间移动的独立闭合手册。
func _build_handbook_item() -> void:
	handbook_item = TextureRect.new()
	handbook_item.name = "ReferenceHandbookItem"
	handbook_item.texture = HANDBOOK_ITEM_TEXTURE
	handbook_item.position = BOOK_DRAWER_POSITION
	handbook_item.size = Vector2(112, 145)
	handbook_item.scale = BOOK_DRAWER_SCALE
	handbook_item.pivot_offset = handbook_item.size / 2.0
	handbook_item.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	handbook_item.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	handbook_item.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	handbook_item.mouse_filter = Control.MOUSE_FILTER_STOP
	handbook_item.z_index = 14
	handbook_item.visible = false
	handbook_item.tooltip_text = "局务参考手册"
	handbook_item.set_meta("debug_zone_label", "可取出的局务参考手册")
	root.add_child(handbook_item)
	# TextureRect 入树时会短暂继承原图最小尺寸；入树后锁回设计尺寸与中心轴。
	handbook_item.position = BOOK_DRAWER_POSITION
	handbook_item.size = Vector2(112, 145)
	handbook_item.pivot_offset = handbook_item.size / 2.0
	handbook_item.scale = BOOK_DRAWER_SCALE

	handbook_return_zone = Control.new()
	handbook_return_zone.name = "HandbookReturnZone"
	# 独立热区使用屏幕设计坐标，不与柜体贴图的缩放或透明边距绑定。
	handbook_return_zone.position = Vector2(-4, 228)
	handbook_return_zone.size = Vector2(250, 154)
	handbook_return_zone.mouse_filter = Control.MOUSE_FILTER_IGNORE
	handbook_return_zone.add_to_group("debug_interaction_zone")
	handbook_return_zone.set_meta("debug_zone_label", "参考手册归还区")
	root.add_child(handbook_return_zone)

	if desk_items != null:
		desk_items.register_item(
			handbook_item,
			BOOK_ITEM_ID,
			_on_handbook_clicked,
			_on_handbook_drag_motion,
			Callable(),
			_prepare_handbook_drop,
			_can_begin_handbook_interaction,
		)
	_set_handbook_pose(BOOK_DRAWER_POSITION, BOOK_DRAWER_SCALE)
	CursorManager.watch(handbook_item, CursorManager.Cursor.POINT)


# 构建纸质双页阅读层；正文保持为代码文本，资产只负责纸张与卷角。
func _build_reader_overlay() -> void:
	reader_overlay = Control.new()
	reader_overlay.name = "ReferenceHandbookReader"
	reader_overlay.position = Vector2.ZERO
	reader_overlay.size = DeskGeometry.design_size()
	reader_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	reader_overlay.z_index = 460
	reader_overlay.visible = false
	root.add_child(reader_overlay)

	var shade := ColorRect.new()
	shade.name = "ReaderShade"
	shade.color = Color(0.008, 0.007, 0.005, 0.78)
	shade.position = Vector2.ZERO
	shade.size = DeskGeometry.design_size()
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	reader_overlay.add_child(shade)

	var paper := TextureRect.new()
	paper.name = "PaperHandbookSpread"
	paper.texture = HANDBOOK_PAPER_TEXTURE
	paper.position = Vector2(120, 34)
	paper.size = Vector2(1040, 650)
	paper.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	paper.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	paper.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	paper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	reader_overlay.add_child(paper)
	paper.position = Vector2(120, 34)
	paper.size = Vector2(1040, 650)

	reader_content = Control.new()
	reader_content.name = "ReaderContent"
	reader_content.position = Vector2.ZERO
	reader_content.size = DeskGeometry.design_size()
	reader_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	reader_overlay.add_child(reader_content)

	reader_left_title = _add_reader_text(Vector2(292, 112), Vector2(326, 40), 22, Color("473b2a"))
	reader_left_body = _add_reader_text(Vector2(292, 166), Vector2(326, 368), 17, Color("40392d"))
	reader_right_title = _add_reader_text(Vector2(706, 112), Vector2(326, 40), 22, Color("473b2a"))
	reader_right_body = _add_reader_text(Vector2(706, 166), Vector2(326, 368), 17, Color("40392d"))
	reader_left_body.add_theme_constant_override("line_spacing", 8)
	reader_right_body.add_theme_constant_override("line_spacing", 8)

	reader_page_label = _add_reader_text(Vector2(570, 582), Vector2(140, 28), 14, Color("665943"))
	reader_page_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	reader_previous_button = _add_page_corner_button("PreviousPageCurl", "◁  卷回", Vector2(228, 560))
	reader_previous_button.pressed.connect(turn_handbook_page.bind(-1))
	reader_next_button = _add_page_corner_button("NextPageCurl", "翻页  ▷", Vector2(876, 560))
	reader_next_button.pressed.connect(turn_handbook_page.bind(1))

	var close_button := Button.new()
	close_button.name = "CloseHandbookButton"
	close_button.text = "合上手册  ×"
	close_button.position = Vector2(1024, 28)
	close_button.size = Vector2(174, 42)
	UI.style_button(close_button, 15)
	close_button.pressed.connect(close_handbook)
	close_button.mouse_entered.connect(_play_hover)
	reader_overlay.add_child(close_button)
	CursorManager.watch(close_button, CursorManager.Cursor.POINT)

	var guide := _add_reader_text(Vector2(462, 666), Vector2(356, 26), 13, Color("c8b991"))
	guide.text = "点击纸页卷角翻页  /  ESC 合上手册"
	guide.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


# 创建阅读层中的纸上文本。
func _add_reader_text(position: Vector2, size: Vector2, font_size: int, color: Color) -> Label:
	var label := WorkbenchUI.add_text(reader_content, "", font_size, color, position, size)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


# 创建覆盖卷角的透明大热区，文字只做轻量方向提示。
func _add_page_corner_button(node_name: String, text: String, position: Vector2) -> Button:
	var button := Button.new()
	button.name = node_name
	button.text = text
	button.position = position
	button.size = Vector2(170, 90)
	button.flat = true
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 16)
	button.add_theme_color_override("font_color", Color("5a4935"))
	button.add_theme_color_override("font_hover_color", Color("2d241a"))
	button.add_theme_color_override("font_disabled_color", Color("9c8d70"))
	button.mouse_entered.connect(_play_hover)
	reader_overlay.add_child(button)
	CursorManager.watch(button, CursorManager.Cursor.POINT)
	return button


# 单击柜内手册先把它取到桌面；单击桌面上的闭合手册才打开内容。
func _on_handbook_clicked() -> void:
	if book_state == BOOK_IN_DRAWER:
		take_handbook_to_desk()
	elif book_state == BOOK_ON_DESK:
		open_handbook()


# 第一次从抽屉拖动时切换为空抽屉，并恢复手册的桌面比例。
func _on_handbook_drag_motion(_item: Control) -> void:
	if book_state != BOOK_IN_DRAWER:
		return
	book_state = BOOK_MOVING
	desk.filing_cabinet.texture = UPPER_OPEN_EMPTY_TEXTURE
	_set_handbook_base_scale(BOOK_DESK_SCALE)
	handbook_item.scale = BOOK_DESK_SCALE


# 仅允许可见的闭合手册参与桌面输入。
func _can_begin_handbook_interaction(_item: Control, _local_position: Vector2) -> bool:
	if _transitioning or reader_overlay.visible:
		return false
	if book_state == BOOK_IN_DRAWER:
		return state == STATE_UPPER_OPEN
	return book_state == BOOK_ON_DESK or book_state == BOOK_MOVING


# 释放前检查是否投入已打开的上层抽屉；命中时由模块接管归还动画。
func _prepare_handbook_drop(item: Control) -> void:
	if state == STATE_UPPER_OPEN and book_state != BOOK_IN_DRAWER and _handbook_over_return_zone():
		item.set_meta("desk_skip_drop_once", true)
		return_handbook_to_drawer()
		return
	if book_state == BOOK_MOVING:
		book_state = BOOK_ON_DESK


# 把柜内手册取到默认桌面位置，不自动打开内容。
func take_handbook_to_desk() -> void:
	if book_state != BOOK_IN_DRAWER or state != STATE_UPPER_OPEN or _transitioning:
		return
	book_state = BOOK_MOVING
	desk.filing_cabinet.texture = UPPER_OPEN_EMPTY_TEXTURE
	_set_handbook_base_scale(BOOK_DESK_SCALE)
	var move := root.create_tween().set_parallel(true)
	move.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	move.tween_property(handbook_item, "position", BOOK_DESK_POSITION, 0.24)
	move.tween_property(handbook_item, "scale", BOOK_DESK_SCALE, 0.24)
	move.tween_property(handbook_item, "rotation", -0.025, 0.18)
	await move.finished
	handbook_item.rotation = 0.0
	book_state = BOOK_ON_DESK
	Sfx.play("ui_click")


# 打开桌面闭合手册并展示纸质双页内容。
func open_handbook() -> void:
	if book_state != BOOK_ON_DESK or _transitioning:
		return
	book_state = BOOK_READING
	handbook_item.visible = false
	_render_reader_page(_handbook_page)
	reader_overlay.modulate.a = 0.0
	reader_overlay.visible = true
	var reveal := reader_overlay.create_tween()
	reveal.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	reveal.tween_property(reader_overlay, "modulate:a", 1.0, 0.16)
	Sfx.play("ui_switch", -4.0, 0.92)


# 合上阅读层并恢复桌面上的闭合实体书。
func close_handbook() -> void:
	if book_state != BOOK_READING or _transitioning:
		return
	_transitioning = true
	var fade := reader_overlay.create_tween()
	fade.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	fade.tween_property(reader_overlay, "modulate:a", 0.0, 0.12)
	await fade.finished
	reader_overlay.visible = false
	reader_overlay.modulate.a = 1.0
	handbook_item.visible = true
	book_state = BOOK_ON_DESK
	_transitioning = false
	Sfx.play("ui_switch", -6.0, 0.82)


# 按页卷角翻动跨页内容。
func turn_handbook_page(delta: int) -> void:
	if book_state != BOOK_READING or _page_transitioning or delta == 0:
		return
	var target := clampi(_handbook_page + delta, 0, HANDBOOK_SPREADS.size() - 1)
	if target == _handbook_page:
		return
	_page_transitioning = true
	reader_previous_button.disabled = true
	reader_next_button.disabled = true
	var out := reader_content.create_tween().set_parallel(true)
	out.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	out.tween_property(reader_content, "modulate:a", 0.0, 0.09)
	out.tween_property(reader_content, "position:x", -14.0 * signf(float(delta)), 0.09)
	await out.finished
	_render_reader_page(target)
	reader_content.position.x = 14.0 * signf(float(delta))
	var incoming := reader_content.create_tween().set_parallel(true)
	incoming.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	incoming.tween_property(reader_content, "modulate:a", 1.0, 0.12)
	incoming.tween_property(reader_content, "position:x", 0.0, 0.12)
	await incoming.finished
	_page_transitioning = false
	_update_page_buttons()
	Sfx.play("ui_switch", -6.0, 1.08)


# 把闭合手册塞回打开的上层抽屉。
func return_handbook_to_drawer() -> void:
	if book_state == BOOK_IN_DRAWER or state != STATE_UPPER_OPEN:
		return
	book_state = BOOK_MOVING
	_set_handbook_base_scale(BOOK_DRAWER_SCALE)
	var move := root.create_tween().set_parallel(true)
	move.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	move.tween_property(handbook_item, "position", BOOK_DRAWER_POSITION, 0.22)
	move.tween_property(handbook_item, "scale", BOOK_DRAWER_SCALE, 0.22)
	move.tween_property(handbook_item, "rotation", 0.0, 0.14)
	await move.finished
	book_state = BOOK_IN_DRAWER
	desk.filing_cabinet.texture = UPPER_OPEN_EMPTY_TEXTURE
	Sfx.play("ui_switch", -6.0, 0.76)


# 柜门打开且书在抽屉时恢复其独立物件视觉。
func _show_book_in_open_drawer() -> void:
	if book_state != BOOK_IN_DRAWER:
		handbook_item.visible = true
		return
	_set_handbook_pose(BOOK_DRAWER_POSITION, BOOK_DRAWER_SCALE)
	handbook_item.visible = true


# 更新手册位置、缩放和 DeskItemController 的回落比例。
func _set_handbook_pose(position: Vector2, scale: Vector2) -> void:
	handbook_item.position = position
	handbook_item.scale = scale
	handbook_item.rotation = 0.0
	_set_handbook_base_scale(scale)


# 更新桌面控制器读取的标准比例。
func _set_handbook_base_scale(scale: Vector2) -> void:
	handbook_item.set_meta("desk_base_scale", scale)


# 判断手册视觉中心是否进入上层抽屉归还区。
func _handbook_over_return_zone() -> bool:
	if not is_instance_valid(handbook_return_zone):
		return false
	var center := handbook_item.get_global_transform() * (handbook_item.size * 0.5)
	return handbook_return_zone.get_global_rect().has_point(center)


# 渲染指定跨页内容并刷新页码与卷角可用状态。
func _render_reader_page(page_index: int) -> void:
	_handbook_page = clampi(page_index, 0, HANDBOOK_SPREADS.size() - 1)
	var spread: Dictionary = HANDBOOK_SPREADS[_handbook_page]
	reader_left_title.text = WorkdayContext.read_string(spread, "left_title")
	reader_left_body.text = WorkdayContext.read_string(spread, "left_body")
	reader_right_title.text = WorkdayContext.read_string(spread, "right_title")
	reader_right_body.text = WorkdayContext.read_string(spread, "right_body")
	reader_page_label.text = "— %d / %d —" % [_handbook_page + 1, HANDBOOK_SPREADS.size()]
	_update_page_buttons()


# 只在确实存在相邻页时启用对应卷角。
func _update_page_buttons() -> void:
	if not is_instance_valid(reader_previous_button):
		return
	reader_previous_button.disabled = _handbook_page <= 0 or _page_transitioning
	reader_next_button.disabled = _handbook_page >= HANDBOOK_SPREADS.size() - 1 or _page_transitioning


func _build_overlay() -> void:
	overlay = Control.new()
	overlay.name = "FilingCabinetOverlay"
	overlay.position = Vector2.ZERO
	overlay.size = DeskGeometry.design_size()
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.z_index = 420
	overlay.visible = false
	root.add_child(overlay)

	var shade := ColorRect.new()
	shade.name = "CabinetShade"
	shade.color = Color(0.008, 0.012, 0.009, 0.64)
	shade.position = Vector2.ZERO
	shade.size = DeskGeometry.design_size()
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.add_child(shade)

	var panel := Panel.new()
	panel.name = "CabinetPanel"
	# 面板从右侧展开，左边始终保留柜体演出区。
	panel.position = Vector2(260, 58)
	panel.size = Vector2(930, 604)
	panel.add_theme_stylebox_override(
		"panel",
		WorkbenchUI.style_box(Color("0b120e"), 4, Color("9a7844"), 3),
	)
	overlay.add_child(panel)

	var title := WorkbenchUI.add_text(
		panel,
		"第十二区 · 左侧文件柜",
		24,
		Color("ded2ad"),
		Vector2(34, 24),
		Vector2(560, 38),
	)
	title.add_theme_constant_override("outline_size", 4)
	title.add_theme_color_override("font_outline_color", Color("11130f"))

	var close_button := Button.new()
	close_button.name = "CloseCabinetButton"
	close_button.text = "收起文件柜  ×"
	close_button.position = Vector2(714, 20)
	close_button.size = Vector2(184, 44)
	UI.style_button(close_button, 16)
	var escape_shortcut := Shortcut.new()
	var escape_event := InputEventKey.new()
	escape_event.keycode = KEY_ESCAPE
	escape_shortcut.events = [escape_event]
	close_button.shortcut = escape_shortcut
	close_button.shortcut_in_tooltip = false
	close_button.pressed.connect(close)
	close_button.mouse_entered.connect(_play_hover)
	panel.add_child(close_button)

	var separator := ColorRect.new()
	separator.position = Vector2(34, 77)
	separator.size = Vector2(862, 2)
	separator.color = Color("665438")
	separator.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(separator)

	var asset_frame := Panel.new()
	asset_frame.name = "CabinetContentAssetFrame"
	asset_frame.position = Vector2(28, 102)
	asset_frame.size = Vector2(370, 432)
	asset_frame.add_theme_stylebox_override(
		"panel",
		WorkbenchUI.style_box(Color("121a14"), 3, Color("4f5c3d"), 2),
	)
	panel.add_child(asset_frame)

	content_asset = TextureRect.new()
	content_asset.name = "CabinetContentAsset"
	content_asset.position = Vector2(12, 10)
	content_asset.size = Vector2(346, 410)
	content_asset.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	content_asset.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	content_asset.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	content_asset.mouse_filter = Control.MOUSE_FILTER_IGNORE
	asset_frame.add_child(content_asset)

	clue_asset = TextureRect.new()
	clue_asset.name = "LooseClueAsset"
	clue_asset.position = Vector2(162, 224)
	clue_asset.size = Vector2(198, 149)
	clue_asset.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	clue_asset.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	clue_asset.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	clue_asset.mouse_filter = Control.MOUSE_FILTER_IGNORE
	clue_asset.visible = false
	asset_frame.add_child(clue_asset)

	section_label = WorkbenchUI.add_text(
		panel,
		"",
		22,
		Color("d8c9a9"),
		Vector2(424, 118),
		Vector2(472, 38),
	)
	body_label = WorkbenchUI.add_text(
		panel,
		"",
		16,
		Color("aebb8c"),
		Vector2(424, 176),
		Vector2(472, 334),
	)
	body_label.add_theme_constant_override("line_spacing", 7)
	footer_label = WorkbenchUI.add_text(
		panel,
		"上层：局务规定  /  下层：私人证物",
		14,
		Color("897b5d"),
		Vector2(28, 558),
		Vector2(868, 24),
	)
	footer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

func _render_evidence() -> void:
	content_asset.texture = DOSSIER_TEXTURE
	clue_asset.texture = CLUE_TEXTURE
	clue_asset.visible = true
	section_label.text = "私人证物 / 已保存的早期线索"
	body_label.text = EVIDENCE_BODY
	footer_label.text = "下层：私人证物  /  不与右侧当日归档托盘混用"


func _reveal_overlay() -> void:
	overlay.modulate.a = 0.0
	overlay.visible = true
	var fade := overlay.create_tween()
	fade.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	fade.tween_property(overlay, "modulate:a", 1.0, 0.16)
	await fade.finished


func _set_drawer_buttons_disabled(disabled: bool) -> void:
	if is_instance_valid(desk.filing_cabinet_upper_hit):
		desk.filing_cabinet_upper_hit.disabled = disabled
	if is_instance_valid(desk.filing_cabinet_lower_hit):
		desk.filing_cabinet_lower_hit.disabled = disabled


func _play_hover() -> void:
	Sfx.play("ui_hover")
