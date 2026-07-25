extends Control

const UI := preload("res://scripts/ui/bureau_ui.gd")
const MAIN_SCENE := "res://main.tscn"
const CONFIG_PATH := "res://data/narrative/pre_work_sequence.json"
const DESIGN_SIZE := Vector2(1280.0, 720.0)
const HOME_TEXTURE := preload("res://assets/concepts/after_work_interiors/home_12c_concept.png")
const ARRIVAL_TEXTURE := preload("res://assets/office/background/service_hall_light.png")
const WALK_TEXTURES: Array[String] = [
	"res://assets/office/transitions/after_work_corridor_leg_closeup/corridor_legs_01_step.png",
	"res://assets/office/transitions/after_work_corridor_leg_closeup/corridor_legs_02_step.png",
	"res://assets/office/transitions/after_work_corridor_leg_closeup/corridor_legs_03_stop.png",
	"res://assets/office/transitions/after_work_corridor_leg_closeup/corridor_legs_04_resume.png",
]
const STOPPED_WALK_INDEX := 2

var phase := "newspaper"
var walk_index := -1
var exiting := false
var footsteps_active := false
var preserve_arrival_ambience := false
var day_content: Dictionary = {}
var walk_lines: Array[String] = []
var dialogue_box: DialogueBox
var available_newspapers: Array[Dictionary] = []
var selected_newspaper: Dictionary = {}
var newspaper_selector: Control

@onready var backdrop: TextureRect = $Backdrop
@onready var mood_tint: ColorRect = $MoodTint
@onready var frame_texture: TextureRect = $FrameTexture
@onready var newspaper: Panel = $Newspaper
@onready var edition_label: Label = $Newspaper/Edition
@onready var headline_label: Label = $Newspaper/Headline
@onready var article_label: Label = $Newspaper/Article
@onready var day_label: Label = $Newspaper/DayMarker
@onready var location_label: Label = $LocationLabel
@onready var slide_flash: ColorRect = $SlideFlash
@onready var fade: ColorRect = $Fade


# 每日晨间序列从报纸开始；所有画面只响应统一对话框的手动推进。
func _ready() -> void:
	Sfx.stop_ambience()
	Sfx.stop_walking()
	day_content = _load_day_content()
	walk_lines = _read_walk_lines(day_content)
	_build_newspaper_selector()
	_build_dialogue_box()
	get_viewport().size_changed.connect(_fit_to_window)
	_fit_to_window()
	_begin_newspaper_flow()
	fade.visible = true
	fade.modulate.a = 1.0
	var reveal := create_tween()
	reveal.tween_property(fade, "modulate:a", 0.0, 0.42)
	reveal.finished.connect(func(): fade.visible = false)


# 复用全游戏 DialogueBox；首击补全文字，次击才推进画面。
func _build_dialogue_box() -> void:
	dialogue_box = DialogueBox.new()
	add_child(dialogue_box)
	dialogue_box.advance_requested.connect(advance_sequence)


# 根据有效订阅开始晨间读报；多份报纸先选头条，只有官方报时直接精读。
func _begin_newspaper_flow() -> void:
	available_newspapers = WorkdayState.manager.get_available_newspapers()
	var already_read := WorkdayState.manager.get_read_newspaper()
	if not already_read.is_empty():
		for item in available_newspapers:
			if WorkdayContext.read_string(item, "id") == already_read:
				selected_newspaper = item
				_show_newspaper(item)
				_show_departure_prompt()
				return
	if available_newspapers.size() <= 1:
		_choose_newspaper(available_newspapers[0] if not available_newspapers.is_empty() else {})
	else:
		_show_newspaper_selection()


# 构建最多四份报纸并列的晨间头条选择层；正文仍复用既有报纸面板。
func _build_newspaper_selector() -> void:
	newspaper_selector = Control.new()
	newspaper_selector.name = "NewspaperSelector"
	newspaper_selector.position = Vector2(44, 92)
	newspaper_selector.size = Vector2(1192, 472)
	newspaper_selector.visible = false
	add_child(newspaper_selector)
	move_child(newspaper_selector, slide_flash.get_index())


# 展示所有到报的头条与摘要。只有玩家按下某张报纸的“精读”按钮才会继续。
func _show_newspaper_selection() -> void:
	phase = "newspaper_selection"
	backdrop.texture = HOME_TEXTURE
	backdrop.visible = true
	frame_texture.visible = false
	newspaper.visible = false
	newspaper_selector.visible = true
	mood_tint.color = Color(0.04, 0.055, 0.07, 0.42)
	location_label.text = "06:24  /  职员宿舍 12-C"
	for child in newspaper_selector.get_children():
		child.queue_free()
	var heading := _make_newspaper_label("今天送到门口的报纸 · 只能精读一份", 24, Color("ded5b8"))
	heading.position = Vector2(0, 0)
	heading.size = Vector2(1192, 42)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	newspaper_selector.add_child(heading)
	var note := _make_newspaper_label("其余报纸只保留头条与摘要；选择后不可改选", 14, Color("929b87"))
	note.position = Vector2(0, 42)
	note.size = Vector2(1192, 26)
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	newspaper_selector.add_child(note)
	var card_width := 278.0
	var gap := 20.0
	var total_width := available_newspapers.size() * card_width + (available_newspapers.size() - 1) * gap
	var start_x := (1192.0 - total_width) * 0.5
	for index in available_newspapers.size():
		var item: Dictionary = available_newspapers[index]
		var card := _build_newspaper_card(item)
		card.position = Vector2(start_x + index * (card_width + gap), 82)
		newspaper_selector.add_child(card)
	dialogue_box.close()
	_publish_phase()


func _build_newspaper_card(item: Dictionary) -> Panel:
	var accent := Color(WorkdayContext.read_string(item, "accent", "a88948"))
	var paper_color := Color(WorkdayContext.read_string(item, "paper_color", "d2c7a2"))
	var issue := WorkdayContext.read_dictionary(item, "issue")
	var card := Panel.new()
	card.size = Vector2(278, 364)
	card.clip_contents = true
	var style := StyleBoxFlat.new()
	style.bg_color = paper_color
	style.border_color = accent
	style.set_border_width_all(4)
	style.shadow_color = Color(0, 0, 0, 0.55)
	style.shadow_size = 8
	style.shadow_offset = Vector2(5, 6)
	card.add_theme_stylebox_override("panel", style)

	var masthead := _make_newspaper_label(WorkdayContext.read_string(item, "name"), 23, Color("25231c"))
	masthead.position = Vector2(16, 16)
	masthead.size = Vector2(246, 34)
	masthead.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card.add_child(masthead)

	var stripe := ColorRect.new()
	stripe.color = accent
	stripe.position = Vector2(18, 57)
	stripe.size = Vector2(242, 5)
	card.add_child(stripe)

	var tagline := _make_newspaper_label(_wrap_card_text(WorkdayContext.read_string(item, "tagline"), 15), 11, Color("5b5547"))
	tagline.position = Vector2(18, 70)
	tagline.size = Vector2(242, 46)
	tagline.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	tagline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card.add_child(tagline)

	var headline := _make_newspaper_label(WorkdayContext.read_string(issue, "headline"), 20, Color("201f19"))
	headline.position = Vector2(18, 124)
	headline.size = Vector2(242, 90)
	headline.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	headline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	headline.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	card.add_child(headline)

	var teaser := _make_newspaper_label(_wrap_card_text(WorkdayContext.read_string(issue, "teaser"), 15), 13, Color("4d493d"))
	teaser.position = Vector2(20, 222)
	teaser.size = Vector2(238, 70)
	teaser.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	teaser.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	teaser.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	card.add_child(teaser)

	var read_button := Button.new()
	read_button.text = "精读这份报纸"
	read_button.position = Vector2(34, 310)
	read_button.size = Vector2(210, 38)
	read_button.add_theme_font_override("font", UI.PIXEL_FONT)
	read_button.add_theme_font_size_override("font_size", 15)
	read_button.pressed.connect(func(): _choose_newspaper(item))
	card.add_child(read_button)
	return card


# 锁定当天选择，并展开该发行商的完整正文。
func _choose_newspaper(item: Dictionary) -> void:
	if item.is_empty():
		return
	selected_newspaper = item.duplicate(true)
	newspaper_selector.visible = false
	_show_newspaper(selected_newspaper)


# 在家中展示选中报纸的完整头版。
func _show_newspaper(item: Dictionary = {}) -> void:
	phase = "newspaper"
	if not item.is_empty():
		selected_newspaper = item.duplicate(true)
	if selected_newspaper.is_empty() and not available_newspapers.is_empty():
		selected_newspaper = available_newspapers[0].duplicate(true)
	var issue := WorkdayContext.read_dictionary(selected_newspaper, "issue")
	backdrop.texture = HOME_TEXTURE
	backdrop.visible = true
	frame_texture.visible = false
	newspaper.visible = true
	newspaper_selector.visible = false
	mood_tint.color = Color(0.04, 0.055, 0.07, 0.28)
	location_label.text = "06:24  /  职员宿舍 12-C"
	var publisher_name := WorkdayContext.read_string(selected_newspaper, "name", "衡川日报")
	edition_label.text = "%s\n%s" % [publisher_name, WorkdayContext.read_string(selected_newspaper, "tagline")]
	headline_label.text = WorkdayContext.read_string(issue, "headline", "今日行政规则等待发布")
	article_label.text = WorkdayContext.read_string(issue, "article", "窗口人员须在上班后收听内部广播。")
	day_label.text = "第 %02d 工作日 · 今日精读" % WorkdayState.day_number
	var accent := Color(WorkdayContext.read_string(selected_newspaper, "accent", "a88948"))
	var paper_color := Color(WorkdayContext.read_string(selected_newspaper, "paper_color", "d2c7a2"))
	var newspaper_style := StyleBoxFlat.new()
	newspaper_style.bg_color = paper_color
	newspaper_style.border_color = accent
	newspaper_style.set_border_width_all(4)
	newspaper_style.shadow_color = Color(0, 0, 0, 0.62)
	newspaper_style.shadow_size = 13
	newspaper_style.shadow_offset = Vector2(9, 10)
	newspaper.add_theme_stylebox_override("panel", newspaper_style)
	dialogue_box.show_line(_player_speaker(), WorkdayContext.read_string(issue, "reflection", "今天的报纸没有更多说明。"), "player")
	_publish_phase()


# 报纸、四拍走路和办事厅入口均由玩家逐拍确认，不设置自动播放计时器。
func advance_sequence() -> void:
	if exiting:
		return
	match phase:
		"newspaper":
			if WorkdayState.manager.mark_newspaper_read(WorkdayContext.read_string(selected_newspaper, "id")):
				_send_secretary_daybrief()
				_show_departure_prompt()
		"departure_prompt":
			_show_walk(0)
		"walking":
			var next_index := walk_index + 1
			if next_index >= WALK_TEXTURES.size():
				_show_arrival()
			else:
				_show_walk(next_index)
		"arrival":
			_enter_workday()


# 精读完成后先给出独立的时间提示；该句仍需玩家再次确认才进入走路播片。
func _show_departure_prompt() -> void:
	phase = "departure_prompt"
	dialogue_box.show_line(_player_speaker(), "时间已经不早了，该去上班了。", "player")
	_publish_phase()


# 将当天精读报纸与既往档案决策整理成眼镜端约定的数据结构。
func _send_secretary_daybrief() -> void:
	var bridge := get_tree().root.get_node_or_null("RealityBridge")
	if bridge == null or selected_newspaper.is_empty():
		return
	var issue := WorkdayContext.read_dictionary(selected_newspaper, "issue")
	var newspaper: Array[Dictionary] = [
		{
			"headline": WorkdayContext.read_string(issue, "headline", "本日无公开头条"),
			"body": WorkdayContext.read_string(issue, "article", WorkdayContext.read_string(issue, "teaser")),
		}
	]
	var decisions: Array[Dictionary] = []
	var first_archive_index := maxi(0, WorkdayState.archived_cases.size() - 12)
	for index: int in range(first_archive_index, WorkdayState.archived_cases.size()):
		var archive: Dictionary = WorkdayState.archived_cases[index]
		var raw_decision := WorkdayContext.read_string(archive, "decision")
		var normalized_decision := "held"
		if raw_decision == "批准":
			normalized_decision = "approved"
		elif raw_decision == "驳回":
			normalized_decision = "rejected"
		(
			decisions
			. append(
				{
					"formId": WorkdayContext.read_string(archive, "case_id"),
					"title": WorkdayContext.read_string(archive, "request", WorkdayContext.read_string(archive, "applicant", "未登记事项")),
					"decision": normalized_decision,
					"day": WorkdayContext.read_int(archive, "archived_day"),
				}
			)
		)
	bridge.call("secretary_daybrief", WorkdayState.day_number, newspaper, decisions)


# 复用已经确认的中性腿部侧视图；停顿拍同步停止脚步声。
func _show_walk(index: int) -> void:
	phase = "walking"
	walk_index = clampi(index, 0, WALK_TEXTURES.size() - 1)
	backdrop.visible = false
	newspaper.visible = false
	frame_texture.visible = true
	frame_texture.texture = load(WALK_TEXTURES[walk_index])
	mood_tint.color = Color(0, 0, 0, 0)
	location_label.text = "06:41  /  通往第十二区综合办事厅"
	if walk_index == STOPPED_WALK_INDEX:
		_stop_footsteps()
	else:
		_start_footsteps()
	dialogue_box.show_line(_player_speaker(), walk_lines[walk_index], "player")
	_flash_slide()
	_publish_phase()


# 最后一拍停在办事厅入口；嘈杂声此时先以较高音量进入，等待玩家推门。
func _show_arrival() -> void:
	phase = "arrival"
	_stop_footsteps()
	backdrop.texture = ARRIVAL_TEXTURE
	backdrop.visible = true
	frame_texture.visible = false
	newspaper.visible = false
	mood_tint.color = Color(0.025, 0.035, 0.03, 0.36)
	location_label.text = "06:57  /  第十二区综合办事厅"
	Sfx.start_arrival_ambience()
	dialogue_box.show_line(_player_speaker(), "门后已经很吵。推门进去。", "player")
	_flash_slide()
	_publish_phase()


# 玩家确认推门后进入工作台；环境声持续到广播开始，再由广播模块渐退压低。
func _enter_workday() -> void:
	if exiting:
		return
	exiting = true
	preserve_arrival_ambience = true
	dialogue_box.close()
	Sfx.play("door")
	fade.visible = true
	fade.modulate.a = 0.0
	var outro := create_tween()
	outro.tween_property(fade, "modulate:a", 1.0, 0.48)
	await outro.finished
	var error := get_tree().change_scene_to_file(MAIN_SCENE)
	if error != OK:
		exiting = false
		preserve_arrival_ambience = false
		fade.visible = false
		dialogue_box.show_line("内部提示", "办事厅的门没有打开。", "warning")


# 自动化测试可直接切换到目标拍，但仍使用正式 UI 与音频路径。
func show_phase_for_tests(target_phase: String, index := 0) -> void:
	match target_phase:
		"newspaper":
			if available_newspapers.is_empty():
				available_newspapers = WorkdayState.manager.get_available_newspapers()
			_show_newspaper(available_newspapers[0] if not available_newspapers.is_empty() else {})
		"newspaper_selection":
			_show_newspaper_selection()
		"departure_prompt":
			_show_departure_prompt()
		"walking":
			_show_walk(index)
		"arrival":
			_show_arrival()


# 自动化测试跳过淡出，验证晨间序列的最终入口。
func finish_for_tests() -> void:
	if exiting:
		return
	exiting = true
	preserve_arrival_ambience = true
	_stop_footsteps()
	dialogue_box.close()
	get_tree().change_scene_to_file(MAIN_SCENE)


# 从独立配置读取当前工作日的晨报和心理活动。
func _load_day_content() -> Dictionary:
	if FileAccess.file_exists(CONFIG_PATH):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(CONFIG_PATH))
		if parsed is Dictionary:
			for value: Variant in WorkdayContext.read_array(parsed, "days"):
				if value is Dictionary and WorkdayContext.read_int(value, "day") == WorkdayState.day_number:
					@warning_ignore("unsafe_cast")
					var configured: Dictionary = value
					return configured.duplicate(true)
	return {
		"edition": "晨版",
		"headline": "今日行政规则等待发布",
		"article": "详细内容将在到岗后的内部广播中说明。",
		"home_line": "报纸没有写完。",
		"walk_lines": ["……", "到岗以后再听一遍。", "再确认一下。", "……"],
	}


# 保证配置缺行时仍有完整四拍，不允许数据错误破坏手动过场。
func _read_walk_lines(source: Dictionary) -> Array[String]:
	var result: Array[String] = []
	for value: Variant in WorkdayContext.read_array(source, "walk_lines"):
		result.append(WorkdayContext.stringify_value(value))
	while result.size() < WALK_TEXTURES.size():
		result.append("……")
	result.resize(WALK_TEXTURES.size())
	return result


# 玩家心理活动沿用开局输入姓名，不补充主角性别。
func _player_speaker() -> String:
	return WorkdayState.player_name if not WorkdayState.player_name.is_empty() else "经办员"


func _make_newspaper_label(text_value: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text_value
	label.add_theme_font_override("font", UI.PIXEL_FONT)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


# 像素字体对连续中文的自动换行并不稳定，卡片摘要按可读字符数主动分行。
func _wrap_card_text(text_value: String, characters_per_line: int) -> String:
	var text := text_value.strip_edges()
	if text.length() <= characters_per_line:
		return text
	var lines: Array[String] = []
	var cursor := 0
	while cursor < text.length():
		lines.append(text.substr(cursor, characters_per_line))
		cursor += characters_per_line
	return "\n".join(lines)


# 短促黑场只负责换拍质感，不触发下一句或下一张画面。
func _flash_slide() -> void:
	slide_flash.visible = true
	slide_flash.modulate.a = 0.76
	var flash := create_tween()
	flash.tween_property(slide_flash, "modulate:a", 0.0, 0.14)
	flash.finished.connect(func(): slide_flash.visible = false)


# 对外同步当前晨间阶段，方便眼镜端和自动化测试识别。
func _publish_phase() -> void:
	GameStateSync.scene_changed("pre_work_sequence", phase, {"day": WorkdayState.day_number, "walk_index": walk_index})


# 行走拍持续播放循环脚步声。
func _start_footsteps() -> void:
	if footsteps_active:
		return
	footsteps_active = true
	Sfx.start_walking()


# 停步、抵达和离场时停止脚步声。
func _stop_footsteps() -> void:
	if not footsteps_active:
		return
	footsteps_active = false
	Sfx.stop_walking()


# 非正常离开晨间场景时清理循环声；进入工作台时保留已建立的大厅声场。
func _exit_tree() -> void:
	_stop_footsteps()
	if not preserve_arrival_ambience:
		Sfx.stop_ambience()


# 以 1280×720 设计基准适配实际窗口。
func _fit_to_window() -> void:
	var viewport_size := get_viewport_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return
	scale = Vector2(viewport_size.x / DESIGN_SIZE.x, viewport_size.y / DESIGN_SIZE.y)
	position = Vector2.ZERO
