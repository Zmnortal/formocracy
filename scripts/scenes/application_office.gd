extends Control

const UI := preload("res://scripts/ui/bureau_ui.gd")
const DESIGN_SIZE := Vector2(1280, 720)
const OFFICE_BACKGROUND := preload("res://assets/life/interiors/central_forms_department.png")
const INTAKE_MACHINE := preload("res://assets/life/application_office/intake_machine.png")

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


# 场景就绪时构建界面、刷新空白表单库存并监听视口变化以自适应缩放。
func _ready() -> void:
	build_scene()
	refresh_inventory()
	get_viewport().size_changed.connect(fit_to_window)
	fit_to_window()


# 以代码构建受理局界面：背景、表单选择器、纸面填写区、受理机面板与返回按钮。
func build_scene() -> void:
	custom_minimum_size = DESIGN_SIZE
	var background := TextureRect.new()
	background.texture = OFFICE_BACKGROUND
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	var background_shade := ColorRect.new()
	background_shade.color = Color(0.018, 0.028, 0.022, 0.7)
	background_shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background_shade)

	var frame := make_panel(Color(0.075, 0.1, 0.078, 0.94), Color("6c7852"), 4)
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

	var paper := DocumentBackground.create(Vector2(38, 186), Vector2(720, 406))
	paper.position = Vector2(38, 186)
	paper.size = Vector2(720, 406)
	frame.add_child(paper)

	form_title = make_label("没有可提交的空白表单", 23, Color("222319"))
	form_title.position = Vector2(54, 38)
	form_title.size = Vector2(612, 40)
	paper.add_child(form_title)

	form_code = make_label("", 14, Color("514b35"))
	form_code.position = Vector2(54, 82)
	form_code.size = Vector2(612, 28)
	paper.add_child(form_code)

	applicant_input = make_input("申请人姓名")
	applicant_input.position = Vector2(54, 122)
	applicant_input.size = Vector2(292, 42)
	paper.add_child(applicant_input)

	residence_input = make_input("登记住所")
	residence_input.position = Vector2(364, 122)
	residence_input.size = Vector2(302, 42)
	paper.add_child(residence_input)

	reason_input = make_input("申请事由")
	reason_input.position = Vector2(54, 182)
	reason_input.size = Vector2(612, 42)
	paper.add_child(reason_input)

	truth_check = CheckBox.new()
	truth_check.text = "本人确认上述内容真实，并接受行政记录核验"
	truth_check.position = Vector2(54, 242)
	truth_check.size = Vector2(612, 38)
	truth_check.add_theme_color_override("font_color", Color("343124"))
	truth_check.add_theme_color_override("font_pressed_color", Color("343124"))
	truth_check.add_theme_font_override("font", UI.PIXEL_FONT)
	truth_check.add_theme_font_size_override("font_size", 14)
	paper.add_child(truth_check)

	submit_button = Button.new()
	submit_button.text = "投入官方受理机器"
	submit_button.position = Vector2(174, 310)
	submit_button.size = Vector2(372, 48)
	submit_button.add_theme_font_override("font", UI.PIXEL_FONT)
	submit_button.add_theme_font_size_override("font_size", 17)
	submit_button.pressed.connect(submit_selected_form)
	paper.add_child(submit_button)

	var machine := make_panel(Color(0.04, 0.055, 0.045, 0.78), Color("786c3f"), 3)
	machine.position = Vector2(800, 186)
	machine.size = Vector2(330, 278)
	frame.add_child(machine)
	var machine_title := make_label("统一申请受理机", 20, Color("c8b260"))
	machine_title.position = Vector2(24, 14)
	machine_title.size = Vector2(282, 34)
	machine_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	machine.add_child(machine_title)

	var machine_asset := Sprite2D.new()
	machine_asset.name = "IntakeMachineAsset"
	machine_asset.texture = INTAKE_MACHINE
	machine_asset.centered = false
	machine_asset.position = Vector2(35, 48)
	machine_asset.scale = Vector2(
		260.0 / float(INTAKE_MACHINE.get_width()),
		164.0 / float(INTAKE_MACHINE.get_height()),
	)
	machine_asset.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	machine.add_child(machine_asset)

	var warning := make_label("旧版、内部或注销表单\n同样会进入身份核验程序", 14, Color("747d60"))
	warning.position = Vector2(34, 218)
	warning.size = Vector2(266, 48)
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


# 从 WorkdayState 读取空白表单库存并重建选择器；无表单时禁用填写区，否则加载第一张表单。
func refresh_inventory() -> void:
	blank_forms = WorkdayState.manager.get_blank_personal_forms()
	blank_forms = blank_forms.filter(
		func(item: Dictionary) -> bool:
			var form := ConfigDatabase.get_ontology("personal_forms", String(item.get("form_type_id", "")))
			return String(form.get("submission_location_id", "LOCATION-FORMS")) == "LOCATION-FORMS"
	)
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


# 将选中的空白表单信息填入纸面标题与编号，并重置申请人字段与状态提示。
func load_selected_form() -> void:
	if blank_forms.is_empty() or selector.selected < 0:
		return
	var item := blank_forms[selector.selected]
	var form := ConfigDatabase.get_ontology("personal_forms", String(item.get("form_type_id", "")))
	form_title.text = String(form.get("name", "未登记表单"))
	form_code.text = (
		"表单 %s · 版本 %s · %s"
		% [
			form.get("form_code", ""),
			form.get("version", ""),
			item.get("inventory_id", ""),
		]
	)
	applicant_input.text = WorkdayState.player_name
	residence_input.text = "第十二区 · 职员宿舍 12-C"
	reason_input.text = ""
	truth_check.button_pressed = false
	status_label.text = "等待申请人填写并送交。"


# 收集填写字段并提交选中的表单；未确认真实性或提交失败时提示错误，成功后刷新库存。
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
	if not truth_check.button_pressed or not WorkdayState.manager.submit_personal_form(form_type_id, fields):
		status_label.text = "受理失败：请填写全部字段并确认真实性声明。"
		Sfx.play("ui_switch")
		return
	Sfx.play("bling")
	status_label.text = "受理完成：表单将在第 %02d 工作日处理。" % (WorkdayState.day_number + 1)
	refresh_inventory()


# 统一启用或禁用表单填写相关的全部控件。
func set_form_enabled(enabled: bool) -> void:
	selector.disabled = not enabled
	applicant_input.editable = enabled
	residence_input.editable = enabled
	reason_input.editable = enabled
	truth_check.disabled = not enabled
	submit_button.disabled = not enabled


# 创建使用像素字体的指定文本、字号与颜色的 Label。
func make_label(text_value: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text_value
	label.add_theme_font_override("font", UI.PIXEL_FONT)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


# 创建使用像素字体并带占位提示的单行输入框。
func make_input(placeholder: String) -> LineEdit:
	var input := LineEdit.new()
	input.placeholder_text = placeholder
	input.add_theme_font_override("font", UI.PIXEL_FONT)
	input.add_theme_font_size_override("font_size", 15)
	return input


# 创建指定背景色、边框色与边框宽度的 Panel。
func make_panel(background: Color, border: Color, width: int) -> Panel:
	var panel := Panel.new()
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(width)
	panel.add_theme_stylebox_override("panel", style)
	return panel


# 以 1280x720 为设计分辨率，按实际视口大小横纵独立缩放整个界面并将位置归零。
func fit_to_window() -> void:
	var viewport_size := get_viewport_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return
	scale = Vector2(viewport_size.x / DESIGN_SIZE.x, viewport_size.y / DESIGN_SIZE.y)
	position = Vector2.ZERO
