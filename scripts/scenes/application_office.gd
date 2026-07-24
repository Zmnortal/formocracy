extends Control

const UI := preload("res://scripts/ui/bureau_ui.gd")
const DESIGN_SIZE := Vector2(1280, 720)

var selector: OptionButton
var form_title: Label
var form_code: Label
var applicant_input: LineEdit
var residence_input: LineEdit
var reason_input: LineEdit
var truth_check: CheckBox
var status_label: Label
var submit_button: Button
var blank_forms: Array[Dictionary] = []


func _ready() -> void:
	build_scene()
	refresh_inventory()
	get_viewport().size_changed.connect(fit_to_window)
	fit_to_window()


func build_scene() -> void:
	custom_minimum_size = DESIGN_SIZE
	var background := ColorRect.new()
	background.color = Color("080d0a")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var frame := make_panel(Color("151c16"), Color("6c7852"), 4)
	frame.position = Vector2(54, 36)
	frame.size = Vector2(1172, 648)
	add_child(frame)

	var title := make_label("中央表单部 · 公民申请受理局", 27, Color("d3bd71"))
	title.position = Vector2(36, 24)
	title.size = Vector2(700, 40)
	frame.add_child(title)

	var subtitle := make_label("所有来源的表单均由同一台受理机处理。进入本局的行动已计入今晚额度。", 14, Color("87916d"))
	subtitle.position = Vector2(38, 70)
	subtitle.size = Vector2(900, 30)
	frame.add_child(subtitle)

	selector = OptionButton.new()
	selector.position = Vector2(38, 122)
	selector.size = Vector2(430, 44)
	selector.add_theme_font_override("font", UI.PIXEL_FONT)
	selector.item_selected.connect(func(_index): load_selected_form())
	frame.add_child(selector)

	var paper := make_panel(Color("cbbf91"), Color("4f472f"), 3)
	paper.position = Vector2(38, 186)
	paper.size = Vector2(720, 406)
	frame.add_child(paper)

	form_title = make_label("没有可提交的空白表单", 23, Color("222319"))
	form_title.position = Vector2(30, 24)
	form_title.size = Vector2(660, 40)
	paper.add_child(form_title)

	form_code = make_label("", 14, Color("514b35"))
	form_code.position = Vector2(30, 70)
	form_code.size = Vector2(660, 28)
	paper.add_child(form_code)

	applicant_input = make_input("申请人姓名")
	applicant_input.position = Vector2(30, 116)
	applicant_input.size = Vector2(310, 42)
	paper.add_child(applicant_input)

	residence_input = make_input("登记住所")
	residence_input.position = Vector2(360, 116)
	residence_input.size = Vector2(330, 42)
	paper.add_child(residence_input)

	reason_input = make_input("申请事由")
	reason_input.position = Vector2(30, 180)
	reason_input.size = Vector2(660, 42)
	paper.add_child(reason_input)

	truth_check = CheckBox.new()
	truth_check.text = "本人确认上述内容真实，并接受行政记录核验"
	truth_check.position = Vector2(30, 244)
	truth_check.size = Vector2(660, 38)
	truth_check.add_theme_font_override("font", UI.PIXEL_FONT)
	truth_check.add_theme_font_size_override("font_size", 14)
	paper.add_child(truth_check)

	submit_button = Button.new()
	submit_button.text = "投入官方受理机器"
	submit_button.position = Vector2(160, 318)
	submit_button.size = Vector2(400, 52)
	submit_button.add_theme_font_override("font", UI.PIXEL_FONT)
	submit_button.add_theme_font_size_override("font_size", 17)
	submit_button.pressed.connect(submit_selected_form)
	paper.add_child(submit_button)

	var machine := make_panel(Color("080b09"), Color("786c3f"), 3)
	machine.position = Vector2(800, 186)
	machine.size = Vector2(330, 250)
	frame.add_child(machine)
	var machine_title := make_label("统一申请受理机", 20, Color("c8b260"))
	machine_title.position = Vector2(24, 24)
	machine_title.size = Vector2(282, 34)
	machine.add_child(machine_title)
	var slot := ColorRect.new()
	slot.color = Color("010201")
	slot.position = Vector2(38, 88)
	slot.size = Vector2(254, 36)
	machine.add_child(slot)
	var warning := make_label("旧版、内部或注销表单\n同样会进入身份核验程序", 14, Color("747d60"))
	warning.position = Vector2(34, 150)
	warning.size = Vector2(266, 58)
	warning.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	machine.add_child(warning)

	status_label = make_label("", 15, Color("a9ae85"))
	status_label.position = Vector2(800, 464)
	status_label.size = Vector2(330, 74)
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	frame.add_child(status_label)

	var back_button := Button.new()
	back_button.text = "返回夜间地图"
	back_button.position = Vector2(832, 550)
	back_button.size = Vector2(270, 46)
	back_button.add_theme_font_override("font", UI.PIXEL_FONT)
	back_button.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/evening_map.tscn"))
	frame.add_child(back_button)


func refresh_inventory() -> void:
	blank_forms = WorkdayState.get_blank_personal_forms()
	selector.clear()
	for item in blank_forms:
		var form := ConfigDatabase.get_ontology("personal_forms", String(item.get("form_type_id", "")))
		selector.add_item("%s · %s" % [form.get("name", "未登记表单"), item.get("inventory_id", "")])
	if blank_forms.is_empty():
		set_form_enabled(false)
		form_title.text = "档案袋中没有空白表单"
		form_code.text = "请先前往正规商店或其他发行窗口取得表单。"
		status_label.text = "受理机待机。"
		return
	set_form_enabled(true)
	selector.select(0)
	load_selected_form()


func load_selected_form() -> void:
	if blank_forms.is_empty() or selector.selected < 0:
		return
	var item := blank_forms[selector.selected]
	var form := ConfigDatabase.get_ontology("personal_forms", String(item.get("form_type_id", "")))
	form_title.text = String(form.get("name", "未登记表单"))
	form_code.text = "表单 %s · 版本 %s · %s" % [
		form.get("form_code", ""),
		form.get("version", ""),
		item.get("inventory_id", ""),
	]
	applicant_input.text = WorkdayState.player_name
	residence_input.text = "第十二区 · 职员宿舍 12-C"
	reason_input.text = ""
	truth_check.button_pressed = false
	status_label.text = "等待申请人填写并送交。"


func submit_selected_form() -> void:
	if blank_forms.is_empty() or selector.selected < 0:
		return
	var item := blank_forms[selector.selected]
	var form_type_id := String(item.get("form_type_id", ""))
	var fields := {
		"applicant_name": applicant_input.text.strip_edges(),
		"residence": residence_input.text.strip_edges(),
		"request_reason": reason_input.text.strip_edges(),
		"truth_declared": truth_check.button_pressed,
	}
	if not truth_check.button_pressed or not WorkdayState.submit_personal_form(form_type_id, fields):
		status_label.text = "受理失败：请填写全部字段并确认真实性声明。"
		Sfx.play("ui_switch")
		return
	Sfx.play("bling")
	status_label.text = "受理完成：表单将在第 %02d 工作日处理。" % (WorkdayState.day_number + 1)
	refresh_inventory()


func set_form_enabled(enabled: bool) -> void:
	selector.disabled = not enabled
	applicant_input.editable = enabled
	residence_input.editable = enabled
	reason_input.editable = enabled
	truth_check.disabled = not enabled
	submit_button.disabled = not enabled


func make_label(text_value: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text_value
	label.add_theme_font_override("font", UI.PIXEL_FONT)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func make_input(placeholder: String) -> LineEdit:
	var input := LineEdit.new()
	input.placeholder_text = placeholder
	input.add_theme_font_override("font", UI.PIXEL_FONT)
	input.add_theme_font_size_override("font_size", 15)
	return input


func make_panel(background: Color, border: Color, width: int) -> Panel:
	var panel := Panel.new()
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(width)
	panel.add_theme_stylebox_override("panel", style)
	return panel


func fit_to_window() -> void:
	var viewport_size := get_viewport_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return
	scale = Vector2(viewport_size.x / DESIGN_SIZE.x, viewport_size.y / DESIGN_SIZE.y)
	position = Vector2.ZERO
