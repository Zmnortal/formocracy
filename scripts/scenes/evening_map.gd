extends Control

signal end_sequence_finished

const UI := preload("res://scripts/ui/bureau_ui.gd")
const ROUTE_NODE_TEXTURE := preload("res://assets/map/tokens/route_node_active.png")
const LOCATION_TEXTURES := {
	"LOCATION-FORMS": preload("res://assets/map/locations/central_forms_v2.png"),
	"LOCATION-RATION": preload("res://assets/map/locations/ration_depot_v2.png"),
	"LOCATION-HOME": preload("res://assets/map/locations/home_12c_v2.png"),
	"LOCATION-FORM-SHOP": preload("res://assets/map/locations/form_shop_v3.png"),
	"LOCATION-NEWSSTAND": preload("res://assets/map/locations/newspaper_kiosk_v3.png"),
}
const DESIGN_SIZE := Vector2(1280, 720)
const LOCATION_OFFICE := "LOCATION-OFFICE"
const LOCATION_FORMS := "LOCATION-FORMS"
const LOCATION_RATION := "LOCATION-RATION"
const LOCATION_HOME := "LOCATION-HOME"
const LOCATION_FORM_SHOP := "LOCATION-FORM-SHOP"
const LOCATION_NEWSSTAND := "LOCATION-NEWSSTAND"
const WATER_FORM_ID := "PERSONAL-FORM-WATER-R01"
const NEWSPAPER_FORM_ID := "PERSONAL-FORM-NEWSPAPER-S01"

const LOCATION_POSITIONS := {
	LOCATION_OFFICE: Vector2(640, 316),
	LOCATION_FORMS: Vector2(640, 180),
	LOCATION_RATION: Vector2(985, 320),
	LOCATION_HOME: Vector2(943, 540),
	LOCATION_FORM_SHOP: Vector2(365, 505),
	LOCATION_NEWSSTAND: Vector2(652, 390),
}
const LOCATION_NAMES := {
	LOCATION_FORMS: "中央表单部",
	LOCATION_RATION: "公共配给站",
	LOCATION_HOME: "职员宿舍 12-C",
	LOCATION_FORM_SHOP: "第十二区合作供销社",
	LOCATION_NEWSSTAND: "第十二区报刊亭",
}
const LOCATION_DETAILS := {
	LOCATION_FORMS: {
		"proprietor": "负责人：袁科员",
		"status": "当前状态：夜间受理",
		"services": "可办理：申请送验、档案查询、退件领取",
	},
	LOCATION_RATION: {
		"proprietor": "负责人：马姐",
		"status": "当前状态：第三领取窗开放",
		"services": "可办理：配给核验、饮水表领取",
	},
	LOCATION_HOME: {
		"proprietor": "负责人：秦叔",
		"status": "当前状态：门房值守",
		"services": "可办理：查看投递、个人表单、休息",
	},
	LOCATION_FORM_SHOP: {
		"proprietor": "负责人：周姨",
		"status": "当前状态：晚间目录开放",
		"services": "可办理：购买空白表单",
	},
	LOCATION_NEWSSTAND: {
		"proprietor": "负责人：自动验收机",
		"status": "当前状态：投递口运行",
		"services": "可办理：报刊订阅申请送验",
	},
}

var moving := false
var purchasing := false
var ending_night := false
var end_dialogue_index := -1
# 保留供旧测试与调试脚本写入，但对话不再读取此计时值自动推进。
var end_sequence_step_duration := 1.8
var end_sequence_fade_duration := 0.65
var auto_transition_after_end_sequence := true
var auto_open_location_scenes := true
var campaign_completed := false
var active_route_points: Array[Vector2] = []
var highlighted_route_points: Array[Vector2] = []
var selected_location_id := ""
var location_sprites: Dictionary = {}
var location_dossier: Panel
var location_dossier_title: Label
var location_dossier_image: TextureRect
var location_dossier_details: Label
var location_dossier_confirm: Button
var location_dossier_cancel: Button
var end_dialogue_lines: Array[Dictionary] = [
	{"speaker": "邻室职员", "text": "还不走？这一层的灯马上就要熄了。"},
	{"speaker": "PLAYER", "text": "今天的行动许可已经用完。剩下的事，只能留到明天。"},
	{"speaker": "走廊广播", "text": "第十二区夜间窗口现已关闭。所有职员返回登记住所。"},
]
var dialogue_box: DialogueBox
var end_speaker_label: Label
var end_dialogue_label: Label
var end_continue_label: Label

@onready var day_label: Label = $Header/Day
@onready var balance_label: Label = $Header/Balance
@onready var action_label: Label = $Header/Actions
@onready var notice_label: Label = $Notice
@onready var player_token: TextureRect = $PlayerToken
@onready var route_highlight: Line2D = $RouteHighlight
@onready var route_markers: Control = $RouteMarkers
@onready var forms_button: Button = $FormsButton
@onready var ration_button: Button = $RationButton
@onready var home_button: Button = $HomeButton
@onready var shop_button: Button = $ShopButton
@onready var kiosk_button: Button = $KioskButton
@onready var arrival_card: Panel = $ArrivalCard
@onready var arrival_title: Label = $ArrivalCard/Title
@onready var arrival_body: Label = $ArrivalCard/Body
@onready var ration_window: Panel = $RationWindow
@onready var catalog_name: Label = $RationWindow/FormSlip/FormName
@onready var catalog_code: Label = $RationWindow/FormSlip/FormCode
@onready var catalog_fee: Label = $RationWindow/FormSlip/Fee
@onready var buy_button: Button = $RationWindow/BuyButton
@onready var close_ration_button: Button = $RationWindow/CloseButton
@onready var form_slip: Panel = $RationWindow/FormSlip
@onready var dossier_button: Button = $DossierButton
@onready var dossier_panel: Panel = $DossierPanel
@onready var dossier_contents: Label = $DossierPanel/Contents
@onready var close_dossier_button: Button = $DossierPanel/CloseButton
@onready var home_window: Panel = $HomeWindow
@onready var applicant_input: LineEdit = $HomeWindow/FormPaper/ApplicantInput
@onready var residence_input: LineEdit = $HomeWindow/FormPaper/ResidenceInput
@onready var reason_input: LineEdit = $HomeWindow/FormPaper/ReasonInput
@onready var truth_declaration: CheckBox = $HomeWindow/FormPaper/TruthDeclaration
@onready var submit_form_button: Button = $HomeWindow/SubmitButton
@onready var close_home_button: Button = $HomeWindow/CloseButton
@onready var home_form_status: Label = $HomeWindow/FormStatus
@onready var end_night_button: Button = $HomeWindow/EndNightButton
@onready var next_day_receipt: DocumentBackground = $NextDayReceipt
@onready var review_result_label: Label = $NextDayReceipt/ReviewResult
@onready var review_detail_label: Label = $NextDayReceipt/ReviewDetail
@onready var next_day_effect_label: Label = $NextDayReceipt/Effect
@onready var enter_workday_button: Button = $NextDayReceipt/EnterWorkdayButton
@onready var end_overlay: Control = $EndOfNightOverlay
@onready var map_shade: ColorRect = $MapShade
@onready var forms_sprite: TextureRect = $FormsSprite
@onready var ration_sprite: TextureRect = $RationSprite
@onready var home_sprite: TextureRect = $HomeSprite
@onready var shop_sprite: TextureRect = $ShopSprite
@onready var kiosk_sprite: TextureRect = $KioskSprite


# 初始化傍晚地图场景：绑定按钮、刷新状态并适配窗口。
func _ready() -> void:
	WorkdayState.manager.begin_evening()
	day_label.text = "第 %02d 工作日 · 18:40" % WorkdayState.day_number
	balance_label.text = "账户余额  %03d 配给券" % WorkdayState.balance
	_apply_pixel_theme(self)
	location_sprites = {
		LOCATION_FORMS: forms_sprite,
		LOCATION_RATION: ration_sprite,
		LOCATION_HOME: home_sprite,
		LOCATION_FORM_SHOP: shop_sprite,
		LOCATION_NEWSSTAND: kiosk_sprite,
	}
	_style_location_labels()
	_build_location_dossier()
	_connect_location_button(forms_button, LOCATION_FORMS)
	_connect_location_button(ration_button, LOCATION_RATION)
	_connect_location_button(home_button, LOCATION_HOME)
	_connect_location_button(shop_button, LOCATION_FORM_SHOP)
	_connect_location_button(kiosk_button, LOCATION_NEWSSTAND)
	buy_button.pressed.connect(purchase_water_form)
	close_ration_button.pressed.connect(func(): ration_window.visible = false)
	dossier_button.pressed.connect(_toggle_dossier)
	close_dossier_button.pressed.connect(func(): dossier_panel.visible = false)
	close_home_button.pressed.connect(func(): home_window.visible = false)
	submit_form_button.pressed.connect(submit_water_form)
	applicant_input.text_changed.connect(
		func(_text):
			Sfx.typewriter_tick()
			refresh_home_form_validity()
	)
	residence_input.text_changed.connect(
		func(_text):
			Sfx.typewriter_tick()
			refresh_home_form_validity()
	)
	reason_input.text_changed.connect(
		func(_text):
			Sfx.typewriter_tick()
			refresh_home_form_validity()
	)
	truth_declaration.toggled.connect(
		func(_pressed):
			Sfx.play("ui_switch")
			refresh_home_form_validity()
	)
	end_night_button.pressed.connect(end_night)
	enter_workday_button.pressed.connect(_enter_next_workday)
	_build_end_dialogue_box()
	_populate_water_catalog()
	_attach_button_sounds(self)
	player_token.position = LOCATION_POSITIONS.get(WorkdayState.evening_location_id, LOCATION_POSITIONS[LOCATION_OFFICE]) - player_token.size * 0.5
	_refresh_map_state()
	get_viewport().size_changed.connect(_fit_to_window)
	_fit_to_window()
	queue_redraw()
	if WorkdayState.evening_actions_remaining <= 0 and WorkdayState.evening_location_id != LOCATION_HOME:
		call_deferred("_start_end_of_night_sequence")


# 用全局统一的最前层底部对话框替换旧过场专用控件。
func _build_end_dialogue_box() -> void:
	$EndOfNightOverlay/DialoguePanel.visible = false
	$EndOfNightOverlay/AdvanceButton.visible = false
	dialogue_box = DialogueBox.new()
	end_overlay.add_child(dialogue_box)
	end_speaker_label = dialogue_box.speaker_label
	end_dialogue_label = dialogue_box.dialogue_label
	end_continue_label = dialogue_box.advance_arrow
	dialogue_box.advance_requested.connect(_advance_end_dialogue)


# 为地点按钮绑定点击移动。悬停只使用 Theme 中的颜色与边框样式，不改变尺寸。
func _connect_location_button(button: Button, location_id: String) -> void:
	button.pressed.connect(func(): _preview_location(location_id))
	button.scale = Vector2.ONE


func _style_location_labels() -> void:
	var paper := StyleBoxFlat.new()
	paper.bg_color = Color("d8cfad")
	paper.border_color = Color("776b46")
	paper.set_border_width_all(2)
	paper.corner_radius_top_left = 2
	paper.corner_radius_top_right = 2
	paper.corner_radius_bottom_left = 2
	paper.corner_radius_bottom_right = 2
	paper.shadow_color = Color(0.03, 0.035, 0.025, 0.48)
	paper.shadow_size = 4
	var paper_hover := paper.duplicate() as StyleBoxFlat
	paper_hover.bg_color = Color("ece0b8")
	paper_hover.border_color = Color("aa8d45")
	for button in [forms_button, ration_button, home_button, shop_button, kiosk_button]:
		button.add_theme_stylebox_override("normal", paper)
		button.add_theme_stylebox_override("hover", paper_hover)
		button.add_theme_stylebox_override("pressed", paper_hover)
		button.add_theme_color_override("font_color", Color("34372e"))
		button.add_theme_color_override("font_hover_color", Color("22251f"))
		button.add_theme_color_override("font_pressed_color", Color("22251f"))
		button.add_theme_font_size_override("font_size", 14)


func _build_location_dossier() -> void:
	location_dossier = Panel.new()
	location_dossier.name = "LocationDossier"
	location_dossier.position = Vector2(46, 116)
	location_dossier.size = Vector2(382, 486)
	location_dossier.z_index = 40
	location_dossier.visible = false
	var paper := StyleBoxFlat.new()
	paper.bg_color = Color("d1c7a5")
	paper.border_color = Color("5d593f")
	paper.set_border_width_all(4)
	paper.corner_radius_top_right = 4
	paper.corner_radius_bottom_right = 4
	paper.shadow_color = Color(0.015, 0.02, 0.015, 0.72)
	paper.shadow_size = 12
	location_dossier.add_theme_stylebox_override("panel", paper)
	add_child(location_dossier)

	location_dossier_title = Label.new()
	location_dossier_title.position = Vector2(24, 20)
	location_dossier_title.size = Vector2(334, 42)
	location_dossier_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	location_dossier_title.add_theme_font_override("font", UI.PIXEL_FONT)
	location_dossier_title.add_theme_font_size_override("font_size", 21)
	location_dossier_title.add_theme_color_override("font_color", Color("5a3026"))
	location_dossier.add_child(location_dossier_title)

	var rule := HSeparator.new()
	rule.position = Vector2(24, 64)
	rule.size = Vector2(334, 4)
	location_dossier.add_child(rule)

	location_dossier_image = TextureRect.new()
	location_dossier_image.position = Vector2(50, 76)
	location_dossier_image.size = Vector2(282, 210)
	location_dossier_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	location_dossier_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	location_dossier_image.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	location_dossier_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	location_dossier.add_child(location_dossier_image)

	location_dossier_details = Label.new()
	location_dossier_details.position = Vector2(28, 298)
	location_dossier_details.size = Vector2(326, 92)
	location_dossier_details.add_theme_font_override("font", UI.PIXEL_FONT)
	location_dossier_details.add_theme_font_size_override("font_size", 14)
	location_dossier_details.add_theme_color_override("font_color", Color("37382f"))
	location_dossier_details.add_theme_constant_override("line_spacing", 5)
	location_dossier.add_child(location_dossier_details)

	location_dossier_confirm = Button.new()
	location_dossier_confirm.text = "前往此处  →"
	location_dossier_confirm.position = Vector2(26, 410)
	location_dossier_confirm.size = Vector2(224, 52)
	location_dossier_confirm.add_theme_font_override("font", UI.PIXEL_FONT)
	location_dossier_confirm.add_theme_font_size_override("font_size", 17)
	location_dossier_confirm.add_theme_color_override("font_color", Color("e7dba9"))
	location_dossier_confirm.add_theme_stylebox_override("normal", _make_dossier_button_style(Color("253c32")))
	location_dossier_confirm.add_theme_stylebox_override("hover", _make_dossier_button_style(Color("365044")))
	location_dossier_confirm.pressed.connect(_confirm_selected_location)
	location_dossier.add_child(location_dossier_confirm)

	location_dossier_cancel = Button.new()
	location_dossier_cancel.text = "取消"
	location_dossier_cancel.position = Vector2(260, 410)
	location_dossier_cancel.size = Vector2(96, 52)
	location_dossier_cancel.add_theme_font_override("font", UI.PIXEL_FONT)
	location_dossier_cancel.add_theme_font_size_override("font_size", 15)
	location_dossier_cancel.add_theme_color_override("font_color", Color("403d31"))
	location_dossier_cancel.add_theme_stylebox_override("normal", _make_dossier_button_style(Color("b8ae8f")))
	location_dossier_cancel.add_theme_stylebox_override("hover", _make_dossier_button_style(Color("c9bea0")))
	location_dossier_cancel.pressed.connect(_cancel_location_preview)
	location_dossier.add_child(location_dossier_cancel)


func _make_dossier_button_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = Color("88794d")
	style.set_border_width_all(3)
	style.corner_radius_top_left = 2
	style.corner_radius_top_right = 2
	style.corner_radius_bottom_left = 2
	style.corner_radius_bottom_right = 2
	return style


func _preview_location(location_id: String) -> void:
	if moving or ending_night:
		return
	if WorkdayState.evening_actions_remaining <= 0 and location_id != LOCATION_HOME:
		notice_label.text = "今日行动已经用尽。你只能返回职员宿舍。"
		return
	selected_location_id = location_id
	var details: Dictionary = LOCATION_DETAILS.get(location_id, {})
	location_dossier_title.text = LOCATION_NAMES.get(location_id, "未登记地点")
	location_dossier_image.texture = LOCATION_TEXTURES.get(location_id)
	location_dossier_details.text = "%s\n%s\n%s" % [
		details.get("proprietor", "负责人：未登记"),
		details.get("status", "当前状态：未知"),
		details.get("services", "可办理：未登记"),
	]
	location_dossier_confirm.disabled = location_id == WorkdayState.evening_location_id
	location_dossier_confirm.text = "当前位置" if location_dossier_confirm.disabled else "前往此处  →"
	location_dossier.visible = true
	map_shade.color = Color(0.018, 0.024, 0.019, 0.48)
	_refresh_landmark_focus()
	Sfx.play("ui_switch")


func _cancel_location_preview() -> void:
	selected_location_id = ""
	location_dossier.visible = false
	map_shade.color = Color(0.02, 0.025, 0.02, 0.12)
	_refresh_landmark_focus()


func _confirm_selected_location() -> void:
	if selected_location_id.is_empty():
		return
	var destination := selected_location_id
	_cancel_location_preview()
	select_location(destination)


func _refresh_landmark_focus() -> void:
	for location_id in location_sprites:
		var sprite := location_sprites[location_id] as TextureRect
		sprite.pivot_offset = sprite.size * 0.5
		var selected: bool = not selected_location_id.is_empty() and location_id == selected_location_id
		sprite.modulate = Color.WHITE if selected or selected_location_id.is_empty() else Color(0.48, 0.5, 0.45, 0.72)
		sprite.scale = Vector2(1.045, 1.045) if selected else Vector2.ONE


# 为场景内所有按钮统一挂接点击与悬停音效。
func _attach_button_sounds(node: Node) -> void:
	if node is Button:
		node.pressed.connect(func(): Sfx.play("ui_click"))
		node.mouse_entered.connect(
			func():
				if not node.disabled:
					Sfx.play("ui_hover")
		)
	for child in node.get_children():
		_attach_button_sounds(child)


# 处理地点选择：沿路线移动玩家棋子并抵达目标地点。
func select_location(location_id: String) -> void:
	if moving or location_id == WorkdayState.evening_location_id:
		return
	if WorkdayState.evening_actions_remaining <= 0 and location_id != LOCATION_HOME:
		notice_label.text = "今日行动已经用尽。你只能返回职员宿舍。"
		return
	arrival_card.visible = false
	ration_window.visible = false
	dossier_panel.visible = false
	home_window.visible = false
	next_day_receipt.visible = false
	moving = true
	_set_location_buttons_enabled(false)
	active_route_points = _build_route(WorkdayState.evening_location_id, location_id)
	highlighted_route_points = [active_route_points[0]]
	notice_label.text = "正在前往：%s" % LOCATION_NAMES[location_id]
	_refresh_route_overlay()
	Sfx.start_walking()
	await _animate_route(active_route_points)
	Sfx.stop_walking()
	WorkdayState.arrive_at_evening_location(location_id)
	moving = false
	_show_arrival_card(location_id)
	_refresh_map_state()
	var location_scene_path: String = (
		{
			LOCATION_FORM_SHOP: "res://scenes/form_shop.tscn",
			LOCATION_FORMS: "res://scenes/central_forms_scene.tscn",
			LOCATION_RATION: "res://scenes/ration_depot_scene.tscn",
			LOCATION_HOME: "res://scenes/home_12c_scene.tscn",
			LOCATION_NEWSSTAND: "res://scenes/newspaper_kiosk.tscn",
		}
		. get(location_id, "")
	)
	if auto_open_location_scenes and not location_scene_path.is_empty():
		get_tree().change_scene_to_file(location_scene_path)
	elif WorkdayState.evening_actions_remaining <= 0 and location_id != LOCATION_HOME:
		_start_end_of_night_sequence()


# 构建从起点到终点的路线点序列，必要时途经办公室。
func _build_route(from_id: String, to_id: String) -> Array[Vector2]:
	var start: Vector2 = LOCATION_POSITIONS.get(from_id, LOCATION_POSITIONS[LOCATION_OFFICE])
	var finish: Vector2 = LOCATION_POSITIONS[to_id]
	var route: Array[Vector2] = [start]
	if from_id != LOCATION_OFFICE and to_id != LOCATION_OFFICE:
		route.append(LOCATION_POSITIONS[LOCATION_OFFICE])
	var midpoint := Vector2((route[-1].x + finish.x) * 0.5, minf(route[-1].y, finish.y) - 34.0)
	route.append(midpoint)
	route.append(finish)
	return route


# 逐段移动玩家棋子并高亮已经走过的路线节点。
func _animate_route(route: Array[Vector2]) -> void:
	for i in range(1, route.size()):
		var tween := create_tween()
		tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
		tween.tween_property(player_token, "position", route[i] - player_token.size * 0.5, 0.34)
		await tween.finished
		highlighted_route_points.append(route[i])
		_refresh_route_overlay()


# 根据已高亮的路线点重绘路线线条与节点标记。
func _refresh_route_overlay() -> void:
	route_highlight.clear_points()
	for point in highlighted_route_points:
		route_highlight.add_point(point)
	route_highlight.visible = highlighted_route_points.size() > 1
	for child in route_markers.get_children():
		child.queue_free()
	for point in highlighted_route_points:
		var marker := TextureRect.new()
		marker.texture = ROUTE_NODE_TEXTURE
		marker.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		marker.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		marker.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		marker.position = point - Vector2(11, 11)
		marker.size = Vector2(22, 22)
		marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
		route_markers.add_child(marker)


# 显示抵达卡片并按地点打开对应的办理窗口。
func _show_arrival_card(location_id: String) -> void:
	Sfx.play("door")
	arrival_title.text = "已抵达 · %s" % LOCATION_NAMES[location_id]
	match location_id:
		LOCATION_RATION:
			arrival_body.text = "营业状态：开放\n可购买居民饮水配额领取申请。"
			ration_window.visible = true
			_refresh_purchase_ui()
		LOCATION_HOME:
			arrival_body.text = "住宅门禁已确认身份。\n可以从个人档案袋取出一张空白表单。"
			_open_home_window()
		LOCATION_FORM_SHOP:
			arrival_body.text = "周姨仍在窗口后整理表单。\n今晚目录已经摆上柜台。"
		LOCATION_NEWSSTAND:
			arrival_body.text = "夜间投递验收机仍在运行。\n订阅表会先被吞入，再进行字段核验。"
		_:
			arrival_body.text = "特殊窗口仅在收到行政通知时办理。\n当前没有可办理事项。"
	arrival_card.visible = true


# 打开宿舍窗口并重置个人表单的填写状态。
func _open_home_window() -> void:
	home_window.visible = true
	applicant_input.text = WorkdayState.player_name
	residence_input.text = "第十二区 · 职员宿舍 12-C"
	reason_input.clear()
	truth_declaration.button_pressed = false
	submit_form_button.text = "签署并送交表单"
	home_form_status.text = "状态：等待申请人填写"
	_set_home_fields_enabled(true)
	refresh_home_form_validity()


# 校验宿舍表单填写完整性并更新提交按钮与状态提示。
func refresh_home_form_validity() -> void:
	var blank_count := WorkdayState.manager.get_personal_form_count(WATER_FORM_ID, "blank")
	var already_submitted := false
	for item in WorkdayState.personal_form_inventory:
		if int(item.get("submitted_day", -1)) == WorkdayState.day_number:
			already_submitted = true
			break
	var fields_complete := (
		not applicant_input.text.strip_edges().is_empty() and not residence_input.text.strip_edges().is_empty() and not reason_input.text.strip_edges().is_empty() and truth_declaration.button_pressed
	)
	submit_form_button.disabled = blank_count <= 0 or already_submitted or not fields_complete
	if blank_count <= 0:
		home_form_status.text = "状态：档案袋中没有空白饮水表"
	elif already_submitted:
		home_form_status.text = "状态：今晚已经送交过一份个人表单"


# 统一启用或禁用宿舍表单的输入控件。
func _set_home_fields_enabled(enabled: bool) -> void:
	applicant_input.editable = enabled
	residence_input.editable = enabled
	reason_input.editable = enabled
	truth_declaration.disabled = not enabled


# 收集表单字段并送交个人饮水申请，更新回执提示。
func submit_water_form() -> void:
	var fields := {
		"applicant_name": applicant_input.text.strip_edges(),
		"residence": residence_input.text.strip_edges(),
		"request_reason": reason_input.text.strip_edges(),
		"truth_declared": truth_declaration.button_pressed,
	}
	if not WorkdayState.manager.submit_personal_form(WATER_FORM_ID, fields):
		home_form_status.text = "状态：送交失败，请检查空白表单和必填字段"
		refresh_home_form_validity()
		return
	_set_home_fields_enabled(false)
	submit_form_button.disabled = true
	submit_form_button.text = "已送交 · 等待次日处理"
	home_form_status.text = "回执：P-12/%02d · 预计第 %02d 工作日处理" % [WorkdayState.day_number, WorkdayState.day_number + 1]
	notice_label.text = "个人饮水表已送交。当前状态：等待处理。"
	_refresh_purchase_ui()


# 在宿舍位置触发夜晚结束流程。
func end_night() -> void:
	if ending_night or WorkdayState.evening_location_id != LOCATION_HOME:
		return
	_start_end_of_night_sequence()


# 开始夜晚结束演出：关闭所有窗口并淡入结尾对话。
func _start_end_of_night_sequence() -> void:
	if ending_night:
		return
	ending_night = true
	_set_location_buttons_enabled(false)
	home_window.visible = false
	arrival_card.visible = false
	ration_window.visible = false
	dossier_panel.visible = false
	next_day_receipt.visible = false
	end_dialogue_index = -1
	end_speaker_label.text = ""
	end_dialogue_label.text = ""
	end_continue_label.visible = false
	end_overlay.visible = true
	end_overlay.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(end_overlay, "modulate:a", 1.0, end_sequence_fade_duration)
	tween.finished.connect(func(): _show_end_dialogue_line(0))


# 显示指定索引的结尾对话行；下一句只能由玩家在箭头出现后手动推进。
func _show_end_dialogue_line(index: int) -> void:
	if not ending_night or index < 0 or index >= end_dialogue_lines.size():
		return
	end_dialogue_index = index
	var line := end_dialogue_lines[index]
	var speaker := _resolve_dialogue_speaker(String(line.speaker))
	var speaker_kind := "broadcast" if speaker.contains("广播") else ("player" if speaker == WorkdayState.player_name else "npc")
	dialogue_box.show_line(speaker, String(line.text), speaker_kind)
	_send_end_dialogue_to_glass(speaker, String(line.text))


# 玩家确认后推进到下一句；处理回执本身也是最后一条必须手动确认的台词。
func _advance_end_dialogue() -> void:
	if not ending_night or end_dialogue_index < 0:
		return
	if end_dialogue_index >= end_dialogue_lines.size():
		dialogue_box.close()
		end_sequence_finished.emit()
		if auto_transition_after_end_sequence:
			if campaign_completed:
				_enter_trial_complete()
			else:
				_enter_next_workday()
		return
	var next_index := end_dialogue_index + 1
	if next_index < end_dialogue_lines.size():
		_show_end_dialogue_line(next_index)
	else:
		_finish_end_of_night_sequence()


# 收束夜晚演出：推进到次日并展示个人申请处理结果。
func _finish_end_of_night_sequence() -> void:
	end_dialogue_index = end_dialogue_lines.size()
	WorkdayState.manager.begin_next_day()
	campaign_completed = WorkdayContext.read_bool(WorkdayState.narrative_flags, "trial_completed")
	if campaign_completed:
		var completion_text := "七日试行期已经结束。\n感谢前来试玩。你的全部裁决已写入时间线。"
		dialogue_box.show_line("中央现实管理局", completion_text, "system")
		_send_end_dialogue_to_glass("中央现实管理局", completion_text)
		return
	var summary := WorkdayState.manager.get_personal_review_summary()
	var summary_text := "第 %02d 工作日\n个人申请处理：%s" % [WorkdayState.day_number, summary.result]
	dialogue_box.show_line("中央现实管理局", summary_text, "system")
	_send_end_dialogue_to_glass("中央现实管理局", summary_text)


# 将结尾对话按说话人类型转发给 RealityBridge。
func _send_end_dialogue_to_glass(speaker: String, text: String) -> void:
	var bridge := get_tree().root.get_node_or_null("RealityBridge")
	if bridge == null or text.strip_edges().is_empty():
		return
	if speaker.contains("广播") or speaker.contains("管理局"):
		bridge.secretary_line(text)
	elif speaker == WorkdayState.player_name:
		bridge.npc_line(speaker, text, "male", "young")
	else:
		bridge.npc_line(speaker, text)


# 将 PLAYER 占位符解析为玩家的登记姓名。
func _resolve_dialogue_speaker(speaker: String) -> String:
	if speaker == "PLAYER":
		return WorkdayState.player_name if not WorkdayState.player_name.is_empty() else "未登记职员"
	return speaker


# 切换到主场景进入下一个工作日。
func _enter_next_workday() -> void:
	Sfx.play("start")
	var next_scene := "res://scenes/pre_work_sequence.tscn"
	if WorkdayState.get_resume_phase() == "du_chunmei_death_notice":
		next_scene = "res://scenes/du_chunmei_death_notice.tscn"
	var error := get_tree().change_scene_to_file(next_scene)
	if error != OK:
		review_detail_label.text = "进入下一工作日失败：%s" % error_string(error)


# 七日结算完成后进入独立感谢试玩页。
func _enter_trial_complete() -> void:
	Sfx.play("start")
	var error := get_tree().change_scene_to_file("res://scenes/trial_complete.tscn")
	if error != OK:
		review_detail_label.text = "进入试玩结束页失败：%s" % error_string(error)


# 从本体配置填充饮水表单的目录信息。
func _populate_water_catalog() -> void:
	var form := ConfigDatabase.get_ontology("personal_forms", WATER_FORM_ID)
	catalog_name.text = String(form.get("name", "未登记表单"))
	catalog_code.text = "表单 %s · 版本 %s" % [form.get("form_code", ""), form.get("version", "")]
	catalog_fee.text = "工本费  %d 配给券" % int(form.get("fee", 0))
	_refresh_purchase_ui()


# 刷新余额、档案袋计数与购买按钮的可用状态。
func _refresh_purchase_ui() -> void:
	var form := ConfigDatabase.get_ontology("personal_forms", WATER_FORM_ID)
	var fee := int(form.get("fee", 0))
	var owned := WorkdayState.manager.get_personal_form_count(WATER_FORM_ID, "blank")
	var pending := WorkdayState.manager.get_personal_form_count(WATER_FORM_ID, "pending")
	var newspaper_blank := WorkdayState.manager.get_personal_form_count(NEWSPAPER_FORM_ID, "blank")
	var total_blank := WorkdayState.manager.get_blank_personal_forms().size()
	balance_label.text = "账户余额  %03d 配给券" % WorkdayState.balance
	dossier_button.text = "个人档案袋  空白 × %d  待处理 × %d" % [total_blank, pending]
	buy_button.text = "购买空白表单  -%d" % fee
	buy_button.disabled = purchasing or WorkdayState.balance < fee
	if total_blank + pending <= 0:
		dossier_contents.text = "档案袋内没有个人表单。"
	else:
		dossier_contents.text = ("居民饮水配额领取申请\nR-01 / 空白 × %d / 待处理 × %d\n\n" % [owned, pending] + "报刊订阅通行申请\nS-01 / 空白 × %d / 送交地点：第十二区报刊亭" % newspaper_blank)


# 在配给站购买空白饮水表并播放入袋动画。
func purchase_water_form() -> void:
	if purchasing or WorkdayState.evening_location_id != LOCATION_RATION:
		return
	if not WorkdayState.manager.purchase_personal_form(WATER_FORM_ID):
		notice_label.text = "余额不足，无法支付表单工本费。"
		_refresh_purchase_ui()
		return
	purchasing = true
	buy_button.disabled = true
	Sfx.play("bling")
	notice_label.text = "表单已登记，正在装入个人档案袋……"
	await _animate_form_to_dossier()
	purchasing = false
	_refresh_purchase_ui()
	notice_label.text = "购买完成：空白饮水表已放入个人档案袋。"


# 播放表单纸条飞入个人档案袋的动画并复位其状态。
func _animate_form_to_dossier() -> void:
	var original_parent := form_slip.get_parent()
	var original_position := form_slip.position
	form_slip.reparent(self, true)
	form_slip.z_index = 20
	var tween := create_tween()
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(form_slip, "position", dossier_button.position + Vector2(40, -16), 0.55)
	tween.tween_property(form_slip, "scale", Vector2(0.28, 0.28), 0.55)
	tween.tween_property(form_slip, "modulate:a", 0.15, 0.55)
	await tween.finished
	form_slip.reparent(original_parent, false)
	form_slip.position = original_position
	form_slip.scale = Vector2.ONE
	form_slip.modulate = Color.WHITE
	form_slip.z_index = 0


# 切换个人档案袋面板的显示状态。
func _toggle_dossier() -> void:
	dossier_panel.visible = not dossier_panel.visible
	if dossier_panel.visible:
		_refresh_purchase_ui()


# 刷新剩余行动数、按钮可用性与当前位置提示。
func _refresh_map_state() -> void:
	action_label.text = "剩余行动  %d / 2" % WorkdayState.evening_actions_remaining
	if not moving:
		_set_location_buttons_enabled(true)
	notice_label.text = "当前位置：%s。请选择下一处地点。" % _get_current_location_name()
	if WorkdayState.evening_actions_remaining <= 0:
		notice_label.text = "今日行动已经用尽。夜间窗口即将关闭。"


# 按剩余行动与当前位置设置各地点按钮的禁用状态。
func _set_location_buttons_enabled(enabled: bool) -> void:
	forms_button.disabled = not enabled or WorkdayState.evening_actions_remaining <= 0
	ration_button.disabled = not enabled or WorkdayState.evening_actions_remaining <= 0
	home_button.disabled = not enabled or WorkdayState.evening_actions_remaining <= 0 or WorkdayState.evening_location_id == LOCATION_HOME
	shop_button.disabled = not enabled or WorkdayState.evening_actions_remaining <= 0
	kiosk_button.disabled = not enabled or WorkdayState.evening_actions_remaining <= 0


# 返回当前所在地点的显示名称。
func _get_current_location_name() -> String:
	if WorkdayState.evening_location_id == LOCATION_OFFICE:
		return "中央现实管理局"
	return String(LOCATION_NAMES.get(WorkdayState.evening_location_id, "未登记地点"))


# 递归为文本类控件应用像素字体。
func _apply_pixel_theme(node: Node) -> void:
	if node is Label:
		node.add_theme_font_override("font", UI.PIXEL_FONT)
	elif node is Button:
		node.add_theme_font_override("font", UI.PIXEL_FONT)
	elif node is LineEdit:
		node.add_theme_font_override("font", UI.PIXEL_FONT)
	elif node is CheckBox:
		node.add_theme_font_override("font", UI.PIXEL_FONT)
	for child in node.get_children():
		_apply_pixel_theme(child)


# 按窗口尺寸缩放场景以适配设计分辨率。
func _fit_to_window() -> void:
	var viewport_size := get_viewport_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return
	scale = Vector2(viewport_size.x / DESIGN_SIZE.x, viewport_size.y / DESIGN_SIZE.y)
	position = Vector2.ZERO
