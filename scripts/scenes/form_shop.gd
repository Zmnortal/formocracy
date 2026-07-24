extends Control

const UI := preload("res://scripts/ui/bureau_ui.gd")
const DESIGN_SIZE := Vector2(1280, 720)
const SHOP_LOCATION_ID := "LOCATION-FORM-SHOP"
const FORM_IDS := [
	"PERSONAL-FORM-LOST-PROPERTY-C01",
	"PERSONAL-FORM-ARCHIVE-EXTRACT-A02",
	"PERSONAL-FORM-COMM-TERMINAL-T04",
]

var balance_label: Label
var dialogue_label: Label
var dossier_label: Label
var card_buttons: Dictionary = {}


func _ready() -> void:
	build_scene()
	refresh_store()
	get_viewport().size_changed.connect(fit_to_window)
	fit_to_window()


func build_scene() -> void:
	custom_minimum_size = DESIGN_SIZE
	var background := ColorRect.new()
	background.color = Color("11140f")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	var wall := ColorRect.new()
	wall.position = Vector2(34, 28)
	wall.size = Vector2(1212, 650)
	wall.color = Color("24271c")
	add_child(wall)

	var title := make_label("第十二区合作供销社 · 表单发行窗口", 28, Color("d2bd72"))
	title.position = Vector2(70, 54)
	title.size = Vector2(760, 42)
	add_child(title)

	balance_label = make_label("", 17, Color("b5a66b"))
	balance_label.position = Vector2(920, 62)
	balance_label.size = Vector2(270, 34)
	balance_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(balance_label)

	var proprietor_panel := make_panel(Color("0b0e0b"), Color("79835b"), 3)
	proprietor_panel.position = Vector2(70, 116)
	proprietor_panel.size = Vector2(1140, 118)
	add_child(proprietor_panel)

	var proprietor := make_label("周姨", 22, Color("d9c26f"))
	proprietor.position = Vector2(24, 18)
	proprietor.size = Vector2(130, 34)
	proprietor_panel.add_child(proprietor)

	dialogue_label = make_label("", 17, Color("b8bd98"))
	dialogue_label.position = Vector2(164, 18)
	dialogue_label.size = Vector2(930, 72)
	dialogue_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	proprietor_panel.add_child(dialogue_label)

	for index in FORM_IDS.size():
		var form_id: String = FORM_IDS[index]
		var card := build_form_card(form_id)
		card.position = Vector2(70 + index * 380, 264)
		add_child(card)

	dossier_label = make_label("", 15, Color("9fa77d"))
	dossier_label.position = Vector2(70, 620)
	dossier_label.size = Vector2(720, 34)
	add_child(dossier_label)

	var back_button := make_button("收起档案袋并返回地图")
	back_button.position = Vector2(890, 610)
	back_button.size = Vector2(320, 48)
	back_button.pressed.connect(return_to_map)
	add_child(back_button)


func build_form_card(form_id: String) -> Panel:
	var form := ConfigDatabase.get_ontology("personal_forms", form_id)
	var card := make_panel(Color("c6b883"), Color("51472d"), 3)
	card.size = Vector2(350, 320)

	var agency := make_label("第十二区表单发行管理处", 13, Color("4b432d"))
	agency.position = Vector2(20, 18)
	agency.size = Vector2(310, 24)
	card.add_child(agency)

	var name := make_label(String(form.get("name", "未登记表单")), 20, Color("222319"))
	name.position = Vector2(20, 54)
	name.size = Vector2(310, 58)
	name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	card.add_child(name)

	var code := make_label("%s · 版本 %s" % [form.get("form_code", ""), form.get("version", "")], 13, Color("514a34"))
	code.position = Vector2(20, 118)
	code.size = Vector2(310, 26)
	card.add_child(code)

	var description := make_label(String(form.get("description", "")), 14, Color("403c2a"))
	description.position = Vector2(20, 154)
	description.size = Vector2(310, 78)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	card.add_child(description)

	var fee := make_label("空白表单工本费  %d 配给券" % int(form.get("fee", 0)), 14, Color("6a3528"))
	fee.position = Vector2(20, 236)
	fee.size = Vector2(310, 28)
	card.add_child(fee)

	var buy_button := make_button("请周姨发行")
	buy_button.position = Vector2(20, 272)
	buy_button.size = Vector2(310, 38)
	buy_button.pressed.connect(func(): purchase_form(form_id))
	card.add_child(buy_button)
	card_buttons[form_id] = buy_button
	return card


func purchase_form(form_id: String) -> void:
	if not WorkdayState.purchase_personal_form(form_id):
		dialogue_label.text = "周姨：配给券不够。空白件也要入账，我没法替你垫这个。"
		Sfx.play("ui_switch")
		refresh_store()
		return
	var form := ConfigDatabase.get_ontology("personal_forms", form_id)
	dialogue_label.text = "周姨：%s。收好，买到表不等于申请会批。" % String(form.get("name", "这张表"))
	Sfx.play("stamp")
	refresh_store()


func refresh_store() -> void:
	balance_label.text = "账户余额  %03d 配给券" % WorkdayState.balance
	var blank_count := WorkdayState.get_blank_personal_forms().size()
	dossier_label.text = "个人档案袋：空白表单 × %d　前往中央表单部提交申请" % blank_count
	if dialogue_label.text.is_empty():
		dialogue_label.text = build_greeting()
	for form_id in FORM_IDS:
		var form := ConfigDatabase.get_ontology("personal_forms", form_id)
		var button: Button = card_buttons[form_id]
		button.disabled = WorkdayState.balance < int(form.get("fee", 0))


func build_greeting() -> String:
	var proprietor := ConfigDatabase.get_ontology("proprietors", "PROPRIETOR-ZHOU")
	var greetings: Dictionary = proprietor.get("greetings", {})
	var owned := WorkdayState.get_blank_personal_forms().size()
	if owned > 0:
		return "周姨：" + String(greetings.get("has_blank_forms", "档案袋里还有没交的表。"))
	if WorkdayState.balance < 8:
		return "周姨：" + String(greetings.get("low_balance", "先看清表号，退件不退工本费。"))
	return "周姨：" + String(greetings.get("default", "表我可以发，能不能拿到东西要看你自己怎么填。"))


func return_to_map() -> void:
	get_tree().change_scene_to_file("res://scenes/evening_map.tscn")


func make_label(text_value: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text_value
	label.add_theme_font_override("font", UI.PIXEL_FONT)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func make_panel(background: Color, border: Color, width: int) -> Panel:
	var panel := Panel.new()
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(width)
	panel.add_theme_stylebox_override("panel", style)
	return panel


func make_button(text_value: String) -> Button:
	var button := Button.new()
	button.text = text_value
	button.add_theme_font_override("font", UI.PIXEL_FONT)
	button.add_theme_font_size_override("font_size", 15)
	return button


func fit_to_window() -> void:
	var viewport_size := get_viewport_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return
	scale = Vector2(viewport_size.x / DESIGN_SIZE.x, viewport_size.y / DESIGN_SIZE.y)
	position = Vector2.ZERO
