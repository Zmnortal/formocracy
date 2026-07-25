extends Control

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
	_build_dialogue_box()
	get_viewport().size_changed.connect(_fit_to_window)
	_fit_to_window()
	_show_newspaper()
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


# 在家中展示当天报纸头版；报纸内容由七日配置驱动。
func _show_newspaper() -> void:
	phase = "newspaper"
	backdrop.texture = HOME_TEXTURE
	backdrop.visible = true
	frame_texture.visible = false
	newspaper.visible = true
	mood_tint.color = Color(0.04, 0.055, 0.07, 0.28)
	location_label.text = "06:24  /  职员宿舍 12-C"
	edition_label.text = "衡川日报 · 第十二区晨版\n%s" % WorkdayContext.read_string(day_content, "edition", "晨版")
	headline_label.text = WorkdayContext.read_string(day_content, "headline", "今日行政规则等待发布")
	article_label.text = WorkdayContext.read_string(day_content, "article", "窗口人员须在上班后收听内部广播。")
	day_label.text = "第 %02d 工作日" % WorkdayState.day_number
	dialogue_box.show_line(
		_player_speaker(),
		WorkdayContext.read_string(day_content, "home_line", "今天的报纸没有更多说明。"),
		"player"
	)
	_publish_phase()


# 报纸、四拍走路和办事厅入口均由玩家逐拍确认，不设置自动播放计时器。
func advance_sequence() -> void:
	if exiting:
		return
	match phase:
		"newspaper":
			_show_walk(0)
		"walking":
			var next_index := walk_index + 1
			if next_index >= WALK_TEXTURES.size():
				_show_arrival()
			else:
				_show_walk(next_index)
		"arrival":
			_enter_workday()


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
			_show_newspaper()
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


# 短促黑场只负责换拍质感，不触发下一句或下一张画面。
func _flash_slide() -> void:
	slide_flash.visible = true
	slide_flash.modulate.a = 0.76
	var flash := create_tween()
	flash.tween_property(slide_flash, "modulate:a", 0.0, 0.14)
	flash.finished.connect(func(): slide_flash.visible = false)


# 对外同步当前晨间阶段，方便眼镜端和自动化测试识别。
func _publish_phase() -> void:
	GameStateSync.scene_changed(
		"pre_work_sequence",
		phase,
		{"day": WorkdayState.day_number, "walk_index": walk_index}
	)


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
