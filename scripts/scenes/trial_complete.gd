extends Control

const MENU_SCENE := "res://scenes/main_menu.tscn"
const TIMELINE_SCENE := "res://scenes/workday_selector.tscn"
const PIXEL_FONT := preload("res://assets/fonts/unifont/unifont_ui.tres")


func _ready() -> void:
	RenderingServer.set_default_clear_color(Color.BLACK)
	_build_scene()


func _build_scene() -> void:
	var background := ColorRect.new()
	background.color = Color("#060806")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var frame := Panel.new()
	frame.name = "CompletionPanel"
	frame.set_anchors_preset(Control.PRESET_CENTER)
	frame.position = Vector2(-430, -286)
	frame.size = Vector2(860, 572)
	frame.add_theme_stylebox_override("panel", _panel_style(Color("#10130f"), Color("#76623e"), 2))
	add_child(frame)

	var eyebrow := _label("FORMOCRACY / SEVEN-DAY TRIAL COMPLETE", 14, Color("#a98b54"))
	eyebrow.position = Vector2(48, 42)
	eyebrow.size = Vector2(764, 24)
	frame.add_child(eyebrow)

	var title := _label("感谢前来试玩", 44, Color("#eee8d7"))
	title.name = "ThanksTitle"
	title.position = Vector2(48, 86)
	title.size = Vector2(764, 64)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	frame.add_child(title)

	var rule := ColorRect.new()
	rule.color = Color("#4f4736")
	rule.position = Vector2(48, 164)
	rule.size = Vector2(764, 1)
	frame.add_child(rule)

	var body := _label(
		"第十二区的七个工作日已经结束。\n你批准、驳回和遗漏的每一份申请，都已经进入这条时间线。",
		20,
		Color("#c9c1ac"),
	)
	body.name = "CompletionBody"
	body.position = Vector2(82, 194)
	body.size = Vector2(696, 76)
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	frame.add_child(body)

	var outcome := _label(_outcome_text(), 18, Color("#b79b68"))
	outcome.name = "OutcomeSummary"
	outcome.position = Vector2(82, 298)
	outcome.size = Vector2(696, 76)
	outcome.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	outcome.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	frame.add_child(outcome)

	var timeline_button := _button("查看时间线", Vector2(154, 428))
	timeline_button.name = "TimelineButton"
	timeline_button.pressed.connect(_change_scene.bind(TIMELINE_SCENE))
	frame.add_child(timeline_button)

	var menu_button := _button("返回标题", Vector2(466, 428))
	menu_button.name = "MenuButton"
	menu_button.pressed.connect(_change_scene.bind(MENU_SCENE))
	frame.add_child(menu_button)

	var footer := _label("试玩版本止于第 07 工作日 · 存档已保留", 13, Color("#686b5d"))
	footer.position = Vector2(48, 528)
	footer.size = Vector2(764, 24)
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	frame.add_child(footer)
	timeline_button.grab_focus()


func _outcome_text() -> String:
	if WorkdayContext.read_bool(WorkdayState.narrative_flags, "du_chunmei_deceased"):
		return "杜春梅：第七日上班路事件确认死亡。\n原因：M-52 的净水与连续用药资源未能在第六夜前生效。"
	if WorkdayContext.read_bool(WorkdayState.narrative_flags, "du_chunmei_protected"):
		return "杜春梅：生存资源已经生效。\n她活过了这个周期，但下一份申请仍在等待。"
	return "杜春梅：结果未登记。"


func _change_scene(path: String) -> void:
	Sfx.play("start")
	get_tree().change_scene_to_file(path)


func _label(text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", PIXEL_FONT)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label


func _button(text: String, at: Vector2) -> Button:
	var button := Button.new()
	button.text = text
	button.position = at
	button.size = Vector2(240, 58)
	button.add_theme_font_override("font", PIXEL_FONT)
	button.add_theme_font_size_override("font_size", 19)
	button.add_theme_color_override("font_color", Color("#e9e1cc"))
	button.add_theme_stylebox_override("normal", _panel_style(Color("#171b16"), Color("#5c513d"), 2))
	button.add_theme_stylebox_override("hover", _panel_style(Color("#292d22"), Color("#b18b4c"), 2))
	return button


func _panel_style(fill: Color, border: Color, width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(width)
	return style
