extends Control

const PRE_WORK_SCENE := "res://scenes/pre_work_sequence.tscn"
const PIXEL_FONT := preload("res://assets/fonts/ark_pixel/ark-pixel-16px-proportional-zh_cn.ttf")
const PORTRAIT := preload("res://assets/characters/portraits_8bit/person_du.png")
const CLINIC_STILL_PATH := "res://assets/narrative/events/du_chunmei_death/clinic_window.png"
const BELONGINGS_STILL_PATH := "res://assets/narrative/events/du_chunmei_death/belongings.png"

var event_image: TextureRect
var portrait: TextureRect
var speaker_label: Label
var body_label: Label
var record_label: Label
var continue_button: Button
var step_index := 0

var lines: Array[Dictionary] = [
	{
		"speaker": "第五诊疗站 · 夜间登记",
		"text": "第 06 工作日 23:40，杜春梅被登记死亡。\n连续用药与净水配额未能按时生效。",
		"image": CLINIC_STILL_PATH,
	},
	{
		"speaker": "遗留物登记",
		"text": "未兑付药袋一只、居民配给册一本、宿舍钥匙一枚。\n所有物品等待亲属或登记单位认领。",
		"image": BELONGINGS_STILL_PATH,
	},
	{
		"speaker": "杜春梅 · 申请记录 M-52",
		"text": "“总得有人被排到后面。”\n机器记得优先级，却不会记得排在后面的人。",
		"image": BELONGINGS_STILL_PATH,
	},
]


func _ready() -> void:
	RenderingServer.set_default_clear_color(Color("#070806"))
	_build_scene()
	_show_step(0)


func _build_scene() -> void:
	var background := ColorRect.new()
	background.color = Color("#080a08")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var header := Label.new()
	header.text = "CENTRAL REALITY BUREAU  /  EXCEPTION NOTICE"
	header.position = Vector2(44, 28)
	header.size = Vector2(1190, 28)
	_style_label(header, 15, Color("#b9985b"))
	add_child(header)

	var rule := ColorRect.new()
	rule.color = Color("#594b34")
	rule.position = Vector2(44, 67)
	rule.size = Vector2(1192, 2)
	add_child(rule)

	var image_frame := Panel.new()
	image_frame.position = Vector2(44, 96)
	image_frame.size = Vector2(720, 540)
	image_frame.add_theme_stylebox_override("panel", _panel_style(Color("#0e110e"), Color("#6d634d"), 2))
	add_child(image_frame)

	event_image = TextureRect.new()
	event_image.name = "EventImage"
	event_image.position = Vector2(12, 12)
	event_image.size = Vector2(696, 516)
	event_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	event_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	event_image.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	image_frame.add_child(event_image)

	var paper := Panel.new()
	paper.position = Vector2(792, 96)
	paper.size = Vector2(444, 540)
	paper.add_theme_stylebox_override("panel", _panel_style(Color("#ded5bc"), Color("#332d23"), 2))
	add_child(paper)

	var classification := Label.new()
	classification.text = "死亡登记抄件 / D-06-2340"
	classification.position = Vector2(28, 24)
	classification.size = Vector2(388, 26)
	_style_label(classification, 14, Color("#5c1717"))
	paper.add_child(classification)

	portrait = TextureRect.new()
	portrait.name = "DuChunmeiPortrait"
	portrait.texture = PORTRAIT
	portrait.position = Vector2(28, 72)
	portrait.size = Vector2(128, 128)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	paper.add_child(portrait)

	record_label = Label.new()
	record_label.name = "Record"
	record_label.text = "姓名　杜春梅\n公民序号　11-604-42\n原职业　退休电话接线员\n关联申请　M-52\n登记日　第 06 工作日"
	record_label.position = Vector2(178, 72)
	record_label.size = Vector2(232, 138)
	record_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_style_label(record_label, 15, Color("#28251f"))
	paper.add_child(record_label)

	var divider := ColorRect.new()
	divider.color = Color("#6f6756")
	divider.position = Vector2(28, 228)
	divider.size = Vector2(388, 1)
	paper.add_child(divider)

	speaker_label = Label.new()
	speaker_label.name = "Speaker"
	speaker_label.position = Vector2(28, 252)
	speaker_label.size = Vector2(388, 28)
	_style_label(speaker_label, 16, Color("#7a241e"))
	paper.add_child(speaker_label)

	body_label = Label.new()
	body_label.name = "Body"
	body_label.position = Vector2(28, 294)
	body_label.size = Vector2(388, 132)
	body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_style_label(body_label, 18, Color("#191713"))
	paper.add_child(body_label)

	continue_button = Button.new()
	continue_button.name = "ContinueButton"
	continue_button.text = "查阅下一项  ▶"
	continue_button.position = Vector2(202, 458)
	continue_button.size = Vector2(214, 54)
	continue_button.add_theme_font_override("font", PIXEL_FONT)
	continue_button.add_theme_font_size_override("font_size", 17)
	continue_button.add_theme_color_override("font_color", Color("#efe7cf"))
	continue_button.add_theme_stylebox_override("normal", _panel_style(Color("#171b16"), Color("#725f3c"), 2))
	continue_button.add_theme_stylebox_override("hover", _panel_style(Color("#292d22"), Color("#b28d4e"), 2))
	continue_button.pressed.connect(advance_notice)
	paper.add_child(continue_button)

	var footer := Label.new()
	footer.text = "第 07 工作日晨间附加通知 · 查阅后进入当日工作"
	footer.position = Vector2(44, 660)
	footer.size = Vector2(1192, 28)
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_style_label(footer, 13, Color("#777564"))
	add_child(footer)


func _show_step(index: int) -> void:
	step_index = clampi(index, 0, lines.size() - 1)
	var line := lines[step_index]
	speaker_label.text = WorkdayContext.read_string(line, "speaker")
	body_label.text = WorkdayContext.read_string(line, "text")
	var texture_path := WorkdayContext.read_string(line, "image")
	event_image.texture = load(texture_path) as Texture2D
	continue_button.text = "进入第 07 工作日  ▶" if step_index == lines.size() - 1 else "查阅下一项  ▶"
	continue_button.grab_focus()


func advance_notice() -> void:
	if step_index + 1 < lines.size():
		_show_step(step_index + 1)
		return
	WorkdayState.narrative_flags["du_chunmei_notice_seen"] = true
	if WorkdayState.persistence_enabled:
		WorkdayState.save_progress()
	Sfx.play("start")
	var error := get_tree().change_scene_to_file(PRE_WORK_SCENE)
	if error != OK:
		body_label.text = "进入第 07 工作日失败：%s" % error_string(error)


func _style_label(label: Label, font_size: int, color: Color) -> void:
	label.add_theme_font_override("font", PIXEL_FONT)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)


func _panel_style(fill: Color, border: Color, width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(width)
	return style
