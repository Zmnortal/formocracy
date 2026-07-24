extends Control

const UI := preload("res://scripts/ui/bureau_ui.gd")
const SHOP_BACKGROUND := preload("res://assets/shop/background/form_shop_interior.png")
const ZHOU_PORTRAIT := preload("res://assets/shop/characters/zhou_proprietor.png")
const TRANSACTION_TRAY := preload("res://assets/shop/items/form_transaction_tray.png")
const DESIGN_SIZE := Vector2(1280, 720)
const SHOP_LOCATION_ID := "LOCATION-FORM-SHOP"
const FORM_IDS := [
	"PERSONAL-FORM-LOST-PROPERTY-C01",
	"PERSONAL-FORM-ARCHIVE-EXTRACT-A02",
	"PERSONAL-FORM-COMM-TERMINAL-T04",
]

var balance_label: Label
var dialogue_label: Label
var dialogue_box: DialogueBox
var dossier_label: Label
var card_buttons: Dictionary = {}
var greeting_shown := false


# 场景就绪时构建商店界面、刷新货架状态并监听视口变化以自适应缩放。
func _ready() -> void:
	build_scene()
	refresh_store()
	get_viewport().size_changed.connect(fit_to_window)
	fit_to_window()


# 以代码构建供销社界面：背景、店主立绘、对话面板、表单卡片与返回按钮。
func build_scene() -> void:
	custom_minimum_size = DESIGN_SIZE
	var background := ColorRect.new()
	background.color = Color("11140f")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	var shop_background := TextureRect.new()
	shop_background.texture = SHOP_BACKGROUND
	shop_background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shop_background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shop_background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	shop_background.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	shop_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shop_background)

	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.025, 0.018, 0.28)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)

	var title := make_label("第十二区合作供销社 · 表单发行窗口", 28, Color("d2bd72"))
	title.position = Vector2(52, 34)
	title.size = Vector2(760, 42)
	add_child(title)

	balance_label = make_label("", 17, Color("b5a66b"))
	balance_label.position = Vector2(932, 42)
	balance_label.size = Vector2(270, 34)
	balance_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(balance_label)

	var zhou := TextureRect.new()
	zhou.texture = ZHOU_PORTRAIT
	zhou.position = Vector2(62, 100)
	zhou.size = Vector2(286, 286)
	zhou.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	zhou.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	zhou.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	zhou.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(zhou)

	var proprietor_panel := make_panel(Color("0b0e0b"), Color("79835b"), 3)
	proprietor_panel.position = Vector2(360, 126)
	proprietor_panel.size = Vector2(844, 142)
	add_child(proprietor_panel)

	var proprietor := make_label("周姨", 22, Color("d9c26f"))
	proprietor.position = Vector2(24, 18)
	proprietor.size = Vector2(130, 34)
	proprietor_panel.add_child(proprietor)

	var proprietor_note := make_label("熟人柜台 / 仅发行空白表单 / 所有申请仍需另行送审", 15, Color("8f9875"))
	proprietor_note.position = Vector2(24, 62)
	proprietor_note.size = Vector2(794, 40)
	proprietor_panel.add_child(proprietor_note)

	var tray := TextureRect.new()
	tray.texture = TRANSACTION_TRAY
	tray.position = Vector2(960, 276)
	tray.size = Vector2(244, 138)
	tray.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tray.stretch_mode = TextureRect.STRETCH_SCALE
	tray.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	tray.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(tray)

	for index in FORM_IDS.size():
		var form_id: String = FORM_IDS[index]
		var card := build_form_card(form_id)
		card.position = Vector2(52 + index * 398, 418)
		add_child(card)

	dossier_label = make_label("", 15, Color("9fa77d"))
	dossier_label.position = Vector2(52, 674)
	dossier_label.size = Vector2(720, 34)
	add_child(dossier_label)

	var back_button := make_button("收起档案袋并返回地图")
	back_button.position = Vector2(914, 664)
	back_button.size = Vector2(290, 42)
	back_button.pressed.connect(return_to_map)
	add_child(back_button)

	dialogue_box = DialogueBox.new()
	add_child(dialogue_box)
	dialogue_label = dialogue_box.dialogue_label
	dialogue_box.advance_requested.connect(dialogue_box.close)


# 根据本体配置构建一张表单售卖卡片，含发行机关、名称、编号、说明、工本费与购买按钮。
func build_form_card(form_id: String) -> Panel:
	var form := ConfigDatabase.get_ontology("personal_forms", form_id)
	var card := make_panel(Color("c6b883"), Color("51472d"), 3)
	card.size = Vector2(374, 226)

	var agency := make_label("第十二区表单发行管理处", 13, Color("4b432d"))
	agency.position = Vector2(16, 12)
	agency.size = Vector2(342, 22)
	card.add_child(agency)

	var name := make_label(String(form.get("name", "未登记表单")), 18, Color("222319"))
	name.position = Vector2(16, 40)
	name.size = Vector2(342, 34)
	name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	card.add_child(name)

	var code := make_label("%s · 版本 %s" % [form.get("form_code", ""), form.get("version", "")], 13, Color("514a34"))
	code.position = Vector2(16, 77)
	code.size = Vector2(342, 22)
	card.add_child(code)

	var description := make_label(String(form.get("description", "")), 13, Color("403c2a"))
	description.position = Vector2(16, 103)
	description.size = Vector2(342, 47)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	card.add_child(description)

	var fee := make_label("空白表单工本费  %d 配给券" % int(form.get("fee", 0)), 14, Color("6a3528"))
	fee.position = Vector2(16, 154)
	fee.size = Vector2(342, 24)
	card.add_child(fee)

	var buy_button := make_button("请周姨发行")
	buy_button.position = Vector2(16, 184)
	buy_button.size = Vector2(342, 30)
	buy_button.pressed.connect(func(): purchase_form(form_id))
	card.add_child(buy_button)
	card_buttons[form_id] = buy_button
	return card


# 购买指定表单：余额不足时显示周姨的拒绝台词，成功后播放盖章音效并刷新货架。
func purchase_form(form_id: String) -> void:
	if not WorkdayState.manager.purchase_personal_form(form_id):
		_show_shop_dialogue("配给券不够。空白件也要入账，我没法替你垫这个。")
		Sfx.play("ui_switch")
		refresh_store()
		return
	var form := ConfigDatabase.get_ontology("personal_forms", form_id)
	_show_shop_dialogue("%s。收好，买到表不等于申请会批。" % String(form.get("name", "这张表")))
	Sfx.play("stamp")
	refresh_store()


# 刷新余额、档案袋空白表单计数与问候语，并按余额启用或禁用各卡片的购买按钮。
func refresh_store() -> void:
	balance_label.text = "账户余额  %03d 配给券" % WorkdayState.balance
	var blank_count := WorkdayState.manager.get_blank_personal_forms().size()
	dossier_label.text = "个人档案袋：空白表单 × %d　前往中央表单部提交申请" % blank_count
	if not greeting_shown:
		greeting_shown = true
		_show_shop_dialogue(build_greeting())
	for form_id in FORM_IDS:
		var form := ConfigDatabase.get_ontology("personal_forms", form_id)
		var button: Button = card_buttons[form_id]
		button.disabled = WorkdayState.balance < int(form.get("fee", 0))


# 根据玩家持有表单数与余额从店主本体配置中挑选问候语，并替换玩家名占位符。
func build_greeting() -> String:
	var proprietor := ConfigDatabase.get_ontology("proprietors", "PROPRIETOR-ZHOU")
	var greetings: Dictionary = proprietor.get("greetings", {})
	var owned := WorkdayState.manager.get_blank_personal_forms().size()
	var greeting := ""
	if owned > 0:
		greeting = String(greetings.get("has_blank_forms", "档案袋里还有没交的表。"))
	elif WorkdayState.balance < 8:
		greeting = String(greetings.get("low_balance", "先看清表号，退件不退工本费。"))
	else:
		greeting = String(greetings.get("default", "表我可以发，能不能拿到东西要看你自己怎么填。"))
	var player_name := WorkdayState.player_name if not WorkdayState.player_name.is_empty() else "经办员"
	return greeting.replace("{player_name}", player_name)


# 在最前层底部对话框显示周姨台词；完成后由玩家再次点击或按空格收起。
func _show_shop_dialogue(text: String) -> void:
	dialogue_box.show_line("周姨", text, "npc")


# 返回夜间地图场景。
func return_to_map() -> void:
	get_tree().change_scene_to_file("res://scenes/evening_map.tscn")


# 创建使用像素字体的指定文本、字号与颜色的 Label。
func make_label(text_value: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text_value
	label.add_theme_font_override("font", UI.PIXEL_FONT)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


# 创建指定背景色、边框色与边框宽度的 Panel。
func make_panel(background: Color, border: Color, width: int) -> Panel:
	var panel := Panel.new()
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(width)
	panel.add_theme_stylebox_override("panel", style)
	return panel


# 创建使用像素字体的标准按钮。
func make_button(text_value: String) -> Button:
	var button := Button.new()
	button.text = text_value
	button.add_theme_font_override("font", UI.PIXEL_FONT)
	button.add_theme_font_size_override("font_size", 15)
	return button


# 以 1280x720 为设计分辨率，按实际视口大小横纵独立缩放整个界面并将位置归零。
func fit_to_window() -> void:
	var viewport_size := get_viewport_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return
	scale = Vector2(viewport_size.x / DESIGN_SIZE.x, viewport_size.y / DESIGN_SIZE.y)
	position = Vector2.ZERO
