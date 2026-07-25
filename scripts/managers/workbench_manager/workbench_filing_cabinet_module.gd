class_name WorkbenchFilingCabinetModule
extends RefCounted

# 左侧双层文件柜。
# 上层保存局务参考手册，下层保存跨工作日累积的私人证物。

const CLOSED_TEXTURE := preload("res://assets/office/filing_cabinet/states/00_closed.png")
const UPPER_HALF_TEXTURE := preload("res://assets/office/filing_cabinet/states/01_upper_half_open.png")
const UPPER_OPEN_TEXTURE := preload("res://assets/office/filing_cabinet/states/02_upper_open_handbook.png")
const LOWER_HALF_TEXTURE := preload("res://assets/office/filing_cabinet/states/03_lower_half_open.png")
const LOWER_OPEN_TEXTURE := preload("res://assets/office/filing_cabinet/states/04_lower_open_evidence.png")
const HANDBOOK_TEXTURE := preload("res://assets/office/filing_cabinet/contents/reference_handbook_open.png")
const DOSSIER_TEXTURE := preload("res://assets/office/filing_cabinet/contents/private_evidence_dossier.png")
const CLUE_TEXTURE := preload("res://assets/office/filing_cabinet/contents/loose_clue_set.png")
const UI := preload("res://scripts/ui/bureau_ui.gd")

const STATE_CLOSED := "closed"
const STATE_UPPER_HALF := "upper_half"
const STATE_UPPER_OPEN := "upper_open"
const STATE_LOWER_HALF := "lower_half"
const STATE_LOWER_OPEN := "lower_open"

const HANDBOOK_TITLES := [
	"办理流程",
	"操作方法",
	"局务常识",
]

const HANDBOOK_BODIES := [
	(
		"一、接收申请人投递的封存文件袋。\n"
		+ "二、拆封并逐项核对表单与附件。\n"
		+ "三、依据当日规则作出批准或退回决定。\n"
		+ "四、将全部材料重新装袋并封存。\n"
		+ "五、把封存袋放入当日归档托盘，集中送验。"
	),
	(
		"拖动：按住文件、附件或印章移动。\n"
		+ "查验：点击表单可将其立起阅读。\n"
		+ "勾选：点击方框完成形式核对。\n"
		+ "盖章：将批准章或退回章压在表单指定区域。\n"
		+ "菜单：按 ESC 打开暂停菜单。"
	),
	(
		"表单不是记录现实的纸张。\n"
		+ "在中央现实管理局，完成程序的表单会获得现实效力。\n\n"
		+ "经办员既是制度的执行者，也是制度的申请人。\n"
		+ "所有私人需求，同样必须通过申请、审批与送验。"
	),
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
var overlay: Control
var content_asset: TextureRect
var clue_asset: TextureRect
var section_label: Label
var body_label: Label
var footer_label: Label
var handbook_buttons: Array[Button] = []
var state := STATE_CLOSED
var _transition_token := 0
var _transitioning := false
var _handbook_page := 0


func _init(owner_root: Node2D, desk_nodes: DeskNodes) -> void:
	root = owner_root
	desk = desk_nodes
	_build_overlay()
	desk.filing_cabinet_upper_hit.pressed.connect(open_upper)
	desk.filing_cabinet_lower_hit.pressed.connect(open_lower)
	desk.filing_cabinet_upper_hit.mouse_entered.connect(_play_hover)
	desk.filing_cabinet_lower_hit.mouse_entered.connect(_play_hover)
	CursorManager.watch(desk.filing_cabinet_upper_hit, CursorManager.Cursor.POINT)
	CursorManager.watch(desk.filing_cabinet_lower_hit, CursorManager.Cursor.POINT)


# 打开上层抽屉，并在短促机械过渡后显示参考手册。
func open_upper() -> void:
	if _transitioning or overlay.visible:
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
	desk.filing_cabinet.texture = UPPER_OPEN_TEXTURE
	_render_handbook(0)
	await _reveal_overlay()
	_transitioning = false


# 打开下层抽屉，并显示跨工作日保存的私人证物。
func open_lower() -> void:
	if _transitioning or overlay.visible:
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
	if not overlay.visible or not event is InputEventKey:
		return false
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo or key_event.keycode != KEY_ESCAPE:
		return false
	close()
	root.get_viewport().set_input_as_handled()
	return true


# 测试与调试入口：切换参考手册页签。
func select_handbook_page(page_index: int) -> void:
	_render_handbook(page_index)


# 场景退出时终止异步过渡并释放阅读层。
func shutdown() -> void:
	_transition_token += 1
	_transitioning = false
	if is_instance_valid(overlay):
		overlay.queue_free()
	overlay = null
	root = null
	desk = null


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

	for index in HANDBOOK_TITLES.size():
		var tab := Button.new()
		tab.name = "HandbookTab%d" % index
		tab.text = HANDBOOK_TITLES[index]
		tab.position = Vector2(420 + index * 158, 104)
		tab.size = Vector2(148, 44)
		UI.style_button(tab, 15)
		tab.pressed.connect(_render_handbook.bind(index))
		tab.mouse_entered.connect(_play_hover)
		panel.add_child(tab)
		handbook_buttons.append(tab)

	section_label = WorkbenchUI.add_text(
		panel,
		"",
		22,
		Color("d8c9a9"),
		Vector2(424, 171),
		Vector2(472, 38),
	)
	body_label = WorkbenchUI.add_text(
		panel,
		"",
		16,
		Color("aebb8c"),
		Vector2(424, 222),
		Vector2(472, 286),
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


func _render_handbook(page_index: int) -> void:
	_handbook_page = clampi(page_index, 0, HANDBOOK_TITLES.size() - 1)
	content_asset.texture = HANDBOOK_TEXTURE
	clue_asset.visible = false
	section_label.text = "局务参考手册 / %s" % HANDBOOK_TITLES[_handbook_page]
	body_label.text = HANDBOOK_BODIES[_handbook_page]
	footer_label.text = "上层：局务规定  /  内容随工作日与新规章更新"
	for index in handbook_buttons.size():
		handbook_buttons[index].visible = true
		handbook_buttons[index].disabled = index == _handbook_page


func _render_evidence() -> void:
	content_asset.texture = DOSSIER_TEXTURE
	clue_asset.texture = CLUE_TEXTURE
	clue_asset.visible = true
	section_label.text = "私人证物 / 已保存的早期线索"
	body_label.text = EVIDENCE_BODY
	footer_label.text = "下层：私人证物  /  不与右侧当日归档托盘混用"
	for button in handbook_buttons:
		button.visible = false


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
