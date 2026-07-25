extends Control

const UI := preload("res://scripts/ui/bureau_ui.gd")
const CONFIG_PATH := "res://data/narrative/newspapers.json"
const MAP_SCENE := "res://scenes/evening_map.tscn"
const FORM_ID := "PERSONAL-FORM-NEWSPAPER-S01"
const DESIGN_SIZE := Vector2(1280, 720)
const SUBSCRIPTION_FORM_TEXTURE := preload("res://assets/newspapers/forms/subscription_form_s01.png")
const KIOSK_BACKGROUND := preload("res://assets/life/newspaper_kiosk/interior.png")
const ACCEPTANCE_MACHINE := preload("res://assets/life/newspaper_kiosk/acceptance_machine.png")
const KIOSK_PROPRIETOR := preload("res://assets/life/newspaper_kiosk/proprietor/lu_vendor.png")

var publisher_selector: OptionButton
var duration_selector: OptionButton
var address_input: LineEdit
var identity_input: LineEdit
var signature_input: LineEdit
var declaration: CheckBox
var submit_button: Button
var status_label: Label
var balance_label: Label
var form_count_label: Label
var dialogue_box: DialogueBox
var publishers: Array[Dictionary] = []
var form_asset: TextureRect
var proprietor_overlay: Control


func _ready() -> void:
	_build_scene()
	_load_publishers()
	_refresh_state()
	get_viewport().size_changed.connect(_fit_to_window)
	_fit_to_window()


# 构建独立报刊亭：左侧是订阅表，右侧是吞表验收机与费用警示。
func _build_scene() -> void:
	custom_minimum_size = DESIGN_SIZE
	var background := TextureRect.new()
	background.texture = KIOSK_BACKGROUND
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	var shade := ColorRect.new()
	shade.color = Color(0.015, 0.025, 0.028, 0.48)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)

	var title := _label("第十二区报刊亭 · 私人投递登记窗口", 28, Color("dbc989"))
	title.position = Vector2(48, 34)
	title.size = Vector2(750, 44)
	add_child(title)

	var subtitle := _label("PRESS DELIVERY ACCESS / 夜间机器受理", 14, Color("7f8a8f"))
	subtitle.position = Vector2(50, 78)
	subtitle.size = Vector2(650, 26)
	add_child(subtitle)

	balance_label = _label("", 17, Color("bfae71"))
	balance_label.position = Vector2(900, 42)
	balance_label.size = Vector2(330, 32)
	balance_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(balance_label)

	var form_paper := Panel.new()
	form_paper.position = Vector2(48, 120)
	form_paper.size = Vector2(716, 530)
	var transparent_form_style := StyleBoxFlat.new()
	transparent_form_style.bg_color = Color(0, 0, 0, 0)
	transparent_form_style.shadow_color = Color(0, 0, 0, 0.62)
	transparent_form_style.shadow_size = 10
	transparent_form_style.shadow_offset = Vector2(7, 8)
	form_paper.add_theme_stylebox_override("panel", transparent_form_style)
	add_child(form_paper)

	form_asset = TextureRect.new()
	form_asset.name = "SubscriptionFormAsset"
	form_asset.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	form_asset.texture = SUBSCRIPTION_FORM_TEXTURE
	form_asset.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	form_asset.stretch_mode = TextureRect.STRETCH_SCALE
	form_asset.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	form_asset.mouse_filter = Control.MOUSE_FILTER_IGNORE
	form_paper.add_child(form_asset)

	form_count_label = _label("", 14, Color("733c32"))
	form_count_label.position = Vector2(820, 80)
	form_count_label.size = Vector2(394, 28)
	form_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(form_count_label)

	publisher_selector = OptionButton.new()
	publisher_selector.position = Vector2(66, 178)
	publisher_selector.size = Vector2(286, 36)
	_style_input(publisher_selector)
	form_paper.add_child(publisher_selector)

	duration_selector = OptionButton.new()
	duration_selector.position = Vector2(370, 178)
	duration_selector.size = Vector2(278, 36)
	_style_input(duration_selector)
	duration_selector.add_item("3 日短期投递", 3)
	duration_selector.set_item_metadata(0, 3)
	duration_selector.add_item("7 日连续投递", 7)
	duration_selector.set_item_metadata(1, 7)
	form_paper.add_child(duration_selector)

	address_input = _line_edit("须与居住登记完全一致")
	address_input.position = Vector2(66, 254)
	address_input.size = Vector2(582, 36)
	address_input.text = "第十二区 · 职员宿舍 12-C"
	form_paper.add_child(address_input)

	identity_input = _line_edit("本市身份证明号")
	identity_input.position = Vector2(66, 332)
	identity_input.size = Vector2(286, 36)
	identity_input.text = WorkdayState.manager.get_player_identity_number()
	form_paper.add_child(identity_input)

	signature_input = _line_edit("须与登记姓名一致")
	signature_input.position = Vector2(370, 332)
	signature_input.size = Vector2(278, 36)
	signature_input.text = WorkdayState.player_name if not WorkdayState.player_name.is_empty() else "经办员"
	form_paper.add_child(signature_input)

	declaration = CheckBox.new()
	declaration.text = "本人知悉：机器先收费并吞表；退件不退款，原表不退还"
	declaration.position = Vector2(66, 388)
	declaration.size = Vector2(582, 40)
	declaration.add_theme_font_override("font", UI.PIXEL_FONT)
	declaration.add_theme_font_size_override("font_size", 14)
	declaration.add_theme_color_override("font_color", Color("373329"))
	declaration.toggled.connect(func(_pressed): _refresh_state())
	form_paper.add_child(declaration)

	submit_button = Button.new()
	submit_button.text = "支付 1 配给券并送入验收机"
	submit_button.position = Vector2(182, 456)
	submit_button.size = Vector2(352, 44)
	UI.style_button(submit_button, 17, true)
	submit_button.pressed.connect(_submit)
	form_paper.add_child(submit_button)

	var machine := Panel.new()
	machine.position = Vector2(804, 120)
	machine.size = Vector2(426, 414)
	var machine_panel_style := StyleBoxFlat.new()
	machine_panel_style.bg_color = Color(0, 0, 0, 0)
	machine.add_theme_stylebox_override("panel", machine_panel_style)
	add_child(machine)

	var machine_asset := Sprite2D.new()
	machine_asset.name = "AcceptanceMachineAsset"
	machine_asset.texture = ACCEPTANCE_MACHINE
	machine_asset.centered = false
	machine_asset.position = Vector2(98, 34)
	machine_asset.scale = Vector2(
		230.0 / float(ACCEPTANCE_MACHINE.get_width()),
		300.0 / float(ACCEPTANCE_MACHINE.get_height()),
	)
	machine_asset.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	machine.add_child(machine_asset)

	var machine_title := _label("投递验收机  P-K12", 22, Color("a9c1bc"))
	machine_title.position = Vector2(30, 0)
	machine_title.size = Vector2(366, 36)
	machine_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	machine.add_child(machine_title)

	var arrows := _label("▲　表单由此送入　▲", 16, Color("9b8d58"))
	arrows.position = Vector2(48, 344)
	arrows.size = Vector2(330, 32)
	arrows.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	machine.add_child(arrows)

	var warning := _label("送件费：1 配给券 · 先吞表，后核验 · 原表不退", 14, Color("c99171"))
	warning.position = Vector2(22, 378)
	warning.size = Vector2(382, 28)
	warning.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	warning.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	machine.add_child(warning)

	status_label = _label("", 15, Color("9ba8a5"))
	status_label.position = Vector2(804, 552)
	status_label.size = Vector2(426, 54)
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(status_label)

	var back_button := Button.new()
	back_button.text = "收起申请表"
	back_button.position = Vector2(878, 620)
	back_button.size = Vector2(280, 44)
	UI.style_button(back_button, 16)
	back_button.pressed.connect(_close_subscription_form)
	add_child(back_button)

	_build_proprietor_overlay()

	dialogue_box = DialogueBox.new()
	add_child(dialogue_box)
	dialogue_box.advance_requested.connect(dialogue_box.close)
	dialogue_box.show_line("陆伯", "订报纸可以，先说清楚你想看什么。机器只认表，我还认人。", "npc")


func _build_proprietor_overlay() -> void:
	proprietor_overlay = Control.new()
	proprietor_overlay.name = "ProprietorLayer"
	proprietor_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	proprietor_overlay.z_index = 20
	add_child(proprietor_overlay)

	var backdrop := TextureRect.new()
	backdrop.texture = KIOSK_BACKGROUND
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	backdrop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	backdrop.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	proprietor_overlay.add_child(backdrop)

	var focus_shade := ColorRect.new()
	focus_shade.color = Color(0.012, 0.022, 0.024, 0.52)
	focus_shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	focus_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	proprietor_overlay.add_child(focus_shade)

	var title := _label("第十二区报刊亭 · 夜间发行窗口", 28, Color("dbc989"))
	title.position = Vector2(48, 34)
	title.size = Vector2(720, 44)
	proprietor_overlay.add_child(title)

	var subtitle := _label("PRESS & DELIVERY / 街区报刊登记处", 14, Color("91a09b"))
	subtitle.position = Vector2(50, 78)
	subtitle.size = Vector2(620, 28)
	proprietor_overlay.add_child(subtitle)

	var proprietor_name := _label("陆伯", 25, Color("d4bd72"))
	proprietor_name.position = Vector2(62, 132)
	proprietor_name.size = Vector2(260, 38)
	proprietor_overlay.add_child(proprietor_name)

	var proprietor_note := _label("报刊亭值守人 / 在这里干了三十七年 / 不负责解释报纸", 15, Color("a3aa8d"))
	proprietor_note.position = Vector2(62, 176)
	proprietor_note.size = Vector2(610, 30)
	proprietor_overlay.add_child(proprietor_note)

	var action_panel := Panel.new()
	action_panel.position = Vector2(52, 226)
	action_panel.size = Vector2(560, 324)
	action_panel.add_theme_stylebox_override(
		"panel",
		UI.make_box(Color(0.035, 0.055, 0.048, 0.88), Color("6e7656"), 3, 4),
	)
	proprietor_overlay.add_child(action_panel)

	var action_heading := _label("今晚可以办理", 18, Color("c5b36e"))
	action_heading.position = Vector2(28, 22)
	action_heading.size = Vector2(300, 32)
	action_panel.add_child(action_heading)

	var subscribe_button := Button.new()
	subscribe_button.text = "办理报纸订阅"
	subscribe_button.position = Vector2(28, 72)
	subscribe_button.size = Vector2(238, 54)
	UI.style_button(subscribe_button, 17, true)
	subscribe_button.pressed.connect(_open_subscription_form)
	action_panel.add_child(subscribe_button)

	var headline_button := Button.new()
	headline_button.text = "查看今日头条"
	headline_button.position = Vector2(288, 72)
	headline_button.size = Vector2(238, 54)
	UI.style_button(headline_button, 17)
	headline_button.pressed.connect(
		func(): dialogue_box.show_line("陆伯", "头条在外面贴着。看字免费，相信它另算。", "npc")
	)
	action_panel.add_child(headline_button)

	var chat_button := Button.new()
	chat_button.text = "随便聊两句"
	chat_button.position = Vector2(28, 148)
	chat_button.size = Vector2(238, 54)
	UI.style_button(chat_button, 17)
	chat_button.pressed.connect(
		func(): dialogue_box.show_line("陆伯", "昨晚的报纸今天还在卖。事情变了，日期没变。", "npc")
	)
	action_panel.add_child(chat_button)

	var machine_button := Button.new()
	machine_button.text = "问问吞表机器"
	machine_button.position = Vector2(288, 148)
	machine_button.size = Vector2(238, 54)
	UI.style_button(machine_button, 17)
	machine_button.pressed.connect(
		func(): dialogue_box.show_line("陆伯", "它不跟人说话。你要是听见它回答，今晚就别交表。", "npc")
	)
	action_panel.add_child(machine_button)

	var leave_button := Button.new()
	leave_button.text = "离开报刊亭"
	leave_button.position = Vector2(158, 236)
	leave_button.size = Vector2(238, 48)
	UI.style_button(leave_button, 16)
	leave_button.pressed.connect(func(): get_tree().change_scene_to_file(MAP_SCENE))
	action_panel.add_child(leave_button)

	var proprietor_sprite := Sprite2D.new()
	proprietor_sprite.name = "KioskProprietor"
	proprietor_sprite.texture = KIOSK_PROPRIETOR
	proprietor_sprite.centered = false
	proprietor_sprite.position = Vector2(820, 94)
	var proprietor_scale: float = min(
		410.0 / float(KIOSK_PROPRIETOR.get_width()),
		626.0 / float(KIOSK_PROPRIETOR.get_height()),
	)
	proprietor_sprite.scale = Vector2.ONE * proprietor_scale
	proprietor_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	proprietor_overlay.add_child(proprietor_sprite)


func _open_subscription_form() -> void:
	proprietor_overlay.visible = false
	dialogue_box.close()
	Sfx.play("ui_switch")


func _close_subscription_form() -> void:
	proprietor_overlay.visible = true
	dialogue_box.show_line("陆伯", "不填也行。空表留着，哪天政策改了还能垫桌脚。", "npc")
	Sfx.play("ui_switch")


func _load_publishers() -> void:
	if FileAccess.file_exists(CONFIG_PATH):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(CONFIG_PATH))
		if parsed is Dictionary:
			for value: Variant in WorkdayContext.read_array(parsed, "publishers"):
				if value is Dictionary and not WorkdayContext.read_bool(value, "free"):
					@warning_ignore("unsafe_cast")
					var publisher: Dictionary = value
					publishers.append(publisher)
	for publisher in publishers:
		publisher_selector.add_item(WorkdayContext.read_string(publisher, "name"))
		publisher_selector.set_item_metadata(
			publisher_selector.item_count - 1,
			WorkdayContext.read_string(publisher, "id")
		)


func _submit() -> void:
	if publisher_selector.selected < 0 or duration_selector.selected < 0:
		return
	var fields := {
		"publisher_id": String(publisher_selector.get_item_metadata(publisher_selector.selected)),
		"duration_days": int(duration_selector.get_item_metadata(duration_selector.selected)),
		"delivery_address": address_input.text.strip_edges(),
		"identity_number": identity_input.text.strip_edges(),
		"signature": signature_input.text.strip_edges(),
		"truth_declared": declaration.button_pressed,
	}
	var result := WorkdayState.manager.submit_newspaper_subscription(fields)
	var consumed := WorkdayContext.read_bool(result, "form_consumed")
	var approved := WorkdayContext.read_bool(result, "approved")
	var reason := WorkdayContext.read_string(result, "reason")
	if consumed:
		Sfx.play("stamp" if approved else "ui_switch")
		dialogue_box.show_line(
			"报刊亭验收机",
			("订阅登记完成。\n" if approved else "退件。原表已销毁。\n") + reason,
			"system" if approved else "warning"
		)
	else:
		Sfx.play("ui_switch")
		dialogue_box.show_line("报刊亭验收机", reason, "warning")
	_refresh_state()


func _refresh_state() -> void:
	var blank_count := WorkdayState.manager.get_personal_form_count(FORM_ID, "blank")
	balance_label.text = "账户余额  %03d 配给券" % WorkdayState.balance
	form_count_label.text = "档案袋空白表\n× %d" % blank_count
	submit_button.disabled = blank_count <= 0 or WorkdayState.balance < 1 or not declaration.button_pressed
	if blank_count <= 0:
		status_label.text = "没有可送交的订阅表。请先到合作供销社购买 S-01/PRESS。"
	elif WorkdayState.balance < 1:
		status_label.text = "余额不足。机器不会在未收费时吞入表单。"
	else:
		status_label.text = "机器待机。核对发行商、期限、地址、身份证明号与签名。"


func _add_field_label(parent: Control, text_value: String, at: Vector2) -> void:
	var field_label := _label(text_value, 14, Color("514a37"))
	field_label.position = at
	field_label.size = Vector2(300, 24)
	parent.add_child(field_label)


func _line_edit(placeholder: String) -> LineEdit:
	var input := LineEdit.new()
	input.placeholder_text = placeholder
	_style_input(input)
	input.text_changed.connect(func(_text): Sfx.typewriter_tick())
	return input


func _style_input(control: Control) -> void:
	control.add_theme_font_override("font", UI.PIXEL_FONT)
	control.add_theme_font_size_override("font_size", 15)


func _label(text_value: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text_value
	label.add_theme_font_override("font", UI.PIXEL_FONT)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func _fit_to_window() -> void:
	var viewport_size := get_viewport_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return
	scale = Vector2(viewport_size.x / DESIGN_SIZE.x, viewport_size.y / DESIGN_SIZE.y)
	position = Vector2.ZERO
