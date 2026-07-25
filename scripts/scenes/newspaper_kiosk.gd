extends Control

const UI := preload("res://scripts/ui/bureau_ui.gd")
const CONFIG_PATH := "res://data/narrative/newspapers.json"
const MAP_SCENE := "res://scenes/evening_map.tscn"
const FORM_ID := "PERSONAL-FORM-NEWSPAPER-S01"
const DESIGN_SIZE := Vector2(1280, 720)
const SUBSCRIPTION_FORM_TEXTURE := preload("res://assets/newspapers/forms/subscription_form_s01.png")

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


func _ready() -> void:
	_build_scene()
	_load_publishers()
	_refresh_state()
	get_viewport().size_changed.connect(_fit_to_window)
	_fit_to_window()


# 构建独立报刊亭：左侧是订阅表，右侧是吞表验收机与费用警示。
func _build_scene() -> void:
	custom_minimum_size = DESIGN_SIZE
	var background := ColorRect.new()
	background.color = Color("090b10")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var stripe := ColorRect.new()
	stripe.color = Color("7c4e32")
	stripe.position = Vector2(0, 0)
	stripe.size = Vector2(1280, 18)
	add_child(stripe)

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
	machine.add_theme_stylebox_override("panel", UI.make_box(Color("10171a"), Color("65757a"), 4, 6))
	add_child(machine)

	var machine_title := _label("投递验收机  P-K12", 22, Color("a9c1bc"))
	machine_title.position = Vector2(30, 24)
	machine_title.size = Vector2(366, 36)
	machine_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	machine.add_child(machine_title)

	var lamp := ColorRect.new()
	lamp.color = Color("c57d42")
	lamp.position = Vector2(48, 82)
	lamp.size = Vector2(330, 8)
	machine.add_child(lamp)

	var slot_frame := Panel.new()
	slot_frame.position = Vector2(48, 122)
	slot_frame.size = Vector2(330, 94)
	slot_frame.add_theme_stylebox_override("panel", UI.make_box(Color("050708"), Color("3d484b"), 3, 2))
	machine.add_child(slot_frame)
	var slot := ColorRect.new()
	slot.color = Color("000000")
	slot.position = Vector2(28, 38)
	slot.size = Vector2(274, 18)
	slot_frame.add_child(slot)

	var arrows := _label("▲　表单由此送入　▲", 16, Color("9b8d58"))
	arrows.position = Vector2(48, 230)
	arrows.size = Vector2(330, 32)
	arrows.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	machine.add_child(arrows)

	var warning := _label("送件费：1 配给券\n先吞表，后核验\n无退表槽 / 无退款程序", 17, Color("c07260"))
	warning.position = Vector2(48, 278)
	warning.size = Vector2(330, 92)
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
	back_button.text = "离开报刊亭"
	back_button.position = Vector2(878, 620)
	back_button.size = Vector2(280, 44)
	UI.style_button(back_button, 16)
	back_button.pressed.connect(func(): get_tree().change_scene_to_file(MAP_SCENE))
	add_child(back_button)

	dialogue_box = DialogueBox.new()
	add_child(dialogue_box)
	dialogue_box.advance_requested.connect(dialogue_box.close)


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
