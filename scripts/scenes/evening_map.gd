extends Control

signal end_sequence_finished

const UI := preload("res://scripts/ui/bureau_ui.gd")
const ROUTE_NODE_TEXTURE := preload("res://assets/map/tokens/route_node_active.png")
const DESIGN_SIZE := Vector2(1280, 720)
const LOCATION_OFFICE := "LOCATION-OFFICE"
const LOCATION_FORMS := "LOCATION-FORMS"
const LOCATION_RATION := "LOCATION-RATION"
const LOCATION_HOME := "LOCATION-HOME"
const LOCATION_FORM_SHOP := "LOCATION-FORM-SHOP"
const WATER_FORM_ID := "PERSONAL-FORM-WATER-R01"

const LOCATION_POSITIONS := {
	LOCATION_OFFICE: Vector2(748, 520),
	LOCATION_FORMS: Vector2(320, 220),
	LOCATION_RATION: Vector2(640, 350),
	LOCATION_HOME: Vector2(920, 540),
	LOCATION_FORM_SHOP: Vector2(270, 420),
}
const LOCATION_NAMES := {
	LOCATION_FORMS: "中央表单部",
	LOCATION_RATION: "公共配给站",
	LOCATION_HOME: "职员宿舍 12-C",
	LOCATION_FORM_SHOP: "第十二区合作供销社",
}

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
@onready var next_day_receipt: Panel = $NextDayReceipt
@onready var review_result_label: Label = $NextDayReceipt/ReviewResult
@onready var review_detail_label: Label = $NextDayReceipt/ReviewDetail
@onready var next_day_effect_label: Label = $NextDayReceipt/Effect
@onready var enter_workday_button: Button = $NextDayReceipt/EnterWorkdayButton
@onready var end_overlay: Control = $EndOfNightOverlay
@onready var end_speaker_label: Label = $EndOfNightOverlay/DialoguePanel/Speaker
@onready var end_dialogue_label: Label = $EndOfNightOverlay/DialoguePanel/Dialogue
@onready var end_continue_label: Label = $EndOfNightOverlay/DialoguePanel/ContinueHint
@onready var end_advance_button: Button = $EndOfNightOverlay/AdvanceButton

var moving := false
var purchasing := false
var ending_night := false
var end_dialogue_index := -1
var end_sequence_step_duration := 1.8
var end_sequence_fade_duration := 0.65
var auto_transition_after_end_sequence := true
var auto_open_location_scenes := true
var active_route_points: Array[Vector2] = []
var highlighted_route_points: Array[Vector2] = []
var end_dialogue_lines: Array[Dictionary] = [
	{"speaker": "邻室职员", "text": "还不走？这一层的灯马上就要熄了。"},
	{"speaker": "林默", "text": "今天的行动许可已经用完。剩下的事，只能留到明天。"},
	{"speaker": "走廊广播", "text": "第十二区夜间窗口现已关闭。所有职员返回登记住所。"},
]


func _ready() -> void:
	WorkdayState.begin_evening()
	day_label.text = "第 %02d 工作日 · 18:40" % WorkdayState.day_number
	balance_label.text = "账户余额  %03d 配给券" % WorkdayState.balance
	apply_pixel_theme(self)
	connect_location_button(forms_button, LOCATION_FORMS)
	connect_location_button(ration_button, LOCATION_RATION)
	connect_location_button(home_button, LOCATION_HOME)
	connect_location_button(shop_button, LOCATION_FORM_SHOP)
	buy_button.pressed.connect(purchase_water_form)
	close_ration_button.pressed.connect(func(): ration_window.visible = false)
	dossier_button.pressed.connect(toggle_dossier)
	close_dossier_button.pressed.connect(func(): dossier_panel.visible = false)
	close_home_button.pressed.connect(func(): home_window.visible = false)
	submit_form_button.pressed.connect(submit_water_form)
	applicant_input.text_changed.connect(func(_text):
		Sfx.typewriter_tick()
		refresh_home_form_validity())
	residence_input.text_changed.connect(func(_text):
		Sfx.typewriter_tick()
		refresh_home_form_validity())
	reason_input.text_changed.connect(func(_text):
		Sfx.typewriter_tick()
		refresh_home_form_validity())
	truth_declaration.toggled.connect(func(_pressed):
		Sfx.play("ui_switch")
		refresh_home_form_validity())
	end_night_button.pressed.connect(end_night)
	enter_workday_button.pressed.connect(enter_next_workday)
	end_advance_button.pressed.connect(advance_end_dialogue)
	populate_water_catalog()
	attach_button_sounds(self)
	player_token.position = LOCATION_POSITIONS.get(WorkdayState.evening_location_id, LOCATION_POSITIONS[LOCATION_OFFICE]) - player_token.size * 0.5
	refresh_map_state()
	get_viewport().size_changed.connect(fit_to_window)
	fit_to_window()
	queue_redraw()
	if WorkdayState.evening_actions_remaining <= 0 and WorkdayState.evening_location_id != LOCATION_HOME:
		call_deferred("start_end_of_night_sequence")


func connect_location_button(button: Button, location_id: String) -> void:
	button.pressed.connect(func(): select_location(location_id))
	button.mouse_entered.connect(func(): animate_button_hover(button, true))
	button.mouse_exited.connect(func(): animate_button_hover(button, false))
	button.pivot_offset = button.size * 0.5


# 为场景内所有按钮统一挂接点击与悬停音效。
func attach_button_sounds(node: Node) -> void:
	if node is Button:
		node.pressed.connect(func(): Sfx.play("ui_click"))
		node.mouse_entered.connect(func():
			if not node.disabled:
				Sfx.play("ui_hover"))
	for child in node.get_children():
		attach_button_sounds(child)


func animate_button_hover(button: Button, hovered: bool) -> void:
	if moving or button.disabled:
		return
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(button, "scale", Vector2(1.035, 1.035) if hovered else Vector2.ONE, 0.1)


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
	set_location_buttons_enabled(false)
	active_route_points = build_route(WorkdayState.evening_location_id, location_id)
	highlighted_route_points = [active_route_points[0]]
	notice_label.text = "正在前往：%s" % LOCATION_NAMES[location_id]
	refresh_route_overlay()
	Sfx.start_walking()
	await animate_route(active_route_points)
	Sfx.stop_walking()
	WorkdayState.arrive_at_evening_location(location_id)
	moving = false
	show_arrival_card(location_id)
	refresh_map_state()
	if auto_open_location_scenes and location_id == LOCATION_FORM_SHOP:
		get_tree().change_scene_to_file("res://scenes/form_shop.tscn")
		return
	if auto_open_location_scenes and location_id == LOCATION_FORMS:
		get_tree().change_scene_to_file("res://scenes/application_office.tscn")
		return
	if WorkdayState.evening_actions_remaining <= 0 and location_id != LOCATION_HOME:
		start_end_of_night_sequence()


func build_route(from_id: String, to_id: String) -> Array[Vector2]:
	var start: Vector2 = LOCATION_POSITIONS.get(from_id, LOCATION_POSITIONS[LOCATION_OFFICE])
	var finish: Vector2 = LOCATION_POSITIONS[to_id]
	var route: Array[Vector2] = [start]
	if from_id != LOCATION_OFFICE and to_id != LOCATION_OFFICE:
		route.append(LOCATION_POSITIONS[LOCATION_OFFICE])
	var midpoint := Vector2((route[-1].x + finish.x) * 0.5, minf(route[-1].y, finish.y) - 34.0)
	route.append(midpoint)
	route.append(finish)
	return route


func animate_route(route: Array[Vector2]) -> void:
	for i in range(1, route.size()):
		var tween := create_tween()
		tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
		tween.tween_property(player_token, "position", route[i] - player_token.size * 0.5, 0.34)
		await tween.finished
		highlighted_route_points.append(route[i])
		refresh_route_overlay()


func refresh_route_overlay() -> void:
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


func show_arrival_card(location_id: String) -> void:
	Sfx.play("door")
	arrival_title.text = "已抵达 · %s" % LOCATION_NAMES[location_id]
	match location_id:
		LOCATION_RATION:
			arrival_body.text = "营业状态：开放\n可购买居民饮水配额领取申请。"
			ration_window.visible = true
			refresh_purchase_ui()
		LOCATION_HOME:
			arrival_body.text = "住宅门禁已确认身份。\n可以从个人档案袋取出一张空白表单。"
			open_home_window()
		LOCATION_FORM_SHOP:
			arrival_body.text = "周姨仍在窗口后整理表单。\n今晚目录已经摆上柜台。"
		_:
			arrival_body.text = "特殊窗口仅在收到行政通知时办理。\n当前没有可办理事项。"
	arrival_card.visible = true


func open_home_window() -> void:
	home_window.visible = true
	applicant_input.text = WorkdayState.player_name
	residence_input.text = "第十二区 · 职员宿舍 12-C"
	reason_input.clear()
	truth_declaration.button_pressed = false
	submit_form_button.text = "签署并送交表单"
	home_form_status.text = "状态：等待申请人填写"
	set_home_fields_enabled(true)
	refresh_home_form_validity()


func refresh_home_form_validity() -> void:
	var blank_count := WorkdayState.get_personal_form_count(WATER_FORM_ID, "blank")
	var already_submitted := false
	for item in WorkdayState.personal_form_inventory:
		if int(item.get("submitted_day", -1)) == WorkdayState.day_number:
			already_submitted = true
			break
	var fields_complete := (
		not applicant_input.text.strip_edges().is_empty()
		and not residence_input.text.strip_edges().is_empty()
		and not reason_input.text.strip_edges().is_empty()
		and truth_declaration.button_pressed
	)
	submit_form_button.disabled = blank_count <= 0 or already_submitted or not fields_complete
	if blank_count <= 0:
		home_form_status.text = "状态：档案袋中没有空白饮水表"
	elif already_submitted:
		home_form_status.text = "状态：今晚已经送交过一份个人表单"


func set_home_fields_enabled(enabled: bool) -> void:
	applicant_input.editable = enabled
	residence_input.editable = enabled
	reason_input.editable = enabled
	truth_declaration.disabled = not enabled


func submit_water_form() -> void:
	var fields := {
		"applicant_name": applicant_input.text.strip_edges(),
		"residence": residence_input.text.strip_edges(),
		"request_reason": reason_input.text.strip_edges(),
		"truth_declared": truth_declaration.button_pressed,
	}
	if not WorkdayState.submit_personal_form(WATER_FORM_ID, fields):
		home_form_status.text = "状态：送交失败，请检查空白表单和必填字段"
		refresh_home_form_validity()
		return
	set_home_fields_enabled(false)
	submit_form_button.disabled = true
	submit_form_button.text = "已送交 · 等待次日处理"
	home_form_status.text = "回执：P-12/%02d · 预计第 %02d 工作日处理" % [WorkdayState.day_number, WorkdayState.day_number + 1]
	notice_label.text = "个人饮水表已送交。当前状态：等待处理。"
	refresh_purchase_ui()


func end_night() -> void:
	if ending_night or WorkdayState.evening_location_id != LOCATION_HOME:
		return
	start_end_of_night_sequence()


func start_end_of_night_sequence() -> void:
	if ending_night:
		return
	ending_night = true
	set_location_buttons_enabled(false)
	home_window.visible = false
	arrival_card.visible = false
	ration_window.visible = false
	dossier_panel.visible = false
	next_day_receipt.visible = false
	end_dialogue_index = -1
	end_speaker_label.text = ""
	end_dialogue_label.text = ""
	end_continue_label.text = ""
	end_overlay.visible = true
	end_overlay.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(end_overlay, "modulate:a", 1.0, end_sequence_fade_duration)
	tween.finished.connect(func(): show_end_dialogue_line(0))


func show_end_dialogue_line(index: int) -> void:
	if not ending_night or index < 0 or index >= end_dialogue_lines.size():
		return
	end_dialogue_index = index
	var line := end_dialogue_lines[index]
	end_speaker_label.text = String(line.speaker)
	end_dialogue_label.text = String(line.text)
	end_continue_label.text = "点击继续  ·  %d / %d" % [index + 1, end_dialogue_lines.size()]
	var expected_index := index
	get_tree().create_timer(end_sequence_step_duration).timeout.connect(func():
		if ending_night and end_dialogue_index == expected_index:
			advance_end_dialogue()
	)


func advance_end_dialogue() -> void:
	if not ending_night or end_dialogue_index < 0:
		return
	Sfx.play("ui_click")
	var next_index := end_dialogue_index + 1
	if next_index < end_dialogue_lines.size():
		show_end_dialogue_line(next_index)
	else:
		finish_end_of_night_sequence()


func finish_end_of_night_sequence() -> void:
	end_dialogue_index = end_dialogue_lines.size()
	WorkdayState.begin_next_day()
	var summary := WorkdayState.get_personal_review_summary()
	end_speaker_label.text = "中央现实管理局"
	end_dialogue_label.text = "第 %02d 工作日\n个人申请处理：%s" % [WorkdayState.day_number, summary.result]
	end_continue_label.text = ""
	var completed_day := WorkdayState.day_number
	get_tree().create_timer(end_sequence_step_duration * 0.75).timeout.connect(func():
		if WorkdayState.day_number != completed_day:
			return
		end_sequence_finished.emit()
		if auto_transition_after_end_sequence:
			enter_next_workday()
	)


func enter_next_workday() -> void:
	Sfx.play("start")
	var error := get_tree().change_scene_to_file("res://main.tscn")
	if error != OK:
		review_detail_label.text = "进入下一工作日失败：%s" % error_string(error)


func populate_water_catalog() -> void:
	var form := ConfigDatabase.get_ontology("personal_forms", WATER_FORM_ID)
	catalog_name.text = String(form.get("name", "未登记表单"))
	catalog_code.text = "表单 %s · 版本 %s" % [form.get("form_code", ""), form.get("version", "")]
	catalog_fee.text = "工本费  %d 配给券" % int(form.get("fee", 0))
	refresh_purchase_ui()


func refresh_purchase_ui() -> void:
	var form := ConfigDatabase.get_ontology("personal_forms", WATER_FORM_ID)
	var fee := int(form.get("fee", 0))
	var owned := WorkdayState.get_personal_form_count(WATER_FORM_ID, "blank")
	var pending := WorkdayState.get_personal_form_count(WATER_FORM_ID, "pending")
	balance_label.text = "账户余额  %03d 配给券" % WorkdayState.balance
	dossier_button.text = "个人档案袋  空白 × %d  待处理 × %d" % [owned, pending]
	buy_button.text = "购买空白表单  -%d" % fee
	buy_button.disabled = purchasing or WorkdayState.balance < fee
	if owned + pending <= 0:
		dossier_contents.text = "档案袋内没有个人表单。"
	else:
		dossier_contents.text = "居民饮水配额领取申请\nR-01 / 空白 × %d / 待处理 × %d" % [owned, pending]


func purchase_water_form() -> void:
	if purchasing or WorkdayState.evening_location_id != LOCATION_RATION:
		return
	if not WorkdayState.purchase_personal_form(WATER_FORM_ID):
		notice_label.text = "余额不足，无法支付表单工本费。"
		refresh_purchase_ui()
		return
	purchasing = true
	buy_button.disabled = true
	Sfx.play("bling")
	notice_label.text = "表单已登记，正在装入个人档案袋……"
	await animate_form_to_dossier()
	purchasing = false
	refresh_purchase_ui()
	notice_label.text = "购买完成：空白饮水表已放入个人档案袋。"


func animate_form_to_dossier() -> void:
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


func toggle_dossier() -> void:
	dossier_panel.visible = not dossier_panel.visible
	if dossier_panel.visible:
		refresh_purchase_ui()


func refresh_map_state() -> void:
	action_label.text = "剩余行动  %d / 2" % WorkdayState.evening_actions_remaining
	if not moving:
		set_location_buttons_enabled(true)
	notice_label.text = "当前位置：%s。请选择下一处地点。" % get_current_location_name()
	if WorkdayState.evening_actions_remaining <= 0:
		notice_label.text = "今日行动已经用尽。夜间窗口即将关闭。"


func set_location_buttons_enabled(enabled: bool) -> void:
	forms_button.disabled = not enabled or WorkdayState.evening_actions_remaining <= 0
	ration_button.disabled = not enabled or WorkdayState.evening_actions_remaining <= 0
	home_button.disabled = not enabled or WorkdayState.evening_actions_remaining <= 0 or WorkdayState.evening_location_id == LOCATION_HOME
	shop_button.disabled = not enabled or WorkdayState.evening_actions_remaining <= 0


func get_current_location_name() -> String:
	if WorkdayState.evening_location_id == LOCATION_OFFICE:
		return "中央现实管理局"
	return String(LOCATION_NAMES.get(WorkdayState.evening_location_id, "未登记地点"))


func apply_pixel_theme(node: Node) -> void:
	if node is Label:
		node.add_theme_font_override("font", UI.PIXEL_FONT)
	elif node is Button:
		node.add_theme_font_override("font", UI.PIXEL_FONT)
	elif node is LineEdit:
		node.add_theme_font_override("font", UI.PIXEL_FONT)
	elif node is CheckBox:
		node.add_theme_font_override("font", UI.PIXEL_FONT)
	for child in node.get_children():
		apply_pixel_theme(child)


func fit_to_window() -> void:
	var viewport_size := get_viewport_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return
	scale = Vector2(viewport_size.x / DESIGN_SIZE.x, viewport_size.y / DESIGN_SIZE.y)
	position = Vector2.ZERO
